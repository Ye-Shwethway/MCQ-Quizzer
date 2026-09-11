import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../models/quiz.dart';
import '../models/question.dart';
import '../models/flashcard.dart';
import '../services/quiz_service.dart';
import '../services/database_service.dart';

enum QuizTimerMode { practice, exam }

class QuizProvider extends ChangeNotifier {
  String _attemptId = _newAttemptId();
  bool _completed = false;
  bool _submitting = false;
  Future<bool>? _finalizing;
  bool get isCompleted => _completed;
  bool get isSubmitting => _submitting;
  static String _newAttemptId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  final Stopwatch _stopwatch = Stopwatch()..start();
  late final Duration Function() _elapsed;
  Duration _runStarted = Duration.zero;
  Duration _remainingAtRunStart = Duration.zero;
  final DateTime Function() _now;
  final DatabaseService _database;
  DateTime? _deadline;
  QuizTimerMode _timerMode = QuizTimerMode.practice;
  QuizTimerMode get timerMode => _timerMode;

  QuizProvider({
    Duration Function()? elapsed,
    DateTime Function()? now,
    DatabaseService? database,
  }) : _now = now ?? DateTime.now,
       _database = database ?? DatabaseService.instance {
    _elapsed = elapsed ?? (() => _stopwatch.elapsed);
  }
  Quiz? _quiz;
  int? _quizSetId; // Store quiz set ID for saving progress
  int _currentQuestionIndex = 0;
  Map<int, List<bool?>> _answers =
      {}; // Map of question index to list of true/false/null answers for A-E
  ScoringMethod _scoringMethod = ScoringMethod.straight;

  // Timer properties
  Timer? _timer;
  int? _totalTimeInSeconds;
  int _remainingTimeInSeconds = 0;
  bool _isTimerActive = false;
  bool _isTimerPaused = false;
  VoidCallback? _onTimerExpiredCallback;

  // Flashcard mode
  List<Flashcard>? _flashcards;
  int _currentFlashcardIndex = 0;
  Map<int, bool?> _flashcardAnswers =
      {}; // Map of flashcard index to true/false answer

  Quiz? get quiz => _quiz;
  int get currentQuestionIndex => _currentQuestionIndex;
  Question? get currentQuestion {
    if (_quiz == null ||
        _quiz!.questions.isEmpty ||
        _currentQuestionIndex < 0 ||
        _currentQuestionIndex >= _quiz!.questions.length) {
      return null;
    }
    return _quiz!.questions[_currentQuestionIndex];
  }

  int get totalQuestions => _quiz?.questions.length ?? 0;
  double get progress =>
      totalQuestions > 0 ? (_currentQuestionIndex + 1) / totalQuestions : 0.0;
  int get answeredCount =>
      List.generate(totalQuestions, (index) => index).where(isAnswered).length;
  int get partialCount => List.generate(totalQuestions, (index) => index)
      .where(
        (index) =>
            !isAnswered(index) &&
            (_answers[index]?.any((value) => value != null) ?? false),
      )
      .length;
  double get completionProgress =>
      totalQuestions > 0 ? answeredCount / totalQuestions : 0;
  Map<int, List<bool?>> get answers => Map.unmodifiable(
    _answers.map(
      (key, value) => MapEntry(key, List<bool?>.unmodifiable(value)),
    ),
  );
  ScoringMethod get scoringMethod => _scoringMethod;
  int? get quizSetId => _quizSetId;
  QuestionType get quizType =>
      currentQuestion?.detectedType ?? QuestionType.multipleChoice;

  // Timer getters
  bool get isTimerActive => _isTimerActive;
  bool get isTimerPaused => _isTimerPaused;
  int get remainingTimeInSeconds => _remainingTimeInSeconds;
  int? get totalTimeInSeconds => _totalTimeInSeconds;
  bool get hasTimer => _totalTimeInSeconds != null;

  String get formattedTimeRemaining {
    final hours = _remainingTimeInSeconds ~/ 3600;
    final minutes = (_remainingTimeInSeconds % 3600) ~/ 60;
    final seconds = _remainingTimeInSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Flashcard getters
  List<Flashcard>? get flashcards => _flashcards;
  int get currentFlashcardIndex => _currentFlashcardIndex;
  Flashcard? get currentFlashcard {
    if (_flashcards == null ||
        _flashcards!.isEmpty ||
        _currentFlashcardIndex < 0 ||
        _currentFlashcardIndex >= _flashcards!.length) {
      return null;
    }
    return _flashcards![_currentFlashcardIndex];
  }

  int get totalFlashcards => _flashcards?.length ?? 0;
  double get flashcardProgress => totalFlashcards > 0
      ? (_currentFlashcardIndex + 1) / totalFlashcards
      : 0.0;
  Map<int, bool?> get flashcardAnswers => _flashcardAnswers;

  void setQuiz(
    Quiz quiz, {
    int? quizSetId,
    ScoringMethod scoringMethod = ScoringMethod.straight,
    int? timeLimitInMinutes,
    QuizTimerMode timerMode = QuizTimerMode.practice,
  }) {
    _timer?.cancel();
    _quizSetId = quizSetId;
    _attemptId = _newAttemptId();
    _completed = false;
    _submitting = false;
    _finalizing = null;
    _onTimerExpiredCallback = null;
    _timerMode = timerMode;
    _deadline = null;
    _isTimerPaused = false;
    _quiz = Quiz.fromJson(quiz.toJson());
    _currentQuestionIndex = 0;
    _answers = {};
    _scoringMethod = scoringMethod;
    _flashcards = null;
    _currentFlashcardIndex = 0;
    _flashcardAnswers = {};

    // Setup timer if time limit provided
    if (timeLimitInMinutes != null && timeLimitInMinutes > 0) {
      _totalTimeInSeconds = timeLimitInMinutes * 60;
      _remainingTimeInSeconds = _totalTimeInSeconds!;
      if (_timerMode == QuizTimerMode.exam) {
        _deadline = _now().toUtc().add(Duration(seconds: _totalTimeInSeconds!));
      }
      _startTimer();
    } else {
      _totalTimeInSeconds = null;
      _remainingTimeInSeconds = 0;
      _isTimerActive = false;
      _timer?.cancel();
    }

    debugPrint('setQuiz: Quiz set with ${quiz.questions.length} questions');
    notifyListeners();
  }

  // Alias for setQuiz with optional quizSetId parameter for database tracking
  void startQuiz(
    Quiz quiz, {
    ScoringMethod scoringMethod = ScoringMethod.straight,
    int? quizSetId,
    int? timeLimitInMinutes,
    QuizTimerMode timerMode = QuizTimerMode.practice,
  }) {
    setQuiz(
      quiz,
      quizSetId: quizSetId,
      scoringMethod: scoringMethod,
      timeLimitInMinutes: timeLimitInMinutes,
      timerMode: timerMode,
    );
  }

  // Timer management
  void _startTimer() {
    _isTimerActive = true;
    _isTimerPaused = false;
    _timer?.cancel();
    _runStarted = _elapsed();
    _remainingAtRunStart = Duration(seconds: _remainingTimeInSeconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => refreshTimer());
  }

  void _syncTimer() {
    if (!_isTimerActive || _isTimerPaused) return;
    final remaining = _timerMode == QuizTimerMode.exam && _deadline != null
        ? _deadline!.difference(_now().toUtc())
        : _remainingAtRunStart - (_elapsed() - _runStarted);
    _remainingTimeInSeconds = ((remaining.inMilliseconds + 999) ~/ 1000).clamp(
      0,
      _totalTimeInSeconds ?? 0,
    );
  }

  void refreshTimer() {
    if (!_isTimerActive || _isTimerPaused) return;
    _syncTimer();
    if (_remainingTimeInSeconds == 0) {
      _handleTimerExpired();
    } else {
      notifyListeners();
    }
  }

  void _handleTimerExpired() {
    _timer?.cancel();
    _isTimerActive = false;
    debugPrint('Timer expired!');
    _onTimerExpiredCallback?.call();
    notifyListeners();
  }

  void setTimerExpiredCallback(VoidCallback? callback) {
    _onTimerExpiredCallback = callback;
  }

  void pauseTimer() {
    refreshTimer();
    if (_timerMode == QuizTimerMode.exam) return;
    if (_isTimerActive && !_isTimerPaused) {
      _syncTimer();
      _remainingAtRunStart -= _elapsed() - _runStarted;
      _isTimerPaused = true;
      debugPrint('Timer paused');
      notifyListeners();
    }
  }

  void resumeTimer() {
    if (_isTimerActive && _isTimerPaused) {
      _runStarted = _elapsed();
      _isTimerPaused = false;
      debugPrint('Timer resumed');
      notifyListeners();
    }
  }

  void stopTimer() {
    _syncTimer();
    _timer?.cancel();
    _isTimerActive = false;
    _isTimerPaused = false;
    debugPrint('Timer stopped');
    notifyListeners();
  }

  void setFlashcards(List<Flashcard> flashcards) {
    _flashcards = flashcards;
    _currentFlashcardIndex = 0;
    _flashcardAnswers = {};
    debugPrint(
      'setFlashcards: Flashcards set with ${flashcards.length} flashcards',
    );
    notifyListeners();
  }

  void updateAnswer(int questionIndex, int optionIndex, bool? value) {
    if (_completed || _submitting) return;
    refreshTimer();
    if (hasTimer && (_remainingTimeInSeconds == 0 || _isTimerPaused)) return;
    if (questionIndex < 0 || questionIndex >= totalQuestions) {
      debugPrint(
        'updateAnswer: Invalid questionIndex $questionIndex, totalQuestions: $totalQuestions',
      );
      return;
    }
    if (optionIndex < 0 || optionIndex >= 5) {
      debugPrint('updateAnswer: Invalid optionIndex $optionIndex');
      return;
    }
    _answers[questionIndex] ??= List.filled(
      5,
      null,
    ); // Initialize with null (unanswered)

    if (_quiz!.questions[questionIndex].detectedType ==
            QuestionType.bestOfFive &&
        value == true) {
      // For best of five, setting one to true clears others
      _answers[questionIndex] = List.filled(5, false);
      _answers[questionIndex]![optionIndex] = true;
    } else {
      _answers[questionIndex]![optionIndex] = value;
    }

    debugPrint(
      'updateAnswer: Updated answer for question $questionIndex, option $optionIndex to $value',
    );
    notifyListeners();
  }

  void nextQuestion() {
    if (_currentQuestionIndex < (totalQuestions - 1)) {
      _currentQuestionIndex++;
      debugPrint('nextQuestion: Moved to index $_currentQuestionIndex');
      notifyListeners();
    } else {
      debugPrint(
        'nextQuestion: Cannot move forward, already at last question or no questions',
      );
    }
  }

  void previousQuestion() {
    if (_currentQuestionIndex > 0) {
      _currentQuestionIndex--;
      debugPrint('previousQuestion: Moved to index $_currentQuestionIndex');
      notifyListeners();
    } else {
      debugPrint(
        'previousQuestion: Cannot move backward, already at first question',
      );
    }
  }

  /// Jump directly to a specific question index (0-based). Validates range.
  void goToQuestion(int index) {
    if (_quiz == null) {
      debugPrint('goToQuestion: No quiz loaded');
      return;
    }
    if (index < 0 || index >= totalQuestions) {
      debugPrint('goToQuestion: Invalid index $index');
      return;
    }
    _currentQuestionIndex = index;
    debugPrint('goToQuestion: Moved to index $_currentQuestionIndex');
    notifyListeners();
  }

  bool isAnswered(int questionIndex) {
    if (questionIndex < 0 || questionIndex >= totalQuestions) {
      debugPrint(
        'isAnswered: Invalid questionIndex $questionIndex, totalQuestions: $totalQuestions',
      );
      return false;
    }
    return QuizService().isQuestionComplete(
      _quiz!.questions[questionIndex],
      _answers[questionIndex],
    );
  }

  List<String> getSelectedOptions(int questionIndex) {
    if (questionIndex < 0 || questionIndex >= totalQuestions) {
      debugPrint(
        'getSelectedOptions: Invalid questionIndex $questionIndex, totalQuestions: $totalQuestions',
      );
      return [];
    }
    final answerList = _answers[questionIndex] ?? List.filled(5, null);
    final options = ['A', 'B', 'C', 'D', 'E'];
    // Ensure answerList length matches options length to prevent RangeError
    final safeAnswerList = answerList.length >= options.length
        ? answerList.sublist(0, options.length)
        : answerList + List.filled(options.length - answerList.length, null);
    return options
        .where((option) => safeAnswerList[options.indexOf(option)] == true)
        .toList();
  }

  void nextFlashcard() {
    if (_currentFlashcardIndex < (totalFlashcards - 1)) {
      _currentFlashcardIndex++;
      debugPrint('nextFlashcard: Moved to index $_currentFlashcardIndex');
      notifyListeners();
    } else {
      debugPrint(
        'nextFlashcard: Cannot move forward, already at last flashcard or no flashcards',
      );
    }
  }

  void previousFlashcard() {
    if (_currentFlashcardIndex > 0) {
      _currentFlashcardIndex--;
      debugPrint('previousFlashcard: Moved to index $_currentFlashcardIndex');
      notifyListeners();
    } else {
      debugPrint(
        'previousFlashcard: Cannot move backward, already at first flashcard',
      );
    }
  }

  void updateFlashcardAnswer(int flashcardIndex, bool? answer) {
    if (flashcardIndex < 0 || flashcardIndex >= totalFlashcards) {
      debugPrint(
        'updateFlashcardAnswer: Invalid flashcardIndex $flashcardIndex, totalFlashcards: $totalFlashcards',
      );
      return;
    }
    _flashcardAnswers[flashcardIndex] = answer;
    debugPrint(
      'updateFlashcardAnswer: Updated answer for flashcard $flashcardIndex to $answer',
    );
    notifyListeners();
  }

  void setScoringMethod(ScoringMethod method) {
    _scoringMethod = method;
    notifyListeners();
  }

  void reset() {
    _quiz = null;
    _quizSetId = null;
    _currentQuestionIndex = 0;
    _answers = {};
    _scoringMethod = ScoringMethod.straight;
    _flashcards = null;
    _currentFlashcardIndex = 0;
    _flashcardAnswers = {};

    // Clean up timer
    _timer?.cancel();
    _timer = null;
    _totalTimeInSeconds = null;
    _remainingTimeInSeconds = 0;
    _isTimerActive = false;
    _isTimerPaused = false;
    _onTimerExpiredCallback = null;

    debugPrint('reset: Provider reset');
    notifyListeners();
  }

  // Save and load quiz progress

  Future<bool> saveProgress() async {
    if (_completed || _submitting) return false;
    if (_quiz == null || _quizSetId == null) {
      debugPrint('saveProgress: No quiz or quiz set ID to save');
      return false;
    }

    try {
      _syncTimer();
      await _database.saveQuizProgress(
        attemptId: _attemptId,
        quizSnapshot: _quiz,
        quizSetId: _quizSetId!,
        currentQuestionIndex: _currentQuestionIndex,
        answers: _answers.map(
          (key, value) => MapEntry(key, List<bool?>.from(value)),
        ),
        timerRemaining: hasTimer ? _remainingTimeInSeconds : null,
        timerMode: hasTimer ? _timerMode.name : null,
        timerState: hasTimer
            ? {
                'total': _totalTimeInSeconds,
                'remaining': _remainingTimeInSeconds,
                'mode': _timerMode.name,
                'deadline': _deadline?.toIso8601String(),
                'paused': _isTimerPaused,
              }
            : null,
        scoringMethod: _scoringMethod.name,
      );
      debugPrint('saveProgress: Saved progress for quiz set $_quizSetId');
      return true;
    } catch (e) {
      debugPrint('saveProgress: Error saving progress - $e');
      return false;
    }
  }

  /// All resume entry points resolve the selected set before touching the route.
  Future<bool> resumeQuizSet(int quizSetId) async {
    if (_submitting) return false;
    try {
      final set = await _database.getQuizSet(quizSetId);
      if (set == null) return false;
      return await loadProgress(quizSetId, set.quiz);
    } catch (_) {
      return false;
    }
  }

  Future<bool> loadProgress(int quizSetId, Quiz quiz) async {
    try {
      final savedData = await _database.getSavedProgress(quizSetId);
      if (savedData == null) {
        debugPrint(
          'loadProgress: No saved progress found for quiz set $quizSetId',
        );
        return false;
      }

      // Cancel the previous session before restoring this one.
      _timer?.cancel();
      _isTimerActive = false;
      _isTimerPaused = false;
      _onTimerExpiredCallback = null;
      _totalTimeInSeconds = null;
      _remainingTimeInSeconds = 0;
      _deadline = null;
      _timerMode = QuizTimerMode.practice;
      // Parse saved data
      _quiz = savedData['quiz_snapshot'] is String
          ? Quiz.fromJson(
              jsonDecode(savedData['quiz_snapshot'] as String)
                  as Map<String, dynamic>,
            )
          : Quiz.fromJson(quiz.toJson());
      _attemptId = savedData['attempt_id'] as String? ?? _newAttemptId();
      _completed = false;
      _submitting = false;
      _finalizing = null;
      _quizSetId = quizSetId; // Store the quiz set ID
      _currentQuestionIndex = (savedData['current_question_index'] as int)
          .clamp(0, totalQuestions == 0 ? 0 : totalQuestions - 1);

      // Parse answers JSON
      final answersJson =
          jsonDecode(savedData['answers_json'] as String)
              as Map<String, dynamic>;
      _answers = answersJson.map((key, value) {
        final questionIndex = int.parse(key);
        final values = value as List;
        final answerList = List<bool?>.generate(
          5,
          (index) => index < values.length && values[index] is bool
              ? values[index] as bool
              : null,
        );
        return MapEntry(questionIndex, answerList);
      });

      // Restore scoring method
      final methodName = savedData['scoring_method'] as String;
      _scoringMethod = ScoringMethod.values.firstWhere(
        (m) => m.name == methodName,
        orElse: () => ScoringMethod.straight,
      );

      // Restore timer if applicable
      final timerRemaining = savedData['timer_remaining'] as int?;
      if (timerRemaining != null) {
        final state = savedData['timer_state'] == null
            ? null
            : jsonDecode(savedData['timer_state'] as String)
                  as Map<String, dynamic>;
        _totalTimeInSeconds = (state?['total'] as int? ?? timerRemaining).clamp(
          0,
          2147483647,
        );
        _remainingTimeInSeconds = timerRemaining.clamp(0, _totalTimeInSeconds!);
        _timerMode = state?['mode'] == 'exam'
            ? QuizTimerMode.exam
            : QuizTimerMode.practice;
        _deadline = state?['deadline'] is String
            ? DateTime.tryParse(state!['deadline'] as String)?.toUtc()
            : null;
        if (_timerMode == QuizTimerMode.exam && _deadline == null) {
          throw const FormatException('Saved exam has no deadline');
        }
        _startTimer();
        _syncTimer();
        if (_remainingTimeInSeconds == 0) {
          _timer?.cancel();
          _isTimerActive = false;
        } else if (_timerMode == QuizTimerMode.practice) {
          // Always show restored Practice sessions paused until explicitly resumed.
          pauseTimer();
        }
      }

      debugPrint(
        'loadProgress: Loaded progress - question $_currentQuestionIndex/$totalQuestions',
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('loadProgress: Error loading progress - $e');
      return false;
    }
  }

  Future<bool> finalizeAttempt() {
    if (_completed) return Future.value(true);
    return _finalizing ??= _finalize().then((success) {
      if (!success) _finalizing = null;
      return success;
    });
  }

  Future<bool> _finalize() async {
    if (_quiz == null) return false;
    _submitting = true;
    final wasActive = _isTimerActive;
    final wasPaused = _isTimerPaused;
    stopTimer();
    try {
      final results = QuizService().getQuizResults(
        _quiz!,
        answers,
        method: _scoringMethod,
      );
      if (_quizSetId != null) {
        await _database.saveQuizHistory(
          quizSetId: _quizSetId!,
          attemptId: _attemptId,
          quizSnapshot: _quiz,
          score: results['score'] as int,
          maximumScore: results['maxScore'] as int,
          scoringVersion: QuizService.scoringVersion,
          totalQuestions: totalQuestions,
          percentage: results['percentage'] as double,
          scoringMethod: _scoringMethod.name,
          answers: answers,
          retireProgress: true,
          timeTaken: hasTimer
              ? _totalTimeInSeconds! - _remainingTimeInSeconds
              : null,
        );
      }
      _completed = true;
      return true;
    } catch (_) {
      if (wasActive && _remainingTimeInSeconds > 0) {
        _startTimer();
        if (wasPaused) pauseTimer();
      }
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> clearSavedProgress(int quizSetId) async {
    try {
      await _database.deleteSavedProgress(quizSetId);
      debugPrint(
        'clearSavedProgress: Cleared progress for quiz set $quizSetId',
      );
    } catch (e) {
      debugPrint('clearSavedProgress: Error clearing progress - $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }
}
