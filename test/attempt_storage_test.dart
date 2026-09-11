import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mcq_quizzer/models/quiz.dart';
import 'package:mcq_quizzer/models/question.dart';
import 'package:mcq_quizzer/providers/quiz_provider.dart';
import 'package:mcq_quizzer/models/quiz_set.dart';
import 'package:mcq_quizzer/services/database_service.dart';

void main() {
  test(
    'resume by set ID loads the intended attempt instead of current provider state',
    () async {
      final store = DatabaseService(databasePath: inMemoryDatabasePath);
      addTearDown(store.close);
      final quiz = Quiz(
        title: 'Saved',
        questions: [
          Question(
            questionText: 'Saved question',
            options: ['A', 'B', 'C', 'D', 'E'],
            correctAnswer: 'A',
            type: QuestionType.bestOfFive,
          ),
        ],
      );
      final now = DateTime(2026, 9, 10);
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
      final provider = QuizProvider(database: store)
        ..startQuiz(quiz, quizSetId: id);
      addTearDown(provider.dispose);
      provider.updateAnswer(0, 0, true);
      expect(await provider.saveProgress(), true);
      provider.setQuiz(Quiz(title: 'Unrelated', questions: []));
      expect(await provider.resumeQuizSet(id), true);
      expect(provider.quiz!.title, 'Saved');
      expect(provider.quizSetId, id);
      expect(provider.isAnswered(0), true);
    },
  );
  test(
    'resume keeps position in the saved snapshot after source questions change',
    () async {
      final store = DatabaseService(databasePath: inMemoryDatabasePath);
      addTearDown(store.close);
      final quiz = Quiz(
        title: 'Original',
        questions: List.generate(
          3,
          (i) => Question(
            questionText: 'Question $i',
            options: ['A', 'B', 'C', 'D', 'E'],
            correctAnswer: 'A',
            type: QuestionType.bestOfFive,
          ),
        ),
      );
      final now = DateTime(2026, 9, 10);
      final id = await store.createQuizSet(
        QuizSet(
          title: quiz.title,
          description: '',
          quiz: quiz,
          createdAt: now,
          updatedAt: now,
          questionFilePath: '',
          answerKeyFilePath: '',
          totalQuestions: 3,
        ),
      );
      final original = QuizProvider(database: store)
        ..startQuiz(quiz, quizSetId: id);
      original.goToQuestion(2);
      original.updateAnswer(2, 0, true);
      expect(await original.saveProgress(), true);
      original.dispose();
      final resumed = QuizProvider(database: store);
      addTearDown(resumed.dispose);
      final editedSource = Quiz(
        title: 'Edited',
        questions: [quiz.questions.first],
      );
      expect(await resumed.loadProgress(id, editedSource), true);
      expect(resumed.totalQuestions, 3);
      expect(resumed.currentQuestionIndex, 2);
      expect(resumed.currentQuestion!.questionText, 'Question 2');
      expect(resumed.isAnswered(2), true);
    },
  );
  test(
    'starting an imported quiz does not retain a library set identity',
    () async {
      final provider = QuizProvider();
      addTearDown(provider.dispose);
      provider.startQuiz(Quiz(title: 'Library', questions: []), quizSetId: 42);
      provider.setQuiz(Quiz(title: 'Imported', questions: []));
      expect(provider.quizSetId, isNull);
      expect(await provider.saveProgress(), false);
    },
  );
  test(
    'repeated submission saves one immutable result and retires progress',
    () async {
      final store = DatabaseService(databasePath: inMemoryDatabasePath);
      addTearDown(store.close);
      final now = DateTime(2026, 9, 6);
      final quiz = Quiz(
        title: 'Attempt',
        questions: [
          Question(
            questionText: 'A?',
            options: ['A', 'B', 'C', 'D', 'E'],
            correctAnswer: 'A',
            type: QuestionType.bestOfFive,
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
      final provider = QuizProvider(database: store)
        ..startQuiz(quiz, quizSetId: id);
      addTearDown(provider.dispose);
      provider.updateAnswer(0, 0, true);
      expect(await provider.saveProgress(), true);
      expect(await provider.finalizeAttempt(), true);
      expect(await provider.finalizeAttempt(), true);
      provider.updateAnswer(0, 1, true);
      expect(provider.answers[0]![0], true);
      expect(await store.getSavedProgress(id), isNull);
      final history = await store.getQuizHistory(id);
      expect(history, hasLength(1));
      expect(history.single['score'], 1);
      expect(history.single['quiz_snapshot'], isNotNull);
    },
  );
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'version six history upgrades without rewriting its score or percentage',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'quiz-migration-',
      );
      final path = '${directory.path}/legacy.db';
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE saved_progress (id INTEGER PRIMARY KEY)',
            );
            await db.execute(
              'CREATE TABLE quiz_history (id INTEGER PRIMARY KEY, quiz_set_id INTEGER, score INTEGER, total_questions INTEGER, percentage REAL, completed_at TEXT)',
            );
            await db.insert('quiz_history', {
              'id': 1,
              'quiz_set_id': 1,
              'score': 8,
              'total_questions': 2,
              'percentage': 80.0,
              'completed_at': '2026-09-05',
            });
          },
        ),
      );
      await legacy.close();
      final store = DatabaseService(databasePath: path);
      try {
        final history = await store.getQuizHistory(1);
        expect(history.single['score'], 8);
        expect(history.single['percentage'], 80.0);
        expect(history.single['max_score'], 10);
        expect(history.single['scoring_version'], 1);
      } finally {
        await store.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('history retains the scoring version and actual maximum', () async {
    final store = DatabaseService(databasePath: inMemoryDatabasePath);
    addTearDown(store.close);
    final now = DateTime(2026, 9, 6);
    final id = await store.createQuizSet(
      QuizSet(
        title: 'Stored quiz',
        description: '',
        quiz: Quiz(title: 'Stored quiz', questions: []),
        createdAt: now,
        updatedAt: now,
        questionFilePath: '',
        answerKeyFilePath: '',
        totalQuestions: 2,
      ),
    );
    await store.saveQuizHistory(
      quizSetId: id,
      score: 1,
      totalQuestions: 2,
      percentage: 50,
      scoringMethod: 'straight',
      answers: {},
      maximumScore: 2,
      scoringVersion: 2,
    );
    final history = await store.getQuizHistory(id);
    expect(history.single['max_score'], 2);
    expect(history.single['scoring_version'], 2);
  });
}
