class Question {
  final String questionText;
  final List<String> options;
  final List<bool> correctAnswers; // True/False for each option A-E
  final List<String>? explanations; // Optional explanations for each option A-E

  /// Primary constructor. Prefer passing [correctAnswers] (List<bool> of length 5).
  /// For backward compatibility, you may pass a legacy [correctAnswer] string
  /// like 'A' or 'A,B' and it will be converted to [correctAnswers].
  Question({
    required this.questionText,
    required this.options,
    List<bool>? correctAnswers,
    String? correctAnswer,
    this.explanations,
  }) : correctAnswers = _normalizeCorrectAnswers(correctAnswers, correctAnswer);

  // Legacy support: convert old string format to List<bool>
  factory Question.fromJson(Map<String, dynamic> json) {
    List<bool> correctAnswers;
    
    if (json['correctAnswers'] != null && json['correctAnswers'] is List) {
      correctAnswers = List<bool>.from(json['correctAnswers']);
    } else if (json['correctAnswer'] != null && json['correctAnswer'] is String) {
      // Legacy format: convert string like "A" or "A,B,C" to List<bool>
      final correctLetters = (json['correctAnswer'] as String).split(',').map((s) => s.trim()).toList();
      final options = ['A', 'B', 'C', 'D', 'E'];
      correctAnswers = options.map((option) => correctLetters.contains(option)).toList();
    } else {
      // Default: all false
      correctAnswers = List.filled(5, false);
    }
    
    List<String>? explanations;
    if (json['explanations'] != null && json['explanations'] is List) {
      explanations = List<String>.from(json['explanations']);
    }
    
    return Question(
      questionText: json['questionText'],
      options: List<String>.from(json['options']),
      correctAnswers: correctAnswers,
      explanations: explanations,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questionText': questionText,
      'options': options,
      'correctAnswers': correctAnswers,
      if (explanations != null) 'explanations': explanations,
    };
  }

  static List<bool> _normalizeCorrectAnswers(List<bool>? correctAnswers, String? correctAnswer) {
    if (correctAnswers != null) {
      // Ensure length 5
      final list = List<bool>.from(correctAnswers);
      while (list.length < 5) list.add(false);
      return list;
    }

    if (correctAnswer != null) {
      final correctLetters = correctAnswer.split(',').map((s) => s.trim()).toList();
      final options = ['A', 'B', 'C', 'D', 'E'];
      return options.map((option) => correctLetters.contains(option)).toList();
    }

    return List.filled(5, false);
  }
}