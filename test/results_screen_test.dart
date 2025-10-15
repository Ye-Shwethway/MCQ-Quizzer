import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcq_quizzer/screens/results_screen.dart';
import 'package:mcq_quizzer/services/quiz_service.dart';
import 'package:mcq_quizzer/models/quiz.dart';
// import 'package:mcq_quizzer/models/question.dart'; // Not directly used; helper creates questions
import 'test_helpers.dart';

void main() {
  late Quiz testQuiz;
  late Map<int, List<bool?>> testAnswers;

  setUp(() {
    final question1 = createTestQuestion(
      questionText: 'Q1',
      options: ['A', 'B', 'C', 'D', 'E'],
      correctAnswer: 'A',
    );
    final question2 = createTestQuestion(
      questionText: 'Q2',
      options: ['A', 'B', 'C', 'D', 'E'],
      correctAnswer: 'B',
    );
    testQuiz = Quiz(title: 'Test Quiz', questions: [question1, question2]);
    testAnswers = {
      0: [true, false, false, false, false], // Correct answer for Q1
      1: [false, true, false, false, false], // Correct answer for Q2
    };
  });

  testWidgets('ResultsScreen displays score summary', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResultsScreen(
          quiz: testQuiz,
          answers: testAnswers,
          scoringMethod: ScoringMethod.straight,
        ),
      ),
    );

    expect(find.text('Score Summary'), findsOneWidget);
    expect(find.text('Scoring Method: Straight'), findsOneWidget);
    expect(find.text('Score: 2 / 2'), findsOneWidget);
    expect(find.text('Percentage: 100.0%'), findsOneWidget);
  });

  testWidgets('ResultsScreen displays question breakdown', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResultsScreen(
          quiz: testQuiz,
          answers: testAnswers,
          scoringMethod: ScoringMethod.straight,
        ),
      ),
    );

    expect(find.text('Question Breakdown'), findsOneWidget);
    expect(find.text('Question 1'), findsOneWidget);
    expect(find.text('Question 2'), findsOneWidget);
  });

  testWidgets('ResultsScreen shows review options', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResultsScreen(
          quiz: testQuiz,
          answers: testAnswers,
          scoringMethod: ScoringMethod.straight,
        ),
      ),
    );

    expect(find.text('Review Quiz'), findsOneWidget);
    expect(find.text('Take Another Quiz'), findsOneWidget);
  });

  testWidgets('ResultsScreen handles minus not carried over scoring', (WidgetTester tester) async {
    // Set up incorrect answers
    final incorrectAnswers = {
      0: [true, false, false, false, false], // Correct
      1: [false, false, true, false, false], // Incorrect
    };

    await tester.pumpWidget(
      MaterialApp(
        home: ResultsScreen(
          quiz: testQuiz,
          answers: incorrectAnswers,
          scoringMethod: ScoringMethod.minusNotCarriedOver,
        ),
      ),
    );

    expect(find.text('Scoring Method: Minus Not Carried Over'), findsOneWidget);
    expect(find.text('Score: 0 / 2'), findsOneWidget); // 1 - 1 = 0
  });

  testWidgets('ResultsScreen handles minus carried over scoring', (WidgetTester tester) async {
    // Set up incorrect answers
    final incorrectAnswers = {
      0: [true, false, false, false, false], // Correct
      1: [false, false, true, false, false], // Incorrect
    };

    await tester.pumpWidget(
      MaterialApp(
        home: ResultsScreen(
          quiz: testQuiz,
          answers: incorrectAnswers,
          scoringMethod: ScoringMethod.minusCarriedOver,
        ),
      ),
    );

    expect(find.text('Scoring Method: Minus Carried Over'), findsOneWidget);
    expect(find.text('Score: 0 / 2'), findsOneWidget); // 1 - 1 = 0
  });

  testWidgets('ResultsScreen has SafeArea', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResultsScreen(
          quiz: testQuiz,
          answers: testAnswers,
          scoringMethod: ScoringMethod.straight,
        ),
      ),
    );

    expect(find.byType(SafeArea), findsWidgets);
  });

  testWidgets('ResultsScreen displays correct icons for answers', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResultsScreen(
          quiz: testQuiz,
          answers: testAnswers,
          scoringMethod: ScoringMethod.straight,
        ),
      ),
    );

    expect(find.byIcon(Icons.check_circle), findsNWidgets(2)); // Both correct
    expect(find.byIcon(Icons.cancel), findsNothing);
  });
}