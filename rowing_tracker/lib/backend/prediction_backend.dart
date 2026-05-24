import '../data/local/prediction_local_repository.dart';
import '../models/training_models.dart';
import 'health_backend.dart';
import 'ml_prediction_api_client.dart';

class PredictionBackendService {
  PredictionBackendService({
    PredictionLocalRepository? predictionRepo,
    MlPredictionApiClient? apiClient,
  })  : _predictionRepo = predictionRepo ?? PredictionLocalRepository(),
        _apiClient = apiClient ?? MlPredictionApiClient();

  final PredictionLocalRepository _predictionRepo;
  final MlPredictionApiClient _apiClient;

  String formatSeconds(double value) {
    final mins = value ~/ 60;
    final secs = (value % 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String formatDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year}';
  }

  Future<PredictionResult> calculatePrediction({
    required int maxHr,
    required String gender,
    required int periodDays,
    int userId = -1,
  }) {
    if (periodDays < 14 || periodDays > 90) {
      throw BackendRequestError('Период должен быть 14–90 дней.');
    }
    if (maxHr < 80 || maxHr > 240) {
      throw BackendRequestError('Максимальный пульс отсутствует или некорректен.');
    }
    final now = DateTime.now();
    final from = now.subtract(Duration(days: periodDays));

    return _predictFromServer(
      userId: userId,
      fromInclusive: from,
      raceDate: now,
      periodDays: periodDays,
      maxHr: maxHr,
      gender: gender,
    );
  }

  Future<PredictionResult> _predictFromServer({
    required int userId,
    required DateTime fromInclusive,
    required DateTime raceDate,
    required int periodDays,
    required int maxHr,
    required String gender,
  }) async {
    final workouts = await _predictionRepo.loadWorkoutsForWindow(
      userId: userId,
      fromInclusive: fromInclusive,
    );
    if (workouts.isEmpty) {
      throw BackendRequestError('Недостаточно данных: за выбранный период нет тренировок.');
    }
    final workoutIds = workouts
        .map((w) => w['workout_id'])
        .whereType<int>()
        .toList(growable: false);
    final intervals = await _predictionRepo.loadIntervalsForWorkouts(workoutIds);
    final payload = <String, dynamic>{
      'user_id': userId,
      'window_days': periodDays,
      'race_date': raceDate.toIso8601String(),
      'users': [
        {
          'user_id': userId,
          'max_heart_rate': maxHr,
          'gender': _toMlGender(gender),
        },
      ],
      'workouts': workouts.map(_mapWorkoutRowForMl).toList(),
      'intervals': intervals.map(_mapIntervalRowForMl).toList(),
    };
    final response = await _apiClient.predict(payload);
    final predicted = _readPredictedSeconds(response);
    return PredictionResult(
      createdAt: DateTime.now(),
      predicted2kSeconds: predicted,
      gender: gender,
    );
  }

  String _toMlGender(String appGender) {
    if (appGender == 'female') return 'f';
    return 'm';
  }

  Map<String, dynamic> _mapWorkoutRowForMl(Map<String, Object?> row) {
    return {
      'workout_id': row['workout_id'],
      'user_id': row['user_id'],
      'date': row['date'],
      'workout_type': row['workout_type'],
      'intervals_count': row['intervals_count'],
      'distance': row['distance'],
      'time': row['time'],
      'split_500': row['split_500'],
      'heart_rate': row['heart_rate'],
      'stroke_rate': row['stroke_rate'],
      'fatigue_score': row['fatigue_score'],
    };
  }

  Map<String, dynamic> _mapIntervalRowForMl(Map<String, Object?> row) {
    return {
      'workout_id': row['workout_id'],
      'interval_id': row['interval_id'],
      'distance': row['interval_distance'],
      'time': row['interval_time'],
      'split_500': row['interval_split_500'],
      'heart_rate': row['interval_heart_rate'],
      'stroke_rate': row['interval_stroke_rate'],
      'rest_before': row['rest_before'],
    };
  }

  double _readPredictedSeconds(Map<String, dynamic> response) {
    final raw = response['predicted_2k_sec'] ?? response['predicted2kSeconds'];
    if (raw is num) return raw.toDouble();
    throw BackendRequestError('ML сервис вернул ответ без predicted_2k_sec.');
  }
}
