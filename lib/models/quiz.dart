import 'question.dart';

class Quiz {
  final String title;
  final List<Question> questions;

  Quiz({required this.title, required this.questions});

  /// Aggregate type for setup; rendering and scoring use each question's type.
  /// A mixed set retains its branch-scoring options.
  QuestionType get detectedType {
    bool hasMultipleChoice = false;
    for (final question in questions) {
      if (question.detectedType == QuestionType.multipleChoice) {
        hasMultipleChoice = true;
        break;
      }
    }
    return hasMultipleChoice
        ? QuestionType.multipleChoice
        : QuestionType.bestOfFive;
  }

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      title: json['title'],
      questions: (json['questions'] as List)
          .map((q) => Question.fromJson(q))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }
}
