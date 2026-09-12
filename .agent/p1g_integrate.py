from pathlib import Path
import re

path = Path('lib/services/ai_generation_service.dart')
text = path.read_text()

import_anchor = "import '../services/ai_provider_service.dart';\n"
imports = (
    "import '../services/ai_provider_service.dart';\n"
    "import '../services/generation_capability_resolver.dart';\n"
    "import '../services/generation_plan.dart';\n"
    "import '../services/generation_recovery_policy.dart';\n"
)
if 'generation_capability_resolver.dart' not in text:
    assert import_anchor in text
    text = text.replace(import_anchor, imports, 1)

call_anchor = """        quiz = await _generateWithProfile(\n          profile: profile,\n"""
call_replacement = """        final capabilities = await GenerationCapabilityResolver().forProfile(\n          profile,\n        );\n        final plan = GenerationPlanner.build(\n          profile: profile,\n          request: GenerationRequestShape(\n            totalStems: numberOfStems,\n            branchesPerStem: branchesPerStem,\n            questionStyle: questionStyle,\n            sampleCharacters: sampleQuestions?.length ?? 0,\n            additionalInstructionCharacters:\n                additionalInstructions?.length ?? 0,\n          ),\n          capabilities: capabilities,\n        );\n        debugPrint(\n          '[AiGenerationService] Adaptive plan: ${plan.targetStemsPerRequest} stems/request, ${plan.maxOutputTokensPerRequest} max output tokens',\n        );\n        quiz = await _generateWithProfile(\n          profile: profile,\n          plan: plan,\n"""
if 'final plan = GenerationPlanner.build(' not in text:
    assert call_anchor in text
    text = text.replace(call_anchor, call_replacement, 1)

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

  Future<Map<String, dynamic>> _generateAnswerKeysWithProfile'''

matches = list(method_pattern.finditer(text))
assert len(matches) == 1, f'expected one profile-generation method, got {len(matches)}'
text = method_pattern.sub(replacement, text, count=1)
path.write_text(text)
