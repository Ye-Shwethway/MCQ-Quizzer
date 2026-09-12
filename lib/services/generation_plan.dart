import '../models/ai_provider_profile.dart';

/// Immutable request strategy for one AI quiz-generation run.
///
/// The planner is deliberately transport-agnostic. Unknown models keep
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

  GenerationPlan serial() => GenerationPlan(
    targetStemsPerRequest: targetStemsPerRequest,
    fallbackStemsPerRequest: fallbackStemsPerRequest,
    maxConcurrentRequests: 1,
    maxOutputTokensPerRequest: maxOutputTokensPerRequest,
    transportStreaming: transportStreaming,
  );
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

  // Unknown models keep the legacy proven baseline.
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
    if (request.includesExplanations && batch > _safeUnknownBatch) {
      batch = (batch * 0.9).floor().clamp(6, total);
    }

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

    // Bounded concurrency is capped at 2. Normally it is enabled only when
    // catalog metadata indicates that the selected model is not constrained by
    // a small output/context ceiling. NanoGPT subscription is also allowed a
    // bounded real-device trial when metadata is absent, because that is a
    // common route where the catalog can omit token ceilings. Explicitly small
    // ceilings still force serial mode. Runtime 429/timeout/limit recovery
    // immediately downgrades failed parallel work to the serial plan.
    final hasCapabilityMetadata = outputLimit != null || contextLimit != null;
    final outputAllowsParallel = outputLimit == null || outputLimit >= 24000;
    final contextAllowsParallel = contextLimit == null || contextLimit >= 64000;
    final nanoGptSubscriptionTrial =
        profile.definition.adapterKind == AiAdapterKind.nanoGpt &&
        profile.inferenceRoute == AiInferenceRoute.subscription;
    final capabilityEligible =
        hasCapabilityMetadata && outputAllowsParallel && contextAllowsParallel;
    final subscriptionTrialEligible =
        nanoGptSubscriptionTrial &&
        outputAllowsParallel &&
        contextAllowsParallel;
    final parallelEligible =
        request.totalStems >= 20 &&
        (capabilityEligible || subscriptionTrialEligible);

    return GenerationPlan(
      targetStemsPerRequest: batch,
      fallbackStemsPerRequest: fallback,
      maxConcurrentRequests: parallelEligible ? 2 : 1,
      maxOutputTokensPerRequest: outputBudget,
      // Every profile adapter attempts streaming first. Endpoints/models that
      // reject streaming automatically fall back to the proven request path.
      transportStreaming: true,
    );
  }

  static double _estimatedTokensPerStem(GenerationRequestShape request) {
    var tokens = 260.0 + (request.branchesPerStem * 55.0);
    if (request.includesExplanations) tokens += 180.0;
    if (request.isClinicalScenario) tokens += 220.0;
    return tokens;
  }
}
