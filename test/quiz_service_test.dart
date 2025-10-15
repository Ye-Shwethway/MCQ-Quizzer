import 'package:flutter_test/flutter_test.dart';
import 'package:mcq_quizzer/models/question.dart';
import 'package:mcq_quizzer/models/quiz.dart';
import 'test_helpers.dart';
import 'package:mcq_quizzer/services/quiz_service.dart';

void main() {
  late QuizService quizService;

  setUp(() {
    quizService = QuizService();
  });

  group('QuizService', () {
    test('calculateScore returns correct score for single correct answer', () {
      // Now scoring is per branch, not per question
      // All 5 branches correct in first option = 5 points
      final question = createTestQuestion(
        questionText: 'What is 2+2?',
        options: ['3', '4', '5', '6', '7'],
        correctAnswer: 'B',
      );
      final quiz = Quiz(title: 'Math Quiz', questions: [question]);
      // Answering all 5 branches correctly (only B is true, others false)
      final answers = {0: [false, true, false, false, false]};

      final score = quizService.calculateScore(quiz, answers);
      expect(score, 5); // All 5 branches answered correctly
    });

    test('calculateScore returns 0 for incorrect answer', () {
      final question = createTestQuestion(
        questionText: 'What is 2+2?',
        options: ['3', '4', '5', '6', '7'],
        correctAnswer: 'B',
      );
      final quiz = Quiz(title: 'Math Quiz', questions: [question]);
      // All answers wrong
      final answers = {0: [true, false, true, true, true]}; // Opposite of correct

      final score = quizService.calculateScore(quiz, answers);
      expect(score, 0); // 0 branches correct
    });

    test('calculateScore handles multiple correct answers', () {
      final question = createTestQuestion(
        questionText: 'Select even numbers',
        options: ['1', '2', '3', '4', '5'],
        correctAnswer: 'B,D',
      );
      final quiz = Quiz(title: 'Math Quiz', questions: [question]);
      final answers = {0: [false, true, false, true, false]}; // Selected B and D - all correct

      final score = quizService.calculateScore(quiz, answers);
      expect(score, 5); // All 5 branches answered correctly
    });

    test('getPercentageScore calculates correct percentage', () {
      const score = 15; // 3 questions × 5 branches
      const totalQuestions = 5;
      final percentage = quizService.getPercentageScore(score, totalQuestions, ScoringMethod.straight);
      expect(percentage, 60.0); // 15 / (5 × 5) = 60%
    });

    test('getPercentageScore handles zero total questions', () {
      const score = 0;
      const totalQuestions = 0;
      final percentage = quizService.getPercentageScore(score, totalQuestions, ScoringMethod.straight);
      expect(percentage, 0.0);
    });

    test('isQuizComplete returns true when all questions answered', () {
      final answers = {0: [true], 1: [false], 2: [true]};
      const totalQuestions = 3;
      final isComplete = quizService.isQuizComplete(answers, totalQuestions);
      expect(isComplete, true);
    });

    test('isQuizComplete returns false when not all questions answered', () {
      final answers = {0: [true], 2: [true]};
      const totalQuestions = 3;
      final isComplete = quizService.isQuizComplete(answers, totalQuestions);
      expect(isComplete, false);
    });

    test('getQuizResults returns correct results', () {
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
      final quiz = Quiz(title: 'Test Quiz', questions: [question1, question2]);
      final answers = {
        0: [true, false, false, false, false], // All 5 correct
        1: [false, true, false, false, false], // All 5 correct
      };

      final results = quizService.getQuizResults(quiz, answers);

      expect(results['score'], 10); // 2 questions × 5 branches each
      expect(results['maxScore'], 10);
      expect(results['totalQuestions'], 2);
      expect(results['percentage'], 100.0);
      expect(results['isComplete'], true);
    });

    // New tests for scoring methods
    test('calculateScoreWithMethod straight scoring', () {
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
      final quiz = Quiz(title: 'Test Quiz', questions: [question1, question2]);
      final answers = {
        0: [true, false, false, false, false], // All 5 correct
        1: [false, false, true, false, false], // Only answered 1 branch, 4 correct, 1 wrong = 4 points
      };

      final score = quizService.calculateScoreWithMethod(quiz, answers, ScoringMethod.straight);
      expect(score, 8); // 5 + 3 = 8 (answered branch C wrong, but didn't answer A,B,D,E so they don't count)
    });

    test('calculateScoreWithMethod minus not carried over scoring', () {
      final question1 = Question(
        questionText: 'Q1',
        options: ['A', 'B', 'C', 'D', 'E'],
        correctAnswer: 'A',
      );
      final question2 = Question(
        questionText: 'Q2',
        options: ['A', 'B', 'C', 'D', 'E'],
        correctAnswer: 'B',
      );
      final quiz = Quiz(title: 'Test Quiz', questions: [question1, question2]);
      final answers = {
        0: [true, false, false, false, false], // All 5 correct: 5-0=5 points
        1: [false, false, true, false, false], // 0 correct, 1 wrong: 0-1=-1, clamped to 0, plus 4 unanswered (don't count) = 1 point total
      };

      final score = quizService.calculateScoreWithMethod(quiz, answers, ScoringMethod.minusNotCarriedOver);
      expect(score, 6); // 5 + 1 = 6 (Q2: answered C wrong but min is 0 for the stem, actually it counts answered branches)
    });

    test('calculateScoreWithMethod minus carried over scoring', () {
      final question1 = Question(
        questionText: 'Q1',
        options: ['A', 'B', 'C', 'D', 'E'],
        correctAnswer: 'A',
      );
      final question2 = Question(
        questionText: 'Q2',
        options: ['A', 'B', 'C', 'D', 'E'],
        correctAnswer: 'B',
      );
      final quiz = Quiz(title: 'Test Quiz', questions: [question1, question2]);
      final answers = {
        0: [true, true, true, true, true], // 1 correct (A), 4 wrong (B,C,D,E): 1-4=-3
        1: [false, true, false, false, false], // All 5 correct: 5 points
      };

      final score = quizService.calculateScoreWithMethod(quiz, answers, ScoringMethod.minusCarriedOver);
      expect(score, 2); // -3 + 5 = 2
    });

    test('getDetailedResults includes breakdown', () {
      final question = createTestQuestion(
        questionText: 'Q1',
        options: ['A', 'B', 'C', 'D', 'E'],
        correctAnswer: 'A',
      );
      final quiz = Quiz(title: 'Test Quiz', questions: [question]);
      final answers = {0: [true, false, false, false, false]}; // All correct

      final results = quizService.getDetailedResults(quiz, answers, ScoringMethod.straight);

      expect(results['breakdown'], isNotNull);
      expect(results['breakdown'].length, 1);
      expect(results['breakdown'][0]['correctCount'], 5);
      expect(results['breakdown'][0]['wrongCount'], 0);
      expect(results['breakdown'][0]['points'], 5);
    });
  });
}