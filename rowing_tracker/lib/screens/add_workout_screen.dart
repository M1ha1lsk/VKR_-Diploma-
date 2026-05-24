import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/workout_backend.dart';
import '../models/training_models.dart';

class AddWorkoutScreen extends StatefulWidget {
  const AddWorkoutScreen({
    super.key,
    required this.preferredSplitUnit,
  });

  final SplitInputUnit preferredSplitUnit;

  @override
  State<AddWorkoutScreen> createState() => _AddWorkoutScreenState();
}

class _AddWorkoutScreenState extends State<AddWorkoutScreen> {
  final WorkoutBackendService _backend = const WorkoutBackendService();
  final WorkoutDraft draft = WorkoutDraft(
    dateTime: DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ),
  );
  final Map<WorkoutSectionType, WorkoutInputType> _sectionTypes = {
    WorkoutSectionType.warmUp: WorkoutInputType.steady,
    WorkoutSectionType.mainWork: WorkoutInputType.steady,
    WorkoutSectionType.coolDown: WorkoutInputType.steady,
  };
  final Map<WorkoutSectionType, bool> _expanded = {
    WorkoutSectionType.warmUp: false,
    WorkoutSectionType.mainWork: true,
    WorkoutSectionType.coolDown: false,
  };

  @override
  void initState() {
    super.initState();
    for (final section in WorkoutSectionType.values) {
      for (final entry in _sectionList(section)) {
        entry.splitInputUnit = widget.preferredSplitUnit;
      }
    }
  }

  Future<void> _pickDateTime() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: draft.dateTime,
      firstDate: DateTime(2010),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selectedDate == null || !mounted) return;
    setState(() {
      draft.dateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
    });
  }

  List<IntervalEntry> _sectionList(WorkoutSectionType type) {
    return _backend.sectionList(draft, type);
  }

  void _addInterval(WorkoutSectionType type) {
    setState(() {
      _sectionList(type).add(_backend.newEntry(widget.preferredSplitUnit));
    });
  }

  void _toggleExpanded(WorkoutSectionType section) {
    setState(() {
      _expanded[section] = !(_expanded[section] ?? false);
      if (_expanded[section] == true && _sectionList(section).isEmpty) {
        _sectionList(section).add(_backend.newEntry(widget.preferredSplitUnit));
      }
    });
  }

  void _setSectionType(WorkoutSectionType section, WorkoutInputType type) {
    setState(() {
      _sectionTypes[section] = type;
      final entries = _sectionList(section);
      if (entries.isEmpty) {
        entries.add(_backend.newEntry(widget.preferredSplitUnit));
      }
      _backend.normalizeSectionOnTypeChange(entries, type);
    });
  }

  String _formatDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить тренировку')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final section in WorkoutSectionType.values) ...[
            _WorkoutSectionCard(
              title: section.label,
              entries: _sectionList(section),
              isExpanded: _expanded[section] ?? false,
              onExpandTap: () => _toggleExpanded(section),
              workoutInputType: _sectionTypes[section]!,
              onTypeChanged: (type) => _setSectionType(section, type),
              onAdd: () => _addInterval(section),
              onRemoveInterval: (idx) {
                setState(() => _sectionList(section).removeAt(idx));
              },
              onChanged: () => setState(() {}),
              onDistanceChanged: (entry, value) {
                entry.distanceM = value?.floor();
                setState(() {});
              },
              onTimeChanged: (entry, value) {
                entry.timeSec = value == null ? null : _backend.floorToTenth(value);
                setState(() {});
              },
              onSplitInputChanged: (entry, raw) {
                _backend.setSplitFromInput(entry, raw);
                setState(() {});
              },
              onSplitUnitChanged: (entry, unit) {
                entry.splitInputUnit = unit;
                if (entry.splitInputValue != null) {
                  _backend.setSplitFromInput(entry, entry.splitInputValue.toString());
                } else {
                  entry.splitSec500 = null;
                  entry.watts = null;
                }
                setState(() {});
              },
            ),
            if (section == WorkoutSectionType.mainWork) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Усталость после основной работы (0–10)',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: draft.mainWorkFatigue10,
                        decoration: const InputDecoration(
                          labelText: 'Выберите значение',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: List.generate(
                          11,
                          (i) => DropdownMenuItem<int>(
                            value: i,
                            child: Text('$i'),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            draft.mainWorkFatigue10 = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          Card(
            child: ListTile(
              title: const Text('Дата тренировки'),
              subtitle: Text(_formatDate(draft.dateTime)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDateTime,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              FocusScope.of(context).unfocus();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                final validationError = _backend.validateDraft(
                  draft: draft,
                  sectionTypes: _sectionTypes,
                );
                if (validationError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(validationError)),
                  );
                  return;
                }
                final workout = _backend.buildWorkoutRecord(
                  draft: draft,
                  sectionTypes: _sectionTypes,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Тренировка сохранена.')),
                );
                Navigator.of(context).pop(workout);
              });
            },
            icon: const Icon(Icons.save),
            label: const Text('Сохранить тренировку'),
          ),
        ],
      ),
    );
  }
}

class _WorkoutSectionCard extends StatelessWidget {
  const _WorkoutSectionCard({
    required this.title,
    required this.entries,
    required this.isExpanded,
    required this.onExpandTap,
    required this.workoutInputType,
    required this.onTypeChanged,
    required this.onAdd,
    required this.onRemoveInterval,
    required this.onChanged,
    required this.onDistanceChanged,
    required this.onTimeChanged,
    required this.onSplitInputChanged,
    required this.onSplitUnitChanged,
  });

  final String title;
  final List<IntervalEntry> entries;
  final bool isExpanded;
  final VoidCallback onExpandTap;
  final WorkoutInputType workoutInputType;
  final ValueChanged<WorkoutInputType> onTypeChanged;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemoveInterval;
  final VoidCallback onChanged;
  final void Function(IntervalEntry entry, int? value) onDistanceChanged;
  final void Function(IntervalEntry entry, double? value) onTimeChanged;
  final void Function(IntervalEntry entry, String raw) onSplitInputChanged;
  final void Function(IntervalEntry entry, SplitInputUnit unit) onSplitUnitChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  onPressed: onExpandTap,
                  icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                ),
              ],
            ),
            if (!isExpanded) ...[
              const SizedBox(height: 6),
              Text(
                'Секция свернута. Нажмите, чтобы заполнить.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else ...[
              const SizedBox(height: 8),
              SegmentedButton<WorkoutInputType>(
                segments: const [
                  ButtonSegment(
                    value: WorkoutInputType.steady,
                    label: Text('Неинтервальная'),
                  ),
                  ButtonSegment(
                    value: WorkoutInputType.interval,
                    label: Text('Интервальная'),
                  ),
                ],
                selected: {workoutInputType},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) onTypeChanged(selection.first);
                },
              ),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                TextButton(
                  onPressed: onAdd,
                  child: const Text('Добавить запись'),
                ),
              for (int i = 0; i < entries.length; i++) ...[
                _IntervalFormRow(
                  key: ValueKey('${title}_${i}_${entries[i].hashCode}'),
                  index: i,
                  isInterval: workoutInputType == WorkoutInputType.interval,
                  entry: entries[i],
                  onChanged: onChanged,
                  onDistanceChanged: (v) => onDistanceChanged(entries[i], v),
                  onTimeChanged: (v) => onTimeChanged(entries[i], v),
                  onSplitInputChanged: (v) => onSplitInputChanged(entries[i], v),
                  onSplitUnitChanged: (v) => onSplitUnitChanged(entries[i], v),
                  onDelete: entries.length > 1 ? () => onRemoveInterval(i) : null,
                  splitDisplayValue: entries[i].splitInputUnit == SplitInputUnit.watts
                      ? entries[i].watts
                      : entries[i].splitSec500,
                ),
                if (i != entries.length - 1) const Divider(height: 20),
              ],
              if (workoutInputType == WorkoutInputType.interval && entries.isNotEmpty) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('Интервал'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _IntervalFormRow extends StatelessWidget {
  const _IntervalFormRow({
    super.key,
    required this.index,
    required this.isInterval,
    required this.entry,
    required this.onChanged,
    required this.onDistanceChanged,
    required this.onTimeChanged,
    required this.onSplitInputChanged,
    required this.onSplitUnitChanged,
    required this.splitDisplayValue,
    this.onDelete,
  });

  final int index;
  final bool isInterval;
  final IntervalEntry entry;
  final VoidCallback onChanged;
  final ValueChanged<int?> onDistanceChanged;
  final ValueChanged<double?> onTimeChanged;
  final ValueChanged<String> onSplitInputChanged;
  final ValueChanged<SplitInputUnit> onSplitUnitChanged;
  final double? splitDisplayValue;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isInterval ? 'Интервал ${index + 1}' : 'Рабочий блок'),
            if (onDelete != null)
              IconButton(
                tooltip: 'Удалить',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          runSpacing: 8,
          spacing: 8,
          children: [
            _SmallNumberField(
              label: 'Дист. (м)',
              value: entry.distanceM?.toString(),
              integerOnly: true,
              onValue: (v) => onDistanceChanged(v?.floor()),
              onChanged: onChanged,
            ),
            _DurationField(
              totalSeconds: entry.timeSec,
              onValue: onTimeChanged,
              onChanged: onChanged,
              title: 'Время',
              showHours: true,
            ),
            if (isInterval)
              if (index > 0)
              _DurationField(
                totalSeconds: entry.restSec?.toDouble(),
                onValue: (v) => entry.restSec = v?.floor(),
                onChanged: onChanged,
                title: 'Отдых',
                showHours: false,
                showTenths: false,
                compact: true,
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Split (/500м)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                if (entry.splitInputUnit == SplitInputUnit.watts)
                  _SmallNumberField(
                    label: 'Мощность (Вт)',
                    value: splitDisplayValue?.toStringAsFixed(0),
                    onRawChanged: onSplitInputChanged,
                    onValue: (_) {},
                    onChanged: onChanged,
                  )
                else
                  _DurationField(
                    totalSeconds: splitDisplayValue,
                    onValue: (value) {
                      onSplitInputChanged(value?.toString() ?? '');
                    },
                    onChanged: onChanged,
                    title: '',
                    showHours: false,
                    showTitle: false,
                    compact: true,
                  ),
              ],
            ),
            const SizedBox(width: double.infinity, height: 0),
            _SmallNumberField(
              label: 'Темп (уд/мин)',
              value: entry.strokeRate?.toString(),
              integerOnly: true,
              onValue: (v) => entry.strokeRate = v?.floor(),
              onChanged: onChanged,
            ),
            _SmallNumberField(
              label: 'Пульс',
              value: entry.heartRate?.toString(),
              integerOnly: true,
              onValue: (v) => entry.heartRate = v?.floor(),
              onChanged: onChanged,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<SplitInputUnit>(
          segments: const [
            ButtonSegment(value: SplitInputUnit.split, label: Text('Время/500м')),
            ButtonSegment(value: SplitInputUnit.watts, label: Text('Ватты')),
          ],
          selected: {entry.splitInputUnit},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) onSplitUnitChanged(selection.first);
          },
        ),
      ],
    );
  }
}

class _DurationField extends StatefulWidget {
  const _DurationField({
    required this.totalSeconds,
    required this.onValue,
    required this.onChanged,
    required this.title,
    required this.showHours,
    this.showTenths = true,
    this.compact = false,
    this.showTitle = true,
  });

  final double? totalSeconds;
  final ValueChanged<double?> onValue;
  final VoidCallback onChanged;
  final String title;
  final bool showHours;
  final bool showTenths;
  final bool compact;
  final bool showTitle;

  @override
  State<_DurationField> createState() => _DurationFieldState();
}

class _DurationFieldState extends State<_DurationField> {
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  late final TextEditingController _secondsController;
  late final TextEditingController _tenthsController;
  late final FocusNode _hoursFocus;
  late final FocusNode _minutesFocus;
  late final FocusNode _secondsFocus;
  late final FocusNode _tenthsFocus;
  bool _postFrameCommitScheduled = false;
  bool _skipNextExternalSync = false;

  bool _totalsDiffer(double? a, double? b) {
    if (a == null && b == null) return false;
    if (a == null || b == null) return true;
    return (a - b).abs() > 0.0001;
  }

  Iterable<FocusNode> get _allFocusNodes sync* {
    if (widget.showHours) yield _hoursFocus;
    yield _minutesFocus;
    yield _secondsFocus;
    if (widget.showTenths) yield _tenthsFocus;
  }

  bool get _anyPartFocused => _allFocusNodes.any((n) => n.hasFocus);

  @override
  void initState() {
    super.initState();
    _hoursController = TextEditingController();
    _minutesController = TextEditingController();
    _secondsController = TextEditingController();
    _tenthsController = TextEditingController();
    _hoursFocus = FocusNode();
    _minutesFocus = FocusNode();
    _secondsFocus = FocusNode();
    _tenthsFocus = FocusNode();
    for (final n in _allFocusNodes) {
      n.addListener(_onFocusChange);
    }
    _syncFromTotalSeconds(widget.totalSeconds);
  }

  void _onFocusChange() {
    if (_postFrameCommitScheduled) return;
    _postFrameCommitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postFrameCommitScheduled = false;
      if (!mounted) return;
      if (!_anyPartFocused) {
        _commit();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _DurationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_skipNextExternalSync) {
      _skipNextExternalSync = false;
      return;
    }
    if (_totalsDiffer(oldWidget.totalSeconds, widget.totalSeconds) && !_anyPartFocused) {
      _syncFromTotalSeconds(widget.totalSeconds);
    }
  }

  void _syncFromTotalSeconds(double? totalSeconds) {
    if (totalSeconds == null) {
      _hoursController.text = '';
      _minutesController.text = '';
      _secondsController.text = '';
      _tenthsController.text = '';
      return;
    }
    final hours = (totalSeconds ~/ 3600).toInt();
    final remAfterHours =
        widget.showHours ? (totalSeconds - hours * 3600.0) : (totalSeconds % 3600);
    final minutes = (remAfterHours ~/ 60).toInt();
    final secondsFloor = (remAfterHours - minutes * 60).floor();
    final tenths =
        ((remAfterHours - minutes * 60 - secondsFloor) * 10).floor().clamp(0, 9);
    _hoursController.text = widget.showHours ? hours.toString() : '';
    _minutesController.text = minutes.toString();
    _secondsController.text = secondsFloor.toString();
    _tenthsController.text = tenths.toString();
  }

  // Нормализация введенного времени.
  void _commit() {
    final hText = _hoursController.text.trim();
    final mText = _minutesController.text.trim();
    final sText = _secondsController.text.trim();
    final tText = _tenthsController.text.trim();
    final hadHourInput = hText.isNotEmpty;
    final hadMinuteInput = mText.isNotEmpty;
    final hadSecondInput = sText.isNotEmpty;
    final hadTenthInput = tText.isNotEmpty;

    if (hText.isEmpty && mText.isEmpty && sText.isEmpty && tText.isEmpty) {
      widget.onValue(null);
      widget.onChanged();
      return;
    }

    int h = widget.showHours ? (int.tryParse(hText) ?? 0) : 0;
    int m = int.tryParse(mText) ?? 0;
    int s = int.tryParse(sText) ?? 0;
    int t = widget.showTenths ? (int.tryParse(tText) ?? 0).clamp(0, 9) : 0;

    m += s ~/ 60;
    s %= 60;

    if (widget.showHours) {
      h += m ~/ 60;
      m %= 60;
      if (h > 99) {
        h = 99;
        m = 59;
        s = 59;
        t = 9;
      }
    } else if (m > 99) {
      m = 99;
      s = 59;
    }

    if (widget.showHours) {
      _hoursController.value = TextEditingValue(
        text: (h > 0 || hadHourInput) ? h.toString() : '',
        selection: TextSelection.collapsed(
          offset: ((h > 0 || hadHourInput) ? h.toString() : '').length,
        ),
      );
    }
    final minuteText = (m > 0 || hadMinuteInput) ? m.toString() : '';
    _minutesController.value = TextEditingValue(
      text: minuteText,
      selection: TextSelection.collapsed(offset: minuteText.length),
    );
    final secondText = (s > 0 || hadSecondInput) ? s.toString() : '';
    _secondsController.value = TextEditingValue(
      text: secondText,
      selection: TextSelection.collapsed(offset: secondText.length),
    );
    if (widget.showTenths) {
      final tenthText = (t > 0 || hadTenthInput) ? t.toString() : '';
      _tenthsController.value = TextEditingValue(
        text: tenthText,
        selection: TextSelection.collapsed(offset: tenthText.length),
      );
    } else {
      _tenthsController.clear();
    }

    final total =
        (widget.showHours ? h * 3600 : 0) + m * 60 + s + (widget.showTenths ? t / 10.0 : 0.0);
    _skipNextExternalSync = true;
    widget.onValue(total);
    widget.onChanged();
  }

  @override
  void dispose() {
    for (final n in _allFocusNodes) {
      n.removeListener(_onFocusChange);
      n.dispose();
    }
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    _tenthsController.dispose();
    super.dispose();
  }

  static final List<TextInputFormatter> _twoDigits = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(2),
  ];
  static final List<TextInputFormatter> _oneDigit = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(1),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.compact ? 220 : double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showTitle && widget.title.isNotEmpty) ...[
            Text(widget.title),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              if (widget.showHours) ...[
                Expanded(
                  child: _TimePartField(
                    controller: _hoursController,
                    focusNode: _hoursFocus,
                    hint: '0',
                    inputFormatters: _twoDigits,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(':'),
                ),
              ],
              Expanded(
                child: _TimePartField(
                  controller: _minutesController,
                  focusNode: _minutesFocus,
                  hint: '00',
                  inputFormatters: _twoDigits,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(':'),
              ),
              Expanded(
                child: _TimePartField(
                  controller: _secondsController,
                  focusNode: _secondsFocus,
                  hint: '00',
                  inputFormatters: _twoDigits,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                ),
              ),
              if (widget.showTenths) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('.'),
                ),
                Expanded(
                  child: _TimePartField(
                    controller: _tenthsController,
                    focusNode: _tenthsFocus,
                    hint: '0',
                    inputFormatters: _oneDigit,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TimePartField extends StatelessWidget {
  const _TimePartField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.inputFormatters,
    required this.keyboardType,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final List<TextInputFormatter> inputFormatters;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _SmallNumberField extends StatefulWidget {
  const _SmallNumberField({
    required this.label,
    required this.value,
    required this.onValue,
    required this.onChanged,
    this.onRawChanged,
    this.integerOnly = false,
  });

  final String label;
  final String? value;
  final ValueChanged<double?> onValue;
  final ValueChanged<String>? onRawChanged;
  final VoidCallback onChanged;
  final bool integerOnly;

  @override
  State<_SmallNumberField> createState() => _SmallNumberFieldState();
}

class _SmallNumberFieldState extends State<_SmallNumberField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(covariant _SmallNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.value ?? '';
    if (_controller.text != next) {
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (value) {
          widget.onRawChanged?.call(value);
          final parsed = double.tryParse(value.replaceAll(',', '.'));
          if (parsed == null) {
            widget.onValue(null);
          } else if (widget.integerOnly) {
            widget.onValue(parsed.floorToDouble());
          } else {
            widget.onValue(parsed);
          }
          widget.onChanged();
        },
      ),
    );
  }
}

