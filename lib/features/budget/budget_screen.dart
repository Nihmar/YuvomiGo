import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
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
    final currency = ref.watch(appPreferencesValueProvider).currency;

    return Scaffold(
      appBar: AppBar(title: const Text('Budget')),
      body: Column(
        children: [
          _MonthBar(
            label: _monthLabel,
            onPrevious: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
            onToday: () => setState(
              () =>
                  _month = DateTime(DateTime.now().year, DateTime.now().month),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(budgetMonthProvider(_monthKey));
                try {
                  await ref.read(budgetMonthProvider(_monthKey).future);
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
                  currency: currency,
                  onRetry: () => ref.invalidate(budgetMonthProvider(_monthKey)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Mese precedente',
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
            tooltip: 'Mese successivo',
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
          TextButton(onPressed: onToday, child: const Text('Oggi')),
        ],
      ),
    );
  }
}

final class _BudgetBody extends StatelessWidget {
  const _BudgetBody({
    required this.data,
    required this.currency,
    required this.onRetry,
  });

  final BudgetMonth data;
  final String currency;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final maxCategoryTotal = summary.byCategory.fold<double>(
      0,
      (previous, c) => c.total.abs() > previous ? c.total.abs() : previous,
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
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
              title: Text(entry.title),
              subtitle: Text(_entrySubtitle(entry, locale)),
              trailing: Text(
                _money(entry.amount, currency, locale),
                style: TextStyle(
                  color: entry.amount >= 0 ? Colors.green : scheme.error,
                  fontWeight: FontWeight.w600,
                ),
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

String _money(double amount, String currency, String locale) {
  return NumberFormat.currency(
    locale: locale,
    name: currency,
    decimalDigits: 2,
  ).format(amount);
}
