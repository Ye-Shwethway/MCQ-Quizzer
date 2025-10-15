import '../models/quiz.dart';
import '../models/question.dart';

enum ScoringMethod { straight, minusNotCarriedOver, minusCarriedOver }

class QuizService {
  /// Calculate score using straight scoring: 1 point per correct branch
  /// Maximum 5 points per question stem
  int calculateScore(Quiz quiz, Map<int, List<bool?>> answers, {ScoringMethod method = ScoringMethod.straight}) {
    return calculateScoreWithMethod(quiz, answers, method);
  }

  int calculateScoreWithMethod(Quiz quiz, Map<int, List<bool?>> answers, ScoringMethod method) {
    switch (method) {
      case ScoringMethod.straight:
        return _calculateStraight(quiz, answers);
      case ScoringMethod.minusNotCarriedOver:
        return _calculateMinusNotCarriedOver(quiz, answers);
      case ScoringMethod.minusCarriedOver:
        return _calculateMinusCarriedOver(quiz, answers);
    }
  }

  /// Straight scoring: Count each correct branch as 1 point
  /// If all 5 branches correct = 5 points, 4 correct = 4 points, etc.
  int _calculateStraight(Quiz quiz, Map<int, List<bool?>> answers) {
    int totalScore = 0;
    
    for (int i = 0; i < quiz.questions.length; i++) {
      final question = quiz.questions[i];
      final userAnswers = answers[i] ?? List.filled(5, null);
      final correctOptions = _getCorrectOptions(question);

      int correctCount = 0;
      for (int j = 0; j < 5; j++) {
        if (userAnswers[j] != null && userAnswers[j] == correctOptions[j]) {
          correctCount++;
        }
      }
      
      totalScore += correctCount;
    }
    
    return totalScore;
  }

  /// Minus Not Carried Over: Correct branches minus wrong branches
  /// Minimum 0 points per question stem (doesn't go negative per question)
  /// Example: 4 correct + 1 wrong = 4 - 1 = 3 points
  /// Example: 0 correct + 5 wrong = 0 - 5 = 0 points (not -5)
  int _calculateMinusNotCarriedOver(Quiz quiz, Map<int, List<bool?>> answers) {
    int totalScore = 0;
    
    for (int i = 0; i < quiz.questions.length; i++) {
      final question = quiz.questions[i];
      final userAnswers = answers[i] ?? List.filled(5, null);
      final correctOptions = _getCorrectOptions(question);

      int correctCount = 0;
      int wrongCount = 0;
      
      for (int j = 0; j < 5; j++) {
        if (userAnswers[j] != null) {
          if (userAnswers[j] == correctOptions[j]) {
            correctCount++;
          } else {
            wrongCount++;
          }
        }
      }
      
      // Score for this question stem: correct - wrong, minimum 0
      int questionScore = (correctCount - wrongCount).clamp(0, 5);
      totalScore += questionScore;
    }
    
    return totalScore;
  }

  /// Minus Carried Over: Correct branches minus wrong branches
  /// Can go negative and is deducted from total score
  /// Example: 4 correct + 1 wrong = 4 - 1 = 3 points
  /// Example: 0 correct + 5 wrong = 0 - 5 = -5 points (deducted from total)
  int _calculateMinusCarriedOver(Quiz quiz, Map<int, List<bool?>> answers) {
    int totalScore = 0;
    
    for (int i = 0; i < quiz.questions.length; i++) {
      final question = quiz.questions[i];
      final userAnswers = answers[i] ?? List.filled(5, null);
      final correctOptions = _getCorrectOptions(question);

      int correctCount = 0;
      int wrongCount = 0;
      
      for (int j = 0; j < 5; j++) {
        if (userAnswers[j] != null) {
          if (userAnswers[j] == correctOptions[j]) {
            correctCount++;
          } else {
            wrongCount++;
          }
        }
      }
      
      // Score for this question stem: correct - wrong (can be negative)
      int questionScore = correctCount - wrongCount;
      totalScore += questionScore;
    }
    
    return totalScore;
  }

  List<bool> _getCorrectOptions(Question question) {
    // Return the correctAnswers list directly
    return question.correctAnswers;
  }

  double getPercentageScore(int score, int totalQuestions, ScoringMethod method) {
    if (totalQuestions == 0) return 0.0;
    
    // Maximum score is 5 points per question stem (5 branches each)
    final maxScore = totalQuestions * 5;
    
    // For minus carried over, score can be negative, so clamp to 0-100%
    if (method == ScoringMethod.minusCarriedOver) {
      return ((score / maxScore) * 100).clamp(0.0, 100.0);
    }
    
    return (score / maxScore) * 100;
  }

  bool isQuizComplete(Map<int, List<bool?>> answers, int totalQuestions) {
    return answers.length == totalQuestions;
  }

  Map<String, dynamic> getQuizResults(Quiz quiz, Map<int, List<bool?>> answers, {ScoringMethod method = ScoringMethod.straight}) {
    final score = calculateScoreWithMethod(quiz, answers, method);
    final maxScore = quiz.questions.length * 5; // 5 branches per question
    final percentage = getPercentageScore(score, quiz.questions.length, method);
    final isComplete = isQuizComplete(answers, quiz.questions.length);

    return {
      'score': score,
      'maxScore': maxScore,
      'totalQuestions': quiz.questions.length,
      'percentage': percentage,
      'isComplete': isComplete,
      'method': method,
    };
  }

  Map<String, dynamic> getDetailedResults(Quiz quiz, Map<int, List<bool?>> answers, ScoringMethod method) {
    final results = getQuizResults(quiz, answers, method: method);
    final breakdown = <Map<String, dynamic>>[];

    for (int i = 0; i < quiz.questions.length; i++) {
      final question = quiz.questions[i];
      final userAnswers = answers[i] ?? List.filled(5, null);
      final correctOptions = _getCorrectOptions(question);

      // Count correct and wrong branches
      int correctCount = 0;
      int wrongCount = 0;
      int unansweredCount = 0;
      
      for (int j = 0; j < 5; j++) {
        if (userAnswers[j] == null) {
          unansweredCount++;
        } else if (userAnswers[j] == correctOptions[j]) {
          correctCount++;
        } else {
          wrongCount++;
        }
      }

      // Calculate points for this question stem based on scoring method
      int points = 0;
      if (method == ScoringMethod.straight) {
        points = correctCount;
      } else if (method == ScoringMethod.minusNotCarriedOver) {
        points = (correctCount - wrongCount).clamp(0, 5);
      } else if (method == ScoringMethod.minusCarriedOver) {
        points = correctCount - wrongCount;
      }

      breakdown.add({
        'questionIndex': i,
        'questionText': question.questionText,
        'correctCount': correctCount,
        'wrongCount': wrongCount,
        'unansweredCount': unansweredCount,
        'points': points,
        'maxPoints': 5,
        'userAnswers': userAnswers,
        'correctAnswers': correctOptions,
        'explanations': question.explanations,
      });
    }

    results['breakdown'] = breakdown;
    return results;
  }
}