import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/features/meals/meal_models.dart';
import 'package:yuvomigo/features/meals/meal_providers.dart';

/// Schermata Pasti: pianificazione settimanale (lunedì–domenica).
final class MealsScreen extends ConsumerStatefulWidget {
  const MealsScreen({super.key});

  @override
  ConsumerState<MealsScreen> createState() => _MealsScreenState();
}

final class _MealsScreenState extends ConsumerState<MealsScreen> {
  static const _scrollPhysics = AlwaysScrollableScrollPhysics();

  DateTime _week = _mondayOf(DateTime.now());

  String get _weekKey => _dateKey(_week);

  void _shiftWeek(int days) {
    setState(() {
      _week = DateTime(_week.year, _week.month, _week.day + days);
    });
  }

  @override
  Widget build(BuildContext context) {
    final week = ref.watch(mealsWeekProvider(_weekKey));
    ref.listen<Object?>(mealsActionErrorProvider, (_, err) {
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operazione non riuscita: $err')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Pasti')),
      body: Column(
        children: [
          _WeekBar(
            week: _week,
            onPrevious: () => _shiftWeek(-7),
            onNext: () => _shiftWeek(7),
            onToday: () => setState(() => _week = _mondayOf(DateTime.now())),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(mealsWeekProvider(_weekKey).notifier).refresh(),
              child: week.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  physics: _scrollPhysics,
                  padding: const EdgeInsets.all(16),
                  children: [
                    ErrorRetryTile(
                      message: 'Impossibile caricare i pasti.',
                      detail: e.toString(),
                      onRetry: () =>
                          ref.read(mealsWeekProvider(_weekKey).notifier).load(),
                    ),
                  ],
                ),
                data: (data) {
                  if (data.meals.isEmpty) {
                    return ListView(
                      physics: _scrollPhysics,
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          'Nessun pasto in questa settimana.\n'
                          'Usa "Aggiungi" per pianificarne uno.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    );
                  }
                  return _MealsList(
                    data: data,
                    onDelete: (id) => ref
                        .read(mealsWeekProvider(_weekKey).notifier)
                        .remove(id),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _MealEditorDialog.show(context, weekKey: _weekKey),
        child: const Icon(Icons.add),
      ),
    );
  }
}

final class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.week,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime week;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final end = DateTime(week.year, week.month, week.day + 6);
    final label =
        '${DateFormat('d MMM', locale).format(week)} – '
        '${DateFormat('d MMM', locale).format(end)}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Settimana precedente',
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Settimana successiva',
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
          TextButton(onPressed: onToday, child: const Text('Oggi')),
        ],
      ),
    );
  }
}

final class _MealsList extends StatelessWidget {
  const _MealsList({required this.data, required this.onDelete});

  final MealWeek data;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final groups = <String, List<Meal>>{};
    for (final meal in data.meals) {
      groups.putIfAbsent(meal.date, () => []).add(meal);
    }
    final dates = groups.keys.toList()..sort();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
      children: [
        for (final date in dates) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
            child: Text(
              _dayLabel(context, date, locale),
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          for (final meal
              in groups[date]!..sort(
                (a, b) =>
                    mealTypeOrder(a.mealType)
                        .compareTo(mealTypeOrder(b.mealType)),
              ))
            ListTile(
              leading: Icon(_mealIcon(meal.mealType)),
              title: Text(meal.title),
              subtitle: Text(mealTypeLabel(meal.mealType)),
              trailing: IconButton(
                tooltip: 'Elimina',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onDelete(meal.id),
              ),
            ),
        ],
      ],
    );
  }

  String _dayLabel(BuildContext context, String date, String locale) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return date;
    return DateFormat('EEEE d MMMM', locale).format(parsed);
  }

  IconData _mealIcon(String type) => switch (type) {
    'breakfast' => Icons.free_breakfast_outlined,
    'lunch' => Icons.lunch_dining_outlined,
    'dinner' => Icons.dinner_dining_outlined,
    'snack' => Icons.cookie_outlined,
    _ => Icons.restaurant_outlined,
  };
}

/// Dialog per pianificare un pasto: tipo, titolo e data.
final class _MealEditorDialog extends ConsumerStatefulWidget {
  const _MealEditorDialog({required this.weekKey});

  final String weekKey;

  static Future<void> show(BuildContext context, {required String weekKey}) {
    return showDialog<void>(
      context: context,
      builder: (_) => _MealEditorDialog(weekKey: weekKey),
    );
  }

  @override
  ConsumerState<_MealEditorDialog> createState() => _MealEditorDialogState();
}

final class _MealEditorDialogState extends ConsumerState<_MealEditorDialog> {
  static const _types = ['breakfast', 'lunch', 'dinner', 'snack'];

  final _title = TextEditingController();
  String _mealType = 'dinner';
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime(_date.year + 2),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final created = await ref
        .read(mealsWeekProvider(widget.weekKey).notifier)
        .add(date: _dateKey(_date), mealType: _mealType, title: title);
    if (!mounted) return;
    if (!created) {
      setState(() => _busy = false);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    return AlertDialog(
      title: const Text('Nuovo pasto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _mealType,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: [
              for (final type in _types)
                DropdownMenuItem(value: type, child: Text(mealTypeLabel(type))),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _mealType = value ?? 'dinner'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Cosa si mangia?'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _pickDate,
              icon: const Icon(Icons.event),
              label: Text(DateFormat('EEEE d MMMM', locale).format(_date)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Aggiungi'),
        ),
      ],
    );
  }
}

DateTime _mondayOf(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return DateTime(day.year, day.month, day.day - (day.weekday - 1));
}

String _dateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
