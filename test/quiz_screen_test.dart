import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mcq_quizzer/models/quiz.dart';
import 'test_helpers.dart';
import 'package:mcq_quizzer/providers/quiz_provider.dart';
import 'package:mcq_quizzer/screens/quiz_screen.dart';
import 'package:mcq_quizzer/screens/results_screen.dart';
import 'package:mcq_quizzer/services/quiz_service.dart';

void main() {
  late QuizProvider quizProvider;
  late Quiz testQuiz;

  setUp(() {
    quizProvider = QuizProvider();
    testQuiz = Quiz(
      title: 'Test Quiz',
      questions: [
        createTestQuestion(
          questionText: 'What is the capital of France?',
          options: ['London', 'Berlin', 'Paris', 'Madrid', 'Rome'],
          correctAnswer: 'C',
        ),
        createTestQuestion(
          questionText: 'What is 2 + 2?',
          options: ['3', '4', '5', '6', '7'],
          correctAnswer: 'B',
        ),
      ],
    );
    quizProvider.setQuiz(testQuiz);
  });

  group('QuizScreen Widget Tests', () {
    testWidgets('displays question text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<QuizProvider>.value(
            value: quizProvider,
            child: const QuizScreen(),
          ),
        ),
      );

      expect(find.text('What is the capital of France?'), findsOneWidget);
    });

    testWidgets('displays all 5 option checkboxes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<QuizProvider>.value(
            value: quizProvider,
            child: const QuizScreen(),
          ),
        ),
      );

      expect(find.byType(CheckboxListTile), findsNWidgets(5));
    });

    testWidgets('displays progress indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<QuizProvider>.value(
            value: quizProvider,
            child: const QuizScreen(),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('displays question counter in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<QuizProvider>.value(
            value: quizProvider,
            child: const QuizScreen(),
          ),
        ),
      );

      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('next button advances to next question', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<QuizProvider>.value(
            value: quizProvider,
            child: const QuizScreen(),
          ),
        ),
      );

      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(find.text('What is 2 + 2?'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);
    });

    testWidgets('previous button goes back to previous question', (WidgetTester tester) async {
      // First go to second question
      quizProvider.nextQuestion();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<QuizProvider>.value(
            value: quizProvider,
            child: const QuizScreen(),
          ),
        ),
      );

      await tester.tap(find.text('Previous'));
      await tester.pump();

      expect(find.text('What is the capital of France?'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('finish button navigates to results screen', (WidgetTester tester) async {
      // Go to last question
      quizProvider.nextQuestion();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<QuizProvider>.value(
            value: quizProvider,
            child: const QuizScreen(),
          ),
          routes: {
            '/results': (context) => ResultsScreen(
              quiz: testQuiz,
              answers: quizProvider.answers,
              scoringMethod: ScoringMethod.straight,
            ),
          },
        ),
      );

      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();

      expect(find.text('Quiz Results'), findsOneWidget);
      expect(find.text('Score: 0 / 2'), findsOneWidget);
    });

    testWidgets('checkbox selection updates provider', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<QuizProvider>.value(
            value: quizProvider,
            child: const QuizScreen(),
          ),
        ),
      );

      // Find the checkbox for option C (Paris)
      final checkboxFinder = find.text('C. Paris');
      await tester.tap(checkboxFinder);
      await tester.pump();

      expect(quizProvider.answers[0]![2], true); // Index 2 is 'C' (Paris)
    });

    testWidgets('handles quiz with fewer than 5 options', (WidgetTester tester) async {
      final shortQuiz = Quiz(
        title: 'Short Quiz',
        questions: [
          createTestQuestion(
            questionText: 'Yes or No?',
            options: ['Yes', 'No'],
            correctAnswer: 'A',
          ),
        ],
      );
      quizProvider.setQuiz(shortQuiz);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<QuizProvider>.value(
            value: quizProvider,
            child: const QuizScreen(),
          ),
        ),
      );

      expect(find.byType(CheckboxListTile), findsNWidgets(5)); // Still shows 5 checkboxes
      expect(find.text('C. Option C'), findsOneWidget); // Shows placeholder for missing options
    });
  });
}