import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Service for securely storing sensitive data like API keys
/// Uses platform-specific encryption (Keychain on iOS, KeyStore on Android)
class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._internal();

  SecureStorageService._internal();

  // Configure secure storage with platform-specific options
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      migrateOnAlgorithmChange: true,
      migrateWithBackup: true,
      resetOnError: false,
    ),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Storage keys
  static const String _aiProviderKey = 'ai_provider';
  static const String _apiKeyPrefix = 'api_key_';
  static const String _profileKeyPrefix = 'ai_profile_secret_';

  Future<void> saveProfileApiKey(String profileId, String apiKey) async {
    await _storage.write(key: '$_profileKeyPrefix$profileId', value: apiKey);
  }

  Future<String?> getProfileApiKey(String profileId) {
    return _storage.read(key: '$_profileKeyPrefix$profileId');
  }

  Future<bool> hasProfileApiKey(String profileId) async {
    final value = await getProfileApiKey(profileId);
    return value != null && value.isNotEmpty;
  }

  Future<void> deleteProfileApiKey(String profileId) {
    return _storage.delete(key: '$_profileKeyPrefix$profileId');
  }

  Future<void> deleteLegacyAiSettings(String provider) async {
    await _storage.delete(key: _aiProviderKey);
    await _storage.delete(key: '$_apiKeyPrefix$provider');
  }

  /// Save AI provider selection
  Future<void> saveAiProvider(String provider) async {
    try {
      await _storage.write(key: _aiProviderKey, value: provider);
      debugPrint('[SecureStorage] AI provider saved: $provider');
    } catch (e) {
      debugPrint('[SecureStorage] Error saving AI provider: $e');
      rethrow;
    }
  }

  /// Get saved AI provider
  Future<String?> getAiProvider() async {
    try {
      final provider = await _storage.read(key: _aiProviderKey);
      debugPrint('[SecureStorage] AI provider retrieved: $provider');
      return provider;
    } catch (e) {
      debugPrint('[SecureStorage] Error reading AI provider: $e');
      return null;
    }
  }

  /// Save API key for a specific provider
  Future<void> saveApiKey(String provider, String apiKey) async {
    try {
      await _storage.write(key: '$_apiKeyPrefix$provider', value: apiKey);
      debugPrint('[SecureStorage] API key saved for provider: $provider');
    } catch (e) {
      debugPrint('[SecureStorage] Error saving API key: $e');
      rethrow;
    }
  }

  /// Get API key for a specific provider
  Future<String?> getApiKey(String provider) async {
    try {
      final apiKey = await _storage.read(key: '$_apiKeyPrefix$provider');
      final hasKey = apiKey != null && apiKey.isNotEmpty;
      debugPrint(
        '[SecureStorage] API key retrieved for $provider: ${hasKey ? "present" : "missing"}',
      );
      return apiKey;
    } catch (e) {
      debugPrint('[SecureStorage] Error reading API key: $e');
      return null;
    }
  }

  /// Delete API key for a specific provider
  Future<void> deleteApiKey(String provider) async {
    try {
      await _storage.delete(key: '$_apiKeyPrefix$provider');
      debugPrint('[SecureStorage] API key deleted for provider: $provider');
    } catch (e) {
      debugPrint('[SecureStorage] Error deleting API key: $e');
      rethrow;
    }
  }

  /// Check if API key exists for a provider
  Future<bool> hasApiKey(String provider) async {
    final apiKey = await getApiKey(provider);
    return apiKey != null && apiKey.isNotEmpty;
  }

  /// Delete all stored data
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
      debugPrint('[SecureStorage] All data deleted');
    } catch (e) {
      debugPrint('[SecureStorage] Error deleting all data: $e');
      rethrow;
    }
  }

  /// Get all stored keys (for debugging)
  Future<Map<String, String>> getAllKeys() async {
    try {
      return await _storage.readAll();
    } catch (e) {
      debugPrint('[SecureStorage] Error reading all keys: $e');
      return {};
    }
  }
}
