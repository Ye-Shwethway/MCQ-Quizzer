import 'package:flutter_test/flutter_test.dart';
import 'package:mcq_quizzer/models/ai_provider_profile.dart';

void main() {
  group('AiProviderProfile schema v2', () {
    test('migrates a legacy selected model into one saved binding', () {
      final validatedAt = DateTime.utc(2026, 9, 11, 8, 30);
      final profile = AiProviderProfile.fromJson({
        'id': 'legacy-profile',
        'definitionId': 'nanogpt',
        'displayName': 'NanoGPT',
        'baseUrl': 'https://nano-gpt.com/api',
        'modelsPath': '/v1/models',
        'generationPath': '/v1/chat/completions',
        'selectedModelId': 'minimax/minimax-m3:thinking',
        'catalogScope': 'subscription',
        'inferenceRoute': 'subscription',
        'validationState': 'verified',
        'validatedAt': validatedAt.toIso8601String(),
        'lastErrorCategory': null,
        'isActive': true,
        'schemaVersion': 1,
      });

      expect(profile.schemaVersion, 2);
      expect(profile.activeModelId, 'minimax/minimax-m3:thinking');
      expect(profile.selectedModelId, profile.activeModelId);
      expect(profile.savedModels, hasLength(1));

      final migrated = profile.savedModels.single;
      expect(migrated.id, 'minimax/minimax-m3:thinking');
      expect(migrated.catalogScope, AiCatalogScope.subscription);
      expect(migrated.inferenceRoute, AiInferenceRoute.subscription);
      expect(migrated.validationState, AiValidationState.verified);
      expect(migrated.validatedAt, validatedAt);
      expect(profile.isReady, isTrue);
    });
  });
}
