// Test helper to convert old correctAnswer string format to new List<bool> format
import 'package:mcq_quizzer/models/question.dart';

// Helper function to create test questions with correct answers
Question createTestQuestion({
  required String questionText,
  required List<String> options,
  String? correctAnswer, // e.g., "B" or "A,C,E"
  List<bool>? correctAnswers,
}) {
  List<bool> answers;
  
  if (correctAnswers != null) {
    answers = correctAnswers;
  } else if (correctAnswer != null) {
    // Convert string format to List<bool>
    final correctLetters = correctAnswer.split(',').map((s) => s.trim()).toList();
    final optionLetters = ['A', 'B', 'C', 'D', 'E'];
    answers = optionLetters.map((letter) => correctLetters.contains(letter)).toList();
  } else {
    answers = List.filled(5, false);
  }
  
  // Ensure we have exactly 5 answers
  while (answers.length < 5) {
    answers.add(false);
  }
  
  return Question(
    questionText: questionText,
    options: options,
    correctAnswers: answers,
  );
}
