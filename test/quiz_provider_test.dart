import 'package:flutter_test/flutter_test.dart';
import 'package:mcq_quizzer/models/question.dart';
import 'package:mcq_quizzer/models/quiz.dart';
import 'package:mcq_quizzer/models/flashcard.dart';
import 'package:mcq_quizzer/providers/quiz_provider.dart';
import 'test_helpers.dart';

void main() {
  group('QuizProvider', () {
    late QuizProvider provider;

    setUp(() {
      provider = QuizProvider();
    });

    tearDown(() {
      provider.reset();
    });

    test('initial state', () {
      expect(provider.quiz, isNull);
      expect(provider.currentQuestionIndex, 0);
      expect(provider.currentQuestion, isNull);
      expect(provider.totalQuestions, 0);
      expect(provider.progress, 0.0);
    });

    test('setQuiz with valid quiz', () {
      final quiz = Quiz(
        title: 'Test Quiz',
        questions: [
          createTestQuestion(
            questionText: 'What is 1+1?',
            options: ['1', '2', '3', '4'],
            correctAnswer: 'B',
          ),
        ],
      );

      provider.setQuiz(quiz);

      expect(provider.quiz, quiz);
      expect(provider.currentQuestionIndex, 0);
      expect(provider.currentQuestion, quiz.questions[0]);
      expect(provider.totalQuestions, 1);
      expect(provider.progress, 1.0);
    });

    test('setQuiz with empty questions', () {
      final quiz = Quiz(
        title: 'Empty Quiz',
        questions: [],
      );

      provider.setQuiz(quiz);

      expect(provider.quiz, quiz);
      expect(provider.currentQuestionIndex, 0);
      expect(provider.currentQuestion, isNull);
      expect(provider.totalQuestions, 0);
      expect(provider.progress, 0.0);
    });

    test('currentQuestion with null quiz', () {
      expect(provider.currentQuestion, isNull);
    });

    test('currentQuestion with empty questions', () {
      final quiz = Quiz(
        title: 'Empty Quiz',
        questions: [],
      );
      provider.setQuiz(quiz);

      expect(provider.currentQuestion, isNull);
    });

    test('currentQuestion with invalid index', () {
      final quiz = Quiz(
        title: 'Test Quiz',
        questions: [
          createTestQuestion(
            questionText: 'What is 1+1?',
            options: ['1', '2', '3', '4'],
            correctAnswer: 'B',
          ),
        ],
      );
      provider.setQuiz(quiz);

      // Test with invalid index by calling nextQuestion multiple times
      provider.nextQuestion(); // index stays 0 since it's at the end
      expect(provider.currentQuestion, isNotNull); // Should still return the question
    });

    test('nextQuestion within bounds', () {
      final quiz = Quiz(
        title: 'Test Quiz',
        questions: [
          createTestQuestion(
            questionText: 'What is 1+1?',
            options: ['1', '2', '3', '4'],
            correctAnswer: 'B',
          ),
          createTestQuestion(
            questionText: 'What is 2+2?',
            options: ['3', '4', '5', '6'],
            correctAnswer: 'B',
          ),
        ],
      );
      provider.setQuiz(quiz);

      expect(provider.currentQuestionIndex, 0);
      provider.nextQuestion();
      expect(provider.currentQuestionIndex, 1);
    });

    test('nextQuestion at last question', () {
      final quiz = Quiz(
        title: 'Test Quiz',
        questions: [
          createTestQuestion(
            questionText: 'What is 1+1?',
            options: ['1', '2', '3', '4'],
            correctAnswer: 'B',
          ),
        ],
      );
      provider.setQuiz(quiz);

      expect(provider.currentQuestionIndex, 0);
      provider.nextQuestion();
      expect(provider.currentQuestionIndex, 0); // Should not change
    });

    test('previousQuestion within bounds', () {
      final quiz = Quiz(
        title: 'Test Quiz',
        questions: [
          createTestQuestion(
            questionText: 'What is 1+1?',
            options: ['1', '2', '3', '4'],
            correctAnswer: 'B',
          ),
          createTestQuestion(
            questionText: 'What is 2+2?',
            options: ['3', '4', '5', '6'],
            correctAnswer: 'B',
          ),
        ],
      );
      provider.setQuiz(quiz);
      provider.nextQuestion();

      expect(provider.currentQuestionIndex, 1);
      provider.previousQuestion();
      expect(provider.currentQuestionIndex, 0);
    });

    test('previousQuestion at first question', () {
      final quiz = Quiz(
        title: 'Test Quiz',
        questions: [
          Question(
            questionText: 'What is 1+1?',
            options: ['1', '2', '3', '4'],
            correctAnswer: '2',
          ),
        ],
      );
      provider.setQuiz(quiz);

      expect(provider.currentQuestionIndex, 0);
      provider.previousQuestion();
      expect(provider.currentQuestionIndex, 0); // Should not change
    });

    test('updateAnswer with valid indices', () {
      final quiz = Quiz(
        title: 'Test Quiz',
        questions: [
          Question(
            questionText: 'What is 1+1?',
            options: ['1', '2', '3', '4'],
            correctAnswer: '2',
          ),
        ],
      );
      provider.setQuiz(quiz);

      provider.updateAnswer(0, 1, true); // Select option B

      expect(provider.getSelectedOptions(0), ['B']);
    });

    test('updateAnswer with invalid questionIndex', () {
      final quiz = Quiz(
        title: 'Test Quiz',
        questions: [
          Question(
            questionText: 'What is 1+1?',
            options: ['1', '2', '3', '4'],
            correctAnswer: '2',
          ),
        ],
      );
      provider.setQuiz(quiz);

      provider.updateAnswer(5, 1, true); // Invalid questionIndex

      expect(provider.getSelectedOptions(0), []); // No change
    });

    test('updateAnswer with invalid optionIndex', () {
      final quiz = Quiz(
        title: 'Test Quiz',
        questions: [
          Question(
            questionText: 'What is 1+1?',
            options: ['1', '2', '3', '4'],
            correctAnswer: '2',
          ),
        ],
      );
      provider.setQuiz(quiz);

      provider.updateAnswer(0, 10, true); // Invalid optionIndex

      expect(provider.getSelectedOptions(0), []); // No change
    });

    test('isAnswered with valid index', () {
      final quiz = Quiz(
        title: 'Test Quiz',
        questions: [
          Question(
            questionText: 'What is 1+1?',
            options: ['1', '2', '3', '4'],
            correctAnswer: '2',
          ),
        ],
      );
      provider.setQuiz(quiz);

      expect(provider.isAnswered(0), false);
      provider.updateAnswer(0, 1, true);
      expect(provider.isAnswered(0), true);
    });

    test('isAnswered with invalid index', () {
      final quiz = Quiz(
        title: 'Test Quiz',
        questions: [
          Question(
            questionText: 'What is 1+1?',
            options: ['1', '2', '3', '4'],
            correctAnswer: '2',
          ),
        ],
      );
      provider.setQuiz(quiz);

      expect(provider.isAnswered(5), false);
    });

    test('getSelectedOptions with invalid index', () {
      final quiz = Quiz(
        title: 'Test Quiz',
        questions: [
          Question(
            questionText: 'What is 1+1?',
            options: ['1', '2', '3', '4'],
            correctAnswer: '2',
          ),
        ],
      );
      provider.setQuiz(quiz);

      expect(provider.getSelectedOptions(5), []);
    });

    test('flashcard getters with null flashcards', () {
      expect(provider.flashcards, isNull);
      expect(provider.currentFlashcardIndex, 0);
      expect(provider.currentFlashcard, isNull);
      expect(provider.totalFlashcards, 0);
      expect(provider.flashcardProgress, 0.0);
    });

    test('setFlashcards with valid flashcards', () {
      final flashcards = [
        Flashcard(statement: 'What is 1+1?', isCorrect: true),
      ];

      provider.setFlashcards(flashcards);

      expect(provider.flashcards, flashcards);
      expect(provider.currentFlashcardIndex, 0);
      expect(provider.currentFlashcard, flashcards[0]);
      expect(provider.totalFlashcards, 1);
      expect(provider.flashcardProgress, 1.0);
    });

    test('currentFlashcard with empty flashcards', () {
      provider.setFlashcards([]);

      expect(provider.currentFlashcard, isNull);
    });

    test('currentFlashcard with invalid index', () {
      final flashcards = [
        Flashcard(statement: 'What is 1+1?', isCorrect: true),
      ];
      provider.setFlashcards(flashcards);

      // Test with invalid index by calling nextFlashcard multiple times
      provider.nextFlashcard(); // index stays 0 since it's at the end
      expect(provider.currentFlashcard, isNotNull); // Should still return the flashcard
    });

    test('nextFlashcard within bounds', () {
      final flashcards = [
        Flashcard(statement: 'What is 1+1?', isCorrect: true),
        Flashcard(statement: 'What is 2+2?', isCorrect: true),
      ];
      provider.setFlashcards(flashcards);

      expect(provider.currentFlashcardIndex, 0);
      provider.nextFlashcard();
      expect(provider.currentFlashcardIndex, 1);
    });

    test('nextFlashcard at last flashcard', () {
      final flashcards = [
        Flashcard(statement: 'What is 1+1?', isCorrect: true),
      ];
      provider.setFlashcards(flashcards);

      expect(provider.currentFlashcardIndex, 0);
      provider.nextFlashcard();
      expect(provider.currentFlashcardIndex, 0); // Should not change
    });

    test('previousFlashcard within bounds', () {
      final flashcards = [
        Flashcard(statement: 'What is 1+1?', isCorrect: true),
        Flashcard(statement: 'What is 2+2?', isCorrect: true),
      ];
      provider.setFlashcards(flashcards);
      provider.nextFlashcard();

      expect(provider.currentFlashcardIndex, 1);
      provider.previousFlashcard();
      expect(provider.currentFlashcardIndex, 0);
    });

    test('previousFlashcard at first flashcard', () {
      final flashcards = [
        Flashcard(statement: 'What is 1+1?', isCorrect: true),
      ];
      provider.setFlashcards(flashcards);

      expect(provider.currentFlashcardIndex, 0);
      provider.previousFlashcard();
      expect(provider.currentFlashcardIndex, 0); // Should not change
    });

    test('updateFlashcardAnswer with valid index', () {
      final flashcards = [
        Flashcard(statement: 'What is 1+1?', isCorrect: true),
      ];
      provider.setFlashcards(flashcards);

      provider.updateFlashcardAnswer(0, true);

      expect(provider.flashcardAnswers[0], true);
    });

    test('updateFlashcardAnswer with invalid index', () {
      final flashcards = [
        Flashcard(statement: 'What is 1+1?', isCorrect: true),
      ];
      provider.setFlashcards(flashcards);

      provider.updateFlashcardAnswer(5, true); // Invalid index

      expect(provider.flashcardAnswers.containsKey(5), false);
    });

    test('reset', () {
      final quiz = Quiz(
        title: 'Test Quiz',
        questions: [
          Question(
            questionText: 'What is 1+1?',
            options: ['1', '2', '3', '4'],
            correctAnswer: '2',
          ),
        ],
      );
      provider.setQuiz(quiz);
      provider.updateAnswer(0, 1, true);

      provider.reset();

      expect(provider.quiz, isNull);
      expect(provider.currentQuestionIndex, 0);
      expect(provider.answers.isEmpty, true);
    });
  });
}