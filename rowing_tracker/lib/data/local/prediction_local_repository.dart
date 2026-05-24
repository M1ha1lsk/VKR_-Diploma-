import 'app_database.dart';

class PredictionLocalRepository {
  PredictionLocalRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<Map<String, Object?>>> loadWorkoutsForWindow({
    required int userId,
    required DateTime fromInclusive,
  }) async {
    final db = await _database.database;
    return db.query(
      'workouts',
      where: 'user_id = ? AND date >= ?',
      whereArgs: [userId, fromInclusive.toIso8601String()],
      orderBy: 'date ASC, workout_id ASC',
    );
  }

  Future<List<Map<String, Object?>>> loadIntervalsForWorkouts(
    List<int> workoutIds,
  ) async {
    if (workoutIds.isEmpty) return const [];
    final db = await _database.database;
    final placeholders = List.filled(workoutIds.length, '?').join(',');
    return db.query(
      'intervals',
      where: 'workout_id IN ($placeholders)',
      whereArgs: workoutIds,
      orderBy: 'workout_id ASC, interval_id ASC',
    );
  }
}
