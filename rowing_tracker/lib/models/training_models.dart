class IntervalEntry {
  IntervalEntry({
    this.timeSec,
    this.distanceM,
    this.restSec,
    this.splitSec500,
    this.watts,
    this.splitInputValue,
    this.splitInputUnit = SplitInputUnit.split,
    this.strokeRate,
    this.heartRate,
  });

  double? timeSec;
  int? distanceM;
  int? restSec;
  double? splitSec500;
  double? watts;
  double? splitInputValue;
  SplitInputUnit splitInputUnit;
  int? strokeRate;
  int? heartRate;

  bool get hasAnyValue =>
      timeSec != null ||
      distanceM != null ||
      restSec != null ||
      splitSec500 != null ||
      watts != null ||
      splitInputValue != null ||
      strokeRate != null ||
      heartRate != null;

  IntervalEntry copy() => IntervalEntry(
        timeSec: timeSec,
        distanceM: distanceM,
        restSec: restSec,
        splitSec500: splitSec500,
        watts: watts,
        splitInputValue: splitInputValue,
        splitInputUnit: splitInputUnit,
        strokeRate: strokeRate,
        heartRate: heartRate,
      );
}

enum WorkoutInputType { interval, steady }
enum SplitInputUnit { split, watts }

enum WorkoutSectionType { warmUp, mainWork, coolDown }

extension WorkoutSectionTypeLabel on WorkoutSectionType {
  String get label {
    switch (this) {
      case WorkoutSectionType.warmUp:
        return 'Разминка';
      case WorkoutSectionType.mainWork:
        return 'Основная работа';
      case WorkoutSectionType.coolDown:
        return 'Закатка';
    }
  }
}

class WorkoutDraft {
  WorkoutDraft({
    required this.dateTime,
    List<IntervalEntry>? warmUp,
    List<IntervalEntry>? mainWork,
    List<IntervalEntry>? coolDown,
    this.mainWorkFatigue10,
  })  : warmUp = warmUp ?? [],
        mainWork = mainWork ?? [IntervalEntry()],
        coolDown = coolDown ?? [];

  DateTime dateTime;
  final List<IntervalEntry> warmUp;
  final List<IntervalEntry> mainWork;
  final List<IntervalEntry> coolDown;

  // Усталость после основной работы, 0-10.
  int? mainWorkFatigue10;
}

class WorkoutSectionData {
  const WorkoutSectionData({
    required this.type,
    required this.entries,
  });

  final WorkoutInputType type;
  final List<IntervalEntry> entries;
}

class WorkoutRecord {
  const WorkoutRecord({
    required this.id,
    required this.dateTime,
    required this.sections,
    this.mainWorkFatigue10 = 5,
  });

  final int id;
  final DateTime dateTime;
  final Map<WorkoutSectionType, WorkoutSectionData> sections;

  // Усталость после основной работы, 0-10.
  final int mainWorkFatigue10;

  WorkoutRecord copyWith({
    int? id,
    DateTime? dateTime,
    Map<WorkoutSectionType, WorkoutSectionData>? sections,
    int? mainWorkFatigue10,
  }) {
    return WorkoutRecord(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      sections: sections ?? this.sections,
      mainWorkFatigue10: mainWorkFatigue10 ?? this.mainWorkFatigue10,
    );
  }
}

class PredictionResult {
  const PredictionResult({
    required this.createdAt,
    required this.predicted2kSeconds,
    required this.gender,
  });

  final DateTime createdAt;
  final double predicted2kSeconds;
  final String gender;
}
