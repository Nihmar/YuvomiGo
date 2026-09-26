import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/meal_repository.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/meals/meal_models.dart';

final mealRepositoryProvider = Provider<MealRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) throw StateError('MealRepository senza sessione attiva');
  return MealRepository(api);
});

/// Ultimo errore di un'azione sui pasti: lo screen lo mostra come SnackBar.
final mealsActionErrorProvider =
    NotifierProvider<MealsActionErrorNotifier, Object?>(
      MealsActionErrorNotifier.new,
    );

final class MealsActionErrorNotifier extends Notifier<Object?> {
  @override
  Object? build() => null;

  void clear() => state = null;
  void report(Object error) => state = error;
}

/// Pasti della settimana identificata dal giorno [week] (`YYYY-MM-DD`).
final mealsWeekProvider = NotifierProvider.family
    .autoDispose<MealsNotifier, AsyncValue<MealWeek>, String>(
      MealsNotifier.new,
    );

final class MealsNotifier extends Notifier<AsyncValue<MealWeek>> {
  MealsNotifier(this.week);

  final String week;
  bool _loading = false;

  @override
  AsyncValue<MealWeek> build() {
    Future.microtask(load);
    return const AsyncLoading();
  }

  Future<void> load() => _fetch(showLoading: true);

  /// Ricarica mantenendo i pasti correnti (pull-to-refresh).
  Future<void> refresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (!ref.mounted) return;
    if (_loading) return;
    _loading = true;
    final repo = ref.read(mealRepositoryProvider);
    if (showLoading) state = const AsyncLoading();
    try {
      final data = await repo.fetchWeek(week);
      if (!ref.mounted) return;
      state = AsyncData(data);
    } catch (e, st) {
      if (!ref.mounted) return;
      if (state.hasValue) {
        ref.read(mealsActionErrorProvider.notifier).report(e);
      } else {
        state = AsyncError(e, st);
      }
    } finally {
      _loading = false;
    }
  }

  /// Crea il pasto; ritorna false se fallisce (il dialog resta aperto).
  Future<bool> add({
    required String date,
    required String mealType,
    required String title,
    String? notes,
  }) async {
    if (!ref.mounted) return false;
    final repo = ref.read(mealRepositoryProvider);
    ref.read(mealsActionErrorProvider.notifier).clear();
    try {
      await repo.createMeal(
        date: date,
        mealType: mealType,
        title: title,
        notes: notes,
      );
      if (!ref.mounted) return true;
      // La risposta del POST non basta alla vista settimanale: ricarico.
      await _fetch(showLoading: false);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      ref.read(mealsActionErrorProvider.notifier).report(e);
      return false;
    }
  }

  Future<void> remove(int id) async {
    if (!ref.mounted) return;
    final repo = ref.read(mealRepositoryProvider);
    ref.read(mealsActionErrorProvider.notifier).clear();
    try {
      await repo.deleteMeal(id);
      if (!ref.mounted) return;
      final current = state.value;
      if (current != null) {
        state = AsyncData(
          MealWeek(
            weekStart: current.weekStart,
            weekEnd: current.weekEnd,
            meals: current.meals.where((m) => m.id != id).toList(),
          ),
        );
      }
    } catch (e) {
      if (!ref.mounted) return;
      ref.read(mealsActionErrorProvider.notifier).report(e);
    }
  }
}
