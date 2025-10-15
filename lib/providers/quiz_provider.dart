import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import '../models/quiz.dart';
import '../models/question.dart';
import '../models/flashcard.dart';
import '../services/quiz_service.dart';
import '../services/database_service.dart';

class QuizProvider extends ChangeNotifier {
  Quiz? _quiz;
  int? _quizSetId; // Store quiz set ID for saving progress
  int _currentQuestionIndex = 0;
  Map<int, List<bool?>> _answers = {}; // Map of question index to list of true/false/null answers for A-E
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
  Map<int, bool?> _flashcardAnswers = {}; // Map of flashcard index to true/false answer

  Quiz? get quiz => _quiz;
  int get currentQuestionIndex => _currentQuestionIndex;
  Question? get currentQuestion {
    if (_quiz == null || _quiz!.questions.isEmpty || _currentQuestionIndex < 0 || _currentQuestionIndex >= _quiz!.questions.length) {
      debugPrint('currentQuestion: Returning null - quiz: ${_quiz != null}, questions length: ${_quiz?.questions.length ?? 0}, index: $_currentQuestionIndex');
      return null;
    }
    debugPrint('currentQuestion: Accessing question at index $_currentQuestionIndex');
    return _quiz!.questions[_currentQuestionIndex];
  }
  int get totalQuestions => _quiz?.questions.length ?? 0;
  double get progress => totalQuestions > 0 ? (_currentQuestionIndex + 1) / totalQuestions : 0.0;
  Map<int, List<bool?>> get answers => _answers;
  ScoringMethod get scoringMethod => _scoringMethod;
  int? get quizSetId => _quizSetId;

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
    if (_flashcards == null || _flashcards!.isEmpty || _currentFlashcardIndex < 0 || _currentFlashcardIndex >= _flashcards!.length) {
      debugPrint('currentFlashcard: Returning null - flashcards: ${_flashcards != null}, length: ${_flashcards?.length ?? 0}, index: $_currentFlashcardIndex');
      return null;
    }
    debugPrint('currentFlashcard: Accessing flashcard at index $_currentFlashcardIndex');
    return _flashcards![_currentFlashcardIndex];
  }
  int get totalFlashcards => _flashcards?.length ?? 0;
  double get flashcardProgress => totalFlashcards > 0 ? (_currentFlashcardIndex + 1) / totalFlashcards : 0.0;
  Map<int, bool?> get flashcardAnswers => _flashcardAnswers;

  void setQuiz(Quiz quiz, {ScoringMethod scoringMethod = ScoringMethod.straight, int? timeLimitInMinutes}) {
    _quiz = quiz;
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
  void startQuiz(Quiz quiz, {ScoringMethod scoringMethod = ScoringMethod.straight, int? quizSetId, int? timeLimitInMinutes}) {
    _quizSetId = quizSetId; // Store for later use
    setQuiz(quiz, scoringMethod: scoringMethod, timeLimitInMinutes: timeLimitInMinutes);
  }

  // Timer management
  void _startTimer() {
    _isTimerActive = true;
    _isTimerPaused = false;
    _timer?.cancel();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isTimerPaused && _remainingTimeInSeconds > 0) {
        _remainingTimeInSeconds--;
        notifyListeners();
        
        if (_remainingTimeInSeconds == 0) {
          _handleTimerExpired();
        }
      }
    });
  }

  void _handleTimerExpired() {
    _timer?.cancel();
    _isTimerActive = false;
    debugPrint('Timer expired!');
    _onTimerExpiredCallback?.call();
    notifyListeners();
  }

  void setTimerExpiredCallback(VoidCallback callback) {
    _onTimerExpiredCallback = callback;
  }

  void pauseTimer() {
    if (_isTimerActive) {
      _isTimerPaused = true;
      debugPrint('Timer paused');
      notifyListeners();
    }
  }

  void resumeTimer() {
    if (_isTimerActive && _isTimerPaused) {
      _isTimerPaused = false;
      debugPrint('Timer resumed');
      notifyListeners();
    }
  }

  void stopTimer() {
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
    debugPrint('setFlashcards: Flashcards set with ${flashcards.length} flashcards');
    notifyListeners();
  }

  void updateAnswer(int questionIndex, int optionIndex, bool? value) {
    if (questionIndex < 0 || questionIndex >= totalQuestions) {
      debugPrint('updateAnswer: Invalid questionIndex $questionIndex, totalQuestions: $totalQuestions');
      return;
    }
    if (optionIndex < 0 || optionIndex >= 5) {
      debugPrint('updateAnswer: Invalid optionIndex $optionIndex');
      return;
    }
    _answers[questionIndex] ??= List.filled(5, null); // Initialize with null (unanswered)
    _answers[questionIndex]![optionIndex] = value;
    debugPrint('updateAnswer: Updated answer for question $questionIndex, option $optionIndex to $value');
    notifyListeners();
  }

  void nextQuestion() {
    if (_currentQuestionIndex < (totalQuestions - 1)) {
      _currentQuestionIndex++;
      debugPrint('nextQuestion: Moved to index $_currentQuestionIndex');
      notifyListeners();
    } else {
      debugPrint('nextQuestion: Cannot move forward, already at last question or no questions');
    }
  }

  void previousQuestion() {
    if (_currentQuestionIndex > 0) {
      _currentQuestionIndex--;
      debugPrint('previousQuestion: Moved to index $_currentQuestionIndex');
      notifyListeners();
    } else {
      debugPrint('previousQuestion: Cannot move backward, already at first question');
    }
  }

  bool isAnswered(int questionIndex) {
    if (questionIndex < 0 || questionIndex >= totalQuestions) {
      debugPrint('isAnswered: Invalid questionIndex $questionIndex, totalQuestions: $totalQuestions');
      return false;
    }
    return _answers[questionIndex]?.any((answer) => answer != null) ?? false;
  }

  List<String> getSelectedOptions(int questionIndex) {
    if (questionIndex < 0 || questionIndex >= totalQuestions) {
      debugPrint('getSelectedOptions: Invalid questionIndex $questionIndex, totalQuestions: $totalQuestions');
      return [];
    }
    final answerList = _answers[questionIndex] ?? List.filled(5, null);
    final options = ['A', 'B', 'C', 'D', 'E'];
    // Ensure answerList length matches options length to prevent RangeError
    final safeAnswerList = answerList.length >= options.length
        ? answerList.sublist(0, options.length)
        : answerList + List.filled(options.length - answerList.length, null);
    return options.where((option) => safeAnswerList[options.indexOf(option)] == true).toList();
  }

  void nextFlashcard() {
    if (_currentFlashcardIndex < (totalFlashcards - 1)) {
      _currentFlashcardIndex++;
      debugPrint('nextFlashcard: Moved to index $_currentFlashcardIndex');
      notifyListeners();
    } else {
      debugPrint('nextFlashcard: Cannot move forward, already at last flashcard or no flashcards');
    }
  }

  void previousFlashcard() {
    if (_currentFlashcardIndex > 0) {
      _currentFlashcardIndex--;
      debugPrint('previousFlashcard: Moved to index $_currentFlashcardIndex');
      notifyListeners();
    } else {
      debugPrint('previousFlashcard: Cannot move backward, already at first flashcard');
    }
  }

  void updateFlashcardAnswer(int flashcardIndex, bool? answer) {
    if (flashcardIndex < 0 || flashcardIndex >= totalFlashcards) {
      debugPrint('updateFlashcardAnswer: Invalid flashcardIndex $flashcardIndex, totalFlashcards: $totalFlashcards');
      return;
    }
    _flashcardAnswers[flashcardIndex] = answer;
    debugPrint('updateFlashcardAnswer: Updated answer for flashcard $flashcardIndex to $answer');
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
    if (_quiz == null || _quizSetId == null) {
      debugPrint('saveProgress: No quiz or quiz set ID to save');
      return false;
    }

    try {
      await DatabaseService.instance.saveQuizProgress(
        quizSetId: _quizSetId!,
        currentQuestionIndex: _currentQuestionIndex,
        answers: _answers,
        timerRemaining: _isTimerActive ? _remainingTimeInSeconds : null,
        timerMode: _totalTimeInSeconds != null ? 'timed' : null,
        scoringMethod: _scoringMethod.name,
      );
      debugPrint('saveProgress: Saved progress for quiz set $_quizSetId');
      return true;
    } catch (e) {
      debugPrint('saveProgress: Error saving progress - $e');
      return false;
    }
  }

  Future<bool> loadProgress(int quizSetId, Quiz quiz) async {
    try {
      final savedData = await DatabaseService.instance.getSavedProgress(quizSetId);
      if (savedData == null) {
        debugPrint('loadProgress: No saved progress found for quiz set $quizSetId');
        return false;
      }

      // Parse saved data
      _quiz = quiz;
      _quizSetId = quizSetId; // Store the quiz set ID
      _currentQuestionIndex = savedData['current_question_index'] as int;
      
      // Parse answers JSON
      final answersJson = jsonDecode(savedData['answers_json'] as String) as Map<String, dynamic>;
      _answers = answersJson.map((key, value) {
        final questionIndex = int.parse(key);
        final answerList = (value as List).map((e) => e as bool?).toList();
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
        _totalTimeInSeconds = timerRemaining;
        _remainingTimeInSeconds = timerRemaining;
      }

      debugPrint('loadProgress: Loaded progress - question $_currentQuestionIndex/${quiz.questions.length}');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('loadProgress: Error loading progress - $e');
      return false;
    }
  }

  Future<void> clearSavedProgress(int quizSetId) async {
    try {
      await DatabaseService.instance.deleteSavedProgress(quizSetId);
      debugPrint('clearSavedProgress: Cleared progress for quiz set $quizSetId');
    } catch (e) {
      debugPrint('clearSavedProgress: Error clearing progress - $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}