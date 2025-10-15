import '../models/flashcard.dart';
import '../models/quiz.dart';

class FlashcardService {
  List<Flashcard> generateFlashcards(Quiz quiz) {
    List<Flashcard> flashcards = [];

    for (var i = 0; i < quiz.questions.length; i++) {
      final question = quiz.questions[i];
      final correctAnswers = question.correctAnswers;
      
      // Generate flashcards for each branch (A-E)
      for (var j = 0; j < question.options.length && j < 5; j++) {
        final optionLetter = String.fromCharCode(65 + j); // A, B, C, D, E
        final optionText = question.options[j];
        final isCorrect = j < correctAnswers.length ? correctAnswers[j] : false;
        
        flashcards.add(Flashcard(
          statement: '${question.questionText} - $optionLetter. $optionText',
          isCorrect: isCorrect,
        ));
      }
    }

    return flashcards;
  }
}