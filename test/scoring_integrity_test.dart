import 'package:flutter_test/flutter_test.dart';
import 'package:mcq_quizzer/models/question.dart';
import 'package:mcq_quizzer/models/quiz.dart';
import 'package:mcq_quizzer/providers/quiz_provider.dart';
import 'package:mcq_quizzer/services/quiz_service.dart';

Question stem(QuestionType type) => Question(
  questionText: 'Select A',
  options: ['A', 'B', 'C', 'D', 'E'],
  correctAnswers: [true, false, false, false, false],
  type: type,
);

void main() {
  test(
    'short saved branch answers remain partial and score without crashing',
    () {
      final quiz = Quiz(
        title: 'Partial',
        questions: [stem(QuestionType.multipleChoice)],
      );
      for (final method in ScoringMethod.values) {
        final result = QuizService().getDetailedResults(quiz, {
          0: [true],
        }, method);
        expect(result['score'], 1);
        expect(result['isComplete'], false);
        expect(result['breakdown'][0]['unansweredCount'], 4);
      }
    },
  );
  test('null and partial answer entries do not complete a branch quiz', () {
    final service = QuizService();
    expect(
      service.isQuizComplete({
        0: [null, null, null, null, null],
      }, 1),
      false,
    );
    expect(
      service.isQuizComplete({
        0: [true, null, null, null, null],
      }, 1),
      false,
    );
    expect(
      service.isQuizComplete({
        0: [true, false, false, false, false],
      }, 1),
      true,
    );
  });
  test('mixed quiz uses each question type for selection and completion', () {
    final quiz = Quiz(
      title: 'Mixed',
      questions: [
        stem(QuestionType.multipleChoice),
        stem(QuestionType.bestOfFive),
      ],
    );
    final provider = QuizProvider()..setQuiz(quiz);
    addTearDown(provider.dispose);
    provider.updateAnswer(1, 1, true);
    provider.updateAnswer(1, 0, true);
    expect(
      provider.answers[1]!.where((answer) => answer == true),
      hasLength(1),
    );
    expect(provider.isAnswered(0), false);
    provider.updateAnswer(0, 0, true);
    expect(provider.isAnswered(0), false);
    expect(provider.isAnswered(1), true);
    expect(provider.answeredCount, 1);
    expect(provider.partialCount, 1);
    expect(provider.completionProgress, 0.5);
    provider.goToQuestion(1);
    expect(provider.completionProgress, 0.5);
  });
  test(
    'best-of-five wrong choices earn zero and correct choices one in every scoring mode',
    () {
      final quiz = Quiz(
        title: 'Single choice',
        questions: [stem(QuestionType.bestOfFive)],
      );
      final provider = QuizProvider()..setQuiz(quiz);
      addTearDown(provider.dispose);
      for (final method in ScoringMethod.values) {
        provider.updateAnswer(0, 1, true);
        final wrong = QuizService().getDetailedResults(
          quiz,
          provider.answers,
          method,
        );
        expect(wrong['score'], 0);
        expect(wrong['maxScore'], 1);
        provider.updateAnswer(0, 0, true);
        final right = QuizService().getDetailedResults(
          quiz,
          provider.answers,
          method,
        );
        expect(right['score'], 1);
        expect(right['percentage'], 100.0);
      }
    },
  );
  test('explicit branch type survives one true branch and JSON round trip', () {
    final quiz = Quiz(
      title: 'Branch quiz',
      questions: [stem(QuestionType.multipleChoice)],
    );
    expect(quiz.questions.single.detectedType, QuestionType.multipleChoice);
    expect(
      Quiz.fromJson(quiz.toJson()).detectedType,
      QuestionType.multipleChoice,
    );
  });
}
