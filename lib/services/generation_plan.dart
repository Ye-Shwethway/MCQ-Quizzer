import '../models/ai_provider_profile.dart';

/// Immutable request strategy for one AI quiz-generation run.
///
/// The planner is deliberately transport-agnostic. Streaming/concurrency can be
/// enabled later by adapters that prove those capabilities; unknown models keep
/// conservative defaults instead of being classified as "free" or "paid".
class GenerationPlan {
  const GenerationPlan({
    required this.targetStemsPerRequest,
    required this.fallbackStemsPerRequest,
    required this.maxConcurrentRequests,
    required this.maxOutputTokensPerRequest,
    required this.transportStreaming,
  });

  final int targetStemsPerRequest;
  final int fallbackStemsPerRequest;
  final int maxConcurrentRequests;
  final int maxOutputTokensPerRequest;
  final bool transportStreaming;
}

class GenerationRequestShape {
  const GenerationRequestShape({
    required this.totalStems,
    required this.branchesPerStem,
    this.questionStyle,
    this.sampleCharacters = 0,
    this.additionalInstructionCharacters = 0,
    this.includesExplanations = true,
  });

  final int totalStems;
  final int branchesPerStem;
  final String? questionStyle;
  final int sampleCharacters;
  final int additionalInstructionCharacters;
  final bool includesExplanations;

  bool get isClinicalScenario =>
      questionStyle?.trim().toLowerCase() == 'clinical scenario';
}

/// Capability metadata passed from a provider catalog when available.
/// Missing metadata is a supported state and uses the proven conservative path.
class GenerationModelCapabilities {
  const GenerationModelCapabilities({
    this.contextWindowTokens,
    this.maxOutputTokens,
  });

  final int? contextWindowTokens;
  final int? maxOutputTokens;
}

class GenerationPlanner {
  const GenerationPlanner._();

  // Phase 1 keeps the legacy proven baseline when model metadata is unknown.
  static const int _safeUnknownBatch = 20;
  static const int _absoluteBatchCeiling = 50;
  static const int _safeUnknownOutputTokens = 30000;

  static GenerationPlan build({
    required AiProviderProfile profile,
    required GenerationRequestShape request,
    GenerationModelCapabilities capabilities =
        const GenerationModelCapabilities(),
  }) {
    final total = request.totalStems.clamp(1, _absoluteBatchCeiling);
    final outputLimit = capabilities.maxOutputTokens;
    final contextLimit = capabilities.contextWindowTokens;

    var batch = _safeUnknownBatch.clamp(1, total);

    // Larger output ceilings are the strongest useful signal for a structured
    // quiz response. Context alone never authorizes a huge batch.
    if (outputLimit != null) {
      if (outputLimit >= 60000) {
        batch = 40.clamp(1, total);
      } else if (outputLimit >= 40000) {
        batch = 30.clamp(1, total);
      } else if (outputLimit < 20000) {
        batch = 12.clamp(1, total);
      }
    } else if (contextLimit != null && contextLimit < 32000) {
      batch = 12.clamp(1, total);
    }

    // Rich stems cost materially more output than short direct questions.
    if (request.isClinicalScenario) {
      batch = (batch * 0.75).floor().clamp(6, total);
    }
    if (request.branchesPerStem >= 5) {
      batch = (batch * 0.85).floor().clamp(6, total);
    }
    // Explanations are already part of the proven 20-stem baseline. Only use
    // their extra cost to temper batches that capability metadata enlarged.
    if (request.includesExplanations && batch > _safeUnknownBatch) {
      batch = (batch * 0.9).floor().clamp(6, total);
    }

    // Very large examples/instructions increase input pressure. Keep the
    // adjustment bounded so unknown providers remain usable.
    final promptExtras =
        request.sampleCharacters + request.additionalInstructionCharacters;
    if (promptExtras > 12000) {
      batch = (batch * 0.75).floor().clamp(6, total);
    }

    final fallback = (batch / 2).ceil().clamp(4, batch);
    final estimatedPerStem = _estimatedTokensPerStem(request);
    final desiredOutput = (estimatedPerStem * batch + 1200).ceil();
    final effectiveOutputLimit = outputLimit ?? _safeUnknownOutputTokens;
    final outputBudget = desiredOutput.clamp(4096, effectiveOutputLimit);

    return GenerationPlan(
      targetStemsPerRequest: batch,
      fallbackStemsPerRequest: fallback,
      // Phase 1 remains sequential. Concurrency only increases after runtime
      // error normalization and deterministic reassembly are wired in.
      maxConcurrentRequests: 1,
      maxOutputTokensPerRequest: outputBudget,
      // Current provider adapters are non-streaming. Never advertise streaming
      // until an adapter supplies confirmed question events.
      transportStreaming: false,
    );
  }

  static double _estimatedTokensPerStem(GenerationRequestShape request) {
    var tokens = 260.0 + (request.branchesPerStem * 55.0);
    if (request.includesExplanations) tokens += 180.0;
    if (request.isClinicalScenario) tokens += 220.0;
    return tokens;
  }
}
