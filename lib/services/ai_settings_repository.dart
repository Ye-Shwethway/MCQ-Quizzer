import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_provider_profile.dart';
import 'database_service.dart';
import 'secure_storage_service.dart';

class AiSettingsRepository {
  AiSettingsRepository({
    DatabaseService? database,
    SecureStorageService? secrets,
  }) : _database = database ?? DatabaseService.instance,
       _secrets = secrets ?? SecureStorageService.instance;

  final DatabaseService _database;
  final SecureStorageService _secrets;

  static const _migrationKey = 'ai_provider_profiles_migration_v1';

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_migrationKey) == true) return;

    final existing = await _database.getAiProviderProfiles();
    if (existing.isEmpty) {
      final legacyProvider = await _secrets.getAiProvider();
      if (legacyProvider != null && legacyProvider.isNotEmpty) {
        final definition = _legacyDefinition(legacyProvider);
        final legacyKey = await _secrets.getApiKey(legacyProvider);
        final id = 'legacy_${DateTime.now().microsecondsSinceEpoch}';
        final profile = AiProviderProfile(
          id: id,
          definitionId: definition.id,
          displayName: definition.displayName,
          baseUrl: definition.defaultBaseUrl,
          modelsPath: definition.modelsPath,
          generationPath: definition.generationPath,
          validationState: AiValidationState.needsRetest,
          isActive: true,
        );
        if (legacyKey != null && legacyKey.isNotEmpty) {
          await _secrets.saveProfileApiKey(id, legacyKey);
        }
        await _database.saveAiProviderProfile(profile);
        if (legacyKey != null && legacyKey.isNotEmpty) {
          await _secrets.deleteLegacyAiSettings(legacyProvider);
        }
      }
    }
    await preferences.setBool(_migrationKey, true);
  }

  AiProviderDefinition _legacyDefinition(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('gemini')) return AiProviderRegistry.byId('gemini');
    if (normalized.contains('openai')) return AiProviderRegistry.byId('openai');
    if (normalized.contains('claude') || normalized.contains('anthropic')) {
      return AiProviderRegistry.byId('anthropic');
    }
    return AiProviderRegistry.byId('custom');
  }

  Future<List<AiProviderProfile>> getProfiles() =>
      _database.getAiProviderProfiles();

  Future<AiProviderProfile?> getActiveProfile() =>
      _database.getActiveAiProviderProfile();

  Future<void> saveProfile(
    AiProviderProfile profile, {
    String? newApiKey,
  }) async {
    if (newApiKey != null && newApiKey.trim().isNotEmpty) {
      await _secrets.saveProfileApiKey(profile.id, newApiKey.trim());
    }
    await _database.saveAiProviderProfile(profile);
  }

  Future<void> activate(String profileId) =>
      _database.setActiveAiProviderProfile(profileId);

  Future<void> deleteProfile(String profileId) async {
    await _database.deleteAiProviderProfile(profileId);
    await _secrets.deleteProfileApiKey(profileId);
  }

  Future<String?> getApiKey(String profileId) =>
      _secrets.getProfileApiKey(profileId);

  Future<bool> hasApiKey(String profileId) =>
      _secrets.hasProfileApiKey(profileId);

  Future<void> removeApiKey(String profileId) =>
      _secrets.deleteProfileApiKey(profileId);

  Future<void> saveCatalog(
    AiProviderProfile profile,
    List<ProviderModel> models,
  ) => _database.saveAiModelCatalog(profile.id, profile.catalogScope, models);

  Future<List<ProviderModel>> getCachedCatalog(AiProviderProfile profile) =>
      _database.getAiModelCatalog(profile.id, profile.catalogScope);
}
