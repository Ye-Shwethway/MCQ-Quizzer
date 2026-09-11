import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcq_quizzer/models/ai_provider_profile.dart';
import 'package:mcq_quizzer/services/ai_provider_service.dart';

AiProviderProfile profile(String definitionId, {AiCatalogScope? scope}) {
  final definition = AiProviderRegistry.byId(definitionId);
  return AiProviderProfile(
    id: 'test',
    definitionId: definitionId,
    displayName: definition.displayName,
    baseUrl: definition.defaultBaseUrl,
    modelsPath: definition.modelsPath,
    generationPath: definition.generationPath,
    catalogScope: scope ?? AiCatalogScope.standard,
  );
}

void main() {
  test(
    'normalizes Gemini model names and filters non-generation models',
    () async {
      final client = MockClient((request) async {
        expect(request.headers['x-goog-api-key'], 'secret');
        return http.Response(
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-current',
                'displayName': 'Gemini Current',
                'inputTokenLimit': 1000000,
                'outputTokenLimit': 8192,
                'supportedGenerationMethods': ['generateContent'],
              },
              {
                'name': 'models/embedding-only',
                'supportedGenerationMethods': ['embedContent'],
              },
            ],
          }),
          200,
        );
      });

      final models = await AiProviderService(
        client: client,
      ).fetchModels(profile('gemini'), 'secret');

      expect(models, hasLength(1));
      expect(models.single.id, 'gemini-current');
      expect(models.single.contextWindowTokens, 1000000);
      expect(models.single.pricingNote, 'Not provided by API');
    },
  );

  test('converts OpenRouter per-token prices to per-million prices', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'data': [
            {
              'id': 'vendor/model',
              'pricing': {'prompt': '0.000002', 'completion': '0.000006'},
            },
          ],
        }),
        200,
      ),
    );

    final model = (await AiProviderService(
      client: client,
    ).fetchModels(profile('openrouter'), 'secret')).single;

    expect(model.inputPricePerMillion, '2');
    expect(model.outputPricePerMillion, '6');
  });

  test('converts xAI cents per 100M tokens to USD per million', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'models': [
            {
              'id': 'grok-current',
              'prompt_text_token_price': 50000,
              'completion_text_token_price': 150000,
            },
          ],
        }),
        200,
      ),
    );

    final model = (await AiProviderService(
      client: client,
    ).fetchModels(profile('xai'), 'secret')).single;

    expect(model.inputPricePerMillion, '5');
    expect(model.outputPricePerMillion, '15');
  });

  test('OpenAI model test omits optional generation controls', () async {
    final client = MockClient((request) async {
      final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      expect(body['model'], 'gpt-current');
      expect(body.containsKey('max_completion_tokens'), isFalse);
      expect(body.containsKey('max_tokens'), isFalse);
      expect(body.containsKey('temperature'), isFalse);
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': '{"status":"ok"}'},
            },
          ],
        }),
        200,
      );
    });

    final result = await AiProviderService(client: client).testModel(
      profile('openai').copyWith(selectedModelId: 'gpt-current'),
      'secret',
    );

    expect(result.success, isTrue);
  });

  test('NanoGPT all scope unions subscription and paid catalogs', () async {
    final requestedUrls = <Uri>[];
    final client = MockClient((request) async {
      requestedUrls.add(request.url);
      if (request.url.path.contains('/subscription/')) {
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'shared'},
              {'id': 'subscription-only'},
            ],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'data': [
            {'id': 'shared'},
            {'id': 'paid-only'},
          ],
        }),
        200,
      );
    });

    final models = await AiProviderService(
      client: client,
    ).fetchModels(profile('nanogpt', scope: AiCatalogScope.all), 'secret');

    expect(
      requestedUrls.map((url) => url.path),
      contains('/api/subscription/v1/models'),
    );
    expect(
      requestedUrls.map((url) => url.path),
      contains('/api/paid/v1/models'),
    );
    expect(
      requestedUrls.every((url) => url.queryParameters['detailed'] == 'true'),
      isTrue,
    );
    expect(
      models.map((model) => model.id),
      containsAll(['shared', 'subscription-only', 'paid-only']),
    );
    final shared = models.singleWhere((model) => model.id == 'shared');
    expect(shared.subscriptionEligible, isTrue);
    expect(shared.paidEligible, isTrue);
  });
}
