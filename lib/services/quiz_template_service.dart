import 'package:shared_preferences/shared_preferences.dart';

/// Service for persisting quiz generation template settings
/// Saves all settings EXCEPT quiz name (which should always start blank)
class QuizTemplateService {
  static const String _keyTopic = 'quiz_template_topic';
  static const String _keySubjectCategory = 'quiz_template_subject_category';
  static const String _keyQuestionStyle = 'quiz_template_question_style';
  static const String _keyDifficulty = 'quiz_template_difficulty';
  static const String _keyNumberOfStems = 'quiz_template_number_of_stems';
  static const String _keyBranchesPerStem = 'quiz_template_branches_per_stem';
  static const String _keySampleQuestions = 'quiz_template_sample_questions';
  static const String _keyAdditionalInstructions =
      'quiz_template_additional_instructions';
  static const String _keyUseSampleFile = 'quiz_template_use_sample_file';

  /// Save the current template settings
  Future<void> saveTemplate({
    required String topic,
    String? subjectCategory,
    required String questionStyle,
    required String difficulty,
    required int numberOfStems,
    required int branchesPerStem,
    String? sampleQuestions,
    String? additionalInstructions,
    required bool useSampleFile,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_keyTopic, topic);
    await prefs.setString(_keyQuestionStyle, questionStyle);
    await prefs.setString(_keyDifficulty, difficulty);
    await prefs.setInt(_keyNumberOfStems, numberOfStems);
    await prefs.setInt(_keyBranchesPerStem, branchesPerStem);
    await prefs.setBool(_keyUseSampleFile, useSampleFile);

    // Save nullable strings
    if (subjectCategory != null) {
      await prefs.setString(_keySubjectCategory, subjectCategory);
    } else {
      await prefs.remove(_keySubjectCategory);
    }

    if (sampleQuestions != null && sampleQuestions.isNotEmpty) {
      await prefs.setString(_keySampleQuestions, sampleQuestions);
    } else {
      await prefs.remove(_keySampleQuestions);
    }

    if (additionalInstructions != null && additionalInstructions.isNotEmpty) {
      await prefs.setString(_keyAdditionalInstructions, additionalInstructions);
    } else {
      await prefs.remove(_keyAdditionalInstructions);
    }
  }

  /// Load the last used template settings
  /// Returns null if no template has been saved yet
  Future<QuizTemplate?> loadTemplate() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if we have any saved data
    if (!prefs.containsKey(_keyTopic)) {
      return null;
    }

    return QuizTemplate(
      topic: prefs.getString(_keyTopic) ?? '',
      subjectCategory: prefs.getString(_keySubjectCategory),
      questionStyle: prefs.getString(_keyQuestionStyle) ?? 'mixed',
      // Normalize legacy difficulty values (Easy/Medium/Hard) to new taxonomy
      difficulty: _normalizeDifficulty(
        prefs.getString(_keyDifficulty) ?? 'undergraduate',
      ),
      numberOfStems: prefs.getInt(_keyNumberOfStems) ?? 20,
      branchesPerStem: prefs.getInt(_keyBranchesPerStem) ?? 5,
      sampleQuestions: prefs.getString(_keySampleQuestions),
      additionalInstructions: prefs.getString(_keyAdditionalInstructions),
      useSampleFile: prefs.getBool(_keyUseSampleFile) ?? false,
    );
  }

  /// Clear the saved template
  Future<void> clearTemplate() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_keyTopic);
    await prefs.remove(_keySubjectCategory);
    await prefs.remove(_keyQuestionStyle);
    await prefs.remove(_keyDifficulty);
    await prefs.remove(_keyNumberOfStems);
    await prefs.remove(_keyBranchesPerStem);
    await prefs.remove(_keySampleQuestions);
    await prefs.remove(_keyAdditionalInstructions);
    await prefs.remove(_keyUseSampleFile);
  }

  /// Normalize legacy difficulty labels to new taxonomy
  static String _normalizeDifficulty(String raw) {
    final lower = raw.toLowerCase();
    if (lower == 'easy') return 'undergraduate';
    if (lower == 'medium') return 'postgraduate';
    if (lower == 'hard') return 'master';
    // If it already matches one of our new labels, return as-is
    final allowed = ['undergraduate', 'postgraduate', 'master', 'doctorate'];
    if (allowed.contains(lower)) return lower;
    // Fallback default
    return 'undergraduate';
  }

  /// Check if a template has been saved
  Future<bool> hasTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyTopic);
  }
}

/// Model for quiz generation template
class QuizTemplate {
  final String topic;
  final String? subjectCategory;
  final String questionStyle;
  final String difficulty;
  final int numberOfStems;
  final int branchesPerStem;
  final String? sampleQuestions;
  final String? additionalInstructions;
  final bool useSampleFile;

  QuizTemplate({
    required this.topic,
    this.subjectCategory,
    required this.questionStyle,
    required this.difficulty,
    required this.numberOfStems,
    required this.branchesPerStem,
    this.sampleQuestions,
    this.additionalInstructions,
    required this.useSampleFile,
  });
}
