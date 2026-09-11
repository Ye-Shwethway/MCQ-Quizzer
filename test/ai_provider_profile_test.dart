import 'package:flutter_test/flutter_test.dart';
import 'package:mcq_quizzer/models/ai_provider_profile.dart';

void main() {
  group('AiProviderProfile', () {
    test('round-trips persisted configuration', () {
      final profile = AiProviderProfile(
        id: 'work-openrouter',
        definitionId: 'openrouter',
        displayName: 'Work',
        baseUrl: 'https://openrouter.ai/api/v1',
        modelsPath: '/models',
        generationPath: '/chat/completions',
        selectedModelId: 'vendor/model',
        catalogScope: AiCatalogScope.accountVisible,
        validationState: AiValidationState.verified,
        validatedAt: DateTime.utc(2026, 9, 4),
        isActive: true,
      );

      final restored = AiProviderProfile.fromJson(profile.toJson());

      expect(restored.id, profile.id);
      expect(restored.definitionId, 'openrouter');
      expect(restored.selectedModelId, 'vendor/model');
      expect(restored.validationState, AiValidationState.verified);
      expect(restored.isReady, isTrue);
    });

    test('model search includes metadata and capabilities', () {
      final model = ProviderModel(
        id: 'alpha-chat',
        displayName: 'Alpha',
        description: 'Fast reasoning model',
        capabilities: const ['tools', 'vision'],
        fetchedAt: DateTime.utc(2026, 9, 4),
      );

      expect(model.matches('reason'), isTrue);
      expect(model.matches('VISION'), isTrue);
      expect(model.matches('missing'), isFalse);
    });
  });
}
