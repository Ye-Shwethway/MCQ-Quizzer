import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mcq_quizzer/services/database_service.dart';
import 'package:mcq_quizzer/services/ai_settings_repository.dart';
import 'package:mcq_quizzer/models/ai_provider_profile.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcq_quizzer/services/ai_provider_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mcq_quizzer/providers/ai_settings_provider.dart';
import 'package:mcq_quizzer/screens/ai_provider_editor_screen.dart';

void main() {
  testWidgets('thinking reply enables Save and use and persists active model', (
    tester,
  ) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final store = DatabaseService(databasePath: inMemoryDatabasePath);
    addTearDown(store.close);
    await tester.runAsync(() async {
      await store.database;
    });
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final definition = AiProviderRegistry.byId('nanogpt');
    final draft = AiProviderProfile(
      id: 'probe-profile',
      definitionId: 'nanogpt',
      displayName: 'NanoGPT',
      baseUrl: definition.defaultBaseUrl,
      modelsPath: definition.modelsPath,
      generationPath: definition.generationPath,
      selectedModelId: 'deepseek/test:thinking',
      inferenceRoute: AiInferenceRoute.subscription,
    );
    final settings = AiSettingsProvider(
      repository: AiSettingsRepository(database: store),
      providerService: AiProviderService(
        client: MockClient(
          (_) async => http.Response(
            '{"choices":[{"message":{"content":null,"reasoning":"Thinking reply"}}]}',
            200,
          ),
        ),
      ),
    );
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AiProviderEditorScreen(profile: draft),
                ),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate((w) => w is TextField && w.obscureText),
      'fixture-key',
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save & use'))
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('Test selected model'));
    await tester.tap(find.text('Test selected model'));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save & use');
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.ensureVisible(save);
    await tester.runAsync(() async {
      await tester.tap(save);
      for (var i = 0; i < 100 && settings.activeProfile == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(settings.activeProfile?.selectedModelId, 'deepseek/test:thinking');
    expect(settings.activeProfile?.isReady, true);
    expect(await settings.apiKeyFor('probe-profile'), 'fixture-key');
  });
  testWidgets(
    'connection result appears between its button and the model catalog',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AiSettingsProvider(
            providerService: AiProviderService(
              client: MockClient(
                (_) async => http.Response('{"data":[]}', 200),
              ),
            ),
          ),
          child: const MaterialApp(home: AiProviderEditorScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField && w.obscureText),
        'fixture-key',
      );
      await tester.tap(find.text('Test connection'));
      await tester.pumpAndSettle();
      final status = find.text('Connection and API key verified.');
      expect(status, findsOneWidget);
      expect(
        tester.getTopLeft(status).dy,
        greaterThan(tester.getBottomLeft(find.text('Test connection')).dy),
      );
      expect(
        tester.getBottomLeft(status).dy,
        lessThan(tester.getTopLeft(find.text('Fetch models')).dy),
      );
    },
  );
  testWidgets('connection result cannot verify a key edited during request', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    FlutterSecureStorage.setMockInitialValues({});
    final response = Completer<http.Response>();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AiSettingsProvider(
          providerService: AiProviderService(
            client: MockClient((_) => response.future),
          ),
        ),
        child: const MaterialApp(home: AiProviderEditorScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final keyField = find.byWidgetPredicate(
      (w) => w is TextField && w.obscureText,
    );
    await tester.enterText(keyField, 'first-test-key');
    await tester.tap(find.text('Test connection'));
    await tester.pump();
    await tester.enterText(keyField, 'second-test-key');
    response.complete(http.Response('{"data":[]}', 200));
    await tester.pumpAndSettle();
    expect(
      find.text('Settings changed. Test the current configuration again.'),
      findsOneWidget,
    );
    expect(find.text('Connection and API key verified.'), findsNothing);
  });
  testWidgets('changing endpoint clears the entered credential', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AiSettingsProvider(),
        child: const MaterialApp(home: AiProviderEditorScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final keyField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.obscureText,
    );
    await tester.ensureVisible(keyField);
    await tester.enterText(keyField, 'test-only-secret');
    final endpoint = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.keyboardType == TextInputType.url,
    );
    await tester.ensureVisible(endpoint);
    await tester.enterText(endpoint, 'https://other.example/v1');
    await tester.pump();
    expect(tester.widget<TextField>(keyField).controller!.text, isEmpty);
  });
}
