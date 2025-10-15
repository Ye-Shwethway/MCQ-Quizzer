import 'package:flutter_test/flutter_test.dart';
import 'test_helpers.dart';
// import 'package:mcq_quizzer/models/question.dart'; // Removed unused import
import 'package:mcq_quizzer/models/quiz.dart';
import 'package:mcq_quizzer/services/flashcard_service.dart';

void main() {
  group('FlashcardService', () {
    late FlashcardService flashcardService;

    setUp(() {
      flashcardService = FlashcardService();
    });

    test('generateFlashcards creates correct number of flashcards', () {
      final quiz = Quiz(
        title: 'Test Quiz',
        questions: [
          createTestQuestion(
            questionText: 'What is 2+2?',
            options: ['3', '4', '5'],
            correctAnswer: 'B',
          ),
          createTestQuestion(
            questionText: 'What is the capital of France?',
            options: ['London', 'Paris', 'Berlin'],
            correctAnswer: 'B',
          ),
        ],
      );

      final flashcards = flashcardService.generateFlashcards(quiz);

      // For each question: 1 correct + (options.length - 1) incorrect
      // Question 1: 1 correct + 2 incorrect = 3
      // Question 2: 1 correct + 2 incorrect = 3
      // Total: 6 flashcards
      expect(flashcards.length, 6);
    });

    test('generateFlashcards creates correct flashcards', () {
      final quiz = Quiz(
        title: 'Test Quiz',
        questions: [
          createTestQuestion(
            questionText: 'What is 2+2?',
            options: ['3', '4', '5'],
            correctAnswer: 'B',
          ),
        ],
      );

      final flashcards = flashcardService.generateFlashcards(quiz);

      expect(flashcards.length, 3);

      // Check correct flashcard
      final correctFlashcard = flashcards.firstWhere((f) => f.isCorrect);
      expect(correctFlashcard.statement, 'What is 2+2? 4');
      expect(correctFlashcard.isCorrect, true);

      // Check incorrect flashcards
      final incorrectFlashcards = flashcards.where((f) => !f.isCorrect).toList();
      expect(incorrectFlashcards.length, 2);
      expect(incorrectFlashcards[0].statement, 'What is 2+2? 3');
      expect(incorrectFlashcards[0].isCorrect, false);
      expect(incorrectFlashcards[1].statement, 'What is 2+2? 5');
      expect(incorrectFlashcards[1].isCorrect, false);
    });

    test('generateFlashcards handles empty quiz', () {
      final quiz = Quiz(
        title: 'Empty Quiz',
        questions: [],
      );

      final flashcards = flashcardService.generateFlashcards(quiz);

      expect(flashcards.length, 0);
    });

    test('generateFlashcards handles single option question', () {
      final quiz = Quiz(
        title: 'Single Option Quiz',
        questions: [
          createTestQuestion(
            questionText: 'True or False?',
            options: ['True'],
            correctAnswer: 'A',
          ),
        ],
      );

      final flashcards = flashcardService.generateFlashcards(quiz);

      // Only 1 correct flashcard, no incorrect ones since only one option
      expect(flashcards.length, 1);
      expect(flashcards[0].statement, 'True or False? True');
      expect(flashcards[0].isCorrect, true);
    });
  });
}