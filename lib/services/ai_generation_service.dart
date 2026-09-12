import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../models/quiz.dart';
import '../models/question.dart';
import '../models/ai_provider.dart';
import '../models/ai_provider_profile.dart';
import '../services/secure_storage_service.dart';
import '../services/ai_provider_service.dart';
import '../services/generation_capability_resolver.dart';
import '../services/generation_plan.dart';
import '../services/generation_recovery_policy.dart';
import '../utils/ai_prompt_templates.dart';

/// Custom exception for validation failures that include partial results
class _ValidationException implements Exception {
  final String message;
  final List<Question> validQuestions;
  final int malformedCount;

  _ValidationException({
    required this.message,
    required this.validQuestions,
    required this.malformedCount,
  });

  @override
  String toString() => message;
}

/// Service for AI-powered quiz generation using various providers (Gemini, OpenAI, Claude)
class AiGenerationService {
  final SecureStorageService _storage = SecureStorageService.instance;

  /// HTTP client used for API requests - can be closed to cancel ongoing requests
  http.Client? _httpClient;

  /// Cancellation flag to stop generation
  bool _isCancelled = false;

  /// Cancel any ongoing generation
  void cancelGeneration() {
    debugPrint('[AiGenerationService] Cancellation requested');
    _isCancelled = true;
    // Close the HTTP client to immediately cancel any ongoing request
    _httpClient?.close();
    _httpClient = null;
  }

  /// Reset cancellation state before starting new generation
  void _resetCancellation() {
    _isCancelled = false;
    _httpClient = http.Client();
  }

  /// Check if generation was cancelled
  void _checkCancellation() {
    if (_isCancelled) {
      throw AiGenerationException('Generation cancelled by user');
    }
  }

  /// Timeout for API requests - dynamic based on request size
  /// This is intentionally generous to account for:
  /// - AI model processing time (thinking + generation)
  /// - Network latency variations (mobile data, WiFi, etc.)
  /// - API server load fluctuations
  static Duration _getTimeout(int numberOfStems) {
    // Base timeout of 90 seconds + 10 seconds per stem
    // For 20 stems: 90 + (20 * 10) = 290 seconds (~4.8 minutes)
    // For 10 stems: 90 + (10 * 10) = 190 seconds (~3.2 minutes)
    // Minimum: 120s (2 minutes) for very small requests
    // Maximum: 360s (6 minutes) to avoid indefinite waits
    final calculatedTimeout = 90 + (numberOfStems * 10);
    return Duration(seconds: calculatedTimeout.clamp(120, 360));
  }

  /// Maximum retries for failed requests
  /// We keep retries to handle genuine network failures, but with generous
  /// timeouts, most legitimate requests should succeed on first attempt
  static const int _maxRetries =
      2; // Reduced from 3 since timeout is now generous

  /// Maximum stems per batch to avoid rate limits and token limits
  static const int _maxStemsPerBatch = 20;

  /// Public accessor for the configured batch size so UI code can reflect
  /// batch-level progress (number of stems sent per request).
  static int get batchSize => _maxStemsPerBatch;

  /// Maximum number of batches to run concurrently to speed up generation without
  /// increasing per-request token load. Set to 1 for fully sequential behavior.
  // Note: concurrency disabled; batches run sequentially to allow cross-batch avoidance

  /// Delay between batches to avoid rate limiting (in milliseconds)
  /// Applied for requests with multiple batches
  /// For very large requests (>50 stems), uses longer delay
  static int _getBatchDelay(int totalStems) {
    if (totalStems <= 50) return 500; // 0.5s for moderate requests
    if (totalStems <= 80) return 1000; // 1s for large requests
    return 1500; // 1.5s for very large requests (80+ stems)
  }

  /// Number of attempts to refill missing / deduplicated stems
  static const int _maxRefillAttempts = 2;

  /// Similarity threshold above which two stems are considered near-duplicates
  /// Lower values => more aggressive deduplication. 0.0..1.0
  static const double _dedupeSimilarityThreshold = 0.5;

  /// Maximum characters for the 'avoid' snippet sent to the model per batch
  static const int _maxAvoidSnippetChars = 1500;

  /// Generate a complete quiz using AI
  Future<Quiz> generateQuiz({
    required String topic,
    required int numberOfStems,
    required int branchesPerStem,
    required String difficulty,
    AiProvider provider = AiProvider.gemini,
    AiProviderProfile? profile,
    String? customModel,
    String? questionStyle,
    String? subjectCategory,
    String? sampleQuestions,
    String? additionalInstructions,
    void Function(int current, int total)? onProgress,
  }) async {
    // Get API key from secure storage
    final apiKey = profile == null
        ? await _storage.getApiKey(provider.id)
        : await _storage.getProfileApiKey(profile.id);
    if (apiKey == null || apiKey.isEmpty) {
      throw AiGenerationException(
        'API key not found. Configure this provider in AI settings.',
      );
    }

    // Get the AI model to use
    final model =
        profile?.selectedModelId ?? customModel ?? provider.recommendedModel;

    // Reset cancellation state and create new HTTP client for this generation
    _resetCancellation();

    try {
      // Normalize difficulty to our allowed taxonomy to ensure prompts receive expected values
      final normalizedDifficulty = AiPromptTemplates.normalizeDifficulty(
        difficulty,
      );
      if (normalizedDifficulty != difficulty.toLowerCase()) {
        debugPrint(
          '[AiGenerationService] Normalized difficulty "$difficulty" -> "$normalizedDifficulty"',
        );
      }

      // Warn about very large requests and estimate time
      if (numberOfStems > 50) {
        final numBatches = (numberOfStems / _maxStemsPerBatch).ceil();
        final estimatedMinutes = (numBatches * 5)
            .toInt(); // ~5 minutes per batch (conservative estimate)
        debugPrint(
          '[AiGenerationService] ⚠️ Large request detected: $numberOfStems stems',
        );
        debugPrint(
          '[AiGenerationService] This will be split into $numBatches batches',
        );
        debugPrint(
          '[AiGenerationService] Estimated time: ~$estimatedMinutes minutes',
        );
        debugPrint(
          '[AiGenerationService] Please keep the app in the foreground and ensure stable connectivity',
        );
      }

      // Report initial progress
      onProgress?.call(0, numberOfStems);

      // Generate the quiz based on provider
      Quiz quiz;
      if (profile != null) {
        if (!profile.isReady) {
          throw AiGenerationException(
            'The active AI profile is not verified. Test its selected model in AI settings.',
          );
        }
        final capabilities = await GenerationCapabilityResolver().forProfile(
          profile,
        );
        final plan = GenerationPlanner.build(
          profile: profile,
          request: GenerationRequestShape(
            totalStems: numberOfStems,
            branchesPerStem: branchesPerStem,
            questionStyle: questionStyle,
            sampleCharacters: sampleQuestions?.length ?? 0,
            additionalInstructionCharacters:
                additionalInstructions?.length ?? 0,
          ),
          capabilities: capabilities,
        );
        debugPrint(
          '[AiGenerationService] Adaptive plan: ${plan.targetStemsPerRequest} stems/request, ${plan.maxOutputTokensPerRequest} max output tokens',
        );
        quiz = await _generateWithProfile(
          profile: profile,
          plan: plan,
          apiKey: apiKey,
          topic: topic,
          numberOfStems: numberOfStems,
          branchesPerStem: branchesPerStem,
          difficulty: normalizedDifficulty,
          questionStyle: questionStyle,
          subjectCategory: subjectCategory,
          sampleQuestions: sampleQuestions,
          additionalInstructions: additionalInstructions,
          onProgress: onProgress,
        );
      } else {
        switch (provider) {
          case AiProvider.gemini:
            quiz = await _generateWithGemini(
              apiKey: apiKey,
              model: model,
              topic: topic,
              numberOfStems: numberOfStems,
              branchesPerStem: branchesPerStem,
              difficulty: normalizedDifficulty,
              questionStyle: questionStyle,
              subjectCategory: subjectCategory,
              sampleQuestions: sampleQuestions,
              additionalInstructions: additionalInstructions,
              onProgress: onProgress,
            );
            break;
          case AiProvider.openai:
            quiz = await _generateWithOpenAI(
              apiKey: apiKey,
              model: model,
              topic: topic,
              numberOfStems: numberOfStems,
              branchesPerStem: branchesPerStem,
              difficulty: normalizedDifficulty,
              onProgress: onProgress,
            );
            break;
          case AiProvider.claude:
            quiz = await _generateWithClaude(
              apiKey: apiKey,
              model: model,
              topic: topic,
              numberOfStems: numberOfStems,
              branchesPerStem: branchesPerStem,
              difficulty: normalizedDifficulty,
              onProgress: onProgress,
            );
            break;
        }
      }

      // Final progress update
      onProgress?.call(numberOfStems, numberOfStems);

      return quiz;
    } catch (e) {
      debugPrint('[AiGenerationService] Error generating quiz: $e');
      rethrow;
    } finally {
      // Clean up HTTP client
      _httpClient?.close();
      _httpClient = null;
    }
  }

  /// Generate answer keys for existing questions using AI
  Future<Map<int, Map<String, dynamic>>> generateAnswerKeys({
    required List<Question> questions,
    AiProvider provider = AiProvider.gemini,
    AiProviderProfile? profile,
    String? customModel,
    void Function(int current, int total)? onProgress,
  }) async {
    // Get API key from secure storage
    final apiKey = profile == null
        ? await _storage.getApiKey(provider.id)
        : await _storage.getProfileApiKey(profile.id);
    if (apiKey == null || apiKey.isEmpty) {
      throw AiGenerationException(
        'API key not found. Configure this provider in AI settings.',
      );
    }

    // Get the AI model to use
    final model =
        profile?.selectedModelId ?? customModel ?? provider.recommendedModel;

    // Reset cancellation state and create new HTTP client for this generation
    _resetCancellation();

    try {
      debugPrint(
        '[AiGenerationService] Generating answer keys for ${questions.length} questions',
      );

      // Report initial progress
      onProgress?.call(0, questions.length);

      // Process in batches to avoid overwhelming the API and reduce JSON parsing errors
      const batchSize = 20; // Process 20 questions at a time
      final allAnswerKeys = <int, Map<String, dynamic>>{};

      for (
        int batchStart = 0;
        batchStart < questions.length;
        batchStart += batchSize
      ) {
        if (_isCancelled) {
          throw AiGenerationException('Generation cancelled by user');
        }

        final batchEnd = (batchStart + batchSize).clamp(0, questions.length);
        final batchQuestions = questions.sublist(batchStart, batchEnd);

        debugPrint(
          '[AiGenerationService] Processing batch ${batchStart ~/ batchSize + 1} of ${(questions.length / batchSize).ceil()} (questions ${batchStart + 1}-$batchEnd)',
        );

        // Build the prompt for this batch
        final prompt = _buildAnswerKeyPrompt(
          batchQuestions,
          startIndex: batchStart,
        );

        // Generate answer keys based on provider
        Map<String, dynamic> response;
        if (profile != null) {
          if (!profile.isReady) {
            throw AiGenerationException(
              'The active AI profile is not verified. Test it in AI settings.',
            );
          }
          response = await _generateAnswerKeysWithProfile(
            profile: profile,
            apiKey: apiKey,
            prompt: prompt,
          );
        } else {
          switch (provider) {
            case AiProvider.gemini:
              response = await _generateAnswerKeysWithGemini(
                apiKey: apiKey,
                model: model,
                prompt: prompt,
              );
              break;
            case AiProvider.openai:
              response = await _generateAnswerKeysWithOpenAI(
                apiKey: apiKey,
                model: model,
                prompt: prompt,
              );
              break;
            case AiProvider.claude:
              response = await _generateAnswerKeysWithClaude(
                apiKey: apiKey,
                model: model,
                prompt: prompt,
              );
              break;
          }
        }

        // Parse the response and add to the combined result
        final batchAnswerKeys = _parseAnswerKeyResponse(
          response,
          batchQuestions.length,
          startIndex: batchStart,
        );
        allAnswerKeys.addAll(batchAnswerKeys);

        // Update progress
        onProgress?.call(batchEnd, questions.length);

        // Small delay between batches to avoid rate limiting
        if (batchEnd < questions.length) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }

      return allAnswerKeys;
    } catch (e) {
      debugPrint('[AiGenerationService] Error generating answer keys: $e');
      rethrow;
    } finally {
      // Clean up HTTP client
      _httpClient?.close();
      _httpClient = null;
    }
  }

  Future<Quiz> _generateWithProfile({
    required AiProviderProfile profile,
    required GenerationPlan plan,
    required String apiKey,
    required String topic,
    required int numberOfStems,
    required int branchesPerStem,
    required String difficulty,
    String? questionStyle,
    String? subjectCategory,
    String? sampleQuestions,
    String? additionalInstructions,
    void Function(int current, int total)? onProgress,
  }) async {
    final client = _httpClient;
    if (client == null) {
      throw AiGenerationException('Generation cancelled by user');
    }
    final adapter = AiProviderService(client: client);
    final allQuestions = <Question>[];
    var activeBatchSize = plan.targetStemsPerRequest;
    var failureAttempt = 0;

    while (allQuestions.length < numberOfStems) {
      _checkCancellation();
      final remaining = numberOfStems - allQuestions.length;
      final count = remaining.clamp(1, activeBatchSize);
      final prompt = count > 30
          ? AiPromptTemplates.generateConcisePrompt(
              topic: topic,
              numberOfStems: count,
              branchesPerStem: branchesPerStem,
              difficulty: difficulty,
              questionStyle: questionStyle,
              subjectCategory: subjectCategory,
            )
          : AiPromptTemplates.generateQuizPrompt(
              topic: topic,
              numberOfStems: count,
              branchesPerStem: branchesPerStem,
              difficulty: difficulty,
              questionStyle: questionStyle,
              subjectCategory: subjectCategory,
              sampleQuestions: sampleQuestions,
              additionalInstructions: additionalInstructions,
            );
      final allowsScenario =
          questionStyle?.toLowerCase() == 'clinical scenario';
      final systemInstruction = AiPromptTemplates.getSystemInstruction(
        subjectContext: subjectCategory,
        enforceDirectFormat: !allowsScenario,
      );

      try {
        final responseText = await adapter.generateText(
          profile,
          apiKey,
          systemPrompt: systemInstruction,
          userPrompt: prompt,
          maxTokens: plan.maxOutputTokensPerRequest,
          temperature: questionStyle?.toLowerCase() == 'true_false_statement'
              ? 0.1
              : 0.2,
        );
        final batch = await _parseQuizFromJson(
          responseText,
          topic,
          count,
          branchesPerStem,
          questionStyle: questionStyle,
          sampleQuestions: sampleQuestions,
          reformatAttempted: true,
        );
        allQuestions.addAll(batch.questions.take(remaining));
        failureAttempt = 0;
        activeBatchSize = plan.targetStemsPerRequest;
      } on _ValidationException catch (error) {
        if (error.validQuestions.isNotEmpty) {
          allQuestions.addAll(error.validQuestions.take(remaining));
          failureAttempt = 0;
          activeBatchSize = plan.targetStemsPerRequest;
        } else {
          failureAttempt++;
          final decision = GenerationRecoveryPolicy.decide(
            plan: plan,
            failure: GenerationFailureKind.malformedOrTruncated,
            attemptedBatchSize: count,
            attempt: failureAttempt,
          );
          if (!decision.retry) {
            throw AiGenerationException(error.message);
          }
          activeBatchSize = decision.nextBatchSize;
          if (decision.backoff > Duration.zero) {
            await Future.delayed(decision.backoff);
          }
          continue;
        }
      } on AiProviderException catch (error) {
        failureAttempt++;
        final failure = GenerationRecoveryPolicy.classifyMessage(error.message);
        final decision = GenerationRecoveryPolicy.decide(
          plan: plan,
          failure: failure,
          attemptedBatchSize: count,
          attempt: failureAttempt,
        );
        if (!decision.retry || failure == GenerationFailureKind.unknown) {
          throw AiGenerationException(error.message);
        }
        debugPrint(
          '[AiGenerationService] Adaptive retry after $failure: $count -> ${decision.nextBatchSize} stems',
        );
        activeBatchSize = decision.nextBatchSize;
        if (decision.backoff > Duration.zero) {
          await Future.delayed(decision.backoff);
        }
        continue;
      } on TimeoutException catch (error) {
        failureAttempt++;
        final decision = GenerationRecoveryPolicy.decide(
          plan: plan,
          failure: GenerationFailureKind.timeout,
          attemptedBatchSize: count,
          attempt: failureAttempt,
        );
        if (!decision.retry) {
          throw AiGenerationException('Generation timed out: $error');
        }
        activeBatchSize = decision.nextBatchSize;
        if (decision.backoff > Duration.zero) {
          await Future.delayed(decision.backoff);
        }
        continue;
      }

      onProgress?.call(
        allQuestions.length.clamp(0, numberOfStems),
        numberOfStems,
      );
    }

    if (allQuestions.isEmpty) {
      throw AiGenerationException('The model returned no valid questions.');
    }
    return Quiz(
      title: 'Quiz on $topic',
      questions: allQuestions.take(numberOfStems).toList(),
    );
  }

  Future<Map<String, dynamic>> _generateAnswerKeysWithProfile({
    required AiProviderProfile profile,
    required String apiKey,
    required String prompt,
  }) async {
    final client = _httpClient;
    if (client == null)
      throw AiGenerationException('Generation cancelled by user');
    try {
      final text = await AiProviderService(client: client).generateText(
        profile,
        apiKey,
        systemPrompt: 'Return only valid JSON. Do not wrap it in Markdown or add commentary.',
        userPrompt: prompt,
        maxTokens: 20000,
        temperature: 0.2,
      );
      var cleaned = text.trim();
      cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
      try {
        return Map<String, dynamic>.from(jsonDecode(cleaned) as Map);
      } catch (_) {
        return Map<String, dynamic>.from(
          jsonDecode(_sanitizeJsonQuotes(cleaned)) as Map,
        );
      }
    } on AiProviderException catch (error) {
      throw AiGenerationException(error.message);
    } catch (error) {
      if (error is AiGenerationException) rethrow;
      throw AiGenerationException(
        'The model returned malformed answer-key JSON.',
      );
    }
  }

  /// Generate quiz using Google Gemini API
  Future<Quiz> _generateWithGemini({
    required String apiKey,
    required String model,
    required String topic,
    required int numberOfStems,
    required int branchesPerStem,
    required String difficulty,
    String? questionStyle,
    String? subjectCategory,
    String? sampleQuestions,
    String? additionalInstructions,
    void Function(int current, int total)? onProgress,
  }) async {
    // If number of stems exceeds batch limit, split into multiple requests
    if (numberOfStems > _maxStemsPerBatch) {
      return await _generateInBatches(
        apiKey: apiKey,
        model: model,
        topic: topic,
        numberOfStems: numberOfStems,
        branchesPerStem: branchesPerStem,
        difficulty: difficulty,
        questionStyle: questionStyle,
        subjectCategory: subjectCategory,
        sampleQuestions: sampleQuestions,
        additionalInstructions: additionalInstructions,
        onProgress: onProgress,
      );
    }

    // Single batch generation for smaller requests
    return await _generateSingleBatch(
      apiKey: apiKey,
      model: model,
      topic: topic,
      numberOfStems: numberOfStems,
      branchesPerStem: branchesPerStem,
      difficulty: difficulty,
      questionStyle: questionStyle,
      subjectCategory: subjectCategory,
      sampleQuestions: sampleQuestions,
      additionalInstructions: additionalInstructions,
      onProgress: onProgress,
    );
  }

  /// Generate quiz in multiple batches to avoid rate limits
  Future<Quiz> _generateInBatches({
    required String apiKey,
    required String model,
    required String topic,
    required int numberOfStems,
    required int branchesPerStem,
    required String difficulty,
    String? questionStyle,
    String? subjectCategory,
    String? sampleQuestions,
    String? additionalInstructions,
    void Function(int current, int total)? onProgress,
  }) async {
    debugPrint(
      '[AiGenerationService] Large request detected: $numberOfStems stems. Splitting into batches...',
    );

    final List<Question> allQuestions = [];
    int processedStems = 0;

    // Calculate number of batches needed
    final int numBatches = (numberOfStems / _maxStemsPerBatch).ceil();
    debugPrint('[AiGenerationService] Will generate in $numBatches batches');

    // Create a list of batch sizes ahead of time
    final batchSizes = <int>[];
    int remaining = numberOfStems;
    while (remaining > 0) {
      final take = remaining > _maxStemsPerBatch
          ? _maxStemsPerBatch
          : remaining;
      batchSizes.add(take);
      remaining -= take;
    }

    // Execute batches sequentially and pass already-generated stems as an avoid list
    for (int i = 0; i < batchSizes.length; i++) {
      // Check if cancelled before starting each batch
      _checkCancellation();

      final stemsInThisBatch = batchSizes[i];
      debugPrint(
        '[AiGenerationService] Generating sequential batch ${i + 1}/${batchSizes.length}: $stemsInThisBatch stems',
      );

      // Build a short 'avoid' instruction listing already-generated stems so the model
      // avoids producing overlapping titles/stems across batches.
      String existingStemsSnippet = allQuestions
          .map((q) => '- ${_shortenStem(q.questionText)}')
          .join('\n');
      if (existingStemsSnippet.length > _maxAvoidSnippetChars) {
        existingStemsSnippet =
            existingStemsSnippet.substring(0, _maxAvoidSnippetChars) +
            '\n- ... (truncated)';
      }
      final batchAdditionalInstructions =
          (additionalInstructions?.isNotEmpty == true)
          ? '$additionalInstructions\n\nAvoid repeating these existing stems:\n$existingStemsSnippet'
          : 'Avoid repeating these existing stems:\n$existingStemsSnippet';

      final batchQuiz = await _generateSingleBatch(
        apiKey: apiKey,
        model: model,
        topic: topic,
        numberOfStems: stemsInThisBatch,
        branchesPerStem: branchesPerStem,
        difficulty: difficulty,
        questionStyle: questionStyle,
        subjectCategory: subjectCategory,
        sampleQuestions: sampleQuestions,
        additionalInstructions: batchAdditionalInstructions,
        // Suppress per-question progress during batch generation; we'll report
        // progress once the batch is successfully parsed to avoid transient
        // retry/attempt updates confusing the UI.
        onProgress: null,
        emitPerQuestionProgress: false,
      );

      allQuestions.addAll(batchQuiz.questions);
      processedStems += batchQuiz.questions.length;

      // Report progress at batch granularity: number of successfully parsed
      // stems so far out of the original requested total.
      onProgress?.call(processedStems, numberOfStems);

      debugPrint(
        '[AiGenerationService] Batch ${i + 1} complete. Total questions so far: ${allQuestions.length}',
      );

      // Delay between batches to avoid rate limiting
      if (i + 1 < batchSizes.length) {
        final delayMs = _getBatchDelay(numberOfStems);
        debugPrint(
          '[AiGenerationService] Waiting ${delayMs}ms before next batch (${i + 2}/${batchSizes.length}) to avoid rate limiting...',
        );
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    debugPrint(
      '[AiGenerationService] All batches complete. Total questions generated: ${allQuestions.length}',
    );

    // Post-process: remove near-duplicate stems and attempt refills if we dropped any
    final processedQuestions = await _dedupeAndRefillIfNeeded(
      apiKey: apiKey,
      model: model,
      topic: topic,
      questions: allQuestions,
      desiredCount: numberOfStems,
      branchesPerStem: branchesPerStem,
      difficulty: difficulty,
      questionStyle: questionStyle,
      subjectCategory: subjectCategory,
      sampleQuestions: sampleQuestions,
    );

    // Combine all batches into a single quiz
    return Quiz(title: 'Quiz on $topic', questions: processedQuestions);
  }

  /// Generate a single batch of questions
  Future<Quiz> _generateSingleBatch({
    required String apiKey,
    required String model,
    required String topic,
    required int numberOfStems,
    required int branchesPerStem,
    required String difficulty,
    String? questionStyle,
    String? subjectCategory,
    String? sampleQuestions,
    String? additionalInstructions,
    void Function(int current, int total)? onProgress,
    // When false, suppress per-question progress callbacks and let the caller
    // report progress at batch granularity. Used by _generateInBatches so the
    // UI shows completed batches (e.g., 20/60 -> 33%) instead of per-question
    // increments during long multi-batch runs.
    bool emitPerQuestionProgress = true,
    // Internal: track validation retry attempts
    int validationAttempt = 0,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    // Use concise prompt for large numbers of stems to reduce token usage
    String prompt = numberOfStems > 30
        ? AiPromptTemplates.generateConcisePrompt(
            topic: topic,
            numberOfStems: numberOfStems,
            branchesPerStem: branchesPerStem,
            difficulty: difficulty,
            questionStyle: questionStyle,
            subjectCategory: subjectCategory,
          )
        : AiPromptTemplates.generateQuizPrompt(
            topic: topic,
            numberOfStems: numberOfStems,
            branchesPerStem: branchesPerStem,
            difficulty: difficulty,
            questionStyle: questionStyle,
            subjectCategory: subjectCategory,
            sampleQuestions: sampleQuestions,
            additionalInstructions: additionalInstructions,
          );

    // If the requested question style is NOT a scenario/vignette type,
    // explicitly forbid scenario-like or vignette stems in the prompt.
    // This prevents the model from returning case-based/multi-sentence
    // stems when the UI requested concise statement-style questions.
    // Only allow scenario/vignette outputs when questionStyle explicitly equals 'Clinical Scenario'
    final allowsScenario =
        questionStyle != null &&
        questionStyle.toLowerCase() == 'clinical scenario';

    final systemInstruction = AiPromptTemplates.getSystemInstruction(
      subjectContext: subjectCategory,
      enforceDirectFormat: !allowsScenario,
    );

    debugPrint(
      '[AiGenerationService] Using ${numberOfStems > 30 ? "CONCISE" : "DETAILED"} prompt for $numberOfStems stems',
    );
    debugPrint(
      '[AiGenerationService] Question Style: ${questionStyle ?? "mixed"}',
    );
    debugPrint(
      '[AiGenerationService] Subject Category: ${subjectCategory ?? "general"}',
    );

    // Prepare request body for Gemini
    // Lower temperature and prefer DETAILED prompt for strict true_false style
    double generationTemp = 0.2;
    if (questionStyle != null &&
        questionStyle.toLowerCase() == 'true_false_statement') {
      generationTemp = 0.1; // deterministic for strict true/false
    }

    final requestBody = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': systemInstruction},
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': generationTemp,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 30000, // Increased for larger responses
        'responseMimeType': 'application/json',
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_ONLY_HIGH',
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_ONLY_HIGH',
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_ONLY_HIGH',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_ONLY_HIGH',
        },
      ],
    });

    // Make API request with retries
    String? responseText;
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        // Check if cancelled before starting attempt
        _checkCancellation();

        debugPrint(
          '[AiGenerationService] Attempt $attempt: Sending request to Gemini API...',
        );

        final timeout = _getTimeout(numberOfStems);
        debugPrint(
          '[AiGenerationService] Using timeout: ${timeout.inSeconds}s for $numberOfStems stems',
        );

        // Use the cancellable HTTP client
        if (_httpClient == null) {
          throw AiGenerationException('Generation cancelled by user');
        }

        final response = await _httpClient!
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: requestBody,
            )
            .timeout(timeout);

        debugPrint(
          '[AiGenerationService] Response status: ${response.statusCode}',
        );
        debugPrint(
          '[AiGenerationService] Response body length: ${response.body.length} bytes',
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          debugPrint('[AiGenerationService] Parsed response data structure');

          // Extract text from Gemini response
          if (data['candidates'] != null &&
              data['candidates'].isNotEmpty &&
              data['candidates'][0]['content'] != null &&
              data['candidates'][0]['content']['parts'] != null &&
              data['candidates'][0]['content']['parts'].isNotEmpty) {
            responseText = data['candidates'][0]['content']['parts'][0]['text'];

            debugPrint(
              '[AiGenerationService] Extracted response text length: ${responseText?.length ?? 0} characters',
            );
            debugPrint(
              '[AiGenerationService] Response text preview (first 500 chars): ${responseText?.substring(0, responseText.length > 500 ? 500 : responseText.length)}',
            );

            // Check for finish reason
            final finishReason = data['candidates'][0]['finishReason'];
            debugPrint('[AiGenerationService] Finish reason: $finishReason');

            if (finishReason == 'MAX_TOKENS') {
              debugPrint(
                '[AiGenerationService] WARNING: Response was truncated due to max tokens',
              );
              throw AiGenerationException(
                'Response too long - try reducing number of stems or use concise prompt',
              );
            }

            break;
          } else {
            throw AiGenerationException(
              'Invalid response structure from Gemini API',
            );
          }
        } else if (response.statusCode == 429) {
          // Rate limit - wait and retry
          if (attempt < _maxRetries) {
            await Future.delayed(Duration(seconds: attempt * 2));
            continue;
          }
          throw AiGenerationException(
            'Rate limit exceeded. Please try again later.',
          );
        } else if (response.statusCode == 401) {
          throw AiGenerationException(
            'Invalid API key. Please check your settings.',
          );
        } else {
          final errorData = jsonDecode(response.body);
          throw AiGenerationException(
            'API Error (${response.statusCode}): ${errorData['error']?['message'] ?? 'Unknown error'}',
          );
        }
      } on TimeoutException {
        final timeoutUsed = _getTimeout(numberOfStems);
        if (attempt < _maxRetries) {
          // Exponential backoff: 3s, 6s for retries
          final delaySeconds = 3 * attempt;
          debugPrint(
            '[AiGenerationService] ⚠️ Timeout on attempt $attempt/$_maxRetries after ${timeoutUsed.inSeconds}s.',
          );
          debugPrint(
            '[AiGenerationService] This suggests the API is overloaded or your connection is slow.',
          );
          debugPrint(
            '[AiGenerationService] Waiting ${delaySeconds}s before retry...',
          );
          await Future.delayed(Duration(seconds: delaySeconds));
          continue;
        }
        throw AiGenerationException(
          'Request timeout after $_maxRetries attempts (${timeoutUsed.inSeconds}s each). The Gemini API is taking longer than expected. This could be due to:\n\n• High API server load\n• Slow network connection\n• Request complexity\n\nTry:\n• Waiting a few minutes and retrying\n• Using Wi-Fi instead of mobile data\n• Reducing the number of questions',
        );
      } catch (e) {
        // Handle cancellation - http.Client.close() throws ClientException
        if (e.toString().contains('ClientException')) {
          // Check if it was our cancellation
          if (_isCancelled) {
            debugPrint(
              '[AiGenerationService] Request cancelled - client was closed',
            );
            throw AiGenerationException('Generation cancelled by user');
          }
          // Otherwise it's a genuine network error
          if (e.toString().contains('Connection closed')) {
            if (attempt < _maxRetries) {
              debugPrint(
                '[AiGenerationService] Network connection error on attempt $attempt/$_maxRetries. Waiting before retry...',
              );
              await Future.delayed(
                Duration(seconds: attempt * 3),
              ); // Longer delay for network issues
              continue;
            }
            throw AiGenerationException(
              'Network connection error. Please check your internet connection and try again. If you\'re on mobile data, try switching to Wi-Fi or vice versa. You can also try generating fewer questions at once.',
            );
          }
        }

        if (attempt < _maxRetries && e is! AiGenerationException) {
          // Exponential backoff: 1s, 2s, 4s
          final delaySeconds = attempt;
          debugPrint(
            '[AiGenerationService] Error on attempt $attempt/$_maxRetries: $e',
          );
          debugPrint(
            '[AiGenerationService] Waiting ${delaySeconds}s before retry...',
          );
          await Future.delayed(Duration(seconds: delaySeconds));
          continue;
        }
        rethrow;
      }
    }

    if (responseText == null) {
      throw AiGenerationException(
        'Failed to generate quiz after $_maxRetries attempts',
      );
    }

    // Parse the JSON response into Quiz model.
    // Be robust: if parsing fails due to truncated/malformed JSON, try one-shot reformat.
    // If reformat fails, fall back to regenerating the same batch in smaller chunks to avoid truncation.
    try {
      return await _parseQuizFromJson(
        responseText,
        topic,
        numberOfStems,
        branchesPerStem,
        questionStyle: questionStyle,
        sampleQuestions: sampleQuestions,
        // Only forward per-question progress callbacks when enabled for this
        // single-batch generation. When running multi-batch, the caller will
        // suppress per-question updates and report batch-level progress.
        onProgress: emitPerQuestionProgress ? onProgress : null,
      );
    } on FormatException catch (e) {
      debugPrint(
        '[AiGenerationService] FormatException when parsing response: $e',
      );
      // fallthrough to unified handler below
    } on _ValidationException catch (e) {
      // Handle validation failures with partial results
      debugPrint('[AiGenerationService] Validation exception: ${e.message}');
      debugPrint(
        '[AiGenerationService] Got ${e.validQuestions.length} valid questions, need to regenerate ${e.malformedCount} malformed ones',
      );

      // If we have valid questions but some are malformed, try to regenerate just the malformed ones
      if (validationAttempt < 2 && e.validQuestions.isNotEmpty) {
        debugPrint(
          '[AiGenerationService] Attempting to regenerate ${e.malformedCount} malformed questions (attempt ${validationAttempt + 1}/2)',
        );

        // Build a super-strict prompt for regenerating just the malformed questions
        final strictInstructions =
            '''
CRITICAL: Previous generation failed validation. ${e.malformedCount} questions had MULTIPLE correct answers.

**ABSOLUTE REQUIREMENT for $questionStyle style:**
- EXACTLY ONE correct answer per question
- correctAnswers array MUST have exactly one 'true' and ${branchesPerStem - 1} 'false' values
- Examples:
  ✓ CORRECT: [true, false, false, false, false]
  ✓ CORRECT: [false, true, false, false, false]
  ✗ WRONG: [true, true, false, false, false] - TWO true values
  ✗ WRONG: [false, false, false, false, false] - NO true values
  ✗ WRONG: [true, false, true, false, false] - TWO true values

VERIFY each question has exactly 1 true value before submitting.

${additionalInstructions?.isNotEmpty == true ? '\nOriginal instructions:\n$additionalInstructions' : ''}
''';

        // Regenerate only the missing questions
        final regeneratedQuiz = await _generateSingleBatch(
          apiKey: apiKey,
          model: model,
          topic: topic,
          numberOfStems: e.malformedCount,
          branchesPerStem: branchesPerStem,
          difficulty: difficulty,
          questionStyle: questionStyle,
          subjectCategory: subjectCategory,
          sampleQuestions: sampleQuestions,
          additionalInstructions: strictInstructions,
          onProgress: null, // Don't update progress for small regenerations
          emitPerQuestionProgress: false,
          validationAttempt: validationAttempt + 1,
        );

        // Combine the valid questions from original batch with regenerated ones
        final allQuestions = [
          ...e.validQuestions,
          ...regeneratedQuiz.questions,
        ];
        debugPrint(
          '[AiGenerationService] Successfully combined ${e.validQuestions.length} valid + ${regeneratedQuiz.questions.length} regenerated = ${allQuestions.length} total questions',
        );

        return Quiz(title: topic, questions: allQuestions);
      }

      // If we've exhausted retries or have no valid questions, throw a user-friendly error
      throw AiGenerationException(
        'Quality validation failed: ${e.malformedCount} out of $numberOfStems questions did not meet the "$questionStyle" style requirements after multiple attempts.\n\n'
        'Expected: Each question should have exactly 1 correct answer\n'
        'Found: Some questions had multiple correct answers\n\n'
        'Please try again - the AI will use stricter constraints on the next attempt.',
      );
    } on AiGenerationException catch (e) {
      // Handle validation failures (malformed questions not meeting style requirements)
      if (e.message.contains('Quality validation failed') &&
          validationAttempt < 2) {
        debugPrint(
          '[AiGenerationService] Validation failed on attempt ${validationAttempt + 1}/3. Retrying with stricter prompt...',
        );

        // Add stronger enforcement to the instructions
        final stricterInstructions =
            '''
CRITICAL VALIDATION REQUIREMENT FOR RETRY ${validationAttempt + 1}/3:
The previous generation failed because some questions had MULTIPLE correct answers when only ONE is allowed.

${questionStyle != null && questionStyle.toLowerCase() == 'best_of_5' ? '''
**ABSOLUTE REQUIREMENT**: Each question MUST have EXACTLY ONE correct answer.
- correctAnswers array MUST contain exactly one 'true' and four 'false' values
- Example: [true, false, false, false, false] ✓
- Example: [true, true, false, false, false] ✗ WRONG - TWO true values
- Example: [false, false, false, false, false] ✗ WRONG - NO true values

Before submitting your response, VERIFY each question has exactly 1 true value in correctAnswers.
''' : ''}

${additionalInstructions?.isNotEmpty == true ? '\nOriginal instructions:\n$additionalInstructions' : ''}
''';

        // Retry with stricter instructions
        return await _generateSingleBatch(
          apiKey: apiKey,
          model: model,
          topic: topic,
          numberOfStems: numberOfStems,
          branchesPerStem: branchesPerStem,
          difficulty: difficulty,
          questionStyle: questionStyle,
          subjectCategory: subjectCategory,
          sampleQuestions: sampleQuestions,
          additionalInstructions: stricterInstructions,
          onProgress: onProgress,
          emitPerQuestionProgress: emitPerQuestionProgress,
          validationAttempt: validationAttempt + 1,
        );
      }

      // _parseQuizFromJson wraps FormatException into AiGenerationException; handle both here
      if (!e.message.startsWith('Failed to parse AI response as JSON') &&
          !e.message.contains('Quality validation failed')) {
        rethrow;
      }
      debugPrint(
        '[AiGenerationService] AiGenerationException parsing response: ${e.message}',
      );
      // fallthrough to unified handler below for FormatException cases
    }

    // Unified recovery path: attempt one-shot reformat, then regenerate in smaller chunks
    final reformatText = await _attemptReformat(
      responseText,
      numberOfStems,
      branchesPerStem,
      sampleQuestions,
      questionStyle,
    );
    if (reformatText != null && reformatText.isNotEmpty) {
      debugPrint(
        '[AiGenerationService] Reformat returned; attempting to parse reformatted JSON',
      );
      return await _parseQuizFromJson(
        reformatText,
        topic,
        numberOfStems,
        branchesPerStem,
        questionStyle: questionStyle,
        sampleQuestions: sampleQuestions,
        onProgress: onProgress,
        reformatAttempted: true,
      );
    }

    // If parsed JSON lacks explanations for educational value, attempt to add them
    final addExplanationsText = await _attemptAddExplanations(
      responseText,
      numberOfStems,
      branchesPerStem,
      questionStyle,
    );
    if (addExplanationsText != null && addExplanationsText.isNotEmpty) {
      debugPrint(
        '[AiGenerationService] Add-explanations returned; attempting to parse updated JSON',
      );
      return await _parseQuizFromJson(
        addExplanationsText,
        topic,
        numberOfStems,
        branchesPerStem,
        questionStyle: questionStyle,
        sampleQuestions: sampleQuestions,
        onProgress: onProgress,
        reformatAttempted: true,
      );
    }

    // If reformat didn't help, fall back to generating smaller chunks to avoid truncation
    if (numberOfStems > 1) {
      debugPrint(
        '[AiGenerationService] Falling back to smaller chunks to avoid truncation. Splitting $numberOfStems into smaller requests',
      );
      final List<Question> allQuestions = [];
      int remaining = numberOfStems;
      int processed = 0;
      const int chunkSize =
          10; // smaller chunk size to reduce token usage and truncation

      while (remaining > 0) {
        final int thisChunk = remaining > chunkSize ? chunkSize : remaining;
        debugPrint(
          '[AiGenerationService] Fallback chunk: generating $thisChunk stems (processed so far: $processed)',
        );
        final chunkQuiz = await _generateSingleBatch(
          apiKey: apiKey,
          model: model,
          topic: topic,
          numberOfStems: thisChunk,
          branchesPerStem: branchesPerStem,
          difficulty: difficulty,
          questionStyle: questionStyle,
          subjectCategory: subjectCategory,
          sampleQuestions: sampleQuestions,
          additionalInstructions: additionalInstructions,
          onProgress: (current, total) {
            // map chunk progress to overall progress
            final overall = processed + current;
            onProgress?.call(overall, numberOfStems);
          },
        );

        allQuestions.addAll(chunkQuiz.questions);
        processed += thisChunk;
        remaining -= thisChunk;
      }

      return Quiz(title: 'Quiz on $topic', questions: allQuestions);
    }

    // If we couldn't recover and only one stem was requested, surface an error
    throw AiGenerationException(
      'Failed to parse AI response as JSON and reformat was unsuccessful',
    );
  }

  /// Generate quiz using OpenAI API (placeholder for future implementation)
  Future<Quiz> _generateWithOpenAI({
    required String apiKey,
    required String model,
    required String topic,
    required int numberOfStems,
    required int branchesPerStem,
    required String difficulty,
    String? questionStyle, // ignore: unused_element_parameter
    String? subjectCategory, // ignore: unused_element_parameter
    String? sampleQuestions, // ignore: unused_element_parameter
    String? additionalInstructions, // ignore: unused_element_parameter
    void Function(int current, int total)? onProgress,
  }) async {
    throw UnimplementedError('OpenAI integration coming soon');
  }

  /// Generate quiz using Claude API (placeholder for future implementation)
  Future<Quiz> _generateWithClaude({
    required String apiKey,
    required String model,
    required String topic,
    required int numberOfStems,
    required int branchesPerStem,
    required String difficulty,
    String? questionStyle, // ignore: unused_element_parameter
    String? subjectCategory, // ignore: unused_element_parameter
    String? sampleQuestions, // ignore: unused_element_parameter
    String? additionalInstructions, // ignore: unused_element_parameter
    void Function(int current, int total)? onProgress,
  }) async {
    throw UnimplementedError('Claude integration coming soon');
  }

  /// Sanitize JSON text to fix common issues with unescaped quotes
  /// This handles cases where AI generates quotes within string values
  String _sanitizeJson(String json) {
    try {
      debugPrint('[AiGenerationService] Sanitizing JSON...');

      // Strategy: Fix unescaped quotes within JSON string values
      // We'll look for patterns like: "text with "quotes" inside"
      // and replace them with: "text with \"quotes\" inside"

      // This regex finds quoted strings and captures their content
      // Then we can process each string value individually
      final stringPattern = RegExp(r'"([^"\\]*(?:\\.[^"\\]*)*)"');

      int fixCount = 0;
      String sanitized = json;

      // Find all string values in the JSON
      final matches = stringPattern.allMatches(json).toList();

      // Process from end to beginning to maintain correct indices
      for (int i = matches.length - 1; i >= 0; i--) {
        final match = matches[i];
        final fullMatch = match.group(0)!; // Includes surrounding quotes
        final content = match.group(1)!; // Content without surrounding quotes

        // Check if this is a JSON value (after a colon) or a key (before a colon)
        final beforeMatch = json.substring(0, match.start);

        // Look for colon before this string (it's a value)
        final isValue = beforeMatch.trimRight().endsWith(':');

        if (isValue) {
          // Check for common problematic patterns in the content
          bool needsFix = false;
          String fixedContent = content;

          // Pattern 1: Single word in quotes like 'or "thumbprinting"'
          // Replace: "text or "word"" -> "text or 'word'"
          final quotedWordPattern = RegExp(
            r'(\s+)"(\w+)"(\s+|$|[,.\)])',
            multiLine: true,
          );
          if (quotedWordPattern.hasMatch(content)) {
            fixedContent = content.replaceAllMapped(
              quotedWordPattern,
              (m) => '${m.group(1)}\'${m.group(2)}\'${m.group(3)}',
            );
            needsFix = true;
            fixCount++;
          }

          // Pattern 2: Quoted phrases within text
          // Replace: "referred to as "term"" -> "referred to as 'term'"
          final quotedPhrasePattern = RegExp(
            r'(\s+)"([^"]+)"(\s+|$|[,.\)])',
            multiLine: true,
          );
          if (!needsFix && quotedPhrasePattern.hasMatch(content)) {
            fixedContent = content.replaceAllMapped(
              quotedPhrasePattern,
              (m) => '${m.group(1)}\'${m.group(2)}\'${m.group(3)}',
            );
            needsFix = true;
            fixCount++;
          }

          if (needsFix) {
            // Replace the original string with the fixed version
            final fixedString = '"$fixedContent"';
            sanitized =
                sanitized.substring(0, match.start) +
                fixedString +
                sanitized.substring(match.end);

            debugPrint(
              '[AiGenerationService] Fixed string: ${fullMatch.substring(0, fullMatch.length > 80 ? 80 : fullMatch.length)}...',
            );
          }
        }
      }

      if (fixCount > 0) {
        debugPrint('[AiGenerationService] Sanitized $fixCount string values');
      } else {
        debugPrint('[AiGenerationService] No sanitization needed');
      }

      return sanitized;
    } catch (e) {
      debugPrint('[AiGenerationService] Error during sanitization: $e');
      debugPrint('[AiGenerationService] Returning original JSON');
      return json; // Return original if sanitization fails
    }
  }

  /// Attempt one-shot reformat by calling Gemini with a reformat prompt.
  /// Extracted as a class-level method so it can be used by multiple helpers.
  Future<String?> _attemptReformat(
    String malformedJson,
    int stems,
    int branches,
    String? sampleQuestions,
    String? questionStyle,
  ) async {
    try {
      final reformatPrompt = AiPromptTemplates.generateReformatPrompt(
        malformedResponse: malformedJson,
        expectedStems: stems,
        expectedBranches: branches,
        sampleQuestions: sampleQuestions,
        questionStyle: questionStyle,
      );

      final systemInstruction = AiPromptTemplates.getSystemInstruction(
        subjectContext: null,
      );
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${await _storage.getApiKey(AiProvider.gemini.id)}',
      );

      // Lower temperature for strict reformatting, and reduce temperature further for true_false style
      double temp = 0.2;
      if (questionStyle != null &&
          questionStyle.toLowerCase() == 'true_false_statement') {
        temp = 0.05;
      }

      final requestBody = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': systemInstruction},
              {'text': reformatPrompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': temp,
          'maxOutputTokens': 30000,
          'responseMimeType': 'application/json',
        },
      });

      debugPrint(
        '[AiGenerationService] Attempting one-shot reformat with Gemini...',
      );
      final timeout = _getTimeout(stems);
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          final text =
              data['candidates'][0]['content']['parts'][0]['text'] as String?;
          debugPrint(
            '[AiGenerationService] Reformat response length: ${text?.length ?? 0}',
          );
          return text;
        }
      }
    } catch (e) {
      debugPrint('[AiGenerationService] Reformat attempt failed: $e');
    }
    return null;
  }

  /// Attempt to add educational explanations to a valid-but-incomplete JSON response
  Future<String?> _attemptAddExplanations(
    String validJson,
    int stems,
    int branches,
    String? questionStyle,
  ) async {
    try {
      // If JSON already contains explanations for each question, skip
      try {
        final decoded = jsonDecode(validJson) as Map<String, dynamic>;
        if (decoded.containsKey('questions') && decoded['questions'] is List) {
          final qs = decoded['questions'] as List<dynamic>;
          bool allHave = true;
          for (final q in qs) {
            if (q is Map<String, dynamic>) {
              if (!q.containsKey('explanations') ||
                  q['explanations'] is! List) {
                allHave = false;
                break;
              }
            } else {
              allHave = false;
              break;
            }
          }
          if (allHave) return null; // nothing to do
        }
      } catch (e) {
        // If decode fails, don't attempt add-explanations here
        return null;
      }

      final prompt = AiPromptTemplates.generateAddExplanationsPrompt(
        existingJson: validJson,
        expectedStems: stems,
        expectedBranches: branches,
        questionStyle: questionStyle,
      );

      final systemInstruction = AiPromptTemplates.getSystemInstruction(
        subjectContext: null,
      );
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${await _storage.getApiKey(AiProvider.gemini.id)}',
      );

      double temp = 0.2;
      if (questionStyle != null &&
          questionStyle.toLowerCase() == 'true_false_statement')
        temp = 0.1;

      final requestBody = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': systemInstruction},
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': temp,
          'maxOutputTokens': 30000,
          'responseMimeType': 'application/json',
        },
      });

      debugPrint(
        '[AiGenerationService] Attempting to add explanations via Gemini...',
      );
      final timeout = _getTimeout(stems);
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          final text =
              data['candidates'][0]['content']['parts'][0]['text'] as String?;
          debugPrint(
            '[AiGenerationService] Add-explanations response length: ${text?.length ?? 0}',
          );
          return text;
        }
      }
    } catch (e) {
      debugPrint('[AiGenerationService] _attemptAddExplanations failed: $e');
    }
    return null;
  }

  /// Parse AI response JSON into Quiz model
  Future<Quiz> _parseQuizFromJson(
    String jsonText,
    String topic,
    int expectedStems,
    int expectedBranches, {
    String? questionStyle,
    String? sampleQuestions,
    void Function(int current, int total)? onProgress,
    bool reformatAttempted = false,
  }) async {
    bool looksLikeScenario(String stem) {
      final lower = stem.toLowerCase().trim();

      // Strong scenario indicators (patient presentations)
      final strongPatterns = [
        RegExp(r'\b\d+[\s-]year[\s-]old\b'), // "45-year-old"
        RegExp(r'\bpresent(s|ing|ed)\s+(with|to)\b'), // "presents with"
        RegExp(
          r'\b(comes|came|went|returns|arrived)\s+to\b',
        ), // "comes to clinic"
        RegExp(r'\bhas\s+a\s+\d+[\s-](day|week|month)\s+history\b'),
        RegExp(r'\b(male|female|man|woman|boy|girl)\s+(with|who|is)\b'),
        RegExp(r'\b(patient|individual)\s+(has|was|is|reports)\b'),
        RegExp(r'\b(on examination|physical exam|vital signs)\b'),
      ];

      for (final pattern in strongPatterns) {
        if (pattern.hasMatch(lower)) {
          debugPrint('[Scenario Detected] Pattern: ${pattern.pattern}');
          return true;
        }
      }

      // Multi-sentence check (3+ sentences = definitely scenario)
      final sentenceCount = '.'.allMatches(stem).length;
      if (sentenceCount >= 2) {
        debugPrint(
          '[Scenario Detected] Multi-sentence stem ($sentenceCount sentences)',
        );
        return true;
      }

      // Stem length check (scenarios are typically verbose)
      final wordCount = stem.split(RegExp(r'\s+')).length;
      if (wordCount > 40) {
        // Scenarios are wordy
        debugPrint('[Scenario Detected] Long stem ($wordCount words)');
        return true;
      }

      return false;
    }

    // Helper: attempt one-shot reformat by calling Gemini with a reformat prompt
    Future<String?> _attemptReformat(
      String malformedJson,
      int stems,
      int branches,
      String? sampleQuestions,
      String? questionStyle,
    ) async {
      try {
        final reformatPrompt = AiPromptTemplates.generateReformatPrompt(
          malformedResponse: malformedJson,
          expectedStems: stems,
          expectedBranches: branches,
          sampleQuestions: sampleQuestions,
          questionStyle: questionStyle,
        );

        final systemInstruction = AiPromptTemplates.getSystemInstruction(
          subjectContext: null,
        );
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${await _storage.getApiKey(AiProvider.gemini.id)}',
        );

        // Lower temperature for strict reformatting, and reduce temperature further for true_false style
        double temp = 0.2;
        if (questionStyle != null &&
            questionStyle.toLowerCase() == 'true_false_statement') {
          temp = 0.05;
        }

        final requestBody = jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': systemInstruction},
                {'text': reformatPrompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': temp,
            'maxOutputTokens': 30000,
            'responseMimeType': 'application/json',
          },
        });

        debugPrint(
          '[AiGenerationService] Attempting one-shot reformat with Gemini...',
        );
        final timeout = _getTimeout(stems);
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: requestBody,
            )
            .timeout(timeout);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['candidates'] != null &&
              data['candidates'].isNotEmpty &&
              data['candidates'][0]['content'] != null &&
              data['candidates'][0]['content']['parts'] != null &&
              data['candidates'][0]['content']['parts'].isNotEmpty) {
            final text =
                data['candidates'][0]['content']['parts'][0]['text'] as String?;
            debugPrint(
              '[AiGenerationService] Reformat response length: ${text?.length ?? 0}',
            );
            return text;
          }
        }
      } catch (e) {
        debugPrint('[AiGenerationService] Reformat attempt failed: $e');
      }
      return null;
    }

    try {
      debugPrint('[AiGenerationService] Starting JSON parsing...');
      debugPrint(
        '[AiGenerationService] Raw JSON length: ${jsonText.length} characters',
      );

      // Clean up the JSON text (remove markdown code blocks if present)
      String cleanJson = jsonText.trim();
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
        debugPrint('[AiGenerationService] Removed ```json prefix');
      }
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3);
        debugPrint('[AiGenerationService] Removed ``` prefix');
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
        debugPrint('[AiGenerationService] Removed ``` suffix');
      }
      cleanJson = cleanJson.trim();

      // Sanitize JSON to fix common issues with unescaped quotes
      cleanJson = _sanitizeJson(cleanJson);

      debugPrint(
        '[AiGenerationService] Cleaned JSON length: ${cleanJson.length} characters',
      );
      debugPrint(
        '[AiGenerationService] JSON preview (last 200 chars): ${cleanJson.substring(cleanJson.length > 200 ? cleanJson.length - 200 : 0)}',
      );

      final decodedRaw = jsonDecode(cleanJson);
      Map<String, dynamic> data;

      // Support two possible well-formed responses:
      // 1) Top-level object {"title":..., "questions": [...]}
      // 2) Top-level array [ {...}, {...} ] representing the questions array
      if (decodedRaw is List) {
        debugPrint(
          '[AiGenerationService] JSON decoded to top-level List; wrapping into object with title',
        );
        data = {'title': 'AI Generated Quiz: $topic', 'questions': decodedRaw};
      } else if (decodedRaw is Map<String, dynamic>) {
        data = decodedRaw;
      } else {
        throw FormatException(
          'Unexpected JSON top-level type: ${decodedRaw.runtimeType}',
        );
      }

      debugPrint('[AiGenerationService] JSON decoded successfully');

      // Early tolerant truncation: if the AI returned slightly more stems than requested,
      // trim the questions array before further validation (avoid failing on small overshoots).
      try {
        const int earlyTolerance = 3;
        if (data.containsKey('questions') && data['questions'] is List) {
          final List<dynamic> rawQs = List.from(
            data['questions'] as List<dynamic>,
          );
          if (rawQs.length > expectedStems &&
              (rawQs.length - expectedStems) <= earlyTolerance) {
            debugPrint(
              '[AiGenerationService] Early-truncating questions from ${rawQs.length} to $expectedStems (tolerance ${earlyTolerance})',
            );
            data['questions'] = rawQs.sublist(0, expectedStems);
          }
        }
      } catch (e) {
        debugPrint('[AiGenerationService] Early truncation failed: $e');
      }

      // Check for an explicit error response from the AI
      if (data.containsKey('error') && data['error'] is String) {
        final err = data['error'] as String;
        final expected = data['expected'] ?? 'unknown';
        final found = data['found'] ?? 'unknown';
        debugPrint(
          '[AiGenerationService] AI returned structured error: $err (expected=$expected, found=$found)',
        );
        throw AiGenerationException(
          'AI signalled error: $err (expected=$expected, found=$found)',
        );
      }

      // Tolerant validation: prefer to count only well-formed question objects
      // and allow overshoot by truncating to expected number.

      final rawQuestions = data['questions'] is List
          ? List.from(data['questions'] as List)
          : <dynamic>[];

      // Build a list of well-formed question objects (have stem, branches list, correctAnswers list)
      final wellFormed = <Map<String, dynamic>>[];
      for (final q in rawQuestions) {
        if (q is Map<String, dynamic>) {
          final hasStem =
              q.containsKey('stem') &&
              q['stem'] is String &&
              (q['stem'] as String).trim().isNotEmpty;
          final hasBranches =
              q.containsKey('branches') && q['branches'] is List;
          final hasAnswers =
              q.containsKey('correctAnswers') && q['correctAnswers'] is List;
          if (hasStem && hasBranches && hasAnswers) {
            wellFormed.add(q);
          }
        }
      }

      final validCount = wellFormed.length;
      if (validCount >= expectedStems) {
        // Truncate to expected number if more
        data['questions'] = wellFormed.sublist(0, expectedStems);
        if (validCount > expectedStems) {
          debugPrint(
            '[AiGenerationService] Warning: AI returned $validCount well-formed stems, expected $expectedStems. Auto-truncating to $expectedStems stems.',
          );
        }
      } else {
        // If fewer, proceed with what we have
        data['questions'] = wellFormed;
        debugPrint(
          '[AiGenerationService] Warning: Only $validCount well-formed stems found, expected $expectedStems. Proceeding with available questions.',
        );
      }

      // If earlier validation produced warnings, show them; otherwise skip
      final List<dynamic> validationWarnings =
          (data.containsKey('warnings') && data['warnings'] is List)
          ? data['warnings'] as List<dynamic>
          : <dynamic>[];
      if (validationWarnings.isNotEmpty) {
        debugPrint('[AiGenerationService] WARNINGS: $validationWarnings');
      }

      // Extract title
      final title = data['title'] as String? ?? 'AI Generated Quiz: $topic';

      // Extract questions
      final questionsJson = data['questions'] as List<dynamic>?;
      if (questionsJson == null || questionsJson.isEmpty) {
        debugPrint(
          '[AiGenerationService] ERROR: No questions array found in response',
        );
        throw AiGenerationException('No questions found in AI response');
      }

      debugPrint(
        '[AiGenerationService] Found ${questionsJson.length} questions in response',
      );

      // After initial parse/validation, check semantic style when sample or true_false style is requested
      bool needsReformat = false;
      // If sampleQuestions were provided, we prefer the sample format — use a heuristic: if first stem looks very different, reformat
      if (questionsJson.isNotEmpty) {
        final firstStem =
            (questionsJson[0] is Map &&
                (questionsJson[0] as Map).containsKey('stem'))
            ? (questionsJson[0]['stem'] as String)
            : '';
        if (questionStyle != null &&
            questionStyle.toLowerCase() == 'true_false_statement') {
          if (looksLikeScenario(firstStem)) {
            debugPrint(
              '[AiGenerationService] Detected scenario-like stem but style requested true_false_statement',
            );
            needsReformat = true;
          }
        }
      }

      // If sampleQuestions was passed via prompt (we can't access it here directly), we rely on the initial prompt enforcement;
      // However, we still allow a one-shot reformat whenever the first stem appears to violate the requested style
      if (needsReformat && !reformatAttempted) {
        debugPrint(
          '[AiGenerationService] Triggering one-shot reformat to convert to requested style',
        );

        final reformatText = await _attemptReformat(
          jsonText,
          expectedStems,
          expectedBranches,
          sampleQuestions,
          questionStyle,
        );
        if (reformatText != null && reformatText.isNotEmpty) {
          debugPrint(
            '[AiGenerationService] Reformat returned non-empty response; attempting to parse reformatted JSON',
          );
          // Recursive parse: call this same function on the reformatted text but without infinite loops
          return _parseQuizFromJson(
            reformatText,
            topic,
            expectedStems,
            expectedBranches,
            questionStyle: questionStyle,
            onProgress: onProgress,
            reformatAttempted: true,
          );
        } else {
          debugPrint('[AiGenerationService] One-shot reformat failed');
          // If the requested style explicitly forbids scenarios, abort rather than proceed with scenario-like stems
          final allowsScenario =
              questionStyle != null &&
              questionStyle.toLowerCase() == 'clinical scenario';
          if (!allowsScenario) {
            throw AiGenerationException(
              'AI returned scenario-like or vignette-style stems despite requesting a non-scenario question style. The generation was aborted. Try selecting a scenario/vignette style or simplifying the request.',
            );
          } else {
            debugPrint(
              '[AiGenerationService] Scenario style allowed; proceeding with returned content',
            );
          }
        }
      }

      final questions = <Question>[];
      final malformedIndices =
          <int>[]; // Track questions that don't meet style requirements

      for (int i = 0; i < questionsJson.length; i++) {
        final questionData = questionsJson[i] as Map<String, dynamic>;

        final stem = questionData['stem'] as String?;
        final branchesJson = questionData['branches'] as List<dynamic>?;
        final correctAnswersJson =
            questionData['correctAnswers'] as List<dynamic>?;
        final explanationsJson = questionData['explanations'] as List<dynamic>?;

        if (stem == null ||
            branchesJson == null ||
            correctAnswersJson == null) {
          debugPrint(
            '[AiGenerationService] Skipping malformed question at index $i',
          );
          continue;
        }

        // Validate branch count
        if (branchesJson.length != expectedBranches) {
          debugPrint(
            '[AiGenerationService] Warning: Question ${i + 1} has ${branchesJson.length} branches, expected $expectedBranches',
          );
        }

        // Convert branches to list of strings
        final branches = branchesJson.map((b) => b.toString()).toList();

        // Convert correct answers to list of booleans
        final correctAnswers = correctAnswersJson.map((a) {
          if (a is bool) return a;
          if (a is String) return a.toLowerCase() == 'true';
          return false;
        }).toList();

        // Ensure correctAnswers matches branches length
        while (correctAnswers.length < branches.length) {
          correctAnswers.add(false);
        }
        if (correctAnswers.length > branches.length) {
          correctAnswers.removeRange(branches.length, correctAnswers.length);
        }

        // CRITICAL VALIDATION: Check if question meets the requested style requirements
        final trueCount = correctAnswers.where((a) => a == true).length;

        // For best_of_5 style, REJECT questions that don't have exactly 1 correct answer
        if (questionStyle != null &&
            questionStyle.toLowerCase() == 'best_of_5' &&
            trueCount != 1) {
          debugPrint(
            '[AiGenerationService] REJECTING Question ${i + 1}: has $trueCount correct answers but best_of_5 requires exactly 1',
          );
          malformedIndices.add(i);
          continue; // Skip adding this question - it will need to be regenerated
        }

        // Parse explanations if available
        List<String>? explanations;
        if (explanationsJson != null && explanationsJson.isNotEmpty) {
          explanations = explanationsJson.map((e) => e.toString()).toList();

          // Ensure explanations matches branches length
          while (explanations.length < branches.length) {
            explanations.add('No explanation provided.');
          }
          if (explanations.length > branches.length) {
            explanations = explanations.sublist(0, branches.length);
          }

          debugPrint(
            '[AiGenerationService] Question ${i + 1}: Parsed ${explanations.length} explanations',
          );
        }

        // Determine question type based on correct answers
        QuestionType questionType;
        if (trueCount == 1) {
          questionType = QuestionType.bestOfFive;
        } else {
          questionType = QuestionType.multipleChoice;
        }

        questions.add(
          Question(
            questionText: stem,
            options: branches,
            correctAnswers: correctAnswers,
            explanations: explanations,
            type: questionType,
          ),
        );

        // Report progress after parsing each question
        if (onProgress != null && i < expectedStems) {
          onProgress(i + 1, expectedStems);
        }
      }

      // If we rejected questions for not meeting style requirements, return the partial result
      // The caller can decide to regenerate just the malformed questions
      if (malformedIndices.isNotEmpty) {
        final rejectedCount = malformedIndices.length;
        debugPrint(
          '[AiGenerationService] VALIDATION WARNING: Rejected $rejectedCount questions that don\'t meet $questionStyle style requirements',
        );
        debugPrint(
          '[AiGenerationService] Malformed question indices: $malformedIndices',
        );
        debugPrint(
          '[AiGenerationService] Accepted ${questions.length} valid questions, need to regenerate $rejectedCount malformed questions',
        );

        // Return the valid questions we have - caller will regenerate the missing ones
        // We'll throw a special exception that includes the partial results
        throw _ValidationException(
          message:
              'Validation incomplete: $rejectedCount questions need regeneration',
          validQuestions: questions,
          malformedCount: rejectedCount,
        );
      }

      if (questions.isEmpty) {
        throw AiGenerationException(
          'No valid questions could be parsed from AI response',
        );
      }

      // Warn if we got fewer questions than expected
      if (questions.length < expectedStems) {
        debugPrint(
          '[AiGenerationService] Warning: Generated ${questions.length} questions, expected $expectedStems',
        );
      }

      debugPrint(
        '[AiGenerationService] Successfully parsed ${questions.length} questions',
      );

      return Quiz(title: title, questions: questions);
    } on FormatException catch (e) {
      debugPrint('[AiGenerationService] JSON FORMAT ERROR: $e');
      debugPrint(
        '[AiGenerationService] This usually means the response was truncated.',
      );
      debugPrint(
        '[AiGenerationService] Try reducing the number of stems or using the concise prompt.',
      );
      throw AiGenerationException(
        'Failed to parse AI response as JSON: $e\n\nTip: Try generating fewer questions at once (e.g., 20-30 stems instead of 60).',
      );
    } catch (e) {
      debugPrint('[AiGenerationService] PARSING ERROR: $e');
      throw AiGenerationException('Error parsing quiz data: $e');
    }
  }

  /// Validate API key by making a test request
  Future<bool> validateApiKey(AiProvider provider, String apiKey) async {
    try {
      if (provider == AiProvider.gemini) {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
        );

        final response = await http
            .get(url)
            .timeout(const Duration(seconds: 10));
        return response.statusCode == 200;
      }

      // Placeholder for other providers
      return false;
    } catch (e) {
      debugPrint('[AiGenerationService] API key validation failed: $e');
      return false;
    }
  }

  // ------------------ Deduplication & refill helpers ------------------

  /// Tokenize a stem into a set of normalized tokens for similarity comparisons
  Set<String> _tokenize(String text) {
    final cleaned = text.toLowerCase().replaceAll(RegExp(r"[^a-z0-9\s]"), ' ');
    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    // Remove common English stopwords to reduce noise in similarity comparisons
    const stopwords = {
      'the',
      'and',
      'or',
      'a',
      'an',
      'in',
      'on',
      'of',
      'to',
      'for',
      'with',
      'by',
      'is',
      'are',
      'was',
      'were',
      'be',
      'been',
      'that',
      'this',
      'these',
      'those',
      'it',
      'its',
      'as',
      'at',
      'from',
      'which',
      'but',
      'not',
      'may',
      'can',
    };

    final tokens = words.where((w) => !stopwords.contains(w)).toSet();
    return tokens;
  }

  /// Shorten a stem to a compact title (first N words, no newlines) for avoid-lists
  String _shortenStem(String stem, [int maxWords = 8]) {
    final cleaned = stem.replaceAll(RegExp(r'[\n\r]+'), ' ').trim();
    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final take = words.length <= maxWords ? words.length : maxWords;
    return words.sublist(0, take).join(' ');
  }

  /// Generate k-shingles (contiguous word n-grams) for more robust phrase similarity
  Set<String> _shingles(String text, [int k = 3]) {
    final cleaned = text.toLowerCase().replaceAll(RegExp(r"[^a-z0-9\s]"), ' ');
    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final shingles = <String>{};
    for (int i = 0; i + k <= words.length; i++) {
      shingles.add(words.sublist(i, i + k).join(' '));
    }
    return shingles;
  }

  /// Jaccard similarity between two token sets
  double _jaccardSimilarity(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final intersection = a.intersection(b).length.toDouble();
    final union = a.union(b).length.toDouble();
    return intersection / union;
  }

  /// Combined similarity: average of token-level and shingle-level Jaccard similarities
  double _combinedSimilarity(String a, String b) {
    final tokensA = _tokenize(a);
    final tokensB = _tokenize(b);
    final tokenSim = _jaccardSimilarity(tokensA, tokensB);

    final shingleA = _shingles(a, 3);
    final shingleB = _shingles(b, 3);
    final shingleSim = _jaccardSimilarity(shingleA, shingleB);

    // Weight shingles slightly higher to penalize paraphrases less well-captured by tokens
    return (tokenSim * 0.45) + (shingleSim * 0.55);
  }

  /// Remove near-duplicate questions and attempt to refill up to desiredCount
  Future<List<Question>> _dedupeAndRefillIfNeeded({
    required String apiKey,
    required String model,
    required String topic,
    required List<Question> questions,
    required int desiredCount,
    required int branchesPerStem,
    required String difficulty,
    String? questionStyle,
    String? subjectCategory,
    String? sampleQuestions,
  }) async {
    // Identify near-duplicates by pairwise Jaccard similarity on stems
    final keep = <Question>[];
    // usedTokenSets no longer required (we use keep list and combined similarity)

    for (final q in questions) {
      bool isDuplicate = false;
      for (final existingQ in keep) {
        final sim = _combinedSimilarity(q.questionText, existingQ.questionText);
        if (sim >= _dedupeSimilarityThreshold) {
          isDuplicate = true;
          debugPrint(
            '[AiGenerationService] Detected near-duplicate stem (sim=${sim.toStringAsFixed(2)}): ${q.questionText.substring(0, q.questionText.length > 80 ? 80 : q.questionText.length)}',
          );
          break;
        }
      }
      if (!isDuplicate) {
        keep.add(q);
      }
    }

    debugPrint(
      '[AiGenerationService] Deduplication: kept ${keep.length} of ${questions.length} questions',
    );

    // If we have enough, trim to desiredCount and return
    if (keep.length >= desiredCount) {
      return keep.sublist(0, desiredCount);
    }

    // Need to refill missing stems
    int missing = desiredCount - keep.length;
    int attempts = 0;
    final result = List<Question>.from(keep);

    while (missing > 0 && attempts < _maxRefillAttempts) {
      attempts++;
      debugPrint(
        '[AiGenerationService] Attempting refill #$attempts for $missing stems',
      );

      // Build existing stems snippet to send to the model so it avoids duplicates
      final existingStemsText = result
          .map((q) => '- ${q.questionText}')
          .join('\n');

      final replacementsText = await _generateReplacementStems(
        apiKey: apiKey,
        model: model,
        topic: topic,
        additionalStems: missing,
        branchesPerStem: branchesPerStem,
        difficulty: difficulty,
        existingStems: existingStemsText,
        questionStyle: questionStyle,
        subjectCategory: subjectCategory,
        sampleQuestions: sampleQuestions,
      );

      if (replacementsText == null || replacementsText.isEmpty) {
        debugPrint(
          '[AiGenerationService] Replacements generation returned empty; aborting refill attempts',
        );
        break;
      }

      try {
        // Parse the replacements as a quiz chunk
        final chunkQuiz = await _parseQuizFromJson(
          replacementsText,
          topic,
          missing,
          branchesPerStem,
          questionStyle: questionStyle,
          sampleQuestions: sampleQuestions,
          onProgress: null,
        );

        // Filter out invalid or empty entries from chunkQuiz
        final validReplacements = <Question>[];
        for (final q in chunkQuiz.questions) {
          final stem = q.questionText.trim();
          final nonEmptyBranches = q.options
              .where((b) => b.trim().isNotEmpty)
              .toList();
          if (stem.isEmpty || nonEmptyBranches.length != branchesPerStem) {
            debugPrint(
              '[AiGenerationService] Skipping replacement with empty stem or invalid branches',
            );
            continue;
          }
          validReplacements.add(
            Question(
              questionText: stem,
              options: nonEmptyBranches,
              correctAnswers: q.correctAnswers,
              explanations: q.explanations,
            ),
          );
        }

        // Add non-duplicate replacements
        for (final q in validReplacements) {
          final dup = result.any(
            (existing) =>
                _combinedSimilarity(existing.questionText, q.questionText) >=
                _dedupeSimilarityThreshold,
          );
          if (!dup) {
            result.add(q);
            missing--;
            if (missing == 0) break;
          }
        }
      } on _ValidationException catch (e) {
        // Handle validation failures during refill - some questions might be valid
        debugPrint(
          '[AiGenerationService] Refill validation exception: ${e.validQuestions.length} valid, ${e.malformedCount} malformed',
        );

        // Add the valid questions from this batch
        for (final q in e.validQuestions) {
          final dup = result.any(
            (existing) =>
                _combinedSimilarity(existing.questionText, q.questionText) >=
                _dedupeSimilarityThreshold,
          );
          if (!dup) {
            result.add(q);
            missing--;
            if (missing == 0) break;
          }
        }

        // Update missing count - we still need the malformed ones, but got some valid ones
        debugPrint(
          '[AiGenerationService] After adding valid refills, still need $missing more questions',
        );
        // Continue to next attempt to regenerate the remaining malformed questions
      } catch (e) {
        debugPrint('[AiGenerationService] Failed to parse replacements: $e');

        // If parsing failed for a large replacement request, try splitting into smaller replacement requests
        if (missing > 1) {
          final half = (missing / 2).ceil();
          debugPrint(
            '[AiGenerationService] Parsing failed; retrying refill in smaller sub-requests: $half and ${missing - half}',
          );
          final firstPart = await _generateReplacementStems(
            apiKey: apiKey,
            model: model,
            topic: topic,
            additionalStems: half,
            branchesPerStem: branchesPerStem,
            difficulty: difficulty,
            existingStems: existingStemsText,
            questionStyle: questionStyle,
            subjectCategory: subjectCategory,
            sampleQuestions: sampleQuestions,
          );
          if (firstPart != null && firstPart.isNotEmpty) {
            try {
              final q1 = await _parseQuizFromJson(
                firstPart,
                topic,
                half,
                branchesPerStem,
                questionStyle: questionStyle,
                sampleQuestions: sampleQuestions,
              );
              for (final q in q1.questions) {
                if (result.any(
                  (existing) =>
                      _combinedSimilarity(
                        existing.questionText,
                        q.questionText,
                      ) >=
                      _dedupeSimilarityThreshold,
                ))
                  continue;
                result.add(q);
                missing--;
                if (missing == 0) break;
              }
            } on _ValidationException catch (e2) {
              // Extract valid questions even if some failed validation
              debugPrint(
                '[AiGenerationService] Sub-request validation exception: ${e2.validQuestions.length} valid, ${e2.malformedCount} malformed',
              );
              for (final q in e2.validQuestions) {
                if (result.any(
                  (existing) =>
                      _combinedSimilarity(
                        existing.questionText,
                        q.questionText,
                      ) >=
                      _dedupeSimilarityThreshold,
                ))
                  continue;
                result.add(q);
                missing--;
                if (missing == 0) break;
              }
            } catch (e2) {
              debugPrint('[AiGenerationService] Sub-request parse failed: $e2');
            }
          }

          if (missing > 0) {
            final secondPart = await _generateReplacementStems(
              apiKey: apiKey,
              model: model,
              topic: topic,
              additionalStems: missing,
              branchesPerStem: branchesPerStem,
              difficulty: difficulty,
              existingStems: existingStemsText,
              questionStyle: questionStyle,
              subjectCategory: subjectCategory,
              sampleQuestions: sampleQuestions,
            );
            if (secondPart != null && secondPart.isNotEmpty) {
              try {
                final q2 = await _parseQuizFromJson(
                  secondPart,
                  topic,
                  missing,
                  branchesPerStem,
                  questionStyle: questionStyle,
                  sampleQuestions: sampleQuestions,
                );
                for (final q in q2.questions) {
                  if (result.any(
                    (existing) =>
                        _combinedSimilarity(
                          existing.questionText,
                          q.questionText,
                        ) >=
                        _dedupeSimilarityThreshold,
                  ))
                    continue;
                  result.add(q);
                  missing--;
                  if (missing == 0) break;
                }
              } on _ValidationException catch (e3) {
                // Extract valid questions even if some failed validation
                debugPrint(
                  '[AiGenerationService] Second sub-request validation exception: ${e3.validQuestions.length} valid, ${e3.malformedCount} malformed',
                );
                for (final q in e3.validQuestions) {
                  if (result.any(
                    (existing) =>
                        _combinedSimilarity(
                          existing.questionText,
                          q.questionText,
                        ) >=
                        _dedupeSimilarityThreshold,
                  ))
                    continue;
                  result.add(q);
                  missing--;
                  if (missing == 0) break;
                }
              } catch (e3) {
                debugPrint(
                  '[AiGenerationService] Second sub-request parse failed: $e3',
                );
              }
            }
          }
        }

        // If retries didn't help, break out to avoid infinite loops
        if (missing > 0 && attempts >= _maxRefillAttempts) break;
      }
    }

    if (result.length > desiredCount) return result.sublist(0, desiredCount);
    return result;
  }

  /// Call the model to generate replacement stems avoiding existing stems
  Future<String?> _generateReplacementStems({
    required String apiKey,
    required String model,
    required String topic,
    required int additionalStems,
    required int branchesPerStem,
    required String difficulty,
    required String existingStems,
    String? questionStyle,
    String? subjectCategory,
    String? sampleQuestions,
  }) async {
    try {
      // Build base prompt
      final basePrompt = AiPromptTemplates.generateAdditionalStemsPrompt(
        topic: topic,
        additionalStems: additionalStems,
        branchesPerStem: branchesPerStem,
        difficulty: difficulty,
        existingStems: existingStems,
      );

      // Add strict Best of Five validation if applicable
      String prompt = basePrompt;
      if (questionStyle != null && questionStyle.toLowerCase() == 'best_of_5') {
        prompt =
            '''$basePrompt

**CRITICAL: Best of Five Style Requirements**

This is a "Best of Five" quiz. EVERY question MUST have EXACTLY ONE correct answer:
- correctAnswers array: exactly one 'true' and ${branchesPerStem - 1} 'false' values
- NO questions with multiple true values
- NO questions with zero true values

Examples of CORRECT Best of Five format:
✓ [true, false, false, false, false]
✓ [false, true, false, false, false]
✓ [false, false, false, false, true]

Examples of WRONG format (will be rejected):
✗ [true, true, false, false, false] - TWO true values
✗ [true, false, true, false, false] - TWO true values
✗ [false, false, false, false, false] - NO true values

VERIFY each question has exactly 1 true value before submitting!''';
      }

      final systemInstruction = AiPromptTemplates.getSystemInstruction(
        subjectContext: subjectCategory,
        enforceDirectFormat:
            questionStyle == null ||
            questionStyle.toLowerCase() != 'clinical_scenario',
      );

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );

      final requestBody = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': systemInstruction},
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.25,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 20000,
          'responseMimeType': 'application/json',
        },
      });

      final timeout = _getTimeout(additionalStems);
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          return data['candidates'][0]['content']['parts'][0]['text']
              as String?;
        }
      }
    } catch (e) {
      debugPrint('[AiGenerationService] _generateReplacementStems error: $e');
    }
    return null;
  }

  /// Build prompt for generating answer keys from questions
  String _buildAnswerKeyPrompt(List<Question> questions, {int startIndex = 0}) {
    final buffer = StringBuffer();
    buffer.writeln(
      'You are an expert educator analyzing Multiple Choice Questions (MCQs).',
    );
    buffer.writeln('');
    buffer.writeln(
      'For each question below, analyze the stem and all branches to determine which statements are TRUE and which are FALSE.',
    );
    buffer.writeln(
      'Then provide educational explanations for why each branch is true or false.',
    );
    buffer.writeln('');
    buffer.writeln('CRITICAL JSON FORMATTING RULES:');
    buffer.writeln(
      '1. DO NOT use double quotes (") or single quotes (\') within explanation text',
    );
    buffer.writeln(
      '2. Replace quotes with: single quote → apostrophe, double quotes → nothing or use "approximately" instead',
    );
    buffer.writeln('3. Keep explanations concise (100-150 characters maximum)');
    buffer.writeln('4. Avoid special characters: use plain text only');
    buffer.writeln('5. No line breaks or newlines within strings');
    buffer.writeln('6. Test that your JSON is valid before responding');
    buffer.writeln('');
    buffer.writeln('CONTENT REQUIREMENTS:');
    buffer.writeln(
      '1. Each branch MUST be marked as either true or false (boolean)',
    );
    buffer.writeln(
      '2. Each branch MUST have an explanation (30-150 characters)',
    );
    buffer.writeln('3. Analyze based on current medical/scientific knowledge');
    buffer.writeln('4. Be specific and educational in explanations');
    buffer.writeln('');
    buffer.writeln('Output Format (JSON):');
    buffer.writeln('{');
    buffer.writeln('  "answers": {');
    buffer.writeln('    "1": {');
    buffer.writeln(
      '      "A": {"correct": true, "explanation": "Short clear explanation without quotes"},',
    );
    buffer.writeln(
      '      "B": {"correct": false, "explanation": "Short clear explanation without quotes"}',
    );
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln('}');
    buffer.writeln('');
    buffer.writeln('QUESTIONS TO ANALYZE:');
    buffer.writeln('');

    for (var i = 0; i < questions.length; i++) {
      final question = questions[i];
      final questionNum =
          startIndex + i + 1; // Use actual question number in the full set

      buffer.writeln('Question $questionNum:');
      buffer.writeln('STEM: ${question.questionText}');
      buffer.writeln('BRANCHES:');

      for (var j = 0; j < question.options.length; j++) {
        final letter = String.fromCharCode(65 + j); // A, B, C, D, E...
        buffer.writeln('  $letter: ${question.options[j]}');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  /// Generate answer keys using Gemini
  Future<Map<String, dynamic>> _generateAnswerKeysWithGemini({
    required String apiKey,
    required String model,
    required String prompt,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    final requestBody = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.3, // Lower temperature for more consistent answers
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 20000,
        'responseMimeType': 'application/json',
      },
    });

    final timeout = Duration(minutes: 5); // 5 minutes for answer key generation
    final response = await _httpClient!
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        )
        .timeout(timeout);

    if (_isCancelled) {
      throw AiGenerationException('Generation cancelled by user');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['candidates'] != null &&
          data['candidates'].isNotEmpty &&
          data['candidates'][0]['content'] != null &&
          data['candidates'][0]['content']['parts'] != null &&
          data['candidates'][0]['content']['parts'].isNotEmpty) {
        final text =
            data['candidates'][0]['content']['parts'][0]['text'] as String;

        try {
          // Try to parse the JSON response
          return jsonDecode(text);
        } catch (e) {
          debugPrint('[AiGenerationService] JSON parse error: $e');
          debugPrint(
            '[AiGenerationService] Raw response text: ${text.substring(0, text.length > 500 ? 500 : text.length)}...',
          );

          // Try to fix common JSON issues
          String fixedText = text;

          // Remove any markdown code blocks
          fixedText = fixedText.replaceAll(RegExp(r'```json\s*'), '');
          fixedText = fixedText.replaceAll(RegExp(r'```\s*$'), '');
          fixedText = fixedText.trim();

          // Try parsing again
          try {
            return jsonDecode(fixedText);
          } catch (e2) {
            debugPrint(
              '[AiGenerationService] Second parse attempt failed: $e2',
            );

            // Last resort: try to fix unescaped quotes within explanation strings
            // This is a heuristic approach - look for patterns like: "explanation": "text with "quotes" inside"
            try {
              // Find all explanation values and escape internal quotes
              fixedText = _sanitizeJsonQuotes(fixedText);
              return jsonDecode(fixedText);
            } catch (e3) {
              debugPrint(
                '[AiGenerationService] Final parse attempt failed: $e3',
              );
              throw AiGenerationException(
                'Failed to parse AI response as JSON. The AI generated malformed JSON with unescaped quotes. Please try again.',
              );
            }
          }
        }
      }
      throw AiGenerationException('Invalid response format from Gemini');
    } else {
      final errorBody = response.body;
      throw AiGenerationException(
        'Gemini API error (${response.statusCode}): $errorBody',
      );
    }
  }

  /// Generate answer keys using OpenAI
  Future<Map<String, dynamic>> _generateAnswerKeysWithOpenAI({
    required String apiKey,
    required String model,
    required String prompt,
  }) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final requestBody = jsonEncode({
      'model': model,
      'messages': [
        {
          'role': 'system',
          'content': 'You are an expert educator analyzing MCQ questions. Always respond with valid JSON.',
        },
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0.3,
      'response_format': {'type': 'json_object'},
    });

    final timeout = Duration(minutes: 5);
    final response = await _httpClient!
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: requestBody,
        )
        .timeout(timeout);

    if (_isCancelled) {
      throw AiGenerationException('Generation cancelled by user');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['choices'] != null && data['choices'].isNotEmpty) {
        final text = data['choices'][0]['message']['content'] as String;
        return jsonDecode(text);
      }
      throw AiGenerationException('Invalid response format from OpenAI');
    } else {
      final errorBody = response.body;
      throw AiGenerationException(
        'OpenAI API error (${response.statusCode}): $errorBody',
      );
    }
  }

  /// Generate answer keys using Claude
  Future<Map<String, dynamic>> _generateAnswerKeysWithClaude({
    required String apiKey,
    required String model,
    required String prompt,
  }) async {
    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    final requestBody = jsonEncode({
      'model': model,
      'max_tokens': 20000,
      'temperature': 0.3,
      'system': 'You are an expert educator analyzing MCQ questions. Always respond with valid JSON.',
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
    });

    final timeout = Duration(minutes: 5);
    final response = await _httpClient!
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: requestBody,
        )
        .timeout(timeout);

    if (_isCancelled) {
      throw AiGenerationException('Generation cancelled by user');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['content'] != null && data['content'].isNotEmpty) {
        final text = data['content'][0]['text'] as String;
        return jsonDecode(text);
      }
      throw AiGenerationException('Invalid response format from Claude');
    } else {
      final errorBody = response.body;
      throw AiGenerationException(
        'Claude API error (${response.statusCode}): $errorBody',
      );
    }
  }

  /// Parse answer key response into the expected format
  Map<int, Map<String, dynamic>> _parseAnswerKeyResponse(
    Map<String, dynamic> response,
    int expectedQuestions, {
    int startIndex = 0,
  }) {
    final answerKeys = <int, Map<String, dynamic>>{};

    if (!response.containsKey('answers')) {
      throw AiGenerationException('Response missing "answers" field');
    }

    final answers = response['answers'] as Map<String, dynamic>;

    for (var i = 1; i <= expectedQuestions; i++) {
      // The question number in the response
      final questionKey = (startIndex + i).toString();

      if (!answers.containsKey(questionKey)) {
        debugPrint(
          '[AiGenerationService] Warning: Missing answer key for question $questionKey',
        );
        continue; // Skip missing questions instead of throwing
      }

      final questionAnswers = answers[questionKey] as Map<String, dynamic>;
      final processedAnswers = <String, bool>{};
      final explanations = <String, String>{};

      questionAnswers.forEach((option, value) {
        final optionData = value as Map<String, dynamic>;
        final correct = optionData['correct'] as bool;
        final explanation = optionData['explanation'] as String;

        processedAnswers[option] = correct;
        explanations[option] = explanation;
      });

      answerKeys[startIndex + i] = {
        'answers': processedAnswers,
        'explanations': explanations,
      };
    }

    return answerKeys;
  }

  /// Sanitize JSON by attempting to fix unescaped quotes in strings
  /// This is a heuristic approach for common patterns
  String _sanitizeJsonQuotes(String json) {
    // Simple approach: within "explanation" values, replace internal unescaped quotes
    // Look for patterns like: "explanation": "text with "problem" text"
    // This is a last-resort fallback

    try {
      // Try a simple fix: replace obvious quote patterns within explanations
      // Pattern: "text"text" -> "text text" (remove problematic internal quotes)
      var fixed = json;

      // Find explanation blocks and clean them
      final explanationPattern = RegExp(
        r'"explanation"\s*:\s*"([^"]*(?:"[^"]*)*)"',
        multiLine: true,
      );

      fixed = fixed.replaceAllMapped(explanationPattern, (match) {
        var fullMatch = match.group(0)!;
        // If the match looks problematic (has multiple quotes), try to clean it
        var quoteCount = fullMatch.split('"').length - 1;
        if (quoteCount > 4) {
          // Too many quotes, likely malformed
          // Extract the key part and sanitize
          var value = match.group(1) ?? '';
          // Remove or replace internal quotes
          value = value.replaceAll('"', ''); // Remove all internal quotes
          return '"explanation": "$value"';
        }
        return fullMatch;
      });

      return fixed;
    } catch (e) {
      debugPrint('[AiGenerationService] Error in _sanitizeJsonQuotes: $e');
      return json; // Return original if sanitization fails
    }
  }
}

/// Custom exception for AI generation errors
class AiGenerationException implements Exception {
  final String message;

  AiGenerationException(this.message);

  @override
  String toString() => message;
}
