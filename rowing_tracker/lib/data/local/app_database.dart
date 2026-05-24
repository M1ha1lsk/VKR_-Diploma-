import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<void> _addUserColumnIfMissing(Database db, String name, String sqlType) async {
    final columns = await db.rawQuery('PRAGMA table_info(user)');
    final exists = columns.any((c) => c['name'] == name);
    if (!exists) {
      await db.execute('ALTER TABLE user ADD COLUMN $name $sqlType DEFAULT NULL');
    }
  }

  Future<void> _ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user (
        user_id INTEGER PRIMARY KEY DEFAULT -1,
        login TEXT DEFAULT NULL,
        password TEXT DEFAULT NULL,
        max_hr INTEGER DEFAULT NULL,
        gender TEXT DEFAULT NULL,
        theme TEXT DEFAULT NULL,
        split_unit TEXT DEFAULT NULL,
        last_prediction_2k REAL DEFAULT NULL,
        last_prediction_2k_date TEXT DEFAULT NULL
      )
    ''');
    await _addUserColumnIfMissing(db, 'theme', 'TEXT');
    await _addUserColumnIfMissing(db, 'split_unit', 'TEXT');
    await _addUserColumnIfMissing(db, 'last_prediction_2k', 'REAL');
    await _addUserColumnIfMissing(db, 'last_prediction_2k_date', 'TEXT');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workouts (
        workout_id INTEGER PRIMARY KEY,
        user_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        workout_type INTEGER NOT NULL,
        intervals_count INTEGER NOT NULL,
        distance INTEGER DEFAULT NULL,
        time REAL DEFAULT NULL,
        split_500 REAL DEFAULT NULL,
        split_500_watt INTEGER DEFAULT NULL,
        heart_rate INTEGER DEFAULT NULL,
        stroke_rate INTEGER DEFAULT NULL,
        fatigue_score INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS intervals (
        workout_id INTEGER NOT NULL,
        interval_id INTEGER NOT NULL,
        interval_distance INTEGER DEFAULT NULL,
        interval_time REAL DEFAULT NULL,
        interval_split_500 REAL DEFAULT NULL,
        interval_split_500_watt INTEGER DEFAULT NULL,
        interval_heart_rate INTEGER DEFAULT NULL,
        interval_stroke_rate INTEGER DEFAULT NULL,
        rest_before INTEGER DEFAULT 0,
        PRIMARY KEY (workout_id, interval_id)
      )
    ''');
    await db.insert(
      'user',
      {
        'user_id': -1,
        'login': null,
        'password': null,
        'max_hr': null,
        'gender': null,
        'theme': null,
        'split_unit': null,
        'last_prediction_2k': null,
        'last_prediction_2k_date': null,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    final basePath = await getDatabasesPath();
    final dbPath = p.join(basePath, 'rowing_tracker.db');
    _db = await openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, version) async {
        await _ensureSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _ensureSchema(db);
      },
      onOpen: (db) async {
        await _ensureSchema(db);
      },
    );
    return _db!;
  }
}
