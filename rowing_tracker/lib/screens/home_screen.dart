import 'package:flutter/material.dart';

import '../backend/health_backend.dart';
import '../backend/journal_backend.dart';
import '../data/local/workout_local_repository.dart';
import '../models/training_models.dart';
import '../theme/app_theme.dart';
import 'add_workout_screen.dart';
import 'prediction_screen.dart';



class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
    required this.preferredSplitUnit,
    required this.onPreferredSplitUnitChanged,
    required this.selectedGender,
    required this.onGenderChanged,
    required this.hasPrediction,
    required this.lastPrediction,
    required this.onPredictionCreated,
    required this.maxHr,
    required this.onMaxHrChanged,
  });

  final AppThemeVariant currentTheme;
  final ValueChanged<AppThemeVariant> onThemeChanged;
  final SplitInputUnit preferredSplitUnit;
  final ValueChanged<SplitInputUnit> onPreferredSplitUnitChanged;
  final String? selectedGender;
  final ValueChanged<String> onGenderChanged;
  final bool hasPrediction;
  final PredictionResult? lastPrediction;
  final ValueChanged<PredictionResult> onPredictionCreated;
  final int? maxHr;
  final ValueChanged<int?> onMaxHrChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _journal = JournalBackendService();
  static const _health = HealthBackendService();
  final WorkoutLocalRepository _workoutRepo = WorkoutLocalRepository();
  int _tabIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  List<WorkoutRecord> _workouts = [];

  @override
  void initState() {
    super.initState();
    _loadWorkoutsFromDb();
  }

  Future<void> _loadWorkoutsFromDb() async {
    final loaded = await _workoutRepo.loadWorkouts(userId: -1);
    if (!mounted) return;
    if (loaded.isEmpty) return;
    setState(() {
      _workouts = loaded;
      _sortWorkouts();
    });
  }

  Future<void> _openSettingsDrawer() async {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Future<void> _onGenderChangedFromSettings(String gender) async {
    final isFirstPick = widget.selectedGender == null;
    if (isFirstPick) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Важный выбор'),
            content: const Text(
              'Выбор гендера влияет на расчеты по WR-кривой и точность прогноза. Подтвердить?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Подтвердить'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    } else if (widget.selectedGender != gender) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Смена гендера'),
            content: const Text(
              'Смена гендера после первых прогнозов может ухудшить корректность результатов. Продолжить?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Изменить'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    }
    widget.onGenderChanged(gender);
  }

  Future<bool> _onGenderChangedFromPrediction(String gender) async {
    if (widget.selectedGender == null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Подтвердить гендер'),
            content: const Text(
              'Это важный параметр для расчета прогноза. Проверь выбор перед подтверждением.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Подтвердить'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return false;
    }
    widget.onGenderChanged(gender);
    return true;
  }

  Future<int?> _askAge(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Введите возраст'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Возраст',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(int.tryParse(controller.text.trim()));
              },
              child: const Text('ОК'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _setMaxHrManual() async {
    final controller = TextEditingController(
      text: widget.maxHr == null ? '' : widget.maxHr.toString(),
    );
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Максимальный пульс'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Укажите максимальный пульс',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(int.tryParse(controller.text.trim()));
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
    if (!mounted || value == null) return;
    try {
      final validated = await _health.requestManualMaxHr(value);
      widget.onMaxHrChanged(validated);
    } on BackendRequestError catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Некорректный ввод'),
            content: Text(e.message),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Понятно'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _setMaxHrByAge() async {
    final age = await _askAge(context);
    if (!mounted || age == null) return;
    try {
      final maxHr = await _health.requestMaxHrFromAge(age);
      widget.onMaxHrChanged(maxHr);
    } on BackendRequestError catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Некорректный ввод'),
            content: Text(e.message),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Понятно'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _openWorkoutDetails(int index) async {
    final wasDeleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _WorkoutDetailsScreen(
          workout: _workouts[index],
          preferredSplitUnit: widget.preferredSplitUnit,
        ),
      ),
    );
    if (!mounted || wasDeleted != true) return;
    setState(() => _workouts.removeAt(index));
  }

  String _formatDateTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year}';
  }

  void _sortWorkouts() {
    _workouts.sort((a, b) {
      final aDate = DateTime(a.dateTime.year, a.dateTime.month, a.dateTime.day);
      final bDate = DateTime(b.dateTime.year, b.dateTime.month, b.dateTime.day);
      final byDate = bDate.compareTo(aDate);
      if (byDate != 0) return byDate;
      return b.id.compareTo(a.id);
    });
  }

  String _workoutTitle(WorkoutRecord workout) => _formatDateTime(workout.dateTime);

  @override
  Widget build(BuildContext context) {
    final isJournalTab = _tabIndex == 0;
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(isJournalTab ? 'Журнал тренировок' : 'Прогноз'),
        actions: [
          IconButton(
            onPressed: _openSettingsDrawer,
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Настройки',
          ),
        ],
      ),
      endDrawer: Drawer(
        child: Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).viewPadding.top + 8),
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Настройки', style: Theme.of(context).textTheme.titleLarge),
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Тема', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<AppThemeVariant>(
                  segments: const [
                    ButtonSegment(value: AppThemeVariant.light, label: Text('Light')),
                    ButtonSegment(value: AppThemeVariant.dark, label: Text('Dark')),
                  ],
                  selected: {widget.currentTheme},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) {
                      widget.onThemeChanged(selection.first);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text('Представление', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<SplitInputUnit>(
                  segments: const [
                    ButtonSegment(value: SplitInputUnit.watts, label: Text('Ватты')),
                    ButtonSegment(value: SplitInputUnit.split, label: Text('Split /500м')),
                  ],
                  selected: {widget.preferredSplitUnit},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) {
                      widget.onPreferredSplitUnitChanged(selection.first);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text('Гендер', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  emptySelectionAllowed: true,
                  segments: const [
                    ButtonSegment(value: 'male', label: Text('Мужчина')),
                    ButtonSegment(value: 'female', label: Text('Женщина')),
                  ],
                  selected: widget.selectedGender == null ? {} : {widget.selectedGender!},
                  onSelectionChanged: (selection) async {
                    if (selection.isEmpty) return;
                    await _onGenderChangedFromSettings(selection.first);
                  },
                ),
                const SizedBox(height: 16),
                Text('Макс HR (пульс)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Укажите вручную или выберите "Не знаю", чтобы рассчитать по возрасту.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    widget.maxHr == null ? 'Не задан' : '${widget.maxHr} уд/мин',
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _setMaxHrManual,
                        child: const Text('Ввести'),
                      ),
                      OutlinedButton(
                        onPressed: _setMaxHrByAge,
                        child: const Text('Не знаю'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: isJournalTab
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _workouts.length,
              itemBuilder: (context, index) {
                final item = _workouts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.fitness_center),
                    title: Text(_workoutTitle(item)),
                    isThreeLine: true,
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_journal.journalCardLine2(item)),
                        const SizedBox(height: 4),
                        Text(
                          'Общее расстояние: ${_journal.workoutTotalDistanceMeters(item)} м',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openWorkoutDetails(index),
                  ),
                );
              },
            )
          : PredictionScreen(
              selectedGender: widget.selectedGender,
              canEditGenderInPrediction: !widget.hasPrediction,
              lastPrediction: widget.lastPrediction,
              onTrySetGenderFromPrediction: _onGenderChangedFromPrediction,
              onPredictionCreated: widget.onPredictionCreated,
              maxHr: widget.maxHr,
              onMaxHrChanged: widget.onMaxHrChanged,
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Тренировки',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Прогноз',
          ),
        ],
      ),
      floatingActionButton: isJournalTab
          ? FloatingActionButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final saved = await Navigator.of(context).push<WorkoutRecord>(
                  MaterialPageRoute(
                    builder: (_) => AddWorkoutScreen(
                      preferredSplitUnit: widget.preferredSplitUnit,
                    ),
                  ),
                );
                if (!mounted || saved == null) return;
                int newId;
                try {
                  newId = await _workoutRepo.insertWorkout(workout: saved, userId: -1);
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Ошибка сохранения в БД: $e')),
                  );
                  return;
                }
                if (!mounted) return;
                setState(() {
                  _workouts.add(saved.copyWith(id: newId));
                  _sortWorkouts();
                });
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _WorkoutDetailsScreen extends StatelessWidget {
  const _WorkoutDetailsScreen({
    required this.workout,
    required this.preferredSplitUnit,
  });

  static const _journal = JournalBackendService();
  final WorkoutRecord workout;
  final SplitInputUnit preferredSplitUnit;

  String _formatMeters(int? meters) => meters?.toString() ?? '-';

  String _formatSplit(double? sec500) {
    if (sec500 == null) return '--:--.-';
    final minutes = sec500 ~/ 60;
    final seconds = sec500 - minutes * 60;
    return '$minutes:${seconds.toStringAsFixed(1).padLeft(4, '0')}';
  }

  String _formatPower(double? watts) =>
      watts == null ? '---' : watts.toStringAsFixed(0);

  String _formatSpm(int? spm) => spm?.toString() ?? '-';
  String _formatHr(int? hr) => hr?.toString() ?? '-';

  TableCell _tableCell(String text, {TextAlign textAlign = TextAlign.center}) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(text, textAlign: textAlign),
      ),
    );
  }

  Widget _sectionEntriesTable(WorkoutSectionType section) {
    final data = workout.sections[section]!;
    final isInterval = data.type == WorkoutInputType.interval;
    final rowWidgets = <Widget>[];
    final blocks = isInterval
        ? _journal.buildIntervalBlocks(data.entries)
        : [
            JournalIntervalBlock(
              rows: [
                for (int i = 0; i < data.entries.length; i++)
                  JournalIntervalRow(index: i + 1, entry: data.entries[i]),
              ],
              average: data.entries.isEmpty ? IntervalEntry() : data.entries.first,
              restBeforeSec: null,
              isGrouped: false,
            ),
          ];
    final groupedMode = isInterval && blocks.any((x) => x.isGrouped);

    if (isInterval) {
      final avgAll = _journal.averageAllIntervals(data.entries);
      final avgAllSplit = preferredSplitUnit == SplitInputUnit.watts
          ? _formatPower(avgAll.watts)
          : _formatSplit(avgAll.splitSec500);
      rowWidgets.add(
        Table(
          columnWidths: const {
            0: FixedColumnWidth(28),
            1: FixedColumnWidth(96),
            2: FixedColumnWidth(44),
            3: FixedColumnWidth(56),
            4: FixedColumnWidth(36),
            5: FixedColumnWidth(44),
            6: FixedColumnWidth(32),
          },
          children: [
            TableRow(
              children: [
                _tableCell('ср.'),
                _tableCell(_journal.formatDuration(avgAll.timeSec), textAlign: TextAlign.left),
                _tableCell(_formatMeters(avgAll.distanceM)),
                _tableCell(avgAllSplit),
                _tableCell(_formatSpm(avgAll.strokeRate)),
                _tableCell('-'),
                _tableCell(_formatHr(avgAll.heartRate)),
              ],
            ),
          ],
        ),
      );
      rowWidgets.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 2),
        child: _DashedLine(),
      ));
    }

    for (int b = 0; b < blocks.length; b++) {
      final block = blocks[b];
      if (groupedMode && b > 0) {
        final restText = _journal.formatRestMinSec(block.restBeforeSec);
        rowWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('отдых'),
                  const SizedBox(width: 8),
                  Text(restText),
                ],
              ),
            ),
          ),
        );
      }
      if (block.label != null) {
        rowWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                block.label!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
      }
      if (isInterval) {
        if (groupedMode && block.isGrouped) {
          final avgSplitValue = preferredSplitUnit == SplitInputUnit.watts
              ? _formatPower(block.average.watts)
              : _formatSplit(block.average.splitSec500);
          rowWidgets.add(
            Table(
              columnWidths: const {
                0: FixedColumnWidth(28),
                1: FixedColumnWidth(96),
                2: FixedColumnWidth(44),
                3: FixedColumnWidth(56),
                4: FixedColumnWidth(36),
                5: FixedColumnWidth(44),
                6: FixedColumnWidth(32),
              },
              children: [
                TableRow(
                  children: [
                    _tableCell('ср.'),
                    _tableCell(
                      _journal.formatDuration(block.average.timeSec),
                      textAlign: TextAlign.left,
                    ),
                    _tableCell(_formatMeters(block.average.distanceM)),
                    _tableCell(avgSplitValue),
                    _tableCell(_formatSpm(block.average.strokeRate)),
                    _tableCell('-'),
                    _tableCell(_formatHr(block.average.heartRate)),
                  ],
                ),
              ],
            ),
          );
          rowWidgets.add(const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: _DashedLine(),
          ));
        }
      }

      for (int i = 0; i < block.rows.length; i++) {
        final row = block.rows[i];
        final splitValue = preferredSplitUnit == SplitInputUnit.watts
            ? _formatPower(row.entry.watts)
            : _formatSplit(row.entry.splitSec500);
        final showDashRest = isInterval && (groupedMode ? i == 0 : row.index == 1);
        final restValue = showDashRest ? '-' : _journal.formatRestMinSec(row.entry.restSec);
        rowWidgets.add(
          Table(
            columnWidths: const {
              0: FixedColumnWidth(28),
              1: FixedColumnWidth(96),
              2: FixedColumnWidth(44),
              3: FixedColumnWidth(56),
              4: FixedColumnWidth(36),
              5: FixedColumnWidth(44),
              6: FixedColumnWidth(32),
            },
            children: [
              TableRow(
                children: [
                  _tableCell('${row.index}'),
                  _tableCell(
                    _journal.formatDuration(row.entry.timeSec),
                    textAlign: TextAlign.left,
                  ),
                  _tableCell(_formatMeters(row.entry.distanceM)),
                  _tableCell(splitValue),
                  _tableCell(_formatSpm(row.entry.strokeRate)),
                  _tableCell(isInterval ? restValue : '\u00A0'),
                  _tableCell(_formatHr(row.entry.heartRate)),
                ],
              ),
            ],
          ),
        );
        if (i < block.rows.length - 1) {
          rowWidgets.add(const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: _DashedLine(),
          ));
        }
      }
      if (b < blocks.length - 1) {
        rowWidgets.add(const SizedBox(height: 6));
      }
    }
    return Column(
      children: [
        Table(
          columnWidths: const {
            0: FixedColumnWidth(28),
            1: FixedColumnWidth(96),
            2: FixedColumnWidth(44),
            3: FixedColumnWidth(56),
            4: FixedColumnWidth(36),
            5: FixedColumnWidth(44),
            6: FixedColumnWidth(32),
          },
          children: [
            TableRow(
              children: [
                _tableCell('№'),
                _tableCell('время', textAlign: TextAlign.left),
                _tableCell('м'),
                _tableCell('split'),
                _tableCell('S/M'),
                _tableCell(isInterval ? 'отд.' : '\u00A0'),
                _tableCell('HR'),
              ],
            ),
          ],
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFF0C2A4B)),
        ...rowWidgets,
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Удалить тренировку?'),
          content: const Text('Вы точно хотите удалить эту тренировку?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );
    if (context.mounted && confirmed == true) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали тренировки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Дата'),
              subtitle: Text(
                '${workout.dateTime.day.toString().padLeft(2, '0')}.'
                '${workout.dateTime.month.toString().padLeft(2, '0')}.'
                '${workout.dateTime.year}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final section in WorkoutSectionType.values)
            if (_journal.workoutSectionHasData(section, workout)) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.label, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDF4F4),
                        border: Border.all(color: Colors.black87, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: DefaultTextStyle(
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFF0C2A4B),
                            fontSize: 12,
                          ),
                          child: _sectionEntriesTable(section),
                        ),
                      ),
                    ),
                    if (section == WorkoutSectionType.mainWork) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Усталость: ${workout.mainWorkFatigue10}/10',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Удалить тренировку'),
          ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 4.0;
        const dashSpace = 3.0;
        final dashCount = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            dashCount,
            (_) => const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFF0C2A4B)),
              ),
            ),
          ),
        );
      },
    );
  }
}