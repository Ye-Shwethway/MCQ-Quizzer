import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/quiz_set.dart';
import '../models/quiz.dart';
import '../models/ai_provider_profile.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService();
  Database? _database;
  Future<Database>? _opening;
  final String? _databasePath;

  DatabaseService({String? databasePath}) : _databasePath = databasePath;

  Future<Database> get database async {
    if (_database != null) return _database!;
    try {
      _opening ??= _initDB('mcq_quizzer.db');
      _database = await _opening!;
      return _database!;
    } finally {
      _opening = null;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final path = _databasePath ?? join(await getDatabasesPath(), filePath);

    return await openDatabase(
      path,
      version: 9,
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
    if (oldVersion < 4) {
      // Add source tracking columns for AI-generated vs uploaded quiz sets
      await db.execute('''
        ALTER TABLE quiz_sets ADD COLUMN source TEXT DEFAULT 'uploaded'
      ''');

      await db.execute('''
        ALTER TABLE quiz_sets ADD COLUMN ai_provider TEXT
      ''');

      await db.execute('''
        ALTER TABLE quiz_sets ADD COLUMN ai_model TEXT
      ''');
    }
    if (oldVersion < 5) {
      // Add quiz_type column to track question type
      await db.execute('''
        ALTER TABLE quiz_sets ADD COLUMN quiz_type TEXT
      ''');
    }
    if (oldVersion < 6) {
      await _createAiSettingsTables(db);
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE quiz_history ADD COLUMN max_score INTEGER');
      await db.execute(
        'ALTER TABLE quiz_history ADD COLUMN scoring_version INTEGER NOT NULL DEFAULT 1',
      );
      // Historical versions awarded up to five branch points per question.
      // Preserve their stored scores/percentages, without applying new rules.
      await db.execute(
        'UPDATE quiz_history SET max_score = total_questions * 5',
      );
    }
    if (oldVersion < 8) {
      await db.execute(
        'ALTER TABLE saved_progress ADD COLUMN timer_state TEXT',
      );
    }
    if (oldVersion < 9) await _addAttemptColumns(db);
  }

  Future<void> _addAttemptColumns(Database db) async {
    for (final table in ['quiz_history', 'saved_progress']) {
      await db.execute('ALTER TABLE $table ADD COLUMN attempt_id TEXT');
      await db.execute('ALTER TABLE $table ADD COLUMN quiz_snapshot TEXT');
    }
    await db.execute(
      'CREATE UNIQUE INDEX idx_history_attempt ON quiz_history(attempt_id)',
    );
  }

  Future<void> _createAiSettingsTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_provider_profiles (
        id TEXT PRIMARY KEY,
        profile_json TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_ai_profiles_active
      ON ai_provider_profiles(is_active)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_model_catalogs (
        profile_id TEXT NOT NULL,
        scope TEXT NOT NULL,
        models_json TEXT NOT NULL,
        fetched_at TEXT NOT NULL,
        PRIMARY KEY (profile_id, scope),
        FOREIGN KEY (profile_id) REFERENCES ai_provider_profiles (id)
          ON DELETE CASCADE
      )
    ''');
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
        total_questions INTEGER NOT NULL,
        source TEXT DEFAULT 'uploaded',
        ai_provider TEXT,
        ai_model TEXT,
        quiz_type TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE quiz_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quiz_set_id INTEGER NOT NULL,
        score INTEGER NOT NULL,
        max_score INTEGER,
        scoring_version INTEGER NOT NULL DEFAULT 1,
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
        timer_state TEXT,
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

    await _createAiSettingsTables(db);
    await _addAttemptColumns(db);
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
      'source': quizSet.source ?? 'uploaded',
      'ai_provider': quizSet.aiProvider,
      'ai_model': quizSet.aiModel,
      'quiz_type': quizSet.quizType,
    };

    return await db.insert('quiz_sets', data);
  }

  Future<QuizSet?> getQuizSet(int id) async {
    final db = await database;
    final maps = await db.query('quiz_sets', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return _quizSetFromMap(maps.first);
    }
    return null;
  }

  Future<List<QuizSet>> getAllQuizSets() async {
    final db = await database;
    final maps = await db.query('quiz_sets', orderBy: 'created_at DESC');

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
      'source': quizSet.source,
      'ai_provider': quizSet.aiProvider,
      'ai_model': quizSet.aiModel,
      'quiz_type': quizSet.quizType,
    };

    return await db.update(
      'quiz_sets',
      data,
      where: 'id = ?',
      whereArgs: [quizSet.id],
    );
  }

  /// Removes a set from the active Library without destroying completed history.
  ///
  /// Archived sets remain in `quiz_sets` so the Dashboard can still resolve the
  /// original title and completed attempts. Incomplete progress is retired,
  /// because an archived set is no longer resumable from the Library.
  Future<int> deleteQuizSet(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'quiz_sets',
        columns: ['source'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return 0;

      final currentSource = rows.first['source'] as String? ?? 'uploaded';
      if (currentSource.startsWith('archived_')) return 0;

      final archivedSource = currentSource == 'ai_generated'
          ? 'archived_ai_generated'
          : 'archived_uploaded';
      final updated = await txn.update(
        'quiz_sets',
        {
          'source': archivedSource,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      await txn.delete(
        'saved_progress',
        where: 'quiz_set_id = ?',
        whereArgs: [id],
      );
      return updated;
    });
  }

  /// Irreversible low-level delete retained for a future explicit
  /// "delete set + history" action. The normal Library flow must not call this.
  Future<int> permanentlyDeleteQuizSet(int id) async {
    final db = await database;
    return await db.delete('quiz_sets', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> renameQuizSet(int id, String newTitle) async {
    final db = await database;
    return await db.update(
      'quiz_sets',
      {'title': newTitle, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateQuizSetMetadata(
    int id, {
    String? title,
    String? quizType,
  }) async {
    final db = await database;
    final data = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (title != null) {
      data['title'] = title;
    }

    if (quizType != null) {
      data['quiz_type'] = quizType;
    }

    return await db.update('quiz_sets', data, where: 'id = ?', whereArgs: [id]);
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
      source: map['source'] as String? ?? 'uploaded',
      aiProvider: map['ai_provider'] as String?,
      aiModel: map['ai_model'] as String?,
      quizType: map['quiz_type'] as String?,
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
    int? maximumScore,
    int scoringVersion = 1,
    String? attemptId,
    Quiz? quizSnapshot,
    bool retireProgress = false,
  }) async {
    final db = await database;

    final data = {
      'quiz_set_id': quizSetId,
      'score': score,
      'max_score': maximumScore ?? totalQuestions * 5,
      'scoring_version': scoringVersion,
      'attempt_id': attemptId,
      'quiz_snapshot': quizSnapshot == null
          ? null
          : jsonEncode(quizSnapshot.toJson()),
      'total_questions': totalQuestions,
      'percentage': percentage,
      'scoring_method': scoringMethod,
      'answers_json': jsonEncode(
        answers.map((key, value) => MapEntry(key.toString(), value)),
      ),
      'completed_at': DateTime.now().toIso8601String(),
      'time_taken': timeTaken,
    };

    return db.transaction((txn) async {
      final existing = attemptId == null
          ? const <Map<String, Object?>>[]
          : await txn.query(
              'quiz_history',
              where: 'attempt_id = ?',
              whereArgs: [attemptId],
              limit: 1,
            );
      final id = existing.isEmpty
          ? await txn.insert('quiz_history', data)
          : existing.single['id'] as int;
      if (retireProgress && attemptId != null) {
        await txn.delete(
          'saved_progress',
          where: 'quiz_set_id = ? AND (attempt_id = ? OR attempt_id IS NULL)',
          whereArgs: [quizSetId, attemptId],
        );
      }
      return id;
    });
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
    Map<String, dynamic>? timerState,
    String? attemptId,
    Quiz? quizSnapshot,
    required String scoringMethod,
  }) async {
    final db = await database;

    final data = {
      'quiz_set_id': quizSetId,
      'current_question_index': currentQuestionIndex,
      'answers_json': jsonEncode(
        answers.map((key, value) => MapEntry(key.toString(), value)),
      ),
      'timer_remaining': timerRemaining,
      'timer_mode': timerMode,
      'timer_state': timerState == null ? null : jsonEncode(timerState),
      'attempt_id': attemptId,
      'quiz_snapshot': quizSnapshot == null
          ? null
          : jsonEncode(quizSnapshot.toJson()),
      'scoring_method': scoringMethod,
      'saved_at': DateTime.now().toIso8601String(),
    };

    return db.transaction((txn) async {
      final setRows = await txn.query(
        'quiz_sets',
        columns: ['source'],
        where: 'id = ?',
        whereArgs: [quizSetId],
        limit: 1,
      );
      if (setRows.isEmpty) return 0;
      final source = setRows.first['source'] as String? ?? 'uploaded';
      if (source.startsWith('archived_')) return 0;

      // A delayed autosave must not resurrect a completed attempt.
      if (attemptId != null) {
        final completed = await txn.query(
          'quiz_history',
          columns: ['id'],
          where: 'attempt_id = ?',
          whereArgs: [attemptId],
          limit: 1,
        );
        if (completed.isNotEmpty) return 0;
      }
      await txn.delete(
        'saved_progress',
        where: 'quiz_set_id = ?',
        whereArgs: [quizSetId],
      );
      return txn.insert('saved_progress', data);
    });
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
        {'note_text': noteText, 'updated_at': now},
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

  Future<List<Map<String, dynamic>>> getNotesForQuizSet(int quizSetId) async {
    final db = await database;
    return await db.query(
      'notes',
      where: 'quiz_set_id = ?',
      whereArgs: [quizSetId],
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

  Future<List<AiProviderProfile>> getAiProviderProfiles() async {
    final db = await database;
    final rows = await db.query(
      'ai_provider_profiles',
      orderBy: 'is_active DESC, updated_at DESC',
    );
    return rows.map((row) {
      final profile = AiProviderProfile.fromJson(
        Map<String, dynamic>.from(jsonDecode(row['profile_json'] as String)),
      );
      return profile.copyWith(isActive: (row['is_active'] as int) == 1);
    }).toList();
  }

  Future<AiProviderProfile?> getActiveAiProviderProfile() async {
    final db = await database;
    final rows = await db.query(
      'ai_provider_profiles',
      where: 'is_active = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final profile = AiProviderProfile.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(rows.first['profile_json'] as String),
      ),
    );
    return profile.copyWith(isActive: true);
  }

  Future<void> saveAiProviderProfile(AiProviderProfile profile) async {
    final db = await database;
    await db.transaction((txn) async {
      if (profile.isActive) {
        await txn.update('ai_provider_profiles', {'is_active': 0});
      }
      await txn.insert('ai_provider_profiles', {
        'id': profile.id,
        'profile_json': jsonEncode(profile.toJson()),
        'is_active': profile.isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> setActiveAiProviderProfile(String profileId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('ai_provider_profiles', {'is_active': 0});
      await txn.update(
        'ai_provider_profiles',
        {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [profileId],
      );
    });
  }

  Future<void> deleteAiProviderProfile(String profileId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'ai_model_catalogs',
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      await txn.delete(
        'ai_provider_profiles',
        where: 'id = ?',
        whereArgs: [profileId],
      );
    });
  }

  Future<void> saveAiModelCatalog(
    String profileId,
    AiCatalogScope scope,
    List<ProviderModel> models,
  ) async {
    final db = await database;
    await db.insert('ai_model_catalogs', {
      'profile_id': profileId,
      'scope': scope.name,
      'models_json': ProviderModel.encodeList(models),
      'fetched_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ProviderModel>> getAiModelCatalog(
    String profileId,
    AiCatalogScope scope,
  ) async {
    final db = await database;
    final rows = await db.query(
      'ai_model_catalogs',
      columns: ['models_json'],
      where: 'profile_id = ? AND scope = ?',
      whereArgs: [profileId, scope.name],
      limit: 1,
    );
    if (rows.isEmpty) return [];
    return ProviderModel.decodeList(rows.first['models_json'] as String);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
    _opening = null;
  }
}
