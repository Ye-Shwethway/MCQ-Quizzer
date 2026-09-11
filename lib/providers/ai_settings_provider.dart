import 'package:flutter/foundation.dart';

import '../models/ai_provider_profile.dart';
import '../services/ai_provider_service.dart';
import '../services/ai_settings_repository.dart';

class AiSettingsProvider extends ChangeNotifier {
  AiSettingsProvider({
    AiSettingsRepository? repository,
    AiProviderService? providerService,
  }) : _repository = repository ?? AiSettingsRepository(),
       _providerService = providerService ?? AiProviderService();

  final AiSettingsRepository _repository;
  final AiProviderService _providerService;

  List<AiProviderProfile> _profiles = const [];
  bool _loading = true;
  String? _error;

  List<AiProviderProfile> get profiles => List.unmodifiable(_profiles);
  bool get loading => _loading;
  String? get error => _error;
  AiProviderProfile? get activeProfile {
    for (final profile in _profiles) {
      if (profile.isActive) return profile;
    }
    return null;
  }

  Future<void> initialize() async {
    _loading = true;
    notifyListeners();
    try {
      await _repository.initialize();
      await refresh();
    } catch (error) {
      _error = 'Could not load AI provider settings: $error';
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      _profiles = await _repository.getProfiles();
      _error = null;
    } catch (error) {
      _error = 'Could not load AI provider settings: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> apiKeyFor(String profileId) =>
      _repository.getApiKey(profileId);

  Future<bool> hasApiKey(String profileId) => _repository.hasApiKey(profileId);

  Future<List<ProviderModel>> cachedCatalog(AiProviderProfile profile) =>
      _repository.getCachedCatalog(profile);

  Future<ConnectionTestResult> testConnection(
    AiProviderProfile profile,
    String apiKey,
  ) => _providerService.testConnection(profile, apiKey);

  Future<List<ProviderModel>> fetchModels(
    AiProviderProfile profile,
    String apiKey,
  ) => _providerService.fetchModels(profile, apiKey);

  Future<ConnectionTestResult> testModel(
    AiProviderProfile profile,
    String apiKey,
  ) => _providerService.testModel(profile, apiKey);

  Future<void> save(
    AiProviderProfile profile, {
    String? newApiKey,
    List<ProviderModel>? catalog,
  }) async {
    await _repository.saveProfile(profile, newApiKey: newApiKey);
    if (catalog != null) await _repository.saveCatalog(profile, catalog);
    await refresh();
  }

  Future<void> activate(AiProviderProfile profile) async {
    if (!profile.isReady) {
      throw StateError('Test the connection and selected model first.');
    }
    await _repository.activate(profile.id);
    await refresh();
  }

  Future<void> delete(AiProviderProfile profile) async {
    await _repository.deleteProfile(profile.id);
    await refresh();
  }
}
