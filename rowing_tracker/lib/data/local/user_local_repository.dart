import '../../models/user_profile.dart';
import 'app_database.dart';

class UserLocalRepository {
  UserLocalRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  static const int defaultUserId = -1;

  Future<UserProfile> getCurrentUser() async {
    final db = await _database.database;
    final rows = await db.query(
      'user',
      where: 'user_id = ?',
      whereArgs: [defaultUserId],
      limit: 1,
    );
    if (rows.isEmpty) {
      await db.insert('user', {
        'user_id': defaultUserId,
        'login': null,
        'password': null,
        'max_hr': null,
        'gender': null,
        'theme': null,
        'split_unit': null,
        'last_prediction_2k': null,
        'last_prediction_2k_date': null,
      });
      return const UserProfile(userId: defaultUserId);
    }
    final row = rows.first;
    return UserProfile(
      userId: row['user_id'] as int? ?? defaultUserId,
      login: row['login'] as String?,
      passwordHash: row['password'] as String?,
      maxHr: row['max_hr'] as int?,
      gender: row['gender'] as String?,
      theme: row['theme'] as String?,
      splitUnit: row['split_unit'] as String?,
      lastPrediction2k: (row['last_prediction_2k'] as num?)?.toDouble(),
      lastPrediction2kDate: row['last_prediction_2k_date'] == null
          ? null
          : DateTime.tryParse(row['last_prediction_2k_date'] as String),
    );
  }

  Future<void> updateGender(String? gender) async {
    final db = await _database.database;
    final updated = await db.update(
      'user',
      {'gender': gender},
      where: 'user_id = ?',
      whereArgs: [defaultUserId],
    );
    if (updated == 0) {
      await db.insert('user', {
        'user_id': defaultUserId,
        'login': null,
        'password': null,
        'max_hr': null,
        'gender': gender,
        'theme': null,
        'split_unit': null,
        'last_prediction_2k': null,
        'last_prediction_2k_date': null,
      });
    }
  }

  Future<void> updateMaxHr(int? maxHr) async {
    final db = await _database.database;
    final updated = await db.update(
      'user',
      {'max_hr': maxHr},
      where: 'user_id = ?',
      whereArgs: [defaultUserId],
    );
    if (updated == 0) {
      await db.insert('user', {
        'user_id': defaultUserId,
        'login': null,
        'password': null,
        'max_hr': maxHr,
        'gender': null,
        'theme': null,
        'split_unit': null,
        'last_prediction_2k': null,
        'last_prediction_2k_date': null,
      });
    }
  }

  Future<void> updateTheme(String? theme) async {
    final db = await _database.database;
    final updated = await db.update(
      'user',
      {'theme': theme},
      where: 'user_id = ?',
      whereArgs: [defaultUserId],
    );
    if (updated == 0) {
      await db.insert('user', {
        'user_id': defaultUserId,
        'login': null,
        'password': null,
        'max_hr': null,
        'gender': null,
        'theme': theme,
        'split_unit': null,
        'last_prediction_2k': null,
        'last_prediction_2k_date': null,
      });
    }
  }

  Future<void> updateSplitUnit(String? splitUnit) async {
    final db = await _database.database;
    final updated = await db.update(
      'user',
      {'split_unit': splitUnit},
      where: 'user_id = ?',
      whereArgs: [defaultUserId],
    );
    if (updated == 0) {
      await db.insert('user', {
        'user_id': defaultUserId,
        'login': null,
        'password': null,
        'max_hr': null,
        'gender': null,
        'theme': null,
        'split_unit': splitUnit,
        'last_prediction_2k': null,
        'last_prediction_2k_date': null,
      });
    }
  }

  Future<void> updateLastPrediction({
    required double? seconds,
    required DateTime? date,
  }) async {
    final db = await _database.database;
    final updated = await db.update(
      'user',
      {
        'last_prediction_2k': seconds,
        'last_prediction_2k_date': date?.toIso8601String(),
      },
      where: 'user_id = ?',
      whereArgs: [defaultUserId],
    );
    if (updated == 0) {
      await db.insert('user', {
        'user_id': defaultUserId,
        'login': null,
        'password': null,
        'max_hr': null,
        'gender': null,
        'theme': null,
        'split_unit': null,
        'last_prediction_2k': seconds,
        'last_prediction_2k_date': date?.toIso8601String(),
      });
    }
  }
}
