import 'quiz.dart';

class QuizSet {
  final int? id; // Database ID
  final String title;
  final String description;
  final Quiz quiz;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String questionFilePath;
  final String answerKeyFilePath;
  final int totalQuestions;
  final String? source; // 'uploaded' | 'ai_generated'
  final String? aiProvider; // e.g., 'gemini', 'openai'
  final String? aiModel; // e.g., 'gemini-2.5-flash'
  final String? quizType; // 'multipleChoice' | 'bestOfFive'

  QuizSet({
    this.id,
    required this.title,
    required this.description,
    required this.quiz,
    required this.createdAt,
    required this.updatedAt,
    required this.questionFilePath,
    required this.answerKeyFilePath,
    required this.totalQuestions,
    this.source = 'uploaded',
    this.aiProvider,
    this.aiModel,
    this.quizType,
  });

  factory QuizSet.fromJson(Map<String, dynamic> json) {
    return QuizSet(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      quiz: Quiz.fromJson(json['quiz']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      questionFilePath: json['questionFilePath'],
      answerKeyFilePath: json['answerKeyFilePath'],
      totalQuestions: json['totalQuestions'],
      source: json['source'] ?? 'uploaded',
      aiProvider: json['aiProvider'],
      aiModel: json['aiModel'],
      quizType: json['quizType'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'quiz': quiz.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'questionFilePath': questionFilePath,
      'answerKeyFilePath': answerKeyFilePath,
      'totalQuestions': totalQuestions,
      'source': source,
      'aiProvider': aiProvider,
      'aiModel': aiModel,
      'quizType': quizType,
    };
  }

  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'quiz_json': quiz.toJson().toString(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'question_file_path': questionFilePath,
      'answer_key_file_path': answerKeyFilePath,
      'total_questions': totalQuestions,
      'source': source,
      'ai_provider': aiProvider,
      'ai_model': aiModel,
      'quiz_type': quizType,
    };
  }

  factory QuizSet.fromDatabase(Map<String, dynamic> map) {
    return QuizSet(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      quiz: Quiz.fromJson(map['quiz_json']),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      questionFilePath: map['question_file_path'],
      answerKeyFilePath: map['answer_key_file_path'],
      totalQuestions: map['total_questions'],
      source: map['source'] ?? 'uploaded',
      aiProvider: map['ai_provider'],
      aiModel: map['ai_model'],
      quizType: map['quiz_type'],
    );
  }

  QuizSet copyWith({
    int? id,
    String? title,
    String? description,
    Quiz? quiz,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? questionFilePath,
    String? answerKeyFilePath,
    int? totalQuestions,
    String? source,
    String? aiProvider,
    String? aiModel,
    String? quizType,
  }) {
    return QuizSet(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      quiz: quiz ?? this.quiz,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      questionFilePath: questionFilePath ?? this.questionFilePath,
      answerKeyFilePath: answerKeyFilePath ?? this.answerKeyFilePath,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      source: source ?? this.source,
      aiProvider: aiProvider ?? this.aiProvider,
      aiModel: aiModel ?? this.aiModel,
      quizType: quizType ?? this.quizType,
    );
  }
}
