import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/waste_repository.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/waste/waste_models.dart';

final wasteRepositoryProvider = Provider<WasteRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) throw StateError('WasteRepository senza sessione attiva');
  return WasteRepository(api);
});

/// Ultimo errore di un'azione sui rifiuti (SnackBar).
final wasteActionErrorProvider =
    NotifierProvider<WasteActionErrorNotifier, Object?>(
      WasteActionErrorNotifier.new,
    );

final class WasteActionErrorNotifier extends Notifier<Object?> {
  @override
  Object? build() => null;

  void clear() => state = null;
  void report(Object error) => state = error;
}

/// Prossima raccolta per tipo.
final wasteNextProvider = FutureProvider.autoDispose<List<WasteNextPickup>>((
  ref,
) async {
  final repo = ref.watch(wasteRepositoryProvider);
  return repo.fetchNextPickups();
});

/// Tipi di raccolta (per il form delle raccolte extra).
final wasteTypesProvider = FutureProvider.autoDispose<List<WasteType>>((
  ref,
) async {
  final repo = ref.watch(wasteRepositoryProvider);
  return repo.fetchTypes();
});

/// Raccolte straordinarie + azioni.
final wastePickupsProvider =
    NotifierProvider.autoDispose<
      WastePickupsNotifier,
      AsyncValue<List<WastePickup>>
    >(WastePickupsNotifier.new);

final class WastePickupsNotifier
    extends Notifier<AsyncValue<List<WastePickup>>> {
  bool _loading = false;

  @override
  AsyncValue<List<WastePickup>> build() {
    Future.microtask(load);
    return const AsyncLoading();
  }

  Future<void> load() => _fetch(showLoading: true);

  /// Ricarica mantenendo le raccolte correnti (pull-to-refresh).
  Future<void> refresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (!ref.mounted) return;
    if (_loading) return;
    _loading = true;
    final repo = ref.read(wasteRepositoryProvider);
    if (showLoading) state = const AsyncLoading();
    try {
      final pickups = await repo.fetchPickups();
      if (!ref.mounted) return;
      state = AsyncData(pickups);
    } catch (e, st) {
      if (!ref.mounted) return;
      if (state.hasValue) {
        ref.read(wasteActionErrorProvider.notifier).report(e);
      } else {
        state = AsyncError(e, st);
      }
    } finally {
      _loading = false;
    }
  }

  /// Crea la raccolta; ritorna false se fallisce (dialog aperto).
  Future<bool> add({
    required int typeId,
    required String date,
    String? note,
  }) async {
    if (!ref.mounted) return false;
    final repo = ref.read(wasteRepositoryProvider);
    ref.read(wasteActionErrorProvider.notifier).clear();
    try {
      await repo.createPickup(typeId: typeId, date: date, note: note);
      if (!ref.mounted) return true;
      await _fetch(showLoading: false);
      ref.invalidate(wasteNextProvider);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      ref.read(wasteActionErrorProvider.notifier).report(e);
      return false;
    }
  }

  Future<bool> update(int id, {required String date, String? note}) async {
    if (!ref.mounted) return false;
    final repo = ref.read(wasteRepositoryProvider);
    ref.read(wasteActionErrorProvider.notifier).clear();
    try {
      await repo.updatePickup(id, date: date, note: note);
      if (!ref.mounted) return true;
      await _fetch(showLoading: false);
      ref.invalidate(wasteNextProvider);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      ref.read(wasteActionErrorProvider.notifier).report(e);
      return false;
    }
  }

  Future<void> remove(int id) async {
    if (!ref.mounted) return;
    final repo = ref.read(wasteRepositoryProvider);
    ref.read(wasteActionErrorProvider.notifier).clear();
    try {
      await repo.deletePickup(id);
      if (!ref.mounted) return;
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.where((p) => p.id != id).toList());
      }
      ref.invalidate(wasteNextProvider);
    } catch (e) {
      if (!ref.mounted) return;
      ref.read(wasteActionErrorProvider.notifier).report(e);
    }
  }
}
