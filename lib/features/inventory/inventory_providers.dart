import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/inventory_repository.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/inventory/inventory_models.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) {
    throw StateError('InventoryRepository senza sessione attiva');
  }
  return InventoryRepository(api);
});

/// Ultimo errore di un'azione sull'inventario (SnackBar).
final inventoryActionErrorProvider =
    NotifierProvider<InventoryActionErrorNotifier, Object?>(
      InventoryActionErrorNotifier.new,
    );

final class InventoryActionErrorNotifier extends Notifier<Object?> {
  @override
  Object? build() => null;

  void clear() => state = null;
  void report(Object error) => state = error;
}

final inventoryItemsProvider =
    NotifierProvider.autoDispose<
      InventoryNotifier,
      AsyncValue<List<InventoryItem>>
    >(InventoryNotifier.new);

final class InventoryNotifier
    extends Notifier<AsyncValue<List<InventoryItem>>> {
  bool _loading = false;

  @override
  AsyncValue<List<InventoryItem>> build() {
    Future.microtask(load);
    return const AsyncLoading();
  }

  Future<void> load() => _fetch(showLoading: true);

  /// Ricarica mantenendo gli oggetti correnti (pull-to-refresh).
  Future<void> refresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (_loading) return;
    _loading = true;
    final repo = ref.read(inventoryRepositoryProvider);
    if (showLoading) state = const AsyncLoading();
    try {
      final items = await repo.fetchItems();
      if (!ref.mounted) return;
      state = AsyncData(items);
    } catch (e, st) {
      if (!ref.mounted) return;
      if (state.hasValue) {
        ref.read(inventoryActionErrorProvider.notifier).report(e);
      } else {
        state = AsyncError(e, st);
      }
    } finally {
      _loading = false;
    }
  }

  /// Crea l'oggetto; ritorna false se fallisce (dialog aperto).
  Future<bool> add({
    required String name,
    String? brand,
    String? model,
    String? serialNumber,
    required String category,
    int? locationId,
    String? purchaseDate,
    double? purchasePrice,
    String? vendor,
    int? warrantyMonths,
    String condition = 'good',
    String status = 'active',
    String? notes,
  }) async {
    final repo = ref.read(inventoryRepositoryProvider);
    ref.read(inventoryActionErrorProvider.notifier).clear();
    try {
      await repo.createItem(
        name: name,
        brand: brand,
        model: model,
        serialNumber: serialNumber,
        category: category,
        locationId: locationId,
        purchaseDate: purchaseDate,
        purchasePrice: purchasePrice,
        vendor: vendor,
        warrantyMonths: warrantyMonths,
        condition: condition,
        status: status,
        notes: notes,
      );
      if (!ref.mounted) return true;
      await _fetch(showLoading: false);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      ref.read(inventoryActionErrorProvider.notifier).report(e);
      return false;
    }
  }

  /// Aggiorna l'oggetto (sostituzione completa); false se fallisce.
  Future<bool> update(
    int id, {
    required String name,
    String? brand,
    String? model,
    String? serialNumber,
    required String category,
    int? locationId,
    String? purchaseDate,
    double? purchasePrice,
    String? vendor,
    int? warrantyMonths,
    String condition = 'good',
    String status = 'active',
    String? notes,
  }) async {
    final repo = ref.read(inventoryRepositoryProvider);
    ref.read(inventoryActionErrorProvider.notifier).clear();
    try {
      await repo.updateItem(
        id,
        name: name,
        brand: brand,
        model: model,
        serialNumber: serialNumber,
        category: category,
        locationId: locationId,
        purchaseDate: purchaseDate,
        purchasePrice: purchasePrice,
        vendor: vendor,
        warrantyMonths: warrantyMonths,
        condition: condition,
        status: status,
        notes: notes,
      );
      if (!ref.mounted) return true;
      await _fetch(showLoading: false);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      ref.read(inventoryActionErrorProvider.notifier).report(e);
      return false;
    }
  }

  Future<void> remove(int id) async {
    final repo = ref.read(inventoryRepositoryProvider);
    ref.read(inventoryActionErrorProvider.notifier).clear();
    try {
      await repo.deleteItem(id);
      if (!ref.mounted) return;
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.where((i) => i.id != id).toList());
      }
    } catch (e) {
      if (!ref.mounted) return;
      ref.read(inventoryActionErrorProvider.notifier).report(e);
    }
  }
}

/// Categorie disponibili per il form.
final inventoryCategoriesProvider =
    FutureProvider.autoDispose<List<InventoryCategory>>((ref) async {
      final repo = ref.watch(inventoryRepositoryProvider);
      return repo.fetchCategories();
    });

/// Posizioni disponibili per il form (albero).
final inventoryLocationsProvider =
    FutureProvider.autoDispose<List<InventoryLocation>>((ref) async {
      final repo = ref.watch(inventoryRepositoryProvider);
      return repo.fetchLocations();
    });
