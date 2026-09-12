import 'dart:async';

import 'package:flutter/foundation.dart';

import '../providers/quiz_provider.dart';

/// Adds durable, low-churn session checkpoints without coupling persistence to
/// the quiz UI lifecycle.
///
/// QuizProvider already owns the canonical attempt ID, timer deadline, quiz
/// snapshot, and database save/finalize logic. This coordinator watches only
/// meaningful session state (answers, navigation, and Practice pause state),
/// debounces those changes, and serializes autosaves. Timer tick notifications
/// deliberately do not change the fingerprint, so a long-running timer does
/// not write to SQLite every second.
class QuizSessionDurabilityCoordinator {
  QuizSessionDurabilityCoordinator._(this._provider) {
    _provider.addListener(_handleProviderChanged);
    _handleProviderChanged();
  }

  static QuizSessionDurabilityCoordinator attach(QuizProvider provider) {
    return QuizSessionDurabilityCoordinator._(provider);
  }

  static const Duration _checkpointDebounce = Duration(milliseconds: 650);

  final QuizProvider _provider;
  Timer? _debounce;
  Future<void> _saveTail = Future<void>.value();
  Future<bool>? _expiryFinalization;
  String? _lastMeaningfulFingerprint;

  void _handleProviderChanged() {
    if (_provider.quiz == null || _provider.quizSetId == null) {
      _resetObservedSession();
      return;
    }

    if (_provider.isCompleted) {
      _resetObservedSession();
      return;
    }

    if (_shouldFinalizeExpiredExam()) {
      _finalizeExpiredExam();
      return;
    }

    final fingerprint = _meaningfulFingerprint();
    if (fingerprint == _lastMeaningfulFingerprint) return;

    _lastMeaningfulFingerprint = fingerprint;
    _scheduleCheckpoint();
  }

  bool _shouldFinalizeExpiredExam() {
    return _provider.hasTimer &&
        _provider.timerMode == QuizTimerMode.exam &&
        _provider.remainingTimeInSeconds <= 0 &&
        !_provider.isSubmitting &&
        !_provider.isCompleted;
  }

  void _finalizeExpiredExam() {
    _debounce?.cancel();
    _debounce = null;
    _expiryFinalization ??= _provider.finalizeAttempt().then((success) {
      if (!success) {
        _expiryFinalization = null;
      }
      return success;
    });
  }

  String _meaningfulFingerprint() {
    final entries = _provider.answers.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final answerState = entries
        .map(
          (entry) =>
              '${entry.key}:${entry.value.map(_encodeAnswerValue).join()}',
        )
        .join('|');

    return <Object?>[
      _provider.quizSetId,
      _provider.currentQuestionIndex,
      _provider.scoringMethod.name,
      _provider.hasTimer ? _provider.timerMode.name : 'untimed',
      _provider.hasTimer ? _provider.totalTimeInSeconds : null,
      _provider.hasTimer && _provider.timerMode == QuizTimerMode.practice
          ? _provider.isTimerPaused
          : null,
      answerState,
    ].join('~');
  }

  String _encodeAnswerValue(bool? value) {
    if (value == null) return '-';
    return value ? '1' : '0';
  }

  void _scheduleCheckpoint() {
    _debounce?.cancel();
    _debounce = Timer(_checkpointDebounce, () {
      _saveTail = _saveTail.then(
        (_) => _saveCheckpoint(),
        onError: (Object error, StackTrace stackTrace) {
          debugPrint(
            'QuizSessionDurabilityCoordinator: previous checkpoint failed: $error',
          );
          return _saveCheckpoint();
        },
      );
    });
  }

  Future<void> _saveCheckpoint() async {
    if (_provider.quiz == null ||
        _provider.quizSetId == null ||
        _provider.isCompleted ||
        _provider.isSubmitting ||
        _shouldFinalizeExpiredExam()) {
      return;
    }

    final saved = await _provider.saveProgress();
    if (!saved &&
        !_provider.isCompleted &&
        !_provider.isSubmitting &&
        _provider.quizSetId != null) {
      debugPrint(
        'QuizSessionDurabilityCoordinator: durable checkpoint was not saved',
      );
    }
  }

  void _resetObservedSession() {
    _debounce?.cancel();
    _debounce = null;
    _lastMeaningfulFingerprint = null;
    _expiryFinalization = null;
  }
}
