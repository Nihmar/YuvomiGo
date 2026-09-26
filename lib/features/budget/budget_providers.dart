import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/budget_repository.dart';
import 'package:yuvomigo/features/budget/budget_models.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) throw StateError('BudgetRepository senza sessione attiva');
  return BudgetRepository(api);
});

/// Summary + movimenti dello stesso mese, caricati insieme.
final class BudgetMonth {
  const BudgetMonth({required this.summary, required this.entries});

  final BudgetSummary summary;
  final List<BudgetEntry> entries;
}

final budgetMonthProvider = FutureProvider.family
    .autoDispose<BudgetMonth, String>((ref, month) async {
      final repo = ref.watch(budgetRepositoryProvider);
      final summary = await repo.fetchSummary(month);
      final entries = await repo.fetchEntries(month);
      return BudgetMonth(summary: summary, entries: entries);
    });

/// Statistiche del mese (confronto col precedente). Se fallisce, la card
/// nel screen viene semplicemente omessa.
final budgetStatsProvider = FutureProvider.family
    .autoDispose<BudgetStats, String>((ref, month) async {
      final repo = ref.watch(budgetRepositoryProvider);
      return repo.fetchStats(month);
    });
