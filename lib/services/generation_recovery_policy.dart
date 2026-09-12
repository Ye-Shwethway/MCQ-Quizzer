import 'generation_plan.dart';

enum GenerationFailureKind {
  rateLimit,
  inputOrContextLimit,
  outputLimit,
  timeout,
  transientServer,
  malformedOrTruncated,
  unsupportedStreaming,
  unknown,
}

class GenerationRecoveryDecision {
  const GenerationRecoveryDecision({
    required this.nextBatchSize,
    required this.maxConcurrentRequests,
    required this.retry,
    this.backoff = Duration.zero,
  });

  final int nextBatchSize;
  final int maxConcurrentRequests;
  final bool retry;
  final Duration backoff;
}

/// Small deterministic policy used by transports after they normalize an
/// observed provider failure. It never switches provider/model automatically.
class GenerationRecoveryPolicy {
  const GenerationRecoveryPolicy._();

  static GenerationRecoveryDecision decide({
    required GenerationPlan plan,
    required GenerationFailureKind failure,
    required int attemptedBatchSize,
    int attempt = 1,
  }) {
    final fallback = plan.fallbackStemsPerRequest.clamp(1, attemptedBatchSize);
    final halved = (attemptedBatchSize / 2).ceil().clamp(1, attemptedBatchSize);

    switch (failure) {
      case GenerationFailureKind.rateLimit:
        return GenerationRecoveryDecision(
          nextBatchSize: fallback,
          maxConcurrentRequests: 1,
          retry: attempt <= 2,
          backoff: Duration(seconds: 2 * attempt.clamp(1, 4)),
        );
      case GenerationFailureKind.inputOrContextLimit:
      case GenerationFailureKind.outputLimit:
      case GenerationFailureKind.malformedOrTruncated:
        return GenerationRecoveryDecision(
          nextBatchSize: halved,
          maxConcurrentRequests: 1,
          retry: attempt <= 2 && attemptedBatchSize > 1,
        );
      case GenerationFailureKind.timeout:
        return GenerationRecoveryDecision(
          nextBatchSize: fallback,
          maxConcurrentRequests: 1,
          retry: attempt <= 2,
          backoff: const Duration(seconds: 1),
        );
      case GenerationFailureKind.transientServer:
        return GenerationRecoveryDecision(
          nextBatchSize: fallback,
          maxConcurrentRequests: 1,
          retry: attempt <= 2,
          backoff: Duration(seconds: attempt.clamp(1, 3)),
        );
      case GenerationFailureKind.unsupportedStreaming:
        return GenerationRecoveryDecision(
          nextBatchSize: attemptedBatchSize,
          maxConcurrentRequests: 1,
          retry: attempt <= 1,
        );
      case GenerationFailureKind.unknown:
        return GenerationRecoveryDecision(
          nextBatchSize: fallback,
          maxConcurrentRequests: 1,
          retry: attempt <= 1,
        );
    }
  }

  static GenerationFailureKind classifyMessage(String message) {
    final text = message.toLowerCase();
    if (text.contains('429') ||
        text.contains('rate limit') ||
        text.contains('too many requests')) {
      return GenerationFailureKind.rateLimit;
    }
    if (text.contains('max_tokens') ||
        text.contains('max tokens') ||
        text.contains('output token') ||
        text.contains('response too long')) {
      return GenerationFailureKind.outputLimit;
    }
    if (text.contains('context length') ||
        text.contains('context window') ||
        text.contains('input token') ||
        text.contains('prompt is too long')) {
      return GenerationFailureKind.inputOrContextLimit;
    }
    if (text.contains('timeout') || text.contains('timed out')) {
      return GenerationFailureKind.timeout;
    }
    if (text.contains('500') ||
        text.contains('502') ||
        text.contains('503') ||
        text.contains('504') ||
        text.contains('server error') ||
        text.contains('overloaded')) {
      return GenerationFailureKind.transientServer;
    }
    if (text.contains('truncated') ||
        text.contains('malformed') ||
        text.contains('invalid json') ||
        text.contains('unexpected end')) {
      return GenerationFailureKind.malformedOrTruncated;
    }
    if (text.contains('stream') &&
        (text.contains('unsupported') || text.contains('not supported'))) {
      return GenerationFailureKind.unsupportedStreaming;
    }
    return GenerationFailureKind.unknown;
  }
}
