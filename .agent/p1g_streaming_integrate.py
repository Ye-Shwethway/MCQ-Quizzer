from pathlib import Path
import re

provider_path = Path('lib/services/ai_provider_service.dart')
provider = provider_path.read_text()

anchor = """  Future<String> generateText(\n    AiProviderProfile profile,\n    String apiKey, {\n    required String systemPrompt,\n    required String userPrompt,\n    int maxTokens = 8192,\n    double temperature = 0.2,\n  }) => _generateText(\n    profile,\n    apiKey,\n    systemPrompt: systemPrompt,\n    userPrompt: userPrompt,\n    maxTokens: maxTokens,\n    temperature: temperature,\n  );\n\n"""

stream_method = r'''  /// Streams only visible model text deltas. Provider-specific SSE envelopes are
  /// normalized here so quiz generation can use one incremental parser contract.
  Stream<String> generateTextStream(
    AiProviderProfile profile,
    String apiKey, {
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 8192,
    double temperature = 0.2,
  }) async* {
    final model = profile.selectedModelId;
    if (model == null || model.isEmpty) {
      throw const AiProviderException(
        'configuration',
        'Select a model before generating.',
      );
    }

    late Uri uri;
    late Map<String, dynamic> body;
    switch (profile.definition.adapterKind) {
      case AiAdapterKind.gemini:
        var path = profile.generationPath.replaceAll(
          '{model}',
          Uri.encodeComponent(model),
        );
        path = path.replaceFirst(':generateContent', ':streamGenerateContent');
        uri = _resolve(profile.baseUrl, path).replace(
          queryParameters: {'alt': 'sse'},
        );
        body = {
          if (systemPrompt.isNotEmpty)
            'systemInstruction': {
              'parts': [
                {'text': systemPrompt},
              ],
            },
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': userPrompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': temperature,
            'maxOutputTokens': maxTokens,
            'responseMimeType': 'application/json',
          },
        };

      case AiAdapterKind.anthropic:
        uri = _resolve(profile.baseUrl, profile.generationPath);
        body = {
          'model': model,
          if (systemPrompt.isNotEmpty) 'system': systemPrompt,
          'messages': [
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': temperature,
          'max_tokens': maxTokens,
          'stream': true,
        };

      case AiAdapterKind.nanoGpt:
      case AiAdapterKind.openAiCompatible:
        var generationPath = profile.generationPath;
        if (profile.definition.adapterKind == AiAdapterKind.nanoGpt) {
          generationPath = switch (profile.inferenceRoute) {
            AiInferenceRoute.subscription =>
              '/subscription/v1/chat/completions',
            AiInferenceRoute.paid => '/v1/chat/completions',
            AiInferenceRoute.standard => profile.generationPath,
          };
        }
        uri = _resolve(profile.baseUrl, generationPath);
        body = {
          'model': model,
          'messages': [
            if (systemPrompt.isNotEmpty)
              {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'stream': true,
          if (profile.definitionId != 'openai') 'temperature': temperature,
          if (profile.definitionId == 'openai')
            'max_completion_tokens': maxTokens
          else
            'max_tokens': maxTokens,
        };
    }

    http.StreamedResponse response;
    try {
      final request = http.Request('POST', uri)
        ..followRedirects = false
        ..headers.addAll({
          ..._headers(profile, apiKey),
          'Accept': 'text/event-stream',
        })
        ..body = jsonEncode(body);
      response = await _client.send(request).timeout(_generationTimeout);
    } on TimeoutException {
      throw const AiProviderException(
        'timeout',
        'The provider did not start streaming in time.',
      );
    } catch (error) {
      throw _safeTransportException(error);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.drain<void>();
      if ({400, 404, 405, 415, 422}.contains(response.statusCode)) {
        throw AiProviderException(
          'streaming_unsupported',
          'This endpoint did not accept streaming; retrying without streaming.',
          statusCode: response.statusCode,
        );
      }
      throw AiProviderException(
        _statusCategory(response.statusCode),
        _safeErrorMessage(response.statusCode),
        statusCode: response.statusCode,
      );
    }

    try {
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(_generationTimeout);
      await for (final line in lines) {
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty || payload == '[DONE]') continue;
        dynamic decoded;
        try {
          decoded = jsonDecode(payload);
        } catch (_) {
          continue;
        }
        if (decoded is! Map) continue;
        final event = Map<String, dynamic>.from(decoded);

        switch (profile.definition.adapterKind) {
          case AiAdapterKind.gemini:
            final candidates = event['candidates'] as List?;
            final first = candidates?.isNotEmpty == true
                ? candidates!.first as Map?
                : null;
            final parts = (first?['content'] as Map?)?['parts'] as List?;
            final delta = parts
                ?.whereType<Map>()
                .where((part) => part['thought'] != true)
                .map((part) => part['text'])
                .whereType<String>()
                .join();
            if (delta != null && delta.isNotEmpty) yield delta;

          case AiAdapterKind.anthropic:
            final delta = event['delta'] as Map?;
            final text = delta?['text'];
            if (text is String && text.isNotEmpty) yield text;

          case AiAdapterKind.nanoGpt:
          case AiAdapterKind.openAiCompatible:
            final choices = event['choices'] as List?;
            final first = choices?.isNotEmpty == true
                ? choices!.first as Map?
                : null;
            final delta = first?['delta'] as Map?;
            final content = delta?['content'];
            if (content is String && content.isNotEmpty) {
              yield content;
            } else if (content is List) {
              final text = content
                  .whereType<Map>()
                  .map((part) => part['text'])
                  .whereType<String>()
                  .join();
              if (text.isNotEmpty) yield text;
            }
        }
      }
    } on TimeoutException {
      throw const AiProviderException(
        'timeout',
        'The provider stream stopped responding.',
      );
    } catch (error) {
      if (error is AiProviderException) rethrow;
      throw _safeTransportException(error);
    }
  }

'''

if 'Stream<String> generateTextStream(' not in provider:
    assert anchor in provider, 'generateText anchor missing'
    provider = provider.replace(anchor, anchor + stream_method, 1)
    provider_path.write_text(provider)

service_path = Path('lib/services/ai_generation_service.dart')
service = service_path.read_text()
import_anchor = "import '../services/generation_recovery_policy.dart';\n"
if "incremental_quiz_stream_parser.dart" not in service:
    service = service.replace(
        import_anchor,
        import_anchor + "import '../services/incremental_quiz_stream_parser.dart';\n",
        1,
    )

method_pattern = re.compile(
    r"  Future<Quiz> _generateWithProfile\(\{.*?\n  Future<Map<String, dynamic>> _generateAnswerKeysWithProfile",
    re.S,
)
replacement = r'''  Future<Quiz> _generateWithProfile({
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
    var streamingEnabled = plan.transportStreaming;

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

      final streamedQuestions = <Question>[];
      String? responseText;
      if (streamingEnabled) {
        final parser = IncrementalQuizStreamParser(
          expectedBranches: branchesPerStem,
          questionStyle: questionStyle,
        );
        try {
          await for (final delta in adapter.generateTextStream(
            profile,
            apiKey,
            systemPrompt: systemInstruction,
            userPrompt: prompt,
            maxTokens: plan.maxOutputTokensPerRequest,
            temperature: questionStyle?.toLowerCase() == 'true_false_statement'
                ? 0.1
                : 0.2,
          )) {
            _checkCancellation();
            for (final question in parser.addText(delta)) {
              if (streamedQuestions.length >= count) break;
              streamedQuestions.add(question);
              onProgress?.call(
                (allQuestions.length + streamedQuestions.length).clamp(
                  0,
                  numberOfStems,
                ),
                numberOfStems,
              );
            }
          }
          responseText = parser.accumulatedText;
        } on AiProviderException catch (error) {
          if (streamedQuestions.isNotEmpty) {
            debugPrint(
              '[AiGenerationService] Stream ended after ${streamedQuestions.length}/$count confirmed stems; preserving them and continuing safely.',
            );
            allQuestions.addAll(streamedQuestions.take(remaining));
            streamingEnabled = false;
            failureAttempt = 0;
            activeBatchSize = plan.fallbackStemsPerRequest;
            continue;
          }
          if (error.category == 'streaming_unsupported') {
            debugPrint(
              '[AiGenerationService] Streaming unsupported for this endpoint; using non-streaming fallback for the rest of this run.',
            );
            streamingEnabled = false;
          } else {
            failureAttempt++;
            final failure = GenerationRecoveryPolicy.classifyMessage(
              error.message,
            );
            final decision = GenerationRecoveryPolicy.decide(
              plan: plan,
              failure: failure,
              attemptedBatchSize: count,
              attempt: failureAttempt,
            );
            if (!decision.retry || failure == GenerationFailureKind.unknown) {
              throw AiGenerationException(error.message);
            }
            activeBatchSize = decision.nextBatchSize;
            if (decision.backoff > Duration.zero) {
              await Future.delayed(decision.backoff);
            }
            continue;
          }
        }
      }

      try {
        responseText ??= await adapter.generateText(
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
      } on AiGenerationException catch (error) {
        if (streamedQuestions.isNotEmpty) {
          debugPrint(
            '[AiGenerationService] Final stream tail was incomplete; preserving ${streamedQuestions.length} confirmed stems.',
          );
          allQuestions.addAll(streamedQuestions.take(remaining));
          failureAttempt = 0;
          activeBatchSize = plan.fallbackStemsPerRequest;
        } else {
          failureAttempt++;
          final decision = GenerationRecoveryPolicy.decide(
            plan: plan,
            failure: GenerationFailureKind.malformedOrTruncated,
            attemptedBatchSize: count,
            attempt: failureAttempt,
          );
          if (!decision.retry) rethrow;
          activeBatchSize = decision.nextBatchSize;
          if (decision.backoff > Duration.zero) {
            await Future.delayed(decision.backoff);
          }
          continue;
        }
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

  Future<Map<String, dynamic>> _generateAnswerKeysWithProfile'''

matches = list(method_pattern.finditer(service))
assert len(matches) == 1, f'expected one profile generation method, got {len(matches)}'
service = method_pattern.sub(replacement, service, count=1)
service_path.write_text(service)
