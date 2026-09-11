import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcq_quizzer/models/ai_provider_profile.dart';
import 'package:mcq_quizzer/services/ai_provider_service.dart';

AiProviderProfile connection(String id) {
  final definition = AiProviderRegistry.byId(id);
  return AiProviderProfile(
    id: 'safety',
    definitionId: id,
    displayName: 'Safety test',
    baseUrl: definition.defaultBaseUrl,
    modelsPath: definition.modelsPath,
    generationPath: definition.generationPath,
  );
}

void main() {
  test('NanoGPT balance check uses its documented x-api-key header', () async {
    late http.Request sent;
    final service = AiProviderService(
      client: MockClient((request) async {
        sent = request;
        return http.Response('{"usd_balance":"1"}', 200);
      }),
    );
    final result = await service.testConnection(
      connection('nanogpt'),
      'test-key',
    );
    expect(result.success, true);
    expect(sent.url.path, '/api/check-balance');
    expect(sent.headers['x-api-key'], 'test-key');
    expect(sent.headers.containsKey('authorization'), false);
  });

  test('authenticated requests never automatically follow redirects', () async {
    bool? followsRedirects;
    final service = AiProviderService(
      client: MockClient((request) async {
        followsRedirects = request.followRedirects;
        return http.Response(
          '',
          302,
          headers: {'location': 'https://other.example/models'},
        );
      }),
    );
    final result = await service.testConnection(
      connection('openai'),
      'test-key',
    );
    expect(result.success, false);
    expect(followsRedirects, false);
  });
  test('repeated pagination cursor is rejected without looping', () async {
    var requests = 0;
    final service = AiProviderService(
      client: MockClient((_) async {
        if (++requests > 3) throw StateError('Unbounded pagination');
        return http.Response('{"models":[],"nextPageToken":"same"}', 200);
      }),
    );
    await expectLater(
      service.fetchModels(connection('gemini'), 'test-key'),
      throwsA(
        isA<AiProviderException>().having(
          (e) => e.category,
          'category',
          'invalid_response',
        ),
      ),
    );
    expect(requests, lessThanOrEqualTo(2));
  });
  for (final url in [
    'http://example.com/v1',
    'https://user:secret@example.com/v1',
    'https://example.com/v1?key=secret',
    'https://example.com/v1#fragment',
  ]) {
    test('unsafe base URL rejected before sending credentials: $url', () async {
      var requested = false;
      final service = AiProviderService(
        client: MockClient((_) async {
          requested = true;
          return http.Response('{"data":[]}', 200);
        }),
      );
      final result = await service.testConnection(
        connection('openai').copyWith(baseUrl: url),
        'test-key',
      );
      expect(result.category, 'configuration');
      expect(requested, false);
    });
  }
  test('malformed catalog cannot verify a connection', () async {
    final service = AiProviderService(
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    final result = await service.testConnection(
      connection('openai'),
      'test-key',
    );
    expect(result.success, false);
    expect(result.category, 'invalid_response');
  });
  test(
    'catalog accepts object capabilities and keeps enabled flags only',
    () async {
      final service = AiProviderService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'chat',
                  'capabilities': {'completion_chat': true, 'vision': false},
                },
              ],
            }),
            200,
          ),
        ),
      );
      final models = await service.fetchModels(
        connection('mistral'),
        'test-key',
      );
      expect(models.single.capabilities, contains('completion_chat'));
      expect(models.single.capabilities, isNot(contains('vision')));
    },
  );
}
