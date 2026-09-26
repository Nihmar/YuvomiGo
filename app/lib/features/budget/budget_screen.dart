import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yuvomigo/core/utils/date_utils.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/core/widgets/period_bar.dart';
import 'package:yuvomigo/features/budget/budget_models.dart';
import 'package:yuvomigo/features/budget/budget_providers.dart';
import 'package:yuvomigo/features/settings/preferences_providers.dart';

/// Schermata Budget: riepilogo e movimenti del mese (sola lettura).
final class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

final class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  static const _scrollPhysics = AlwaysScrollableScrollPhysics();

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String get _monthKey =>
      '${_month.year.toString().padLeft(4, '0')}-'
      '${_month.month.toString().padLeft(2, '0')}';

  String get _monthLabel {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('MMMM yyyy', locale).format(_month);
  }

  void _shiftMonth(int months) {
    setState(() {
      _month = DateTime(_month.year, _month.month + months);
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(budgetMonthProvider(_monthKey));
    final stats = ref.watch(budgetStatsProvider(_monthKey));
    final yearStats = ref.watch(budgetYearStatsProvider(_monthKey));
    final currency = ref.watch(appPreferencesValueProvider).currency;
    ref.listen<Object?>(budgetActionErrorProvider, (_, err) {
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operazione non riuscita: $err')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Budget')),
      body: Column(
        children: [
          PeriodBar(
            label: _monthLabel,
            onPrevious: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
            onToday: () => setState(
              () =>
                  _month = DateTime(DateTime.now().year, DateTime.now().month),
            ),
            previousTooltip: 'Mese precedente',
            nextTooltip: 'Mese successivo',
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(budgetMonthProvider(_monthKey));
                ref.invalidate(budgetStatsProvider(_monthKey));
                ref.invalidate(budgetYearStatsProvider(_monthKey));
                try {
                  await ref.read(budgetMonthProvider(_monthKey).future);
                  await ref.read(budgetStatsProvider(_monthKey).future);
                  await ref.read(budgetYearStatsProvider(_monthKey).future);
                } catch (_) {
                  // L'errore è già nello stato: niente eccezione sciolta.
                }
              },
              child: data.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  physics: _scrollPhysics,
                  padding: const EdgeInsets.all(16),
                  children: [
                    ErrorRetryTile(
                      message: 'Impossibile caricare il budget.',
                      detail: e.toString(),
                      onRetry: () =>
                          ref.invalidate(budgetMonthProvider(_monthKey)),
                    ),
                  ],
                ),
                data: (data) => _BudgetBody(
                  data: data,
                  stats: stats.value,
                  yearStats: yearStats.value,
                  month: _monthKey,
                  currency: currency,
                  onRetry: () {
                    ref.invalidate(budgetMonthProvider(_monthKey));
                    ref.invalidate(budgetStatsProvider(_monthKey));
                    ref.invalidate(budgetYearStatsProvider(_monthKey));
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Aggiungi movimento',
        onPressed: () => _BudgetEntryDialog.show(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

final class _BudgetBody extends ConsumerWidget {
  const _BudgetBody({
    required this.data,
    required this.stats,
    required this.yearStats,
    required this.month,
    required this.currency,
    required this.onRetry,
  });

  final BudgetMonth data;
  final BudgetStats? stats;
  final BudgetStats? yearStats;

  /// 'YYYY-MM' del mese selezionato (per evidenziarlo nel grafico).
  final String month;
  final String currency;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = data.summary;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final maxCategoryTotal = summary.byCategory.fold<double>(
      0,
      (previous, c) => c.total.abs() > previous ? c.total.abs() : previous,
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Spazio in fondo per non lasciare l'ultimo movimento sotto la FAB.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TotalTile(
                        label: 'Entrate',
                        amount: summary.income,
                        color: Colors.green,
                        currency: currency,
                        locale: locale,
                      ),
                    ),
                    Expanded(
                      child: _TotalTile(
                        label: 'Uscite',
                        amount: summary.expenses,
                        color: scheme.error,
                        currency: currency,
                        locale: locale,
                      ),
                    ),
                    Expanded(
                      child: _TotalTile(
                        label: 'Saldo',
                        amount: summary.balance,
                        color: summary.balance >= 0
                            ? Colors.green
                            : scheme.error,
                        currency: currency,
                        locale: locale,
                      ),
                    ),
                  ],
                ),
                if (summary.pendingCount > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${summary.pendingCount} movimenti in attesa di conferma',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (stats != null) ...[
          const SizedBox(height: 16),
          _ComparisonCard(stats: stats!, currency: currency, locale: locale),
        ],
        if (yearStats != null && yearStats!.series.isNotEmpty) ...[
          const SizedBox(height: 16),
          _YearBarsCard(
            stats: yearStats!,
            selectedMonth: month,
            currency: currency,
            locale: locale,
          ),
        ],
        if (summary.byCategory.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Per categoria', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final category in summary.byCategory)
            _CategoryRow(
              category: category,
              fraction: maxCategoryTotal == 0
                  ? 0
                  : category.total.abs() / maxCategoryTotal,
              currency: currency,
              locale: locale,
            ),
        ],
        const SizedBox(height: 16),
        Text('Movimenti', style: Theme.of(context).textTheme.titleSmall),
        if (data.entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nessun movimento in questo mese.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          for (final entry in data.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                entry.amount >= 0 ? Icons.south_west : Icons.north_east,
                color: entry.amount >= 0 ? Colors.green : scheme.error,
              ),
              title: Row(
                children: [
                  Expanded(child: Text(entry.title)),
                  Text(
                    _money(entry.amount, currency, locale),
                    style: TextStyle(
                      color: entry.amount >= 0 ? Colors.green : scheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              subtitle: Text(_entrySubtitle(entry, locale)),
              onTap: () => _BudgetEntryDialog.show(context, entry: entry),
              trailing: PopupMenuButton<String>(
                tooltip: 'Azioni movimento',
                onSelected: (value) {
                  final actions = ref.read(budgetActionsProvider);
                  if (value == 'confirm') {
                    actions.confirm(entry.id);
                  } else if (value == 'delete') {
                    actions.remove(entry.id);
                  }
                },
                itemBuilder: (menuContext) => [
                  if (entry.isPending)
                    const PopupMenuItem(
                      value: 'confirm',
                      child: ListTile(
                        leading: Icon(Icons.check_circle_outline),
                        title: Text('Conferma'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Elimina'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  String _entrySubtitle(BudgetEntry entry, String locale) {
    final date = DateTime.tryParse(entry.date);
    final when = date == null
        ? entry.date
        : DateFormat('d MMM', locale).format(date);
    final parts = [when];
    if (entry.category.isNotEmpty) parts.add(entry.category);
    if (entry.isPending) parts.add('in attesa');
    return parts.join(' · ');
  }
}

final class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.currency,
    required this.locale,
  });

  final String label;
  final double amount;
  final Color color;
  final String currency;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          _money(amount, currency, locale),
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

final class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.fraction,
    required this.currency,
    required this.locale,
  });

  final BudgetCategoryTotal category;
  final double fraction;
  final String currency;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(category.category)),
              Text(
                _money(category.total, currency, locale),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: fraction.clamp(0, 1),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

/// Confronto del mese col precedente (da `GET /budget/stats`).
final class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.stats,
    required this.currency,
    required this.locale,
  });

  final BudgetStats stats;
  final String currency;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confronto col mese precedente',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _row(
              context,
              label: 'Entrate',
              current: stats.income,
              previous: stats.prevIncome,
              lowerIsBetter: false,
            ),
            _row(
              context,
              label: 'Uscite',
              current: stats.expenses,
              previous: stats.prevExpenses,
              lowerIsBetter: true,
            ),
            _row(
              context,
              label: 'Saldo',
              current: stats.balance,
              previous: stats.prevBalance,
              lowerIsBetter: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required double current,
    required double previous,
    required bool lowerIsBetter,
  }) {
    final delta = current - previous;
    final good = lowerIsBetter ? delta <= 0 : delta >= 0;
    final color = good ? Colors.green : Theme.of(context).colorScheme.error;
    final sign = delta > 0 ? '+' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(_money(current, currency, locale)),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            child: Text(
              '$sign${_money(delta, currency, locale)}',
              textAlign: TextAlign.end,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grafico a barre del saldo mensile nell'anno (`/budget/stats?range=year`).
final class _YearBarsCard extends StatelessWidget {
  const _YearBarsCard({
    required this.stats,
    required this.selectedMonth,
    required this.currency,
    required this.locale,
  });

  final BudgetStats stats;
  final String selectedMonth;
  final String currency;
  final String locale;

  static const _barHeight = 110.0;

  @override
  Widget build(BuildContext context) {
    final maxAbs = stats.series.fold<double>(
      0,
      (max, period) => period.balance.abs() > max ? period.balance.abs() : max,
    );
    final year = stats.series.first.period.split('-').first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Andamento $year',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Saldo mensile (verde positivo, rosso negativo)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: _barHeight + 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final period in stats.series)
                    Expanded(child: _bar(context, period, maxAbs)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, BudgetPeriod period, double maxAbs) {
    final fraction = maxAbs == 0 ? 0.0 : period.balance.abs() / maxAbs;
    final negative = period.balance < 0;
    final color = negative ? Theme.of(context).colorScheme.error : Colors.green;
    final selected = period.period == selectedMonth;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: _barHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: fraction == 0 ? 0.02 : fraction,
                widthFactor: 0.6,
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: selected ? 1 : 0.55),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _monthLabel(period.period),
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }

  String _monthLabel(String period) {
    final date = DateTime.tryParse('$period-01');
    if (date == null) return period;
    return DateFormat('MMM', locale).format(date);
  }
}

String _money(double amount, String currency, String locale) {
  return NumberFormat.currency(
    locale: locale,
    name: currency,
    decimalDigits: 2,
  ).format(amount);
}

/// Dialog per creare/modificare un movimento.
final class _BudgetEntryDialog extends ConsumerStatefulWidget {
  const _BudgetEntryDialog({this.entry});

  final BudgetEntry? entry;

  static Future<void> show(BuildContext context, {BudgetEntry? entry}) {
    return showDialog<void>(
      context: context,
      builder: (_) => _BudgetEntryDialog(entry: entry),
    );
  }

  @override
  ConsumerState<_BudgetEntryDialog> createState() => _BudgetEntryDialogState();
}

final class _BudgetEntryDialogState extends ConsumerState<_BudgetEntryDialog> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  bool _isExpense = true;
  String? _category;
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry == null) return;
    _title.text = entry.title;
    _amount.text = entry.amount.abs() == entry.amount.abs().roundToDouble()
        ? entry.amount.abs().round().toString()
        : entry.amount.abs().toStringAsFixed(2);
    _isExpense = entry.amount < 0;
    _category = entry.category.isEmpty ? null : entry.category;
    _date = DateTime.tryParse(entry.date) ?? _date;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final value = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    if (title.isEmpty || value == null || value <= 0) return;
    final amount = _isExpense ? -value.abs() : value.abs();
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final actions = ref.read(budgetActionsProvider);
    final entry = widget.entry;
    final category = _category ?? '';
    final success = entry == null
        ? await actions.add(
            title: title,
            amount: amount,
            category: category,
            date: dateKey(_date),
          )
        : await actions.update(
            entry.id,
            title: title,
            amount: amount,
            category: category,
            date: dateKey(_date),
          );
    if (!mounted) return;
    if (!success) {
      setState(() => _busy = false);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(budgetCategoriesProvider).value ?? const <BudgetCategory>[];
    final wantedType = _isExpense ? 'expense' : 'income';
    final visible = categories.where((c) => c.type == wantedType).toList();
    // La categoria salvata può non essere (più) in lista: la aggiungo per non
    // perderla e per non far fallire il dropdown.
    final selected = _category == null || _category!.isEmpty
        ? null
        : visible.any((c) => c.key == _category)
        ? _category
        : '';

    return AlertDialog(
      title: Text(
        widget.entry == null ? 'Nuovo movimento' : 'Modifica movimento',
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Uscita')),
                  ButtonSegment(value: false, label: Text('Entrata')),
                ],
                selected: {_isExpense},
                onSelectionChanged: _busy
                    ? null
                    : (selection) =>
                          setState(() => _isExpense = selection.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Titolo'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Importo'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  if (selected == '')
                    DropdownMenuItem(
                      value: '',
                      child: Text(_category ?? 'Categoria'),
                    ),
                  for (final category in visible)
                    DropdownMenuItem(
                      value: category.key,
                      child: Text(category.name),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _category = value),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickDate,
                  icon: const Icon(Icons.event),
                  label: Text(DateFormat('d MMMM yyyy').format(_date)),
                ),
              ),
            ],
          ),
        ),
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
              : const Text('Salva'),
        ),
      ],
    );
  }
}
