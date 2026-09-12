from pathlib import Path

path = Path('lib/services/ai_generation_service.dart')
source = path.read_text()

old = """    final client = _httpClient;\n    if (client == null) {\n      throw AiGenerationException('Generation cancelled by user');\n    }\n    final adapter = AiProviderService(client: client);\n"""

new = """    final client = _httpClient;\n    if (client == null) {\n      throw AiGenerationException('Generation cancelled by user');\n    }\n    if (plan.maxConcurrentRequests > 1 && numberOfStems >= 20) {\n      return _generateWithProfileConcurrent(\n        profile: profile,\n        plan: plan,\n        apiKey: apiKey,\n        topic: topic,\n        numberOfStems: numberOfStems,\n        branchesPerStem: branchesPerStem,\n        difficulty: difficulty,\n        questionStyle: questionStyle,\n        subjectCategory: subjectCategory,\n        sampleQuestions: sampleQuestions,\n        additionalInstructions: additionalInstructions,\n        onProgress: onProgress,\n      );\n    }\n    final adapter = AiProviderService(client: client);\n"""

if '_generateWithProfileConcurrent({' not in source:
    assert old in source, 'profile generation insertion anchor missing'
    source = source.replace(old, new, 1)

helper_anchor = """  Future<Quiz> _generateWithProfile({\n"""
helper = r'''  Future<Quiz> _generateWithProfileConcurrent({
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
    _checkCancellation();
    final laneCount = plan.maxConcurrentRequests.clamp(1, 2);
    final laneSizes = <int>[];
    var remaining = numberOfStems;
    for (var index = 0; index < laneCount; index++) {
      final lanesLeft = laneCount - index;
      final size = (remaining / lanesLeft).ceil();
      laneSizes.add(size);
      remaining -= size;
    }

    debugPrint(
      '[AiGenerationService] Bounded concurrency: $laneCount lanes for $numberOfStems stems (${laneSizes.join(' + ')}).',
    );

    final serialPlan = plan.serial();
    final laneProgress = List<int>.filled(laneCount, 0);
    final laneResults = List<Quiz?>.filled(laneCount, null);
    final laneErrors = List<Object?>.filled(laneCount, null);
    var reportedProgress = 0;

    void reportCombinedProgress() {
      final confirmed = laneProgress.fold<int>(0, (sum, value) => sum + value);
      if (confirmed > reportedProgress) {
        reportedProgress = confirmed.clamp(0, numberOfStems);
        onProgress?.call(reportedProgress, numberOfStems);
      }
    }

    String laneInstructions(int index) {
      final partition =
          'Parallel generation partition ${index + 1}/$laneCount. Produce a distinct subset of the requested topic. Avoid generic repetition and vary the factual focus from other partitions while following every original quiz requirement.';
      if (additionalInstructions?.trim().isNotEmpty == true) {
        return '${additionalInstructions!.trim()}\n\n$partition';
      }
      return partition;
    }

    await Future.wait(
      List.generate(laneCount, (index) async {
        try {
          laneResults[index] = await _generateWithProfile(
            profile: profile,
            plan: serialPlan,
            apiKey: apiKey,
            topic: topic,
            numberOfStems: laneSizes[index],
            branchesPerStem: branchesPerStem,
            difficulty: difficulty,
            questionStyle: questionStyle,
            subjectCategory: subjectCategory,
            sampleQuestions: sampleQuestions,
            additionalInstructions: laneInstructions(index),
            onProgress: (current, total) {
              laneProgress[index] = current.clamp(0, laneSizes[index]);
              reportCombinedProgress();
            },
          );
        } catch (error) {
          laneErrors[index] = error;
        }
      }),
    );

    // A failed parallel lane is retried serially. This is the runtime downgrade
    // path for rate limits, timeouts, transient overload and similar failures.
    for (var index = 0; index < laneCount; index++) {
      final error = laneErrors[index];
      if (error == null) continue;
      final failure = GenerationRecoveryPolicy.classifyMessage(error.toString());
      if (failure == GenerationFailureKind.unknown) {
        throw error;
      }
      debugPrint(
        '[AiGenerationService] Parallel lane ${index + 1} failed with $failure; downgrading that work to serial generation.',
      );
      if (failure == GenerationFailureKind.rateLimit) {
        await Future.delayed(const Duration(seconds: 2));
      }
      laneProgress[index] = 0;
      laneResults[index] = await _generateWithProfile(
        profile: profile,
        plan: serialPlan,
        apiKey: apiKey,
        topic: topic,
        numberOfStems: laneSizes[index],
        branchesPerStem: branchesPerStem,
        difficulty: difficulty,
        questionStyle: questionStyle,
        subjectCategory: subjectCategory,
        sampleQuestions: sampleQuestions,
        additionalInstructions: laneInstructions(index),
        onProgress: (current, total) {
          laneProgress[index] = current.clamp(0, laneSizes[index]);
          reportCombinedProgress();
        },
      );
    }

    final merged = <Question>[];
    for (final quiz in laneResults) {
      if (quiz != null) merged.addAll(quiz.questions);
    }

    final unique = <Question>[];
    void addUnique(Iterable<Question> questions) {
      for (final question in questions) {
        final duplicate = unique.any(
          (existing) =>
              _combinedSimilarity(
                existing.questionText,
                question.questionText,
              ) >=
              _dedupeSimilarityThreshold,
        );
        if (!duplicate) unique.add(question);
        if (unique.length >= numberOfStems) return;
      }
    }

    addUnique(merged);
    debugPrint(
      '[AiGenerationService] Parallel reassembly: ${merged.length} generated, ${unique.length} unique.',
    );

    // Parallel requests intentionally do not carry giant cross-lane avoid lists.
    // Dedupe locally, then request only the missing count with a compact avoid list.
    var refillAttempt = 0;
    while (unique.length < numberOfStems && refillAttempt < _maxRefillAttempts) {
      refillAttempt++;
      final missing = numberOfStems - unique.length;
      var avoid = unique.map((q) => '- ${_shortenStem(q.questionText)}').join('\n');
      if (avoid.length > _maxAvoidSnippetChars) {
        avoid = '${avoid.substring(0, _maxAvoidSnippetChars)}\n- ... (truncated)';
      }
      final refillInstruction =
          '${additionalInstructions?.trim().isNotEmpty == true ? '${additionalInstructions!.trim()}\n\n' : ''}'
          'Generate $missing additional DISTINCT stems. Do not repeat or closely paraphrase these existing stems:\n$avoid';
      final base = unique.length;
      final refill = await _generateWithProfile(
        profile: profile,
        plan: serialPlan,
        apiKey: apiKey,
        topic: topic,
        numberOfStems: missing,
        branchesPerStem: branchesPerStem,
        difficulty: difficulty,
        questionStyle: questionStyle,
        subjectCategory: subjectCategory,
        sampleQuestions: sampleQuestions,
        additionalInstructions: refillInstruction,
        onProgress: (current, total) {
          final value = (base + current).clamp(0, numberOfStems);
          if (value > reportedProgress) {
            reportedProgress = value;
            onProgress?.call(value, numberOfStems);
          }
        },
      );
      final before = unique.length;
      addUnique(refill.questions);
      if (unique.length == before) break;
    }

    // Count correctness wins over an endless refill loop. If aggressive local
    // similarity filtering still left a gap, do one final serial safety fill.
    if (unique.length < numberOfStems) {
      final missing = numberOfStems - unique.length;
      debugPrint(
        '[AiGenerationService] Final serial safety fill for $missing stems after parallel dedupe.',
      );
      final safety = await _generateWithProfile(
        profile: profile,
        plan: serialPlan,
        apiKey: apiKey,
        topic: topic,
        numberOfStems: missing,
        branchesPerStem: branchesPerStem,
        difficulty: difficulty,
        questionStyle: questionStyle,
        subjectCategory: subjectCategory,
        sampleQuestions: sampleQuestions,
        additionalInstructions: additionalInstructions,
        onProgress: null,
      );
      final stillNeeded = numberOfStems - unique.length;
      unique.addAll(safety.questions.take(stillNeeded));
    }

    if (unique.length < numberOfStems) {
      throw AiGenerationException(
        'Could not produce the requested number of questions after bounded parallel recovery.',
      );
    }
    onProgress?.call(numberOfStems, numberOfStems);
    return Quiz(
      title: 'Quiz on $topic',
      questions: unique.take(numberOfStems).toList(),
    );
  }

'''

if helper not in source:
    assert helper_anchor in source, 'helper insertion anchor missing'
    source = source.replace(helper_anchor, helper + helper_anchor, 1)

path.write_text(source)
