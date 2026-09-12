from pathlib import Path
import re

SERVICE = Path('lib/services/ai_generation_service.dart')
SCREEN = Path('lib/screens/quiz_generation_screen.dart')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected exactly 1 match, found {count}')
    return text.replace(old, new, 1)


service = SERVICE.read_text()

service = replace_once(
    service,
    """  @override\n  String toString() => message;\n}\n\n/// Service for AI-powered quiz generation using various providers (Gemini, OpenAI, Claude)\n""",
    """  @override\n  String toString() => message;\n}\n\nenum GenerationExecutionMode {\n  preparing,\n  serial,\n  parallel,\n  serialRecovery,\n  serialRefill,\n}\n\nclass GenerationExecutionStatus {\n  final GenerationExecutionMode mode;\n  final int concurrency;\n  final List<int> laneSizes;\n\n  const GenerationExecutionStatus({\n    required this.mode,\n    this.concurrency = 1,\n    this.laneSizes = const [],\n  });\n\n  String get displayText {\n    switch (mode) {\n      case GenerationExecutionMode.preparing:\n        return 'Mode: preparing…';\n      case GenerationExecutionMode.serial:\n        return 'Mode: Serial';\n      case GenerationExecutionMode.parallel:\n        final lanes = laneSizes.isEmpty ? '' : ' • ${laneSizes.join(' + ')} stems';\n        return 'Mode: Parallel ×$concurrency$lanes';\n      case GenerationExecutionMode.serialRecovery:\n        return 'Mode: Serial recovery';\n      case GenerationExecutionMode.serialRefill:\n        return 'Mode: Serial refill for unique stems';\n    }\n  }\n}\n\n/// Service for AI-powered quiz generation using various providers (Gemini, OpenAI, Claude)\n""",
    'insert execution status model',
)

service = replace_once(
    service,
    """    String? additionalInstructions,\n    void Function(int current, int total)? onProgress,\n  }) async {\n""",
    """    String? additionalInstructions,\n    void Function(int current, int total)? onProgress,\n    void Function(GenerationExecutionStatus status)? onExecutionStatus,\n  }) async {\n""",
    'generateQuiz execution callback',
)

service = replace_once(
    service,
    """          additionalInstructions: additionalInstructions,\n          onProgress: onProgress,\n        );\n      } else {\n""",
    """          additionalInstructions: additionalInstructions,\n          onProgress: onProgress,\n          onExecutionStatus: onExecutionStatus,\n        );\n      } else {\n""",
    'wire execution callback to profile generation',
)

service = replace_once(
    service,
    """    String? additionalInstructions,\n    void Function(int current, int total)? onProgress,\n  }) async {\n    _checkCancellation();\n    final laneCount = plan.maxConcurrentRequests.clamp(1, 2);\n""",
    """    String? additionalInstructions,\n    void Function(int current, int total)? onProgress,\n    void Function(GenerationExecutionStatus status)? onExecutionStatus,\n  }) async {\n    _checkCancellation();\n    final laneCount = plan.maxConcurrentRequests.clamp(1, 2);\n""",
    'concurrent signature',
)

service = replace_once(
    service,
    """    debugPrint(\n      '[AiGenerationService] Bounded concurrency: $laneCount lanes for $numberOfStems stems (${laneSizes.join(' + ')}).',\n    );\n\n    final serialPlan = plan.serial();\n""",
    """    debugPrint(\n      '[AiGenerationService] Bounded concurrency: $laneCount lanes for $numberOfStems stems (${laneSizes.join(' + ')}).',\n    );\n    onExecutionStatus?.call(\n      GenerationExecutionStatus(\n        mode: GenerationExecutionMode.parallel,\n        concurrency: laneCount,\n        laneSizes: List<int>.unmodifiable(laneSizes),\n      ),\n    );\n\n    final serialPlan = plan.serial();\n""",
    'parallel status emission',
)

old_lane = """    String laneInstructions(int index) {\n      final partition =\n          'Parallel generation partition ${index + 1}/$laneCount. Produce a distinct subset of the requested topic. Avoid generic repetition and vary the factual focus from other partitions while following every original quiz requirement.';\n      if (additionalInstructions?.trim().isNotEmpty == true) {\n        return '${additionalInstructions!.trim()}\\n\\n$partition';\n      }\n      return partition;\n    }\n"""
new_lane = """    String laneInstructions(int index) {\n      final complementaryAngle = index.isEven\n          ? 'Emphasize broad coverage across different subtopics and concepts, including foundational relationships, distinctions, causes/mechanisms, structure, or comparison when those dimensions fit this subject.'\n          : 'Emphasize complementary coverage through application, interpretation, implications, examples, exceptions, chronology/process, evidence, or problem-solving when those dimensions fit this subject.';\n      final subjectHint = subjectCategory?.trim().isNotEmpty == true\n          ? ' Subject category/context: ${subjectCategory!.trim()}.'\n          : '';\n      final partition =\n          'Parallel coverage partition ${index + 1}/$laneCount for topic "$topic".$subjectHint '\n          'Adapt the coverage dimensions to the requested subject; do not force a domain-specific taxonomy. '\n          '$complementaryAngle Vary the subtopic, core fact/entity, cognitive operation, and framing within this partition. '\n          'Do not test the same underlying fact or concept twice merely by paraphrasing the stem.';\n      if (additionalInstructions?.trim().isNotEmpty == true) {\n        return '${additionalInstructions!.trim()}\\n\\n$partition';\n      }\n      return partition;\n    }\n"""
service = replace_once(service, old_lane, new_lane, 'domain-agnostic lane coverage')

service = replace_once(
    service,
    """      debugPrint(\n        '[AiGenerationService] Parallel lane ${index + 1} failed with $failure; downgrading that work to serial generation.',\n      );\n""",
    """      debugPrint(\n        '[AiGenerationService] Parallel lane ${index + 1} failed with $failure; downgrading that work to serial generation.',\n      );\n      onExecutionStatus?.call(\n        const GenerationExecutionStatus(\n          mode: GenerationExecutionMode.serialRecovery,\n        ),\n      );\n""",
    'serial recovery status',
)

service = replace_once(
    service,
    """        final duplicate = unique.any(\n          (existing) =>\n              _combinedSimilarity(\n                existing.questionText,\n                question.questionText,\n              ) >=\n              _dedupeSimilarityThreshold,\n        );\n""",
    """        final duplicate = unique.any(\n          (existing) => _questionsNearDuplicate(existing, question),\n        );\n""",
    'parallel semantic dedupe gate',
)

service = replace_once(
    service,
    """      refillAttempt++;\n      final missing = numberOfStems - unique.length;\n""",
    """      refillAttempt++;\n      onExecutionStatus?.call(\n        const GenerationExecutionStatus(\n          mode: GenerationExecutionMode.serialRefill,\n        ),\n      );\n      final missing = numberOfStems - unique.length;\n""",
    'refill status',
)

service = replace_once(
    service,
    """          'Generate $missing additional DISTINCT stems. Do not repeat or closely paraphrase these existing stems:\\n$avoid';\n""",
    """          'Generate $missing additional DISTINCT stems. Each new stem must test a different underlying fact or concept, not merely use different wording. Do not repeat or closely paraphrase these existing stems:\\n$avoid';\n""",
    'stronger refill instruction',
)

old_safety = """    // Count correctness wins over an endless refill loop. If aggressive local\n    // similarity filtering still left a gap, do one final serial safety fill.\n    if (unique.length < numberOfStems) {\n      final missing = numberOfStems - unique.length;\n      debugPrint(\n        '[AiGenerationService] Final serial safety fill for $missing stems after parallel dedupe.',\n      );\n      final safety = await _generateWithProfile(\n        profile: profile,\n        plan: serialPlan,\n        apiKey: apiKey,\n        topic: topic,\n        numberOfStems: missing,\n        branchesPerStem: branchesPerStem,\n        difficulty: difficulty,\n        questionStyle: questionStyle,\n        subjectCategory: subjectCategory,\n        sampleQuestions: sampleQuestions,\n        additionalInstructions: additionalInstructions,\n        onProgress: null,\n      );\n      final stillNeeded = numberOfStems - unique.length;\n      unique.addAll(safety.questions.take(stillNeeded));\n    }\n"""
new_safety = """    // Final safety fills must pass the same uniqueness gate. Never satisfy the\n    // requested count by blindly appending near-duplicates.\n    var safetyAttempt = 0;\n    while (unique.length < numberOfStems && safetyAttempt < 2) {\n      safetyAttempt++;\n      onExecutionStatus?.call(\n        const GenerationExecutionStatus(\n          mode: GenerationExecutionMode.serialRefill,\n        ),\n      );\n      final missing = numberOfStems - unique.length;\n      var avoid = unique\n          .map((q) => '- ${_shortenStem(q.questionText)}')\n          .join('\\n');\n      if (avoid.length > _maxAvoidSnippetChars) {\n        avoid =\n            '${avoid.substring(0, _maxAvoidSnippetChars)}\\n- ... (truncated)';\n      }\n      debugPrint(\n        '[AiGenerationService] Final uniqueness safety fill #$safetyAttempt for $missing stems.',\n      );\n      final safetyInstruction =\n          '${additionalInstructions?.trim().isNotEmpty == true ? '${additionalInstructions!.trim()}\\n\\n' : ''}'\n          'Generate $missing fresh stems that cover different underlying facts or concepts. '\n          'Do not reuse the same concept through paraphrase or superficial framing changes. '\n          'Avoid these accepted stems:\\n$avoid';\n      final safety = await _generateWithProfile(\n        profile: profile,\n        plan: serialPlan,\n        apiKey: apiKey,\n        topic: topic,\n        numberOfStems: missing,\n        branchesPerStem: branchesPerStem,\n        difficulty: difficulty,\n        questionStyle: questionStyle,\n        subjectCategory: subjectCategory,\n        sampleQuestions: sampleQuestions,\n        additionalInstructions: safetyInstruction,\n        onProgress: null,\n      );\n      final before = unique.length;\n      addUnique(safety.questions);\n      if (unique.length == before) {\n        debugPrint(\n          '[AiGenerationService] Safety fill added no unique stems; stopping rather than appending duplicates.',\n        );\n        break;\n      }\n    }\n"""
service = replace_once(service, old_safety, new_safety, 'dedupe-safe final fill')

service = replace_once(
    service,
    """    String? additionalInstructions,\n    void Function(int current, int total)? onProgress,\n  }) async {\n    final client = _httpClient;\n""",
    """    String? additionalInstructions,\n    void Function(int current, int total)? onProgress,\n    void Function(GenerationExecutionStatus status)? onExecutionStatus,\n  }) async {\n    final client = _httpClient;\n""",
    'profile signature',
)

service = replace_once(
    service,
    """        additionalInstructions: additionalInstructions,\n        onProgress: onProgress,\n      );\n    }\n    final adapter = AiProviderService(client: client);\n""",
    """        additionalInstructions: additionalInstructions,\n        onProgress: onProgress,\n        onExecutionStatus: onExecutionStatus,\n      );\n    }\n    onExecutionStatus?.call(\n      const GenerationExecutionStatus(mode: GenerationExecutionMode.serial),\n    );\n    final adapter = AiProviderService(client: client);\n""",
    'profile parallel/serial mode wiring',
)

service = replace_once(
    service,
    """      'may',\n      'can',\n    };\n""",
    """      'may',\n      'can',\n      'following',\n      'most',\n      'likely',\n      'correct',\n      'incorrect',\n      'statement',\n      'best',\n      'describes',\n      'regarding',\n      'according',\n      'question',\n      'choose',\n      'select',\n    };\n""",
    'generic question boilerplate stopwords',
)

old_combined = """  /// Combined similarity: average of token-level and shingle-level Jaccard similarities\n  double _combinedSimilarity(String a, String b) {\n    final tokensA = _tokenize(a);\n    final tokensB = _tokenize(b);\n    final tokenSim = _jaccardSimilarity(tokensA, tokensB);\n\n    final shingleA = _shingles(a, 3);\n    final shingleB = _shingles(b, 3);\n    final shingleSim = _jaccardSimilarity(shingleA, shingleB);\n\n    // Weight shingles slightly higher to penalize paraphrases less well-captured by tokens\n    return (tokenSim * 0.45) + (shingleSim * 0.55);\n  }\n"""
new_combined = """  double _containmentSimilarity(Set<String> a, Set<String> b) {\n    if (a.isEmpty || b.isEmpty) return 0.0;\n    final intersection = a.intersection(b).length.toDouble();\n    final smaller = a.length < b.length ? a.length : b.length;\n    if (smaller == 0) return 0.0;\n    return intersection / smaller;\n  }\n\n  /// Domain-agnostic near-duplicate score. It combines whole-stem token overlap,\n  /// phrase overlap, and containment so paraphrases with extra framing are still\n  /// caught without relying on any subject-specific vocabulary.\n  double _combinedSimilarity(String a, String b) {\n    final tokensA = _tokenize(a);\n    final tokensB = _tokenize(b);\n    final tokenSim = _jaccardSimilarity(tokensA, tokensB);\n    final containment = _containmentSimilarity(tokensA, tokensB);\n\n    final bigramSim = _jaccardSimilarity(_shingles(a, 2), _shingles(b, 2));\n    final trigramSim = _jaccardSimilarity(_shingles(a, 3), _shingles(b, 3));\n\n    final weighted =\n        (tokenSim * 0.42) + (bigramSim * 0.33) + (trigramSim * 0.25);\n    final containmentSignal = containment * 0.72;\n    final phraseSignal = bigramSim * 0.88;\n    var score = weighted;\n    if (containmentSignal > score) score = containmentSignal;\n    if (phraseSignal > score) score = phraseSignal;\n    return score;\n  }\n\n  List<String> _correctOptionTexts(Question question) {\n    final result = <String>[];\n    final limit = question.options.length < question.correctAnswers.length\n        ? question.options.length\n        : question.correctAnswers.length;\n    for (var index = 0; index < limit; index++) {\n      if (question.correctAnswers[index]) result.add(question.options[index]);\n    }\n    return result;\n  }\n\n  bool _questionsNearDuplicate(Question a, Question b) {\n    final stemScore = _combinedSimilarity(a.questionText, b.questionText);\n    if (stemScore >= _dedupeSimilarityThreshold) return true;\n\n    final answersA = _correctOptionTexts(a).join(' ');\n    final answersB = _correctOptionTexts(b).join(' ');\n    if (answersA.isNotEmpty && answersB.isNotEmpty) {\n      final answerScore = _combinedSimilarity(answersA, answersB);\n      // Same/similar answer plus meaningful stem overlap is a strong signal that\n      // two differently-worded questions test the same underlying concept.\n      if (stemScore >= 0.24 && answerScore >= 0.68) return true;\n\n      final conceptA = '${a.questionText} $answersA';\n      final conceptB = '${b.questionText} $answersB';\n      if (_combinedSimilarity(conceptA, conceptB) >=\n          _dedupeSimilarityThreshold) {\n        return true;\n      }\n    }\n    return false;\n  }\n"""
service = replace_once(service, old_combined, new_combined, 'stronger generic similarity')

old_serial_dedupe = """      for (final existingQ in keep) {\n        final sim = _combinedSimilarity(q.questionText, existingQ.questionText);\n        if (sim >= _dedupeSimilarityThreshold) {\n          isDuplicate = true;\n          debugPrint(\n            '[AiGenerationService] Detected near-duplicate stem (sim=${sim.toStringAsFixed(2)}): ${q.questionText.substring(0, q.questionText.length > 80 ? 80 : q.questionText.length)}',\n          );\n          break;\n        }\n      }\n"""
new_serial_dedupe = """      for (final existingQ in keep) {\n        final sim = _combinedSimilarity(q.questionText, existingQ.questionText);\n        if (_questionsNearDuplicate(q, existingQ)) {\n          isDuplicate = true;\n          debugPrint(\n            '[AiGenerationService] Detected near-duplicate stem (stem score=${sim.toStringAsFixed(2)}): ${q.questionText.substring(0, q.questionText.length > 80 ? 80 : q.questionText.length)}',\n          );\n          break;\n        }\n      }\n"""
service = replace_once(service, old_serial_dedupe, new_serial_dedupe, 'serial semantic dedupe')

SERVICE.write_text(service)

screen = SCREEN.read_text()

screen = replace_once(
    screen,
    """  final ValueNotifier<int> _progressNotifier = ValueNotifier<int>(0);\n""",
    """  final ValueNotifier<int> _progressNotifier = ValueNotifier<int>(0);\n  final ValueNotifier<GenerationExecutionStatus?> _executionStatusNotifier =\n      ValueNotifier<GenerationExecutionStatus?>(null);\n""",
    'execution status notifier',
)

screen = replace_once(
    screen,
    """    _additionalInstructionsController.dispose();\n    _progressNotifier.dispose();\n    super.dispose();\n""",
    """    _additionalInstructionsController.dispose();\n    _progressNotifier.dispose();\n    _executionStatusNotifier.dispose();\n    super.dispose();\n""",
    'dispose execution notifier',
)

screen = replace_once(
    screen,
    """    setState(() => _isGenerating = true);\n    _progressNotifier.value = 0;\n""",
    """    setState(() => _isGenerating = true);\n    _progressNotifier.value = 0;\n    _executionStatusNotifier.value = const GenerationExecutionStatus(\n      mode: GenerationExecutionMode.preparing,\n    );\n""",
    'reset execution status',
)

screen = replace_once(
    screen,
    """        onProgress: (current, total) {\n          _progressNotifier.value = current;\n        },\n      );\n""",
    """        onProgress: (current, total) {\n          _progressNotifier.value = current;\n        },\n        onExecutionStatus: (status) {\n          _executionStatusNotifier.value = status;\n        },\n      );\n""",
    'wire execution status callback',
)

pattern = re.compile(r"  Widget _buildProgressDialog\(\) \{.*?\n  void _showApiKeyError\(\) \{", re.S)
match = pattern.search(screen)
if not match:
    raise RuntimeError('progress dialog function not found')

new_dialog = r'''  Widget _buildProgressDialog() {
    return ValueListenableBuilder<GenerationExecutionStatus?>(
      valueListenable: _executionStatusNotifier,
      builder: (context, executionStatus, child) {
        return ValueListenableBuilder<int>(
          valueListenable: _progressNotifier,
          builder: (context, currentProgressValue, child) {
            final currentValue = currentProgressValue;
            final percentage = _numberOfStems > 0
                ? (currentValue / _numberOfStems * 100).toInt()
                : 0;

            return AlertDialog(
              title: const Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  SizedBox(width: 16),
                  Expanded(child: Text('Generating Quiz…')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quiz: ${_quizNameController.text.trim()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Topic: ${_topicController.text.trim()}'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: _numberOfStems > 0
                              ? currentValue / _numberOfStems
                              : 0,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$percentage%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Progress: $currentValue / $_numberOfStems stems',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    executionStatus?.displayText ?? 'Mode: preparing…',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Generated: ${currentValue * _branchesPerStem} / ${_numberOfStems * _branchesPerStem} questions',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              currentValue == 0
                                  ? 'Preparing request…'
                                  : currentValue < _numberOfStems
                                  ? 'Generating questions… This may take a few moments.'
                                  : executionStatus?.mode ==
                                            GenerationExecutionMode.serialRefill
                                      ? 'Checking uniqueness and replacing near-duplicates…'
                                      : 'Finalizing quiz…',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final shouldCancel = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Cancel Generation?'),
                        content: const Text(
                          'Are you sure you want to cancel this quiz generation? Any progress will be lost.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: const Text('No, Continue'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            child: const Text('Yes, Cancel'),
                          ),
                        ],
                      ),
                    );

                    if (shouldCancel == true) {
                      _aiService.cancelGeneration();
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showApiKeyError() {'''

screen = screen[:match.start()] + new_dialog + screen[match.end():]
SCREEN.write_text(screen)

print('P1G diversity + truthful execution mode patch applied')
