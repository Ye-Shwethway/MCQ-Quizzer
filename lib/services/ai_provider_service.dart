import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

import '../models/ai_provider_profile.dart';

class AiProviderException implements Exception {
  const AiProviderException(this.category, this.message, {this.statusCode});

  final String category;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Network adapter for every provider profile. API keys are accepted only for
/// the duration of a call and are never logged or persisted by this service.
class AiProviderService {
  AiProviderService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _requestTimeout = Duration(seconds: 30);
  static const _generationTimeout = Duration(minutes: 6);

  Future<ConnectionTestResult> testConnection(
    AiProviderProfile profile,
    String apiKey,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      if (profile.definitionId == 'nanogpt') {
        await _requestJson(
          'POST',
          _resolve(profile.baseUrl, '/check-balance'),
          headers: _nanoBalanceHeaders(apiKey),
          body: const {},
        );
      } else if (profile.definitionId == 'openrouter') {
        await _requestJson(
          'GET',
          _resolve(profile.baseUrl, '/key'),
          headers: _headers(profile, apiKey),
        );
      } else if (profile.definitionId == 'deepseek') {
        await _requestJson(
          'GET',
          _resolve(profile.baseUrl, '/user/balance'),
          headers: _headers(profile, apiKey),
        );
      } else {
        await _fetchStandardCatalog(profile, apiKey, stopAfterFirstPage: true);
      }
      stopwatch.stop();
      return ConnectionTestResult(
        success: true,
        category: 'ok',
        message: 'Connection and API key verified.',
        latencyMs: stopwatch.elapsedMilliseconds,
        testedAt: DateTime.now(),
      );
    } on AiProviderException catch (error) {
      stopwatch.stop();
      return ConnectionTestResult(
        success: false,
        category: error.category,
        message: error.message,
        httpStatus: error.statusCode,
        latencyMs: stopwatch.elapsedMilliseconds,
        testedAt: DateTime.now(),
      );
    } catch (_) {
      stopwatch.stop();
      return ConnectionTestResult(
        success: false,
        category: 'network',
        message: 'Could not reach the provider. Check the URL and connection.',
        latencyMs: stopwatch.elapsedMilliseconds,
        testedAt: DateTime.now(),
      );
    }
  }

  Future<List<ProviderModel>> fetchModels(
    AiProviderProfile profile,
    String apiKey,
  ) async {
    if (profile.definition.adapterKind == AiAdapterKind.nanoGpt) {
      return _fetchNanoCatalog(profile, apiKey);
    }
    return _fetchStandardCatalog(profile, apiKey);
  }

  Future<ConnectionTestResult> testModel(
    AiProviderProfile profile,
    String apiKey,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final output = await _generateText(
        profile,
        apiKey,
        systemPrompt: '',
        userPrompt: 'Reply with OK.',
        maxTokens: 1024,
        responseProbe: true,
      );
      stopwatch.stop();
      if (output.trim().isEmpty) {
        throw const AiProviderException(
          'invalid_response',
          'The model returned an empty response.',
        );
      }
      return ConnectionTestResult(
        success: true,
        category: 'ok',
        message:
            'The selected model responded successfully. This checks access, not quiz accuracy or format.',
        latencyMs: stopwatch.elapsedMilliseconds,
        testedAt: DateTime.now(),
      );
    } on AiProviderException catch (error) {
      stopwatch.stop();
      return ConnectionTestResult(
        success: false,
        category: error.category,
        message: error.message,
        httpStatus: error.statusCode,
        latencyMs: stopwatch.elapsedMilliseconds,
        testedAt: DateTime.now(),
      );
    } catch (_) {
      stopwatch.stop();
      return ConnectionTestResult(
        success: false,
        category: 'network',
        message: 'The model test could not reach the provider.',
        latencyMs: stopwatch.elapsedMilliseconds,
        testedAt: DateTime.now(),
      );
    }
  }

  Future<String> generateText(
    AiProviderProfile profile,
    String apiKey, {
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 8192,
    double temperature = 0.2,
  }) => _generateText(
    profile,
    apiKey,
    systemPrompt: systemPrompt,
    userPrompt: userPrompt,
    maxTokens: maxTokens,
    temperature: temperature,
  );

  Future<String> _generateText(
    AiProviderProfile profile,
    String apiKey, {
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 8192,
    double temperature = 0.2,
    bool responseProbe = false,
  }) async {
    final model = profile.selectedModelId;
    if (model == null || model.isEmpty) {
      throw const AiProviderException(
        'configuration',
        'Select a model before testing or generating.',
      );
    }

    switch (profile.definition.adapterKind) {
      case AiAdapterKind.gemini:
        final path = profile.generationPath.replaceAll(
          '{model}',
          Uri.encodeComponent(model),
        );
        final json = await _requestJson(
          'POST',
          _resolve(profile.baseUrl, path),
          headers: _headers(profile, apiKey),
          body: {
            if (systemPrompt.isNotEmpty)
              'systemInstruction': {
                'parts': [
                  {'text': systemPrompt},
                ],
              },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': userPrompt},
                ],
              },
            ],
            'generationConfig': {
              if (!responseProbe) 'temperature': temperature,
              'maxOutputTokens': maxTokens,
              if (!responseProbe) 'responseMimeType': 'application/json',
            },
          },
          timeout: _generationTimeout,
        );
        final candidates = json['candidates'] as List?;
        final content = candidates?.isNotEmpty == true
            ? candidates!.first as Map?
            : null;
        final parts = (content?['content'] as Map?)?['parts'] as List?;
        final text = parts
            ?.whereType<Map>()
            .where((part) => responseProbe || part['thought'] != true)
            .map((part) => part['text'])
            .whereType<String>()
            .join();
        return _requireText(text);

      case AiAdapterKind.anthropic:
        final json = await _requestJson(
          'POST',
          _resolve(profile.baseUrl, profile.generationPath),
          headers: _headers(profile, apiKey),
          body: {
            'model': model,
            if (systemPrompt.isNotEmpty) 'system': systemPrompt,
            'messages': [
              {'role': 'user', 'content': userPrompt},
            ],
            if (!responseProbe) 'temperature': temperature,
            'max_tokens': maxTokens,
          },
          timeout: _generationTimeout,
        );
        final content = json['content'] as List?;
        final text = content
            ?.whereType<Map>()
            .map(
              (part) =>
                  part['text'] ?? (responseProbe ? part['thinking'] : null),
            )
            .whereType<String>()
            .join();
        return _requireText(text);

      case AiAdapterKind.nanoGpt:
      case AiAdapterKind.openAiCompatible:
        var generationPath = profile.generationPath;
        if (profile.definition.adapterKind == AiAdapterKind.nanoGpt) {
          generationPath = switch (profile.inferenceRoute) {
            AiInferenceRoute.subscription =>
              '/subscription/v1/chat/completions',
            // NanoGPT's paid catalog is /paid/v1/models, but paid inference
            // uses the canonical /v1/chat/completions endpoint.
            AiInferenceRoute.paid => '/v1/chat/completions',
            AiInferenceRoute.standard => profile.generationPath,
          };
        }
        final json = await _requestJson(
          'POST',
          _resolve(profile.baseUrl, generationPath),
          headers: _headers(profile, apiKey),
          body: {
            'model': model,
            'messages': [
              if (systemPrompt.isNotEmpty)
                {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
            if (profile.definition.adapterKind == AiAdapterKind.nanoGpt)
              'stream': false,
            if (!responseProbe && profile.definitionId != 'openai')
              'temperature': temperature,
            // Let probes use the provider/model default. A low cap can be
            // consumed entirely by a reasoning model before visible output.
            if (!responseProbe && profile.definitionId == 'openai')
              'max_completion_tokens': maxTokens
            else if (!responseProbe)
              'max_tokens': maxTokens,
          },
          timeout: _generationTimeout,
        );
        final choices = json['choices'] as List?;
        final choice = choices?.isNotEmpty == true
            ? choices!.first as Map?
            : null;
        final message = choice?['message'] as Map?;
        final content = message?['content'];
        // Connectivity only: thinking output proves the model responded. Never
        // substitute it for final quiz text in the generation workflow.
        if (responseProbe && message != null) {
          final reply = [
            content,
            message['reasoning'],
            message['reasoning_content'],
          ].whereType<String>().any((value) => value.trim().isNotEmpty);
          if (reply) return 'Model response received';
          if (content is List &&
              content.whereType<Map>().any(
                (part) =>
                    part['text'] is String &&
                    (part['text'] as String).trim().isNotEmpty,
              ))
            return 'Model response received';
          if (choice?['finish_reason'] == 'length') {
            throw const AiProviderException(
              'output_limit',
              'The model reached the test output limit without returning visible text. Try a non-thinking model. No automatic paid retry was made.',
            );
          }
        }
        if (content is String) return _requireText(content);
        if (content is List) {
          return _requireText(
            content
                .whereType<Map>()
                .map((part) => part['text'])
                .whereType<String>()
                .join(),
          );
        }
        return _requireText(null);
    }
  }

  Future<List<ProviderModel>> _fetchNanoCatalog(
    AiProviderProfile profile,
    String apiKey,
  ) async {
    Future<List<ProviderModel>> fetch(String path, AiCatalogScope scope) async {
      final json = await _requestJson(
        'GET',
        _resolve(profile.baseUrl, '$path?detailed=true'),
        headers: _headers(profile, apiKey),
      );
      return _parseModels(json, profile, nanoScope: scope);
    }

    if (profile.catalogScope == AiCatalogScope.subscription) {
      return fetch('/subscription/v1/models', AiCatalogScope.subscription);
    }
    if (profile.catalogScope == AiCatalogScope.all) {
      final subscription = await fetch(
        '/subscription/v1/models',
        AiCatalogScope.subscription,
      );
      final paid = await fetch('/paid/v1/models', AiCatalogScope.standard);
      final merged = <String, ProviderModel>{};
      for (final model in [...paid, ...subscription]) {
        final old = merged[model.id];
        merged[model.id] = ProviderModel(
          id: model.id,
          displayName: model.displayName ?? old?.displayName,
          description: model.description ?? old?.description,
          ownedBy: model.ownedBy ?? old?.ownedBy,
          contextWindowTokens:
              model.contextWindowTokens ?? old?.contextWindowTokens,
          maxOutputTokens: model.maxOutputTokens ?? old?.maxOutputTokens,
          inputPricePerMillion:
              model.inputPricePerMillion ?? old?.inputPricePerMillion,
          cachedInputPricePerMillion:
              model.cachedInputPricePerMillion ??
              old?.cachedInputPricePerMillion,
          outputPricePerMillion:
              model.outputPricePerMillion ?? old?.outputPricePerMillion,
          currency: model.currency ?? old?.currency,
          pricingNote: model.pricingNote ?? old?.pricingNote,
          capabilities: {...?old?.capabilities, ...model.capabilities}.toList(),
          lifecycle: model.lifecycle ?? old?.lifecycle,
          subscriptionEligible:
              model.subscriptionEligible ||
              (old?.subscriptionEligible ?? false),
          paidEligible: model.paidEligible || (old?.paidEligible ?? false),
          fetchedAt: model.fetchedAt,
          rawMetadata: {...?old?.rawMetadata, ...model.rawMetadata},
        );
      }
      final result = merged.values.toList();
      result.sort((a, b) => a.id.compareTo(b.id));
      return result;
    }
    return _fetchStandardCatalog(profile, apiKey);
  }

  Future<List<ProviderModel>> _fetchStandardCatalog(
    AiProviderProfile profile,
    String apiKey, {
    bool stopAfterFirstPage = false,
  }) async {
    final collected = <ProviderModel>[];
    String? pageToken;
    String? afterId;
    final seenPages = <String>{};
    do {
      final query = <String, String>{};
      if (pageToken != null) query['pageToken'] = pageToken;
      if (afterId != null) query['after_id'] = afterId;
      var uri = _resolve(profile.baseUrl, profile.modelsPath);
      if (query.isNotEmpty) uri = uri.replace(queryParameters: query);
      if (seenPages.length >= 50 || !seenPages.add(uri.toString())) {
        throw const AiProviderException(
          'invalid_response',
          'The model catalog exceeded its page limit or repeated a page.',
        );
      }
      final json = await _requestJson(
        'GET',
        uri,
        headers: _headers(profile, apiKey),
      );
      collected.addAll(_parseModels(json, profile));
      if (stopAfterFirstPage) break;
      pageToken = json['nextPageToken'] as String?;
      final hasMore = json['has_more'] == true;
      afterId = hasMore && json['last_id'] is String
          ? json['last_id'] as String
          : null;
    } while (pageToken != null || afterId != null);
    final unique = <String, ProviderModel>{
      for (final model in collected) model.id: model,
    }.values.toList();
    unique.sort((a, b) => a.id.compareTo(b.id));
    return unique;
  }

  List<ProviderModel> _parseModels(
    Map<String, dynamic> json,
    AiProviderProfile profile, {
    AiCatalogScope? nanoScope,
  }) {
    final rawList = switch (json) {
      {'data': final List value} => value,
      {'models': final List value} => value,
      _ => throw const AiProviderException(
        'invalid_response',
        'The provider did not return a recognized model catalog.',
      ),
    };
    final now = DateTime.now();
    return rawList
        .whereType<Map>()
        .map((raw) {
          final item = Map<String, dynamic>.from(raw);
          final rawId = item['id'] ?? item['name'] ?? item['model'];
          var id = rawId?.toString() ?? '';
          if (profile.definition.adapterKind == AiAdapterKind.gemini &&
              id.startsWith('models/')) {
            id = id.substring('models/'.length);
          }
          final pricing = item['pricing'] is Map
              ? Map<String, dynamic>.from(item['pricing'] as Map)
              : const <String, dynamic>{};
          final input = _price(profile.definitionId, item, pricing, true);
          final output = _price(profile.definitionId, item, pricing, false);
          final methods =
              (item['supportedGenerationMethods'] as List?)
                  ?.map((method) => method.toString())
                  .toList() ??
              const <String>[];
          final capabilities = <String>{
            ...methods,
            ..._capabilities(item['capabilities']),
            ...?((item['architecture'] as Map?)?['modality'] as String?)?.split(
              '+',
            ),
          }.where((value) => value.isNotEmpty).toList();
          final subscription =
              nanoScope == AiCatalogScope.subscription ||
              item['subscription'] == true ||
              item['subscription_eligible'] == true;
          final paid =
              nanoScope == AiCatalogScope.standard ||
              item['paid'] == true ||
              item['paid_eligible'] == true;
          return ProviderModel(
            id: id,
            displayName: _string(item, ['displayName', 'display_name', 'name']),
            description: _string(item, ['description']),
            ownedBy: _string(item, ['owned_by', 'provider', 'organization']),
            contextWindowTokens: _integer(item, [
              'context_window',
              'context_length',
              'inputTokenLimit',
              'max_context_length',
            ]),
            maxOutputTokens: _integer(item, [
              'max_output_tokens',
              'outputTokenLimit',
              'max_completion_tokens',
            ]),
            inputPricePerMillion: input,
            cachedInputPricePerMillion: _cachedPrice(
              profile.definitionId,
              item,
              pricing,
            ),
            outputPricePerMillion: output,
            currency: input != null || output != null ? 'USD' : null,
            pricingNote: input == null && output == null
                ? 'Not provided by API'
                : null,
            capabilities: capabilities,
            lifecycle: _string(item, ['lifecycle', 'status', 'version']),
            subscriptionEligible: subscription,
            paidEligible: paid,
            fetchedAt: now,
            rawMetadata: item,
          );
        })
        .where((model) {
          if (model.id.isEmpty) return false;
          if (profile.definition.adapterKind == AiAdapterKind.gemini) {
            return model.capabilities.isEmpty ||
                model.capabilities.contains('generateContent');
          }
          return true;
        })
        .toList();
  }

  Iterable<String> _capabilities(dynamic value) {
    if (value is List) return value.whereType<String>();
    if (value is Map) {
      return value.entries
          .where((entry) => entry.key is String && entry.value == true)
          .map((entry) => entry.key as String);
    }
    return const [];
  }

  String? _price(
    String providerId,
    Map<String, dynamic> item,
    Map<String, dynamic> pricing,
    bool input,
  ) {
    final keys = input
        ? const [
            'prompt',
            'input',
            'input_price',
            'input_price_per_million',
            'prompt_text_token_price',
          ]
        : const [
            'completion',
            'output',
            'output_price',
            'output_price_per_million',
            'completion_text_token_price',
          ];
    dynamic value;
    for (final key in keys) {
      value = pricing[key] ?? item[key];
      if (value != null) break;
    }
    if (value == null) return null;
    if (providerId == 'openrouter') return _scaleDecimal(value, 6);
    if (providerId == 'xai') return _scaleDecimal(value, -4);
    return _scaleDecimal(value, 0);
  }

  String? _cachedPrice(
    String providerId,
    Map<String, dynamic> item,
    Map<String, dynamic> pricing,
  ) {
    final value =
        pricing['input_cache_read'] ??
        pricing['cache_read'] ??
        pricing['cached_input'] ??
        item['cached_prompt_text_token_price'];
    if (value == null) return null;
    if (providerId == 'openrouter') return _scaleDecimal(value, 6);
    if (providerId == 'xai') return _scaleDecimal(value, -4);
    return _scaleDecimal(value, 0);
  }

  /// Converts decimal provider strings by powers of ten without binary
  /// floating-point rounding (for example per-token -> per-million).
  String? _scaleDecimal(dynamic value, int power) {
    var source = value.toString().trim();
    if (!RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(source)) return null;
    final negative = source.startsWith('-');
    if (negative) source = source.substring(1);
    final parts = source.split('.');
    var digits = '${parts.first}${parts.length == 2 ? parts.last : ''}';
    var decimalPlaces = (parts.length == 2 ? parts.last.length : 0) - power;
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (decimalPlaces <= 0) {
      digits = '$digits${List.filled(-decimalPlaces, '0').join()}';
      decimalPlaces = 0;
    } else if (digits.length <= decimalPlaces) {
      digits =
          '${List.filled(decimalPlaces - digits.length + 1, '0').join()}$digits';
    }
    final splitAt = digits.length - decimalPlaces;
    var output = decimalPlaces == 0
        ? digits
        : '${digits.substring(0, splitAt)}.${digits.substring(splitAt)}';
    if (output.contains('.')) {
      output = output.replaceFirst(RegExp(r'0+$'), '');
      output = output.replaceFirst(RegExp(r'\.$'), '');
    }
    if (output.isEmpty) output = '0';
    return negative ? '-$output' : output;
  }

  String? _string(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  int? _integer(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  Map<String, String> _headers(AiProviderProfile profile, String apiKey) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    switch (profile.definition.adapterKind) {
      case AiAdapterKind.gemini:
        headers['x-goog-api-key'] = apiKey;
      case AiAdapterKind.anthropic:
        headers['x-api-key'] = apiKey;
        headers['anthropic-version'] = '2023-06-01';
      case AiAdapterKind.openAiCompatible:
      case AiAdapterKind.nanoGpt:
        headers['Authorization'] = 'Bearer $apiKey';
    }
    if (profile.definitionId == 'openrouter') {
      headers['HTTP-Referer'] = 'https://github.com/MCQ-Quizzer';
      headers['X-Title'] = 'MCQ Quizzer';
    }
    return headers;
  }

  Map<String, String> _nanoBalanceHeaders(String apiKey) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    // NanoGPT documents x-api-key (rather than Bearer) for /check-balance.
    'x-api-key': apiKey,
  };

  Uri _resolve(String baseUrl, String path) {
    final base = Uri.tryParse(baseUrl.trim());
    if (base == null ||
        !base.hasScheme ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw const AiProviderException(
        'configuration',
        'Use an HTTPS base URL without credentials, a query, or a fragment.',
      );
    }
    final trimmedBase = baseUrl.trim();
    final normalizedBase = trimmedBase.endsWith('/')
        ? trimmedBase.substring(0, trimmedBase.length - 1)
        : trimmedBase;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    Map<String, dynamic>? body,
    Duration timeout = _requestTimeout,
  }) async {
    http.Response response;
    try {
      final request = http.Request(method, uri)
        ..followRedirects = false
        ..headers.addAll(headers);
      if (method == 'POST') request.body = jsonEncode(body ?? const {});
      response = await (() async {
        final streamed = await _client.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(timeout);
    } on TimeoutException {
      throw const AiProviderException(
        'timeout',
        'The provider did not respond in time.',
      );
    } catch (error) {
      throw _safeTransportException(error);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiProviderException(
        _statusCategory(response.statusCode),
        _safeErrorMessage(response.statusCode),
        statusCode: response.statusCode,
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is List) return {'data': decoded};
      return Map<String, dynamic>.from(decoded as Map);
    } catch (_) {
      throw const AiProviderException(
        'invalid_response',
        'The provider returned an unreadable response.',
      );
    }
  }

  AiProviderException _safeTransportException(Object error) {
    final detail = error.toString().toLowerCase();
    if (detail.contains('handshake') ||
        detail.contains('certificate') ||
        detail.contains('tls')) {
      return const AiProviderException(
        'tls',
        'A secure connection could not be established. Check the device date, VPN, or network certificate settings.',
      );
    }
    if (detail.contains('lookup') ||
        detail.contains('host') && detail.contains('failed')) {
      return const AiProviderException(
        'dns',
        'The provider address could not be resolved. Check DNS, VPN, and the base URL.',
      );
    }
    if (detail.contains('closed') ||
        detail.contains('reset') ||
        detail.contains('broken pipe')) {
      return const AiProviderException(
        'connection_closed',
        'The provider closed the connection before completing its response. Retry once, then check VPN or provider status.',
      );
    }
    return const AiProviderException(
      'network',
      'Could not reach the provider. Check the URL and connection.',
    );
  }

  String _requireText(String? value) {
    if (value == null || value.trim().isEmpty) {
      throw const AiProviderException(
        'invalid_response',
        'The provider returned no usable text.',
      );
    }
    return value;
  }

  String _statusCategory(int status) {
    if (status == 401 || status == 403) return 'authentication';
    if (status == 404) return 'endpoint';
    if (status == 408 || status == 504) return 'timeout';
    if (status == 429) return 'rate_limit';
    if (status >= 500) return 'provider';
    return 'request';
  }

  String _safeErrorMessage(int status) {
    if (status == 401 || status == 403) {
      return 'The API key was rejected by the provider.';
    }
    if (status == 404) return 'The configured endpoint was not found.';
    if (status == 429) return 'The provider rate limit was reached.';
    if (status >= 500) return 'The provider is temporarily unavailable.';
    return 'The provider rejected the request (HTTP $status).';
  }
}
