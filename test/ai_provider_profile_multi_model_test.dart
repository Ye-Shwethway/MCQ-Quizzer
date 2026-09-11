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

    test('round-trips multiple saved models and active selection', () {
      const first = AiProviderModelBinding(
        id: 'minimax/minimax-m3:thinking',
        displayName: 'MiniMax M3 Thinking',
        catalogScope: AiCatalogScope.subscription,
        inferenceRoute: AiInferenceRoute.subscription,
        validationState: AiValidationState.verified,
      );
      const secondId = 'deepseek/deepseek-v4-flash-0731:thinking';
      const second = AiProviderModelBinding(
        id: secondId,
        displayName: 'DeepSeek V4 Flash 0731 (Thinking)',
        catalogScope: AiCatalogScope.all,
        inferenceRoute: AiInferenceRoute.paid,
        validationState: AiValidationState.verified,
      );

      const original = AiProviderProfile(
        id: 'nanogpt-primary',
        definitionId: 'nanogpt',
        displayName: 'NanoGPT',
        baseUrl: 'https://nano-gpt.com/api',
        modelsPath: '/v1/models',
        generationPath: '/v1/chat/completions',
        savedModels: [first, second],
        activeModelId: secondId,
        catalogScope: AiCatalogScope.all,
        inferenceRoute: AiInferenceRoute.paid,
        validationState: AiValidationState.verified,
        isActive: true,
      );

      final restored = AiProviderProfile.fromJson(original.toJson());

      expect(restored.schemaVersion, 2);
      expect(restored.savedModels, hasLength(2));
      expect(restored.activeModelId, secondId);
      expect(restored.activeModel?.displayName, second.displayName);
      expect(restored.savedModels.first.displayName, first.displayName);
      expect(restored.savedModels.last.inferenceRoute, AiInferenceRoute.paid);
      expect(restored.isReady, isTrue);
    });

    test('legacy selectedModelId copyWith alias selects and clears safely', () {
      const profile = AiProviderProfile(
        id: 'provider',
        definitionId: 'openai',
        displayName: 'OpenAI',
        baseUrl: 'https://api.openai.com/v1',
        modelsPath: '/models',
        generationPath: '/chat/completions',
      );

      final selected = profile.copyWith(selectedModelId: 'gpt-test');
      expect(selected.activeModelId, 'gpt-test');
      expect(selected.selectedModelId, 'gpt-test');

      final cleared = selected.copyWith(clearSelectedModel: true);
      expect(cleared.activeModelId, isNull);
      expect(cleared.selectedModelId, isNull);
    });
  });
}
