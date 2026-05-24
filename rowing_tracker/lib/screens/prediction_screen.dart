import 'package:flutter/material.dart';

import '../backend/health_backend.dart';
import '../backend/prediction_backend.dart';
import '../models/training_models.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({
    super.key,
    required this.selectedGender,
    required this.canEditGenderInPrediction,
    required this.lastPrediction,
    required this.onTrySetGenderFromPrediction,
    required this.onPredictionCreated,
    required this.maxHr,
    required this.onMaxHrChanged,
  });

  final String? selectedGender;
  final bool canEditGenderInPrediction;
  final PredictionResult? lastPrediction;
  final Future<bool> Function(String gender) onTrySetGenderFromPrediction;
  final ValueChanged<PredictionResult> onPredictionCreated;
  final int? maxHr;
  final ValueChanged<int?> onMaxHrChanged;

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final _backend = PredictionBackendService();
  static const _health = HealthBackendService();
  // Период прогноза в днях.
  double _periodDays = 14;

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

  Future<void> _setManualMaxHr() async {
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
              labelText: 'Укажите max HR',
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _setMaxHrByAge() async {
    final age = await _askAge(context);
    if (!mounted || age == null) return;
    try {
      final maxHr = await _health.requestMaxHrFromAge(age);
      widget.onMaxHrChanged(maxHr);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Расчетный max HR: $maxHr')),
      );
    } on BackendRequestError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedGender = widget.selectedGender;
    final lastPrediction = widget.lastPrediction;
    final maxHrLocked = widget.maxHr != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Период для прогноза', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Последние ${_periodDays.round()} дней'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('14', style: Theme.of(context).textTheme.bodySmall),
                    Text('90', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                Slider(
                  value: _periodDays,
                  min: 14,
                  max: 90,
                  divisions: 76,
                  label: _periodDays.round().toString(),
                  onChanged: (value) => setState(() => _periodDays = value),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Пол', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (selectedGender != null)
                  const Text('Гендер уже задан в настройках. Изменение доступно только там.')
                else if (widget.canEditGenderInPrediction)
                  SegmentedButton<String>(
                    emptySelectionAllowed: true,
                    segments: const [
                      ButtonSegment(value: 'male', label: Text('Мужчина')),
                      ButtonSegment(value: 'female', label: Text('Женщина')),
                    ],
                    selected: selectedGender == null ? {} : {selectedGender},
                    onSelectionChanged: (selection) async {
                      if (selection.isEmpty) return;
                      await widget.onTrySetGenderFromPrediction(selection.first);
                    },
                  )
                else
                  const Text(
                    'Выберите гендер в настройках перед первым прогнозом.',
                  ),
                if (selectedGender == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'При первом прогнозе пол обязателен.',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Макс HR (пульс)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(widget.maxHr == null ? 'Не задан' : '${widget.maxHr} уд/мин'),
                if (maxHrLocked)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Макс HR уже задан в настройках. Изменение доступно только там.'),
                  ),
                if (!maxHrLocked) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _setManualMaxHr,
                        child: const Text('Ввести'),
                      ),
                      OutlinedButton(
                        onPressed: _setMaxHrByAge,
                        child: const Text('Не знаю'),
                      ),
                    ],
                  ),
                ],
                if (widget.maxHr == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'max HR обязателен для прогноза.',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: const Text('Последний прогноз'),
            subtitle: lastPrediction == null
                ? const Text('—')
                : Text(
                    '2k: ${_backend.formatSeconds(lastPrediction.predicted2kSeconds)}\n'
                    'Дата: ${_backend.formatDate(lastPrediction.createdAt)}',
                  ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: selectedGender == null || widget.maxHr == null
              ? null
              : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final newPrediction = await _backend.calculatePrediction(
                      gender: selectedGender,
                      periodDays: _periodDays.round(),
                      maxHr: widget.maxHr!,
                    );
                    if (!mounted) return;
                    widget.onPredictionCreated(newPrediction);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Прогноз рассчитан: ${_backend.formatSeconds(newPrediction.predicted2kSeconds)}',
                        ),
                      ),
                    );
                  } on BackendRequestError catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text(e.message)),
                    );
                  }
                },
          icon: const Icon(Icons.analytics),
          label: const Text('Рассчитать прогноз'),
        ),
      ],
    );
  }
}
