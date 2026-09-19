import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/shopping_repository.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/shopping/shopping_models.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) throw StateError('ShoppingRepository senza sessione attiva');
  return ShoppingRepository(api);
});

/// Le liste di spesa (con conteggi) + azioni.
class ShoppingListsNotifier extends Notifier<AsyncValue<List<ShoppingList>>> {
  bool _loading = false;

  @override
  AsyncValue<List<ShoppingList>> build() {
    // Il fetch parte in un microtask: modificare `state` dentro `build()`
    // (lifecycle) non è permesso, ma un microtask gira dopo il build.
    Future.microtask(load);
    return const AsyncLoading();
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    final repo = ref.read(shoppingRepositoryProvider);
    try {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => repo.fetchLists());
    } finally {
      _loading = false;
    }
  }

  Future<void> add(String name) async {
    final repo = ref.read(shoppingRepositoryProvider);
    final created = await repo.createList(name);
    final prev = state.value ?? const <ShoppingList>[];
    state = AsyncData([...prev, created]);
  }

  Future<void> rename(int id, String name) async {
    final repo = ref.read(shoppingRepositoryProvider);
    final updated = await repo.renameList(id, name);
    final prev = state.value ?? const <ShoppingList>[];
    state = AsyncData(prev.map((l) => l.id == id ? updated : l).toList());
  }

  Future<void> remove(int id) async {
    final repo = ref.read(shoppingRepositoryProvider);
    await repo.deleteList(id);
    final prev = state.value ?? const <ShoppingList>[];
    state = AsyncData(prev.where((l) => l.id != id).toList());
  }
}

final shoppingListsProvider =
    NotifierProvider.autoDispose<ShoppingListsNotifier, AsyncValue<List<ShoppingList>>>(
  ShoppingListsNotifier.new,
);

/// Gli articoli di una lista (Family su listId) + azioni.
class ShoppingItemsNotifier extends Notifier<AsyncValue<List<ShoppingItem>>> {
  ShoppingItemsNotifier(this.listId);

  final int listId;
  bool _loading = false;

  @override
  AsyncValue<List<ShoppingItem>> build() {
    Future.microtask(load);
    return const AsyncLoading();
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    final repo = ref.read(shoppingRepositoryProvider);
    try {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => repo.fetchItems(listId));
    } finally {
      _loading = false;
    }
  }

  Future<void> add(String name, {String? quantity}) async {
    final repo = ref.read(shoppingRepositoryProvider);
    final created = await repo.addItem(listId, name: name, quantity: quantity);
    final prev = state.value ?? const <ShoppingItem>[];
    state = AsyncData([...prev, created]);
  }

  Future<void> toggle(int itemId, bool isChecked) async {
    final repo = ref.read(shoppingRepositoryProvider);
    final updated = await repo.toggleItem(itemId, isChecked);
    final prev = state.value ?? const <ShoppingItem>[];
    state = AsyncData(prev.map((i) => i.id == itemId ? updated : i).toList());
  }

  Future<void> remove(int itemId) async {
    final repo = ref.read(shoppingRepositoryProvider);
    await repo.deleteItem(itemId);
    final prev = state.value ?? const <ShoppingItem>[];
    state = AsyncData(prev.where((i) => i.id != itemId).toList());
  }
}

final shoppingItemsProvider = NotifierProvider.family.autoDispose<
  ShoppingItemsNotifier,
  AsyncValue<List<ShoppingItem>>,
  int>(
  (listId) => ShoppingItemsNotifier(listId),
);
