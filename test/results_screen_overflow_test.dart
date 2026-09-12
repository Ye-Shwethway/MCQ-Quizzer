import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcq_quizzer/models/question.dart';
import 'package:mcq_quizzer/models/quiz.dart';
import 'package:mcq_quizzer/screens/results_screen.dart';
import 'package:mcq_quizzer/services/quiz_service.dart';

void main() {
  testWidgets('quiz results remain overflow-free on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final quiz = Quiz(
      title: 'Narrow results regression',
      questions: List.generate(
        4,
        (index) => Question(
          questionText:
              'A deliberately long clinical question stem that must wrap safely on a narrow phone without forcing the score and review control outside the result card.',
          options: const [
            'Long option A',
            'Long option B',
            'Long option C',
            'Long option D',
            'Long option E',
          ],
          correctAnswers: const [true, false, true, false, true],
          explanations: const [
            'Explanation A',
            'Explanation B',
            'Explanation C',
            'Explanation D',
            'Explanation E',
          ],
          type: QuestionType.multipleChoice,
        ),
      ),
    );

    final answers = <int, List<bool?>>{
      for (var i = 0; i < quiz.questions.length; i++)
        i: const [true, true, false, false, true],
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        home: ResultsScreen(
          quiz: quiz,
          answers: answers,
          scoringMethod: ScoringMethod.straight,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Question Breakdown'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('View Correct Answers').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Correct Answers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
