import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcq_quizzer/models/ai_provider_profile.dart';
import 'package:mcq_quizzer/services/ai_provider_service.dart';

void main() {
  final definition = AiProviderRegistry.byId('nanogpt');
  final profile = AiProviderProfile(
    id: 'probe',
    definitionId: 'nanogpt',
    displayName: 'NanoGPT',
    baseUrl: definition.defaultBaseUrl,
    modelsPath: definition.modelsPath,
    generationPath: definition.generationPath,
    selectedModelId: 'deepseek/test:thinking',
    inferenceRoute: AiInferenceRoute.subscription,
  );

  test(
    'model probe sends a single plain user message and accepts reasoning reply',
    () async {
      late Map<String, dynamic> payload;
      final service = AiProviderService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/subscription/v1/chat/completions');
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'role': 'assistant',
                    'content': null,
                    'reasoning': 'A brief response is needed.',
                  },
                  'finish_reason': 'length',
                },
              ],
            }),
            200,
          );
        }),
      );
      final result = await service.testModel(profile, 'fixture-key');
      expect(result.success, true);
      expect(payload['messages'], [
        {'role': 'user', 'content': 'Reply with OK.'},
      ]);
      expect(payload.containsKey('temperature'), false);
      expect(payload.containsKey('response_format'), false);
      expect(payload.containsKey('max_tokens'), false);
      expect(payload.containsKey('max_completion_tokens'), false);
      expect(payload['stream'], false);
    },
  );

  test('connection closure is reported safely and distinctly', () async {
    var calls = 0;
    final service = AiProviderService(
      client: MockClient((_) async {
        calls++;
        throw http.ClientException('Connection closed while receiving data');
      }),
    );
    final result = await service.testModel(profile, 'fixture-key');
    expect(result.success, false);
    expect(result.category, 'connection_closed');
    expect(result.message, contains('closed the connection'));
    expect(result.message, isNot(contains('fixture-key')));
    expect(calls, 1);
  });

  test('paid NanoGPT models use the documented standard v1 route', () async {
    late Uri requestedUrl;
    final paidProfile = profile.copyWith(inferenceRoute: AiInferenceRoute.paid);
    final service = AiProviderService(
      client: MockClient((request) async {
        requestedUrl = request.url;
        return http.Response('{"choices":[{"message":{"content":"OK"}}]}', 200);
      }),
    );
    expect((await service.testModel(paidProfile, 'fixture-key')).success, true);
    expect(requestedUrl.path, '/api/v1/chat/completions');
  });

  test('empty success envelope does not verify a model', () async {
    final service = AiProviderService(
      client: MockClient(
        (_) async => http.Response(
          '{"choices":[{"message":{"content":""},"finish_reason":"stop"}]}',
          200,
        ),
      ),
    );
    expect((await service.testModel(profile, 'fixture-key')).success, false);
  });

  test(
    'legacy thinking field verifies access but never becomes generated quiz text',
    () async {
      final service = AiProviderService(
        client: MockClient(
          (_) async => http.Response(
            '{"choices":[{"message":{"content":null,"reasoning_content":"Thinking reply"}}]}',
            200,
          ),
        ),
      );
      expect((await service.testModel(profile, 'fixture-key')).success, true);
      await expectLater(
        service.generateText(
          profile,
          'fixture-key',
          systemPrompt: 'Quiz',
          userPrompt: 'Generate',
        ),
        throwsA(isA<AiProviderException>()),
      );
    },
  );

  test(
    'ordinary plain-text and text-block replies both verify access',
    () async {
      for (final content in [
        'OK',
        [
          {'type': 'text', 'text': 'Hello'},
        ],
      ]) {
        final service = AiProviderService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'choices': [
                  {
                    'message': {'content': content},
                  },
                ],
              }),
              200,
            ),
          ),
        );
        expect((await service.testModel(profile, 'fixture-key')).success, true);
      }
    },
  );

  test(
    'empty truncated response gives an actionable error without retrying',
    () async {
      var calls = 0;
      final service = AiProviderService(
        client: MockClient((_) async {
          calls++;
          return http.Response(
            '{"choices":[{"message":{"content":null},"finish_reason":"length"}]}',
            200,
          );
        }),
      );
      final result = await service.testModel(profile, 'fixture-key');
      expect(result.success, false);
      expect(result.category, 'output_limit');
      expect(calls, 1);
    },
  );
}
