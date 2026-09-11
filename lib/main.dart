import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'screens/home_screen.dart';
import 'screens/quiz_library_screen.dart';
import 'screens/quiz_generation_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/flashcard_screen.dart';
import 'screens/results_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/ai_providers_screen.dart';
import 'providers/quiz_provider.dart';
import 'providers/ai_settings_provider.dart';
import 'services/quiz_service.dart';
import 'services/notification_service.dart';
import 'models/quiz.dart';

Future<void> main() async {
  // Route framework errors into the zone handler so they're captured in the log file
  FlutterError.onError = (details) {
    Zone.current.handleUncaughtError(
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };

  await runZonedGuarded<Future<void>>(
    () async {
      // Ensure Flutter binding is initialized in the same zone
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize sqflite for desktop platforms
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      runApp(const MyApp());

      // Initialize notification service asynchronously after app starts
      // This prevents blocking the UI during startup
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final notificationService = NotificationService();
          await notificationService.initialize();
          await notificationService.updateFromPreferences();
          debugPrint('[Main] Notification service initialized successfully');
        } catch (e, st) {
          debugPrint('[Main] Failed to initialize notification service: $e');
          debugPrint('$st');
        }
      });
    },
    (error, stack) async {
      // Append uncaught errors to a file for debugging
      try {
        final f = File('uncaught_error.log');
        final message =
            '${DateTime.now().toIso8601String()} ERROR: $error\n$stack\n';
        await f.writeAsString(message, mode: FileMode.append);
        // Also print so it's visible in stdout if you run flutter run
        print(message);
      } catch (e) {
        // If logging fails, at least print
        print('Failed to write uncaught_error.log: $e');
        print(error);
        print(stack);
      }
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => QuizProvider()),
        ChangeNotifierProvider(
          create: (context) => AiSettingsProvider()..initialize(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'MCQ Quizzer',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1976D2),
                brightness: Brightness.light,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1976D2),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: themeProvider.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => const HomeScreen(),
              '/library': (context) => const QuizLibraryScreen(),
              '/generation': (context) => const QuizGenerationScreen(),
              '/upload': (context) => const UploadScreen(),
              '/quiz': (context) => const QuizScreen(),
              '/flashcard': (context) => const FlashcardScreen(),
              '/dashboard': (context) => const DashboardScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/ai-providers': (context) => const AiProvidersScreen(),
              '/results': (context) => ResultsScreen(
                quiz: Quiz(title: 'Default Quiz', questions: []),
                answers: {},
                scoringMethod: ScoringMethod.straight,
              ),
            },
          );
        },
      ),
    );
  }
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeProvider() {
    _loadThemeMode();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('dark_mode') ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _themeMode == ThemeMode.dark);
    notifyListeners();
  }
}
