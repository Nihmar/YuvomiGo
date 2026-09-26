import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/pantry_repository.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/pantry/pantry_models.dart';

final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) throw StateError('PantryRepository senza sessione attiva');
  return PantryRepository(api);
});

/// Ultimo errore di un'azione sulla dispensa (SnackBar).
final pantryActionErrorProvider =
    NotifierProvider<PantryActionErrorNotifier, Object?>(
      PantryActionErrorNotifier.new,
    );

final class PantryActionErrorNotifier extends Notifier<Object?> {
  @override
  Object? build() => null;

  void clear() => state = null;
  void report(Object error) => state = error;
}

final pantryProvider =
    NotifierProvider.autoDispose<PantryNotifier, AsyncValue<PantryData>>(
      PantryNotifier.new,
    );

final class PantryNotifier extends Notifier<AsyncValue<PantryData>> {
  bool _loading = false;

  @override
  AsyncValue<PantryData> build() {
    Future.microtask(load);
    return const AsyncLoading();
  }

  Future<void> load() => _fetch(showLoading: true);

  /// Ricarica mantenendo la dispensa corrente (pull-to-refresh).
  Future<void> refresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (_loading) return;
    _loading = true;
    final repo = ref.read(pantryRepositoryProvider);
    if (showLoading) state = const AsyncLoading();
    try {
      final data = await repo.fetchPantry();
      if (!ref.mounted) return;
      state = AsyncData(data);
    } catch (e, st) {
      if (!ref.mounted) return;
      if (state.hasValue) {
        ref.read(pantryActionErrorProvider.notifier).report(e);
      } else {
        state = AsyncError(e, st);
      }
    } finally {
      _loading = false;
    }
  }

  /// Crea l'articolo; ritorna false se fallisce (dialog aperto).
  Future<bool> add({
    required String name,
    double? quantity,
    String? unit,
    int? locationId,
    String? category,
    String? expiresOn,
    double? minQuantity,
    String? notes,
  }) async {
    final repo = ref.read(pantryRepositoryProvider);
    ref.read(pantryActionErrorProvider.notifier).clear();
    try {
      await repo.createItem(
        name: name,
        quantity: quantity,
        unit: unit,
        locationId: locationId,
        category: category,
        expiresOn: expiresOn,
        minQuantity: minQuantity,
        notes: notes,
      );
      if (!ref.mounted) return true;
      await _fetch(showLoading: false);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      ref.read(pantryActionErrorProvider.notifier).report(e);
      return false;
    }
  }

  /// Aggiorna l'articolo (sostituzione completa); false se fallisce.
  Future<bool> update(
    int id, {
    required String name,
    double? quantity,
    String? unit,
    int? locationId,
    String? category,
    String? expiresOn,
    double? minQuantity,
    String? notes,
  }) async {
    final repo = ref.read(pantryRepositoryProvider);
    ref.read(pantryActionErrorProvider.notifier).clear();
    try {
      await repo.updateItem(
        id,
        name: name,
        quantity: quantity,
        unit: unit,
        locationId: locationId,
        category: category,
        expiresOn: expiresOn,
        minQuantity: minQuantity,
        notes: notes,
      );
      if (!ref.mounted) return true;
      await _fetch(showLoading: false);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      ref.read(pantryActionErrorProvider.notifier).report(e);
      return false;
    }
  }

  Future<void> remove(int id) async {
    final repo = ref.read(pantryRepositoryProvider);
    ref.read(pantryActionErrorProvider.notifier).clear();
    try {
      await repo.deleteItem(id);
      if (!ref.mounted) return;
      final current = state.value;
      if (current != null) {
        state = AsyncData(
          PantryData(
            items: current.items.where((i) => i.id != id).toList(),
            locations: current.locations,
            categories: current.categories,
          ),
        );
      }
    } catch (e) {
      if (!ref.mounted) return;
      ref.read(pantryActionErrorProvider.notifier).report(e);
    }
  }
}
