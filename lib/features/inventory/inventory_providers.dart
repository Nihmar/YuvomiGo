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

/// Tutti gli oggetti in inventario (ricerca filtrata in locale).
final inventoryItemsProvider = FutureProvider.autoDispose<List<InventoryItem>>((
  ref,
) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.fetchItems();
});
