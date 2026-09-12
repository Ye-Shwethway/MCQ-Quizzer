import '../models/ai_provider_profile.dart';
import 'ai_settings_repository.dart';
import 'generation_plan.dart';

/// Resolves generation-relevant model metadata without making generation
/// depend on catalog availability. A missing/stale/partial catalog simply
/// returns unknown capabilities and lets [GenerationPlanner] use safe defaults.
class GenerationCapabilityResolver {
  GenerationCapabilityResolver({AiSettingsRepository? settings})
      : _settings = settings ?? AiSettingsRepository();

  final AiSettingsRepository _settings;

  Future<GenerationModelCapabilities> forProfile(
    AiProviderProfile profile,
  ) async {
    final modelId = profile.selectedModelId;
    if (modelId == null || modelId.trim().isEmpty) {
      return const GenerationModelCapabilities();
    }

    try {
      final catalog = await _settings.getCachedCatalog(profile);
      ProviderModel? selected;
      for (final model in catalog) {
        if (model.id == modelId) {
          selected = model;
          break;
        }
      }
      if (selected == null) return const GenerationModelCapabilities();

      return GenerationModelCapabilities(
        contextWindowTokens: selected.contextWindowTokens,
        maxOutputTokens: selected.maxOutputTokens,
      );
    } catch (_) {
      // Catalog metadata is advisory. Generation must remain available if a
      // cache read fails or an older profile has no cached catalog yet.
      return const GenerationModelCapabilities();
    }
  }
}
