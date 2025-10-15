import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/quiz_set.dart';
import '../models/quiz.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mcq_quizzer.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add saved_progress table for incomplete quizzes
      await db.execute('''
        CREATE TABLE saved_progress (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          quiz_set_id INTEGER NOT NULL,
          current_question_index INTEGER NOT NULL,
          answers_json TEXT NOT NULL,
          timer_remaining INTEGER,
          timer_mode TEXT,
          scoring_method TEXT NOT NULL,
          saved_at TEXT NOT NULL,
          FOREIGN KEY (quiz_set_id) REFERENCES quiz_sets (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 3) {
      // Add notes table for question/branch notes
      await db.execute('''
        CREATE TABLE notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          quiz_set_id INTEGER NOT NULL,
          question_index INTEGER NOT NULL,
          branch_index INTEGER,
          note_text TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (quiz_set_id) REFERENCES quiz_sets (id) ON DELETE CASCADE
        )
      ''');
      
      await db.execute('''
        CREATE INDEX idx_notes_quiz_question ON notes(quiz_set_id, question_index)
      ''');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE quiz_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        quiz_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        question_file_path TEXT NOT NULL,
        answer_key_file_path TEXT NOT NULL,
        total_questions INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE quiz_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quiz_set_id INTEGER NOT NULL,
        score INTEGER NOT NULL,
        total_questions INTEGER NOT NULL,
        percentage REAL NOT NULL,
        scoring_method TEXT NOT NULL,
        answers_json TEXT NOT NULL,
        completed_at TEXT NOT NULL,
        time_taken INTEGER,
        FOREIGN KEY (quiz_set_id) REFERENCES quiz_sets (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_quiz_set_created ON quiz_sets(created_at DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_history_quiz_set ON quiz_history(quiz_set_id)
    ''');

    // Create saved_progress table
    await db.execute('''
      CREATE TABLE saved_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quiz_set_id INTEGER NOT NULL,
        current_question_index INTEGER NOT NULL,
        answers_json TEXT NOT NULL,
        timer_remaining INTEGER,
        timer_mode TEXT,
        scoring_method TEXT NOT NULL,
        saved_at TEXT NOT NULL,
        FOREIGN KEY (quiz_set_id) REFERENCES quiz_sets (id) ON DELETE CASCADE
      )
    ''');

    // Create notes table
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quiz_set_id INTEGER NOT NULL,
        question_index INTEGER NOT NULL,
        branch_index INTEGER,
        note_text TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (quiz_set_id) REFERENCES quiz_sets (id) ON DELETE CASCADE
      )
    ''');
    
    await db.execute('''
      CREATE INDEX idx_notes_quiz_question ON notes(quiz_set_id, question_index)
    ''');
  }

  // CRUD operations for QuizSet

  Future<int> createQuizSet(QuizSet quizSet) async {
    final db = await database;
    
    final data = {
      'title': quizSet.title,
      'description': quizSet.description,
      'quiz_json': jsonEncode(quizSet.quiz.toJson()),
      'created_at': quizSet.createdAt.toIso8601String(),
      'updated_at': quizSet.updatedAt.toIso8601String(),
      'question_file_path': quizSet.questionFilePath,
      'answer_key_file_path': quizSet.answerKeyFilePath,
      'total_questions': quizSet.totalQuestions,
    };

    return await db.insert('quiz_sets', data);
  }

  Future<QuizSet?> getQuizSet(int id) async {
    final db = await database;
    final maps = await db.query(
      'quiz_sets',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return _quizSetFromMap(maps.first);
    }
    return null;
  }

  Future<List<QuizSet>> getAllQuizSets() async {
    final db = await database;
    final maps = await db.query(
      'quiz_sets',
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => _quizSetFromMap(map)).toList();
  }

  Future<int> updateQuizSet(QuizSet quizSet) async {
    final db = await database;
    
    final data = {
      'title': quizSet.title,
      'description': quizSet.description,
      'quiz_json': jsonEncode(quizSet.quiz.toJson()),
      'updated_at': DateTime.now().toIso8601String(),
      'question_file_path': quizSet.questionFilePath,
      'answer_key_file_path': quizSet.answerKeyFilePath,
      'total_questions': quizSet.totalQuestions,
    };

    return await db.update(
      'quiz_sets',
      data,
      where: 'id = ?',
      whereArgs: [quizSet.id],
    );
  }

  Future<int> deleteQuizSet(int id) async {
    final db = await database;
    return await db.delete(
      'quiz_sets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> renameQuizSet(int id, String newTitle) async {
    final db = await database;
    return await db.update(
      'quiz_sets',
      {
        'title': newTitle,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Helper method to convert database map to QuizSet
  QuizSet _quizSetFromMap(Map<String, dynamic> map) {
    return QuizSet(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      quiz: Quiz.fromJson(jsonDecode(map['quiz_json'])),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      questionFilePath: map['question_file_path'],
      answerKeyFilePath: map['answer_key_file_path'],
      totalQuestions: map['total_questions'],
    );
  }

  // Quiz History operations

  Future<int> saveQuizHistory({
    required int quizSetId,
    required int score,
    required int totalQuestions,
    required double percentage,
    required String scoringMethod,
    required Map<int, List<bool?>> answers,
    int? timeTaken,
  }) async {
    final db = await database;
    
    final data = {
      'quiz_set_id': quizSetId,
      'score': score,
      'total_questions': totalQuestions,
      'percentage': percentage,
      'scoring_method': scoringMethod,
      'answers_json': jsonEncode(answers.map((key, value) => MapEntry(key.toString(), value))),
      'completed_at': DateTime.now().toIso8601String(),
      'time_taken': timeTaken,
    };

    return await db.insert('quiz_history', data);
  }

  Future<List<Map<String, dynamic>>> getQuizHistory(int quizSetId) async {
    final db = await database;
    return await db.query(
      'quiz_history',
      where: 'quiz_set_id = ?',
      whereArgs: [quizSetId],
      orderBy: 'completed_at DESC',
    );
  }

  // Saved Progress operations

  Future<int> saveQuizProgress({
    required int quizSetId,
    required int currentQuestionIndex,
    required Map<int, List<bool?>> answers,
    int? timerRemaining,
    String? timerMode,
    required String scoringMethod,
  }) async {
    final db = await database;
    
    // Delete any existing saved progress for this quiz set
    await db.delete(
      'saved_progress',
      where: 'quiz_set_id = ?',
      whereArgs: [quizSetId],
    );
    
    final data = {
      'quiz_set_id': quizSetId,
      'current_question_index': currentQuestionIndex,
      'answers_json': jsonEncode(answers.map((key, value) => MapEntry(key.toString(), value))),
      'timer_remaining': timerRemaining,
      'timer_mode': timerMode,
      'scoring_method': scoringMethod,
      'saved_at': DateTime.now().toIso8601String(),
    };

    return await db.insert('saved_progress', data);
  }

  Future<Map<String, dynamic>?> getSavedProgress(int quizSetId) async {
    final db = await database;
    final results = await db.query(
      'saved_progress',
      where: 'quiz_set_id = ?',
      whereArgs: [quizSetId],
    );
    
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<void> deleteSavedProgress(int quizSetId) async {
    final db = await database;
    await db.delete(
      'saved_progress',
      where: 'quiz_set_id = ?',
      whereArgs: [quizSetId],
    );
  }

  // Notes operations

  Future<int> saveNote({
    required int quizSetId,
    required int questionIndex,
    int? branchIndex,
    required String noteText,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    // Check if note already exists
    final existing = await db.query(
      'notes',
      where: branchIndex != null 
          ? 'quiz_set_id = ? AND question_index = ? AND branch_index = ?'
          : 'quiz_set_id = ? AND question_index = ? AND branch_index IS NULL',
      whereArgs: branchIndex != null 
          ? [quizSetId, questionIndex, branchIndex]
          : [quizSetId, questionIndex],
    );
    
    if (existing.isNotEmpty) {
      // Update existing note
      return await db.update(
        'notes',
        {
          'note_text': noteText,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      // Insert new note
      final data = {
        'quiz_set_id': quizSetId,
        'question_index': questionIndex,
        'branch_index': branchIndex,
        'note_text': noteText,
        'created_at': now,
        'updated_at': now,
      };
      return await db.insert('notes', data);
    }
  }

  Future<String?> getNote({
    required int quizSetId,
    required int questionIndex,
    int? branchIndex,
  }) async {
    final db = await database;
    final results = await db.query(
      'notes',
      where: branchIndex != null 
          ? 'quiz_set_id = ? AND question_index = ? AND branch_index = ?'
          : 'quiz_set_id = ? AND question_index = ? AND branch_index IS NULL',
      whereArgs: branchIndex != null 
          ? [quizSetId, questionIndex, branchIndex]
          : [quizSetId, questionIndex],
    );
    
    if (results.isNotEmpty) {
      return results.first['note_text'] as String;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getNotesForQuestion({
    required int quizSetId,
    required int questionIndex,
  }) async {
    final db = await database;
    return await db.query(
      'notes',
      where: 'quiz_set_id = ? AND question_index = ?',
      whereArgs: [quizSetId, questionIndex],
    );
  }

  Future<void> deleteNote({
    required int quizSetId,
    required int questionIndex,
    int? branchIndex,
  }) async {
    final db = await database;
    await db.delete(
      'notes',
      where: branchIndex != null 
          ? 'quiz_set_id = ? AND question_index = ? AND branch_index = ?'
          : 'quiz_set_id = ? AND question_index = ? AND branch_index IS NULL',
      whereArgs: branchIndex != null 
          ? [quizSetId, questionIndex, branchIndex]
          : [quizSetId, questionIndex],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
