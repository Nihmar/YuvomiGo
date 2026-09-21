import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/shopping_repository.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/shopping/shopping_models.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) throw StateError('ShoppingRepository senza sessione attiva');
  return ShoppingRepository(api);
});

/// Ultimo errore di un'azione sulle liste/articoli. Lo stato resta intatto:
/// gli screen lo mostrano come SnackBar. Null = nessuna azione fallita.
final shoppingActionErrorProvider =
    NotifierProvider<ShoppingActionErrorNotifier, Object?>(
  ShoppingActionErrorNotifier.new,
);

final class ShoppingActionErrorNotifier extends Notifier<Object?> {
  @override
  Object? build() => null;

  void clear() => state = null;
  void report(Object error) => state = error;
}

ShoppingActionErrorNotifier _errors(Ref ref) =>
    ref.read(shoppingActionErrorProvider.notifier);

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
    _errors(ref).clear();
    try {
      final created = await repo.createList(name);
      final prev = state.value ?? const <ShoppingList>[];
      state = AsyncData([...prev, created]);
    } catch (e) {
      _errors(ref).report(e);
    }
  }

  Future<void> rename(int id, String name) async {
    final repo = ref.read(shoppingRepositoryProvider);
    _errors(ref).clear();
    try {
      final updated = await repo.renameList(id, name);
      final prev = state.value ?? const <ShoppingList>[];
      state = AsyncData(prev.map((l) => l.id == id ? updated : l).toList());
    } catch (e) {
      _errors(ref).report(e);
    }
  }

  Future<void> remove(int id) async {
    final prev = state.value ?? const <ShoppingList>[];
    final repo = ref.read(shoppingRepositoryProvider);
    _errors(ref).clear();
    try {
      await repo.deleteList(id);
      state = AsyncData(prev.where((l) => l.id != id).toList());
    } catch (e) {
      _errors(ref).report(e);
    }
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
    _errors(ref).clear();
    try {
      final created = await repo.addItem(listId, name: name, quantity: quantity);
      final prev = state.value ?? const <ShoppingItem>[];
      state = AsyncData([...prev, created]);
    } catch (e) {
      _errors(ref).report(e);
    }
  }

  Future<void> toggle(int itemId, bool isChecked) async {
    final repo = ref.read(shoppingRepositoryProvider);
    _errors(ref).clear();
    try {
      final updated = await repo.toggleItem(itemId, isChecked);
      final prev = state.value ?? const <ShoppingItem>[];
      state = AsyncData(prev.map((i) => i.id == itemId ? updated : i).toList());
    } catch (e) {
      _errors(ref).report(e);
    }
  }

  Future<void> remove(int itemId) async {
    final prev = state.value ?? const <ShoppingItem>[];
    final repo = ref.read(shoppingRepositoryProvider);
    _errors(ref).clear();
    try {
      await repo.deleteItem(itemId);
      state = AsyncData(prev.where((i) => i.id != itemId).toList());
    } catch (e) {
      _errors(ref).report(e);
    }
  }
}

final shoppingItemsProvider = NotifierProvider.family.autoDispose<
  ShoppingItemsNotifier,
  AsyncValue<List<ShoppingItem>>,
  int>(
  (listId) => ShoppingItemsNotifier(listId),
);
