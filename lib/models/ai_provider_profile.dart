import 'dart:convert';

enum AiAdapterKind { openAiCompatible, gemini, anthropic, nanoGpt }

enum AiCatalogScope { standard, subscription, all, accountVisible }

enum AiInferenceRoute { standard, subscription, paid }

enum AiValidationState { notTested, verified, needsRetest, invalid }

class AiProviderDefinition {
  final String id;
  final String displayName;
  final String description;
  final AiAdapterKind adapterKind;
  final String defaultBaseUrl;
  final String modelsPath;
  final String generationPath;
  final String documentationUrl;
  final bool isCustom;
  final bool supportsCatalogScopes;

  const AiProviderDefinition({
    required this.id,
    required this.displayName,
    required this.description,
    required this.adapterKind,
    required this.defaultBaseUrl,
    required this.modelsPath,
    required this.generationPath,
    required this.documentationUrl,
    this.isCustom = false,
    this.supportsCatalogScopes = false,
  });
}

class AiProviderRegistry {
  static const definitions = <AiProviderDefinition>[
    AiProviderDefinition(
      id: 'openai',
      displayName: 'OpenAI',
      description: 'GPT and reasoning models from OpenAI',
      adapterKind: AiAdapterKind.openAiCompatible,
      defaultBaseUrl: 'https://api.openai.com/v1',
      modelsPath: '/models',
      generationPath: '/chat/completions',
      documentationUrl: 'https://platform.openai.com/api-keys',
    ),
    AiProviderDefinition(
      id: 'gemini',
      displayName: 'Google Gemini',
      description: 'Gemini models through Google AI Studio',
      adapterKind: AiAdapterKind.gemini,
      defaultBaseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      modelsPath: '/models',
      generationPath: '/models/{model}:generateContent',
      documentationUrl: 'https://ai.google.dev/gemini-api/docs/api-key',
    ),
    AiProviderDefinition(
      id: 'anthropic',
      displayName: 'Anthropic Claude',
      description: 'Claude models through the Messages API',
      adapterKind: AiAdapterKind.anthropic,
      defaultBaseUrl: 'https://api.anthropic.com/v1',
      modelsPath: '/models',
      generationPath: '/messages',
      documentationUrl: 'https://console.anthropic.com/settings/keys',
    ),
    AiProviderDefinition(
      id: 'openrouter',
      displayName: 'OpenRouter',
      description: 'A broad catalog of routed AI models',
      adapterKind: AiAdapterKind.openAiCompatible,
      defaultBaseUrl: 'https://openrouter.ai/api/v1',
      modelsPath: '/models',
      generationPath: '/chat/completions',
      documentationUrl: 'https://openrouter.ai/settings/keys',
    ),
    AiProviderDefinition(
      id: 'nanogpt',
      displayName: 'NanoGPT',
      description: 'Subscription and pay-as-you-go model catalogs',
      adapterKind: AiAdapterKind.nanoGpt,
      defaultBaseUrl: 'https://nano-gpt.com/api',
      modelsPath: '/v1/models',
      generationPath: '/v1/chat/completions',
      documentationUrl: 'https://nano-gpt.com/api',
      supportsCatalogScopes: true,
    ),
    AiProviderDefinition(
      id: 'groq',
      displayName: 'Groq',
      description: 'Fast OpenAI-compatible inference',
      adapterKind: AiAdapterKind.openAiCompatible,
      defaultBaseUrl: 'https://api.groq.com/openai/v1',
      modelsPath: '/models',
      generationPath: '/chat/completions',
      documentationUrl: 'https://console.groq.com/keys',
    ),
    AiProviderDefinition(
      id: 'mistral',
      displayName: 'Mistral AI',
      description: 'Mistral chat and reasoning models',
      adapterKind: AiAdapterKind.openAiCompatible,
      defaultBaseUrl: 'https://api.mistral.ai/v1',
      modelsPath: '/models',
      generationPath: '/chat/completions',
      documentationUrl: 'https://console.mistral.ai/api-keys',
    ),
    AiProviderDefinition(
      id: 'together',
      displayName: 'Together AI',
      description: 'Open-source and serverless model catalog',
      adapterKind: AiAdapterKind.openAiCompatible,
      defaultBaseUrl: 'https://api.together.ai/v1',
      modelsPath: '/models',
      generationPath: '/chat/completions',
      documentationUrl: 'https://api.together.ai/settings/api-keys',
    ),
    AiProviderDefinition(
      id: 'xai',
      displayName: 'xAI',
      description: 'Grok language models',
      adapterKind: AiAdapterKind.openAiCompatible,
      defaultBaseUrl: 'https://api.x.ai/v1',
      modelsPath: '/models',
      generationPath: '/chat/completions',
      documentationUrl: 'https://console.x.ai/',
    ),
    AiProviderDefinition(
      id: 'deepseek',
      displayName: 'DeepSeek',
      description: 'DeepSeek chat and reasoning models',
      adapterKind: AiAdapterKind.openAiCompatible,
      defaultBaseUrl: 'https://api.deepseek.com',
      modelsPath: '/models',
      generationPath: '/chat/completions',
      documentationUrl: 'https://platform.deepseek.com/api_keys',
    ),
    AiProviderDefinition(
      id: 'custom',
      displayName: 'Custom OpenAI-compatible',
      description: 'Connect another OpenAI-compatible endpoint',
      adapterKind: AiAdapterKind.openAiCompatible,
      defaultBaseUrl: '',
      modelsPath: '/models',
      generationPath: '/chat/completions',
      documentationUrl: '',
      isCustom: true,
    ),
  ];

  static AiProviderDefinition byId(String id) => definitions.firstWhere(
    (definition) => definition.id == id,
    orElse: () => definitions.last,
  );
}

class AiProviderProfile {
  final String id;
  final String definitionId;
  final String displayName;
  final String baseUrl;
  final String modelsPath;
  final String generationPath;
  final String? selectedModelId;
  final AiCatalogScope catalogScope;
  final AiInferenceRoute inferenceRoute;
  final AiValidationState validationState;
  final DateTime? validatedAt;
  final DateTime? modelsFetchedAt;
  final String? lastErrorCategory;
  final bool isActive;
  final int schemaVersion;

  const AiProviderProfile({
    required this.id,
    required this.definitionId,
    required this.displayName,
    required this.baseUrl,
    required this.modelsPath,
    required this.generationPath,
    this.selectedModelId,
    this.catalogScope = AiCatalogScope.standard,
    this.inferenceRoute = AiInferenceRoute.standard,
    this.validationState = AiValidationState.notTested,
    this.validatedAt,
    this.modelsFetchedAt,
    this.lastErrorCategory,
    this.isActive = false,
    this.schemaVersion = 1,
  });

  AiProviderDefinition get definition => AiProviderRegistry.byId(definitionId);

  bool get isReady =>
      validationState == AiValidationState.verified &&
      selectedModelId != null &&
      selectedModelId!.isNotEmpty;

  AiProviderProfile copyWith({
    String? displayName,
    String? baseUrl,
    String? modelsPath,
    String? generationPath,
    String? selectedModelId,
    bool clearSelectedModel = false,
    AiCatalogScope? catalogScope,
    AiInferenceRoute? inferenceRoute,
    AiValidationState? validationState,
    DateTime? validatedAt,
    DateTime? modelsFetchedAt,
    String? lastErrorCategory,
    bool clearLastError = false,
    bool? isActive,
  }) {
    return AiProviderProfile(
      id: id,
      definitionId: definitionId,
      displayName: displayName ?? this.displayName,
      baseUrl: baseUrl ?? this.baseUrl,
      modelsPath: modelsPath ?? this.modelsPath,
      generationPath: generationPath ?? this.generationPath,
      selectedModelId: clearSelectedModel
          ? null
          : selectedModelId ?? this.selectedModelId,
      catalogScope: catalogScope ?? this.catalogScope,
      inferenceRoute: inferenceRoute ?? this.inferenceRoute,
      validationState: validationState ?? this.validationState,
      validatedAt: validatedAt ?? this.validatedAt,
      modelsFetchedAt: modelsFetchedAt ?? this.modelsFetchedAt,
      lastErrorCategory: clearLastError
          ? null
          : lastErrorCategory ?? this.lastErrorCategory,
      isActive: isActive ?? this.isActive,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'definitionId': definitionId,
    'displayName': displayName,
    'baseUrl': baseUrl,
    'modelsPath': modelsPath,
    'generationPath': generationPath,
    'selectedModelId': selectedModelId,
    'catalogScope': catalogScope.name,
    'inferenceRoute': inferenceRoute.name,
    'validationState': validationState.name,
    'validatedAt': validatedAt?.toIso8601String(),
    'modelsFetchedAt': modelsFetchedAt?.toIso8601String(),
    'lastErrorCategory': lastErrorCategory,
    'isActive': isActive,
    'schemaVersion': schemaVersion,
  };

  factory AiProviderProfile.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.cast<T>().firstWhere(
          (value) => value.name == name,
          orElse: () => fallback,
        );

    return AiProviderProfile(
      id: json['id'] as String,
      definitionId: json['definitionId'] as String,
      displayName: json['displayName'] as String,
      baseUrl: json['baseUrl'] as String,
      modelsPath: json['modelsPath'] as String? ?? '/models',
      generationPath: json['generationPath'] as String? ?? '/chat/completions',
      selectedModelId: json['selectedModelId'] as String?,
      catalogScope: enumValue(
        AiCatalogScope.values,
        json['catalogScope'] as String?,
        AiCatalogScope.standard,
      ),
      inferenceRoute: enumValue(
        AiInferenceRoute.values,
        json['inferenceRoute'] as String?,
        AiInferenceRoute.standard,
      ),
      validationState: enumValue(
        AiValidationState.values,
        json['validationState'] as String?,
        AiValidationState.notTested,
      ),
      validatedAt: DateTime.tryParse(json['validatedAt'] as String? ?? ''),
      modelsFetchedAt: DateTime.tryParse(
        json['modelsFetchedAt'] as String? ?? '',
      ),
      lastErrorCategory: json['lastErrorCategory'] as String?,
      isActive: json['isActive'] as bool? ?? false,
      schemaVersion: json['schemaVersion'] as int? ?? 1,
    );
  }
}

class ProviderModel {
  final String id;
  final String? displayName;
  final String? description;
  final String? ownedBy;
  final int? contextWindowTokens;
  final int? maxOutputTokens;
  final String? inputPricePerMillion;
  final String? cachedInputPricePerMillion;
  final String? outputPricePerMillion;
  final String? currency;
  final String? pricingNote;
  final List<String> capabilities;
  final String? lifecycle;
  final bool subscriptionEligible;
  final bool paidEligible;
  final DateTime fetchedAt;
  final Map<String, dynamic> rawMetadata;

  const ProviderModel({
    required this.id,
    this.displayName,
    this.description,
    this.ownedBy,
    this.contextWindowTokens,
    this.maxOutputTokens,
    this.inputPricePerMillion,
    this.cachedInputPricePerMillion,
    this.outputPricePerMillion,
    this.currency,
    this.pricingNote,
    this.capabilities = const [],
    this.lifecycle,
    this.subscriptionEligible = false,
    this.paidEligible = false,
    required this.fetchedAt,
    this.rawMetadata = const {},
  });

  String get title =>
      displayName?.trim().isNotEmpty == true ? displayName! : id;

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return [
      id,
      displayName,
      description,
      ownedBy,
      lifecycle,
      ...capabilities,
    ].whereType<String>().any((value) => value.toLowerCase().contains(needle));
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'description': description,
    'ownedBy': ownedBy,
    'contextWindowTokens': contextWindowTokens,
    'maxOutputTokens': maxOutputTokens,
    'inputPricePerMillion': inputPricePerMillion,
    'cachedInputPricePerMillion': cachedInputPricePerMillion,
    'outputPricePerMillion': outputPricePerMillion,
    'currency': currency,
    'pricingNote': pricingNote,
    'capabilities': capabilities,
    'lifecycle': lifecycle,
    'subscriptionEligible': subscriptionEligible,
    'paidEligible': paidEligible,
    'fetchedAt': fetchedAt.toIso8601String(),
    'rawMetadata': rawMetadata,
  };

  factory ProviderModel.fromJson(Map<String, dynamic> json) => ProviderModel(
    id: json['id'] as String,
    displayName: json['displayName'] as String?,
    description: json['description'] as String?,
    ownedBy: json['ownedBy'] as String?,
    contextWindowTokens: json['contextWindowTokens'] as int?,
    maxOutputTokens: json['maxOutputTokens'] as int?,
    inputPricePerMillion: json['inputPricePerMillion'] as String?,
    cachedInputPricePerMillion: json['cachedInputPricePerMillion'] as String?,
    outputPricePerMillion: json['outputPricePerMillion'] as String?,
    currency: json['currency'] as String?,
    pricingNote: json['pricingNote'] as String?,
    capabilities: List<String>.from(json['capabilities'] as List? ?? const []),
    lifecycle: json['lifecycle'] as String?,
    subscriptionEligible: json['subscriptionEligible'] as bool? ?? false,
    paidEligible: json['paidEligible'] as bool? ?? false,
    fetchedAt:
        DateTime.tryParse(json['fetchedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    rawMetadata: Map<String, dynamic>.from(
      json['rawMetadata'] as Map? ?? const <String, dynamic>{},
    ),
  );

  static String encodeList(List<ProviderModel> models) =>
      jsonEncode(models.map((model) => model.toJson()).toList());

  static List<ProviderModel> decodeList(String encoded) =>
      (jsonDecode(encoded) as List)
          .map(
            (item) => ProviderModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
}

class ConnectionTestResult {
  final bool success;
  final String category;
  final String message;
  final int? httpStatus;
  final int? latencyMs;
  final DateTime testedAt;

  const ConnectionTestResult({
    required this.success,
    required this.category,
    required this.message,
    this.httpStatus,
    this.latencyMs,
    required this.testedAt,
  });
}
