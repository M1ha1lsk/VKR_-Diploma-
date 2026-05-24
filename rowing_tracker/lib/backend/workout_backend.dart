import 'dart:math';

import '../models/training_models.dart';

class WorkoutBackendService {
  const WorkoutBackendService();

  List<IntervalEntry> sectionList(WorkoutDraft draft, WorkoutSectionType type) {
    switch (type) {
      case WorkoutSectionType.warmUp:
        return draft.warmUp;
      case WorkoutSectionType.mainWork:
        return draft.mainWork;
      case WorkoutSectionType.coolDown:
        return draft.coolDown;
    }
  }

  IntervalEntry newEntry(SplitInputUnit preferredSplitUnit) =>
      IntervalEntry(splitInputUnit: preferredSplitUnit);

  void normalizeSectionOnTypeChange(
    List<IntervalEntry> entries,
    WorkoutInputType type,
  ) {
    if (entries.isEmpty) return;
    if (type == WorkoutInputType.steady && entries.length > 1) {
      entries.removeRange(1, entries.length);
    }
    if (type == WorkoutInputType.interval) {
      entries.first.restSec = 0;
    }
  }

  double floorToTenth(double value) => (value * 10).floorToDouble() / 10.0;

  double splitFromWatts(double watts) {
    final split = 500 * pow(2.80 / watts, 1 / 3).toDouble();
    return floorToTenth(split);
  }

  double wattsFromSplit(double splitSec500) {
    final watts = 2.80 / pow(splitSec500 / 500.0, 3);
    return watts.floorToDouble();
  }

  double? tryParseDouble(String value) {
    final normalized = value.replaceAll(',', '.').trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  void setSplitFromInput(IntervalEntry entry, String raw) {
    final value = tryParseDouble(raw);
    entry.splitInputValue = value;
    if (value == null || value <= 0) {
      entry.splitSec500 = null;
      entry.watts = null;
      return;
    }
    if (entry.splitInputUnit == SplitInputUnit.watts) {
      entry.splitSec500 = splitFromWatts(value);
      entry.watts = value.floorToDouble();
    } else {
      entry.splitSec500 = floorToTenth(value);
      entry.watts = wattsFromSplit(entry.splitSec500!);
      entry.splitInputValue = entry.splitSec500;
    }
  }

  void recalculateDependentFields(IntervalEntry entry) {
    final distance = entry.distanceM?.toDouble();
    final time = entry.timeSec;
    final split = entry.splitSec500;

    final hasDistance = distance != null;
    final hasTime = time != null;
    final hasSplit = split != null;

    if (!hasTime && hasDistance && hasSplit) {
      entry.timeSec = floorToTenth((distance / 500.0) * split);
    } else if (!hasDistance && hasTime && hasSplit && split > 0) {
      entry.distanceM = ((time / split) * 500.0).floor();
    } else if (!hasSplit && hasDistance && hasTime && distance > 0) {
      entry.splitSec500 = floorToTenth(time / (distance / 500.0));
      entry.watts = wattsFromSplit(entry.splitSec500!);
      entry.splitInputValue = entry.splitInputUnit == SplitInputUnit.split
          ? entry.splitSec500
          : entry.watts;
    }
  }

  String? validateDraft({
    required WorkoutDraft draft,
    required Map<WorkoutSectionType, WorkoutInputType> sectionTypes,
  }) {
    if (draft.mainWorkFatigue10 == null) {
      return 'Выберите усталость после основной работы (0–10).';
    }
    for (final section in WorkoutSectionType.values) {
      final type = sectionTypes[section]!;
      final entries = sectionList(draft, section);
      for (int i = 0; i < entries.length; i++) {
        final e = entries[i];
        if (!e.hasAnyValue) {
          continue;
        }
        final trioCount =
            (e.timeSec != null ? 1 : 0) +
            (e.distanceM != null ? 1 : 0) +
            (e.splitSec500 != null ? 1 : 0);
        if (trioCount < 2) {
          return '${section.label}, запись ${i + 1}: '
              'укажите минимум 2 из 3 — время, дистанция, split.';
        }
        if (e.strokeRate == null) {
          return '${section.label}, запись ${i + 1}: '
              'поле "Темп (уд/мин)" обязательно.';
        }
        if (type == WorkoutInputType.interval) {
          if (i == 0) {
            e.restSec = 0;
          } else if (e.restSec == null) {
            return '${section.label}, интервал ${i + 1}: '
                'поле "Отдых (сек)" обязательно.';
          }
        }
      }
    }
    return null;
  }

  WorkoutRecord buildWorkoutRecord({
    required WorkoutDraft draft,
    required Map<WorkoutSectionType, WorkoutInputType> sectionTypes,
  }) {
    List<IntervalEntry> cleaned(List<IntervalEntry> entries) =>
        entries.where((entry) => entry.hasAnyValue).map((e) => e.copy()).toList();

    for (final section in WorkoutSectionType.values) {
      final entries = sectionList(draft, section);
      if (sectionTypes[section] == WorkoutInputType.interval && entries.isNotEmpty) {
        entries.first.restSec = 0;
      }
      for (final entry in entries) {
        recalculateDependentFields(entry);
      }
    }

    return WorkoutRecord(
      id: 0,
      dateTime: draft.dateTime,
      mainWorkFatigue10: draft.mainWorkFatigue10!.clamp(0, 10),
      sections: {
        for (final section in WorkoutSectionType.values)
          section: WorkoutSectionData(
            type: sectionTypes[section]!,
            entries: cleaned(sectionList(draft, section)),
          ),
      },
    );
  }
}
