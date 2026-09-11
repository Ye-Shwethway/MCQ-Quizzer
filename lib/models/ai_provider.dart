/// Supported AI providers for quiz generation
enum AiProvider {
  gemini('Gemini', 'Google Gemini API'),
  openai('OpenAI', 'OpenAI GPT API'),
  claude('Claude', 'Anthropic Claude API');

  final String id;
  final String displayName;

  const AiProvider(this.id, this.displayName);

  /// Get provider from string ID
  static AiProvider? fromId(String id) {
    try {
      return AiProvider.values.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get display name for dropdown
  String get label => displayName;

  /// Get API documentation URL
  String get documentationUrl {
    switch (this) {
      case AiProvider.gemini:
        return 'https://ai.google.dev/gemini-api/docs/api-key';
      case AiProvider.openai:
        return 'https://platform.openai.com/api-keys';
      case AiProvider.claude:
        return 'https://console.anthropic.com/settings/keys';
    }
  }

  /// Get recommended model for quiz generation
  String get recommendedModel {
    switch (this) {
      case AiProvider.gemini:
        return 'gemini-2.5-flash';
      case AiProvider.openai:
        return 'gpt-4o';
      case AiProvider.claude:
        return 'claude-3-5-sonnet-20241022';
    }
  }

  /// Get API endpoint base URL
  String get apiEndpoint {
    switch (this) {
      case AiProvider.gemini:
        return 'https://generativelanguage.googleapis.com/v1beta';
      case AiProvider.openai:
        return 'https://api.openai.com/v1';
      case AiProvider.claude:
        return 'https://api.anthropic.com/v1';
    }
  }
}

/// Configuration for AI provider
class AiProviderConfig {
  final AiProvider provider;
  final String apiKey;
  final String? customModel;

  AiProviderConfig({
    required this.provider,
    required this.apiKey,
    this.customModel,
  });

  String get model => customModel ?? provider.recommendedModel;

  Map<String, dynamic> toJson() {
    return {
      'provider': provider.id,
      'apiKey': apiKey,
      'customModel': customModel,
    };
  }

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) {
    return AiProviderConfig(
      provider: AiProvider.fromId(json['provider']) ?? AiProvider.gemini,
      apiKey: json['apiKey'],
      customModel: json['customModel'],
    );
  }
}
