import 'package:flutter_test/flutter_test.dart';
import 'package:mcq_quizzer/models/quiz.dart';
import 'package:mcq_quizzer/models/question.dart';
import 'package:mcq_quizzer/providers/quiz_provider.dart';
import 'package:mcq_quizzer/models/quiz_set.dart';
import 'package:mcq_quizzer/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'cold-start Exam resume preserves original duration and expired deadline',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final store = DatabaseService(databasePath: inMemoryDatabasePath);
      addTearDown(store.close);
      var now = DateTime.utc(2026, 9, 6);
      final quiz = Quiz(
        title: 'Saved exam',
        questions: [
          Question(
            questionText: 'A?',
            options: ['A', 'B', 'C', 'D', 'E'],
            correctAnswer: 'A',
          ),
        ],
      );
      final id = await store.createQuizSet(
        QuizSet(
          title: quiz.title,
          description: '',
          quiz: quiz,
          createdAt: now,
          updatedAt: now,
          questionFilePath: '',
          answerKeyFilePath: '',
          totalQuestions: 1,
        ),
      );
      final first = QuizProvider(now: () => now, database: store);
      first.startQuiz(
        quiz,
        quizSetId: id,
        timeLimitInMinutes: 1,
        timerMode: QuizTimerMode.exam,
      );
      expect(await first.saveProgress(), true);
      first.dispose();
      now = now.add(const Duration(minutes: 2));
      final resumed = QuizProvider(now: () => now, database: store);
      addTearDown(resumed.dispose);
      expect(await resumed.loadProgress(id, quiz), true);
      expect(resumed.totalTimeInSeconds, 60);
      expect(resumed.remainingTimeInSeconds, 0);
      expect(resumed.timerMode, QuizTimerMode.exam);
      resumed.updateAnswer(0, 0, true);
      expect(resumed.answers, isEmpty);
    },
  );
  test('Exam refuses pause, expires once by deadline and freezes answers', () {
    var now = DateTime.utc(2026, 9, 6);
    final provider = QuizProvider(now: () => now);
    addTearDown(provider.dispose);
    provider.setQuiz(
      Quiz(
        title: 'Exam',
        questions: [
          Question(
            questionText: 'A?',
            options: ['A', 'B', 'C', 'D', 'E'],
            correctAnswer: 'A',
          ),
        ],
      ),
      timeLimitInMinutes: 1,
      timerMode: QuizTimerMode.exam,
    );
    var expirations = 0;
    provider.setTimerExpiredCallback(() => expirations++);
    provider.pauseTimer();
    expect(provider.isTimerPaused, false);
    now = now.add(const Duration(minutes: 2));
    provider.refreshTimer();
    provider.refreshTimer();
    provider.updateAnswer(0, 0, true);
    expect(provider.remainingTimeInSeconds, 0);
    expect(provider.isTimerActive, false);
    expect(provider.answers, isEmpty);
    expect(expirations, 1);
  });
  test('Practice pause retains remaining time across background duration', () {
    var elapsed = Duration.zero;
    final provider = QuizProvider(elapsed: () => elapsed);
    addTearDown(provider.dispose);
    provider.setQuiz(
      Quiz(
        title: 'Timer',
        questions: [
          Question(
            questionText: 'A?',
            options: ['A', 'B', 'C', 'D', 'E'],
            correctAnswer: 'A',
          ),
        ],
      ),
      timeLimitInMinutes: 1,
    );
    elapsed = const Duration(seconds: 17);
    provider.pauseTimer();
    expect(provider.remainingTimeInSeconds, 43);
    elapsed = const Duration(minutes: 5);
    provider.resumeTimer();
    expect(provider.remainingTimeInSeconds, 43);
    elapsed += const Duration(seconds: 3);
    provider.pauseTimer();
    expect(provider.remainingTimeInSeconds, 40);
  });
}
