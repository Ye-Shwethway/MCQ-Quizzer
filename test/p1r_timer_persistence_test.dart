import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mcq_quizzer/models/question.dart';
import 'package:mcq_quizzer/models/quiz.dart';
import 'package:mcq_quizzer/models/quiz_set.dart';
import 'package:mcq_quizzer/providers/quiz_provider.dart';
import 'package:mcq_quizzer/services/database_service.dart';
import 'package:mcq_quizzer/services/quiz_session_durability_coordinator.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('meaningful answer/navigation changes become durable after debounce', () async {
    final store = DatabaseService(databasePath: inMemoryDatabasePath);
    addTearDown(store.close);
    final quiz = _quiz(questionCount: 2);
    final setId = await _createSet(store, quiz);
    final provider = QuizProvider(database: store);
    addTearDown(provider.dispose);
    QuizSessionDurabilityCoordinator.attach(provider);

    provider.startQuiz(quiz, quizSetId: setId);
    provider.updateAnswer(0, 0, true);
    provider.nextQuestion();

    await Future<void>.delayed(const Duration(milliseconds: 800));

    final saved = await store.getSavedProgress(setId);
    expect(saved, isNotNull);
    expect(saved!['current_question_index'], 1);
    final answers = jsonDecode(saved['answers_json'] as String) as Map<String, dynamic>;
    expect((answers['0'] as List).first, true);
  });

  test('timer ticks do not rewrite an unchanged durable checkpoint', () async {
    final store = DatabaseService(databasePath: inMemoryDatabasePath);
    addTearDown(store.close);
    final quiz = _quiz(questionCount: 1);
    final setId = await _createSet(store, quiz);
    final provider = QuizProvider(database: store);
    addTearDown(provider.dispose);
    QuizSessionDurabilityCoordinator.attach(provider);

    provider.startQuiz(
      quiz,
      quizSetId: setId,
      timeLimitInMinutes: 5,
      timerMode: QuizTimerMode.practice,
    );
    provider.updateAnswer(0, 0, true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final firstSaved = await store.getSavedProgress(setId);
    expect(firstSaved, isNotNull);
    final savedAt = firstSaved!['saved_at'];

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final afterTicks = await store.getSavedProgress(setId);
    expect(afterTicks, isNotNull);
    expect(afterTicks!['saved_at'], savedAt);
  });

  test('Practice relaunch restores the last durable state paused', () async {
    final store = DatabaseService(databasePath: inMemoryDatabasePath);
    addTearDown(store.close);
    final quiz = _quiz(questionCount: 2);
    final setId = await _createSet(store, quiz);
    var elapsed = Duration.zero;

    final first = QuizProvider(database: store, elapsed: () => elapsed);
    QuizSessionDurabilityCoordinator.attach(first);
    first.startQuiz(
      quiz,
      quizSetId: setId,
      timeLimitInMinutes: 5,
      timerMode: QuizTimerMode.practice,
    );
    elapsed = const Duration(seconds: 37);
    first.updateAnswer(0, 0, true);
    first.nextQuestion();
    first.pauseTimer();
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final durableRemaining = first.remainingTimeInSeconds;
    first.dispose();

    final resumed = QuizProvider(database: store);
    addTearDown(resumed.dispose);
    QuizSessionDurabilityCoordinator.attach(resumed);
    expect(await resumed.resumeQuizSet(setId), true);
    expect(resumed.currentQuestionIndex, 1);
    expect(resumed.answers[0]![0], true);
    expect(resumed.timerMode, QuizTimerMode.practice);
    expect(resumed.isTimerPaused, true);
    expect(resumed.remainingTimeInSeconds, durableRemaining);
  });

  test('Exam relaunch uses the original absolute UTC deadline', () async {
    final store = DatabaseService(databasePath: inMemoryDatabasePath);
    addTearDown(store.close);
    final quiz = _quiz(questionCount: 1);
    final setId = await _createSet(store, quiz);
    var now = DateTime.utc(2026, 9, 12, 12, 0, 0);

    final first = QuizProvider(database: store, now: () => now);
    QuizSessionDurabilityCoordinator.attach(first);
    first.startQuiz(
      quiz,
      quizSetId: setId,
      timeLimitInMinutes: 1,
      timerMode: QuizTimerMode.exam,
    );
    first.updateAnswer(0, 0, true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    first.dispose();

    now = now.add(const Duration(seconds: 25));
    final resumed = QuizProvider(database: store, now: () => now);
    addTearDown(resumed.dispose);
    QuizSessionDurabilityCoordinator.attach(resumed);
    expect(await resumed.resumeQuizSet(setId), true);
    expect(resumed.timerMode, QuizTimerMode.exam);
    expect(resumed.isTimerPaused, false);
    expect(resumed.remainingTimeInSeconds, inInclusiveRange(34, 35));
  });

  test('expired-away Exam finalizes exactly once and retires progress', () async {
    final store = DatabaseService(databasePath: inMemoryDatabasePath);
    addTearDown(store.close);
    final quiz = _quiz(questionCount: 1);
    final setId = await _createSet(store, quiz);
    var now = DateTime.utc(2026, 9, 12, 12, 0, 0);

    final first = QuizProvider(database: store, now: () => now);
    QuizSessionDurabilityCoordinator.attach(first);
    first.startQuiz(
      quiz,
      quizSetId: setId,
      timeLimitInMinutes: 1,
      timerMode: QuizTimerMode.exam,
    );
    first.updateAnswer(0, 0, true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    first.dispose();

    now = now.add(const Duration(seconds: 61));
    final resumed = QuizProvider(database: store, now: () => now);
    addTearDown(resumed.dispose);
    QuizSessionDurabilityCoordinator.attach(resumed);
    expect(await resumed.resumeQuizSet(setId), true);

    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(await store.getSavedProgress(setId), isNull);
    expect(await store.getQuizHistory(setId), hasLength(1));

    expect(await resumed.finalizeAttempt(), true);
    expect(await store.getQuizHistory(setId), hasLength(1));
  });

  test('repeated Practice resume does not drift durable answers or position', () async {
    final store = DatabaseService(databasePath: inMemoryDatabasePath);
    addTearDown(store.close);
    final quiz = _quiz(questionCount: 3);
    final setId = await _createSet(store, quiz);

    final first = QuizProvider(database: store);
    QuizSessionDurabilityCoordinator.attach(first);
    first.startQuiz(
      quiz,
      quizSetId: setId,
      timeLimitInMinutes: 5,
      timerMode: QuizTimerMode.practice,
    );
    first.goToQuestion(2);
    first.updateAnswer(2, 1, true);
    first.pauseTimer();
    await Future<void>.delayed(const Duration(milliseconds: 800));
    first.dispose();

    final second = QuizProvider(database: store);
    QuizSessionDurabilityCoordinator.attach(second);
    expect(await second.resumeQuizSet(setId), true);
    expect(second.currentQuestionIndex, 2);
    expect(second.answers[2]![1], true);
    expect(second.isTimerPaused, true);
    expect(await second.saveProgress(), true);
    second.dispose();

    final third = QuizProvider(database: store);
    addTearDown(third.dispose);
    QuizSessionDurabilityCoordinator.attach(third);
    expect(await third.resumeQuizSet(setId), true);
    expect(third.currentQuestionIndex, 2);
    expect(third.answers[2]![1], true);
    expect(third.isTimerPaused, true);
  });
}

Quiz _quiz({required int questionCount}) {
  return Quiz(
    title: 'P1R Test Quiz',
    questions: List.generate(
      questionCount,
      (index) => Question(
        questionText: 'Question $index',
        options: const ['A', 'B', 'C', 'D', 'E'],
        correctAnswer: 'A',
        type: QuestionType.bestOfFive,
      ),
    ),
  );
}

Future<int> _createSet(DatabaseService store, Quiz quiz) {
  final now = DateTime.utc(2026, 9, 12);
  return store.createQuizSet(
    QuizSet(
      title: quiz.title,
      description: '',
      quiz: quiz,
      createdAt: now,
      updatedAt: now,
      questionFilePath: '',
      answerKeyFilePath: '',
      totalQuestions: quiz.questions.length,
    ),
  );
}
