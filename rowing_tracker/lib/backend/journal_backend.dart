import '../models/training_models.dart';

class JournalIntervalRow {
  const JournalIntervalRow({
    required this.index,
    required this.entry,
  });

  final int index;
  final IntervalEntry entry;
}

class JournalIntervalBlock {
  const JournalIntervalBlock({
    required this.rows,
    required this.average,
    required this.restBeforeSec,
    required this.isGrouped,
    this.label,
  });

  final List<JournalIntervalRow> rows;
  final IntervalEntry average;
  final int? restBeforeSec;
  final bool isGrouped;
  final String? label;
}

class JournalBackendService {
  const JournalBackendService();

  bool workoutSectionHasData(WorkoutSectionType section, WorkoutRecord workout) {
    if (section == WorkoutSectionType.mainWork) return true;
    final data = workout.sections[section]!;
    return data.entries.any((e) => e.hasAnyValue);
  }

  String formatDuration(double? sec) {
    if (sec == null) return '—';
    final t = sec;
    final h = (t / 3600).floor();
    var rem = t - h * 3600.0;
    if (rem < 0 || rem.isNaN) rem = 0;
    final m = (rem / 60).floor();
    rem = rem - m * 60.0;
    final s = rem.floor();
    final tenth = ((rem - s) * 10).floor().clamp(0, 9);

    final comps = <int>[h, m, s, tenth];
    var start = 0;
    while (start < comps.length - 1 && comps[start] == 0) {
      start++;
    }
    final tail = comps.sublist(start);
    if (tail.length == 1) return '${tail[0]}';
    if (tail.length == 4) {
      return '${tail[0]}:${tail[1].toString().padLeft(2, '0')}:'
          '${tail[2].toString().padLeft(2, '0')}.${tail[3]}';
    }
    if (tail.length == 3) {
      return '${tail[0]}:${tail[1].toString().padLeft(2, '0')}.${tail[2]}';
    }
    return '${tail[0].toString().padLeft(2, '0')}.${tail[1]}';
  }

  int workoutTotalDistanceMeters(WorkoutRecord workout) {
    var sum = 0;
    for (final section in WorkoutSectionType.values) {
      final data = workout.sections[section];
      if (data == null) continue;
      for (final row in data.entries) {
        sum += row.distanceM ?? 0;
      }
    }
    return sum;
  }

  String intervalJournalSummary(List<IntervalEntry> entries) {
    const mul = '×';
    final n = entries.length;
    if (n == 0) return '';
    if (entries.any((x) => x.distanceM == null) || entries.any((x) => x.timeSec == null)) {
      return 'разные интервалы';
    }
    final d0 = entries.first.distanceM!;
    final t0 = entries.first.timeSec!;
    final sameD = entries.every((x) => x.distanceM == d0);
    final sameT = entries.every((x) => (x.timeSec! * 10).round() == (t0 * 10).round());
    if (!sameD && !sameT) return 'разные интервалы';

    int tenth(double t) => ((t * 10).round() % 10 + 10) % 10;
    final allTenth0 = sameT && entries.every((x) => tenth(x.timeSec!) == 0);
    final allTenth5 = sameT && entries.every((x) => tenth(x.timeSec!) == 5);
    final distEnds0 = sameD && (d0 % 10 == 0);

    if (distEnds0) return '$n$mul$d0м';
    if (allTenth0 || allTenth5) return '$n$mul${formatDuration(t0)}';
    return 'разные интервалы';
  }

  String journalCardLine2(WorkoutRecord workout) {
    final main = workout.sections[WorkoutSectionType.mainWork]!;
    final fatigue = ' · ${workout.mainWorkFatigue10}/10';
    if (main.entries.isEmpty) {
      return 'Усталость ${workout.mainWorkFatigue10}/10';
    }
    if (main.type == WorkoutInputType.interval) {
      return '${intervalJournalSummary(main.entries)}$fatigue';
    }
    final single = main.entries.first;
    final timeStr = formatDuration(single.timeSec);
    final distPart = single.distanceM != null ? ' · ${single.distanceM} м' : '';
    return '$timeStr$distPart$fatigue';
  }

  String formatRestMinSec(int? restSec) {
    if (restSec == null) return '—';
    final m = restSec ~/ 60;
    final s = restSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  int _tenth(double value) => ((value * 10).round() % 10 + 10) % 10;

  String? _blockKey(IntervalEntry e) {
    if (e.timeSec != null) {
      final t = _tenth(e.timeSec!);
      if (t == 0 || t == 5) {
        return 't:${(e.timeSec! * 10).round()}';
      }
    }
    if (e.distanceM != null && e.distanceM! % 10 == 0) {
      return 'd:${e.distanceM}';
    }
    return null;
  }

  double _avgDouble(List<double> values) {
    if (values.isEmpty) return double.nan;
    return values.reduce((a, b) => a + b) / values.length;
  }

  int _avgIntFloor(List<int> values) {
    if (values.isEmpty) return 0;
    final sum = values.reduce((a, b) => a + b);
    return (sum / values.length).floor();
  }

  IntervalEntry _blockAverage(List<IntervalEntry> entries) {
    final dVals = entries.where((e) => e.distanceM != null).map((e) => e.distanceM!).toList();
    final tVals = entries.where((e) => e.timeSec != null).map((e) => e.timeSec!).toList();
    final sVals = entries.where((e) => e.splitSec500 != null).map((e) => e.splitSec500!).toList();
    final wVals = entries.where((e) => e.watts != null).map((e) => e.watts!).toList();
    final hrVals = entries.where((e) => e.heartRate != null).map((e) => e.heartRate!).toList();
    final spmVals = entries.where((e) => e.strokeRate != null).map((e) => e.strokeRate!).toList();
    final restSource = entries.length > 1 ? entries.sublist(1) : <IntervalEntry>[];
    final rVals = restSource.where((e) => e.restSec != null).map((e) => e.restSec!).toList();
    final hasHrAll = entries.isNotEmpty && entries.every((e) => e.heartRate != null);
    final dSum = dVals.isEmpty ? null : dVals.reduce((a, b) => a + b);
    final tSum = tVals.isEmpty ? null : ((tVals.reduce((a, b) => a + b) * 10).floor() / 10.0);

    return IntervalEntry(
      distanceM: dSum,
      timeSec: tSum,
      splitSec500: sVals.isEmpty ? null : ((_avgDouble(sVals) * 10).floor() / 10.0),
      watts: wVals.isEmpty ? null : _avgIntFloor(wVals.map((e) => e.floor()).toList()).toDouble(),
      heartRate: hasHrAll ? (hrVals.isEmpty ? null : _avgIntFloor(hrVals)) : null,
      strokeRate: spmVals.isEmpty ? null : _avgIntFloor(spmVals),
      restSec: rVals.isEmpty ? null : _avgIntFloor(rVals),
    );
  }

  String? _blockLabel(String? key, int count) {
    if (key == null || count < 2) return null;
    if (key.startsWith('d:')) {
      final d = key.substring(2);
      return '$count×$dм';
    }
    if (key.startsWith('t:')) {
      final t10 = int.tryParse(key.substring(2));
      if (t10 != null) {
        return '$count×${formatDuration(t10 / 10.0)}';
      }
    }
    return null;
  }

  List<JournalIntervalBlock> buildIntervalBlocks(List<IntervalEntry> entries) {
    if (entries.isEmpty) return const [];
    final blocks = <JournalIntervalBlock>[];
    var start = 0;
    var currentKey = _blockKey(entries.first);

    void closeBlock(int endExclusive) {
      final blockEntries = entries.sublist(start, endExclusive);
      final rows = <JournalIntervalRow>[];
      for (int i = start; i < endExclusive; i++) {
        rows.add(JournalIntervalRow(index: i + 1, entry: entries[i]));
      }
      blocks.add(
        JournalIntervalBlock(
          rows: rows,
          average: _blockAverage(blockEntries),
          restBeforeSec: rows.isEmpty ? null : rows.first.entry.restSec,
          isGrouped: (currentKey != null && blockEntries.length >= 2),
          label: _blockLabel(currentKey, blockEntries.length),
        ),
      );
    }

    for (int i = 1; i < entries.length; i++) {
      final nextKey = _blockKey(entries[i]);
      if (nextKey != currentKey) {
        closeBlock(i);
        start = i;
        currentKey = nextKey;
      }
    }
    closeBlock(entries.length);
    return blocks;
  }

  IntervalEntry averageAllIntervals(List<IntervalEntry> entries) {
    return _blockAverage(entries);
  }
}
