import '../../backend/workout_backend.dart';
import '../../models/training_models.dart';
import 'app_database.dart';

class WorkoutLocalRepository {
  WorkoutLocalRepository({
    AppDatabase? database,
    WorkoutBackendService? backend,
  })  : _database = database ?? AppDatabase.instance,
        _backend = backend ?? const WorkoutBackendService();

  final AppDatabase _database;
  final WorkoutBackendService _backend;

  int _floorInt(double value) => value.floor();

  double _avg(List<double> values) {
    if (values.isEmpty) return double.nan;
    final total = values.reduce((double a, double b) => a + b);
    return total / values.length;
  }

  int _nextWorkoutId(int userId, List<Map<String, Object?>> rows) {
    final prefix = '$userId';
    var maxN = 0;
    for (final r in rows) {
      final raw = r['workout_id'];
      if (raw is! int) continue;
      final text = raw.toString();
      if (!text.startsWith(prefix)) continue;
      final suffix = text.substring(prefix.length);
      final n = int.tryParse(suffix) ?? 0;
      if (n > maxN) maxN = n;
    }
    return int.parse('$userId${maxN + 1}');
  }

  List<IntervalEntry> _flattenEntries(WorkoutRecord workout) {
    final out = <IntervalEntry>[];
    for (final section in WorkoutSectionType.values) {
      final data = workout.sections[section];
      if (data == null) continue;
      for (int i = 0; i < data.entries.length; i++) {
        final e = data.entries[i].copy();
        _backend.recalculateDependentFields(e);
        if (data.type == WorkoutInputType.interval && i == 0) e.restSec = 0;
        e.timeSec = e.timeSec == null ? null : _backend.floorToTenth(e.timeSec!);
        e.splitSec500 =
            e.splitSec500 == null ? null : _backend.floorToTenth(e.splitSec500!);
        e.watts = e.watts?.floorToDouble();
        e.strokeRate = e.strokeRate?.floor();
        e.heartRate = e.heartRate?.floor();
        e.distanceM = e.distanceM?.floor();
        out.add(e);
      }
    }
    return out.where((e) => e.hasAnyValue).toList();
  }

  Future<int> insertWorkout({
    required WorkoutRecord workout,
    int userId = -1,
  }) async {
    final db = await _database.database;
    final userRows = await db.query(
      'workouts',
      columns: ['workout_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    final workoutId = _nextWorkoutId(userId, userRows);
    final entries = _flattenEntries(workout);
    final workoutType =
        entries.length > 1 || entries.any((e) => (e.restSec ?? 0) > 0) ? 1 : 0;

    final sumDist = entries.fold<int>(0, (s, e) => s + (e.distanceM ?? 0));
    final sumTime = entries.fold<double>(0, (s, e) => s + (e.timeSec ?? 0));
    final splitValues =
        entries.where((e) => e.splitSec500 != null).map((e) => e.splitSec500!).toList();
    final wattValues =
        entries.where((e) => e.watts != null).map((e) => e.watts!).toList();
    final hrPresentAll = entries.isNotEmpty && entries.every((e) => e.heartRate != null);
    final hrValues = entries
        .where((e) => e.heartRate != null)
        .map((e) => e.heartRate!.toDouble())
        .toList();
    final spmValues = entries
        .where((e) => e.strokeRate != null)
        .map((e) => e.strokeRate!.toDouble())
        .toList();

    final totalTime = entries.isEmpty ? null : _backend.floorToTenth(sumTime);
    final splitAvg = splitValues.isEmpty ? null : _backend.floorToTenth(_avg(splitValues));
    final wattAvg = wattValues.isEmpty ? null : _floorInt(_avg(wattValues));
    final hrAvg = hrPresentAll ? _floorInt(_avg(hrValues)) : null;
    final spmAvg = spmValues.isEmpty ? null : _floorInt(_avg(spmValues));

    await db.transaction((txn) async {
      await txn.insert('workouts', {
        'workout_id': workoutId,
        'user_id': userId,
        'date': workout.dateTime.toIso8601String(),
        'workout_type': workoutType,
        'intervals_count': entries.length,
        'distance': entries.isEmpty ? null : sumDist,
        'time': totalTime,
        'split_500': splitAvg,
        'split_500_watt': wattAvg,
        'heart_rate': hrAvg,
        'stroke_rate': spmAvg,
        'fatigue_score': workout.mainWorkFatigue10,
      });

      for (int i = 0; i < entries.length; i++) {
        final e = entries[i];
        await txn.insert('intervals', {
          'workout_id': workoutId,
          'interval_id': i + 1,
          'interval_distance': e.distanceM,
          'interval_time': e.timeSec,
          'interval_split_500': e.splitSec500,
          'interval_split_500_watt': e.watts?.floor(),
          'interval_heart_rate': e.heartRate,
          'interval_stroke_rate': e.strokeRate,
          'rest_before': e.restSec ?? 0,
        });
      }
    });
    return workoutId;
  }

  Future<List<WorkoutRecord>> loadWorkouts({int userId = -1}) async {
    final db = await _database.database;
    final workouts = await db.query(
      'workouts',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC, workout_id DESC',
    );
    final result = <WorkoutRecord>[];
    for (final w in workouts) {
      final id = w['workout_id'] as int;
      final intervals = await db.query(
        'intervals',
        where: 'workout_id = ?',
        whereArgs: [id],
        orderBy: 'interval_id ASC',
      );
      final entries = intervals.map((r) {
        return IntervalEntry(
          distanceM: r['interval_distance'] as int?,
          timeSec: (r['interval_time'] as num?)?.toDouble(),
          splitSec500: (r['interval_split_500'] as num?)?.toDouble(),
          watts: (r['interval_split_500_watt'] as num?)?.toDouble(),
          heartRate: r['interval_heart_rate'] as int?,
          strokeRate: r['interval_stroke_rate'] as int?,
          restSec: r['rest_before'] as int?,
          splitInputUnit: SplitInputUnit.split,
          splitInputValue: (r['interval_split_500'] as num?)?.toDouble(),
        );
      }).toList();

      final type = (w['workout_type'] as int) == 1
          ? WorkoutInputType.interval
          : WorkoutInputType.steady;
      result.add(
        WorkoutRecord(
          id: id,
          dateTime: DateTime.parse(w['date'] as String),
          mainWorkFatigue10: (w['fatigue_score'] as int?) ?? 0,
          sections: {
            WorkoutSectionType.warmUp: const WorkoutSectionData(
              type: WorkoutInputType.steady,
              entries: [],
            ),
            WorkoutSectionType.mainWork: WorkoutSectionData(
              type: type,
              entries: entries,
            ),
            WorkoutSectionType.coolDown: const WorkoutSectionData(
              type: WorkoutInputType.steady,
              entries: [],
            ),
          },
        ),
      );
    }
    return result;
  }
}
