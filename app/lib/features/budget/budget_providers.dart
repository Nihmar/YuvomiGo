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

/// Andamento dell'anno che contiene [month] (serie dei 12 mesi).
final budgetYearStatsProvider = FutureProvider.family
    .autoDispose<BudgetStats, String>((ref, month) async {
      final repo = ref.watch(budgetRepositoryProvider);
      return repo.fetchStats(month, range: 'year');
    });

/// Ultimo errore di un'azione sui movimenti (SnackBar).
final budgetActionErrorProvider =
    NotifierProvider<BudgetActionErrorNotifier, Object?>(
      BudgetActionErrorNotifier.new,
    );

final class BudgetActionErrorNotifier extends Notifier<Object?> {
  @override
  Object? build() => null;

  void clear() => state = null;
  void report(Object error) => state = error;
}

/// Categorie per il form dei movimenti.
final budgetCategoriesProvider =
    FutureProvider.autoDispose<List<BudgetCategory>>((ref) async {
      final repo = ref.watch(budgetRepositoryProvider);
      return repo.fetchCategories();
    });

/// Azioni di scrittura sui movimenti: dopo ognuna le viste si ricaricano.
final budgetActionsProvider = Provider<BudgetActions>(BudgetActions.new);

final class BudgetActions {
  BudgetActions(this._ref);

  final Ref _ref;

  void _reload() {
    _ref.invalidate(budgetMonthProvider);
    _ref.invalidate(budgetStatsProvider);
    _ref.invalidate(budgetYearStatsProvider);
  }

  /// Crea il movimento; false se fallisce (dialog aperto).
  Future<bool> add({
    required String title,
    required double amount,
    required String category,
    required String date,
  }) async {
    final repo = _ref.read(budgetRepositoryProvider);
    _ref.read(budgetActionErrorProvider.notifier).clear();
    try {
      await repo.createEntry(
        title: title,
        amount: amount,
        category: category,
        date: date,
      );
      _reload();
      return true;
    } catch (e) {
      _ref.read(budgetActionErrorProvider.notifier).report(e);
      return false;
    }
  }

  Future<bool> update(
    int id, {
    required String title,
    required double amount,
    required String category,
    required String date,
  }) async {
    final repo = _ref.read(budgetRepositoryProvider);
    _ref.read(budgetActionErrorProvider.notifier).clear();
    try {
      await repo.updateEntry(
        id,
        title: title,
        amount: amount,
        category: category,
        date: date,
      );
      _reload();
      return true;
    } catch (e) {
      _ref.read(budgetActionErrorProvider.notifier).report(e);
      return false;
    }
  }

  Future<void> remove(int id) async {
    final repo = _ref.read(budgetRepositoryProvider);
    _ref.read(budgetActionErrorProvider.notifier).clear();
    try {
      await repo.deleteEntry(id);
      _reload();
    } catch (e) {
      _ref.read(budgetActionErrorProvider.notifier).report(e);
    }
  }

  Future<void> confirm(int id) async {
    final repo = _ref.read(budgetRepositoryProvider);
    _ref.read(budgetActionErrorProvider.notifier).clear();
    try {
      await repo.confirmEntry(id);
      _reload();
    } catch (e) {
      _ref.read(budgetActionErrorProvider.notifier).report(e);
    }
  }
}
