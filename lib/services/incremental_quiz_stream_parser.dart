import 'dart:convert';

import '../models/question.dart';

/// Boundary-aware parser for streamed quiz JSON.
///
/// It does not repeatedly jsonDecode arbitrary partial JSON. Instead it finds
/// the top-level `questions` array, tracks string escaping and object depth,
/// and only decodes complete question objects after their closing brace arrives.
class IncrementalQuizStreamParser {
  IncrementalQuizStreamParser({
    required this.expectedBranches,
    this.questionStyle,
  });

  final int expectedBranches;
  final String? questionStyle;

  final StringBuffer _buffer = StringBuffer();
  int _scanIndex = 0;
  bool _questionsArrayFound = false;
  bool _inString = false;
  bool _escaped = false;
  int _objectDepth = 0;
  int? _objectStart;

  String get accumulatedText => _buffer.toString();

  /// Adds a text delta and returns only newly completed, valid questions.
  List<Question> addText(String delta) {
    if (delta.isEmpty) return const [];
    _buffer.write(delta);
    final source = _buffer.toString();
    final emitted = <Question>[];

    if (!_questionsArrayFound) {
      final keyIndex = source.indexOf('"questions"');
      if (keyIndex < 0) {
        _scanIndex = (source.length - 16).clamp(0, source.length);
        return emitted;
      }
      final arrayIndex = source.indexOf('[', keyIndex);
      if (arrayIndex < 0) {
        _scanIndex = keyIndex;
        return emitted;
      }
      _questionsArrayFound = true;
      _scanIndex = arrayIndex + 1;
    }

    for (var i = _scanIndex; i < source.length; i++) {
      final char = source[i];

      if (_inString) {
        if (_escaped) {
          _escaped = false;
          continue;
        }
        if (char == r'\') {
          _escaped = true;
          continue;
        }
        if (char == '"') _inString = false;
        continue;
      }

      if (char == '"') {
        _inString = true;
        continue;
      }

      if (char == '{') {
        if (_objectDepth == 0) _objectStart = i;
        _objectDepth++;
        continue;
      }

      if (char == '}' && _objectDepth > 0) {
        _objectDepth--;
        if (_objectDepth == 0 && _objectStart != null) {
          final raw = source.substring(_objectStart!, i + 1);
          final question = _decodeQuestion(raw);
          if (question != null) emitted.add(question);
          _objectStart = null;
        }
      }
    }

    _scanIndex = source.length;
    return emitted;
  }

  Question? _decodeQuestion(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final data = Map<String, dynamic>.from(decoded);
      final stem = data['stem'];
      final branchesRaw = data['branches'];
      final answersRaw = data['correctAnswers'];
      if (stem is! String || stem.trim().isEmpty) return null;
      if (branchesRaw is! List || answersRaw is! List) return null;

      final branches = branchesRaw.map((value) => value.toString()).toList();
      if (branches.length != expectedBranches ||
          branches.any((value) => value.trim().isEmpty)) {
        return null;
      }

      final answers = answersRaw.map((value) {
        if (value is bool) return value;
        if (value is String) return value.toLowerCase() == 'true';
        return false;
      }).toList();
      if (answers.length != branches.length) return null;

      final trueCount = answers.where((value) => value).length;
      if (questionStyle?.toLowerCase() == 'best_of_5' && trueCount != 1) {
        return null;
      }

      List<String>? explanations;
      final explanationsRaw = data['explanations'];
      if (explanationsRaw is List && explanationsRaw.isNotEmpty) {
        explanations = explanationsRaw
            .map((value) => value.toString())
            .toList();
        if (explanations.length != branches.length) return null;
      }

      return Question(
        questionText: stem,
        options: branches,
        correctAnswers: answers,
        explanations: explanations,
        type: trueCount == 1
            ? QuestionType.bestOfFive
            : QuestionType.multipleChoice,
      );
    } catch (_) {
      return null;
    }
  }
}
