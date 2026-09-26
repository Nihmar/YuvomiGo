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

int _atLeastZero(int value) => value < 0 ? 0 : value;

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

  Future<void> load() => _fetch(showLoading: true);

  /// Ricarica mantenendo le liste correnti (pull-to-refresh).
  Future<void> refresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (!ref.mounted) return;
    if (_loading) return;
    _loading = true;
    final repo = ref.read(shoppingRepositoryProvider);
    if (showLoading) state = const AsyncLoading();
    try {
      final lists = await repo.fetchLists();
      if (!ref.mounted) return;
      state = AsyncData(lists);
    } catch (e, st) {
      if (!ref.mounted) return;
      if (state.hasValue) {
        _errors(ref).report(e);
      } else {
        state = AsyncError(e, st);
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> add(String name) async {
    if (!ref.mounted) return;
    final repo = ref.read(shoppingRepositoryProvider);
    _errors(ref).clear();
    try {
      final created = await repo.createList(name);
      if (!ref.mounted) return;
      final prev = state.value ?? const <ShoppingList>[];
      state = AsyncData([...prev, created]);
    } catch (e) {
      if (!ref.mounted) return;
      _errors(ref).report(e);
    }
  }

  Future<void> rename(int id, String name) async {
    if (!ref.mounted) return;
    final repo = ref.read(shoppingRepositoryProvider);
    _errors(ref).clear();
    try {
      final updated = await repo.renameList(id, name);
      if (!ref.mounted) return;
      final prev = state.value ?? const <ShoppingList>[];
      state = AsyncData(prev.map((l) => l.id == id ? updated : l).toList());
    } catch (e) {
      if (!ref.mounted) return;
      _errors(ref).report(e);
    }
  }

  Future<void> remove(int id) async {
    if (!ref.mounted) return;
    final prev = state.value ?? const <ShoppingList>[];
    final repo = ref.read(shoppingRepositoryProvider);
    _errors(ref).clear();
    try {
      await repo.deleteList(id);
      if (!ref.mounted) return;
      state = AsyncData(prev.where((l) => l.id != id).toList());
    } catch (e) {
      if (!ref.mounted) return;
      _errors(ref).report(e);
    }
  }

  /// Aggiorna i conteggi di [listId] senza rileggere dal server: dopo una
  /// modifica agli articoli la summary della lista deve restare coerente.
  void applyItemDelta(int listId, {int totalDelta = 0, int checkedDelta = 0}) {
    if (!ref.mounted) return;
    final prev = state.value;
    if (prev == null || (totalDelta == 0 && checkedDelta == 0)) return;
    state = AsyncData([
      for (final l in prev)
        if (l.id == listId)
          l.copyWith(
            itemTotal: _atLeastZero(l.itemTotal + totalDelta),
            itemChecked: _atLeastZero(l.itemChecked + checkedDelta),
          )
        else
          l,
    ]);
  }
}

final shoppingListsProvider =
    NotifierProvider.autoDispose<
      ShoppingListsNotifier,
      AsyncValue<List<ShoppingList>>
    >(ShoppingListsNotifier.new);

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

  Future<void> load() => _fetch(showLoading: true);

  /// Ricarica mantenendo gli articoli correnti (pull-to-refresh).
  Future<void> refresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (!ref.mounted) return;
    if (_loading) return;
    _loading = true;
    final repo = ref.read(shoppingRepositoryProvider);
    if (showLoading) state = const AsyncLoading();
    try {
      final items = await repo.fetchItems(listId);
      if (!ref.mounted) return;
      state = AsyncData(items);
    } catch (e, st) {
      if (!ref.mounted) return;
      if (state.hasValue) {
        _errors(ref).report(e);
      } else {
        state = AsyncError(e, st);
      }
    } finally {
      _loading = false;
    }
  }

  Future<bool> add(String name, {String? quantity, String? category}) async {
    if (!ref.mounted) return false;
    final repo = ref.read(shoppingRepositoryProvider);
    _errors(ref).clear();
    try {
      final created = await repo.addItem(
        listId,
        name: name,
        quantity: quantity,
        category: category,
      );
      if (!ref.mounted) return false;
      final prev = state.value ?? const <ShoppingItem>[];
      state = AsyncData([...prev, created]);
      ref
          .read(shoppingListsProvider.notifier)
          .applyItemDelta(listId, totalDelta: 1);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      _errors(ref).report(e);
      return false;
    }
  }

  Future<void> toggle(int itemId, bool isChecked) async {
    if (!ref.mounted) return;
    final repo = ref.read(shoppingRepositoryProvider);
    final wasChecked = _isChecked(itemId);
    _errors(ref).clear();
    try {
      final updated = await repo.toggleItem(itemId, isChecked);
      if (!ref.mounted) return;
      final prev = state.value ?? const <ShoppingItem>[];
      state = AsyncData(prev.map((i) => i.id == itemId ? updated : i).toList());
      if (wasChecked != isChecked) {
        ref
            .read(shoppingListsProvider.notifier)
            .applyItemDelta(listId, checkedDelta: isChecked ? 1 : -1);
      }
    } catch (e) {
      if (!ref.mounted) return;
      _errors(ref).report(e);
    }
  }

  Future<void> remove(int itemId) async {
    if (!ref.mounted) return;
    final prev = state.value ?? const <ShoppingItem>[];
    final wasChecked = _isChecked(itemId);
    final repo = ref.read(shoppingRepositoryProvider);
    _errors(ref).clear();
    try {
      await repo.deleteItem(itemId);
      if (!ref.mounted) return;
      state = AsyncData(prev.where((i) => i.id != itemId).toList());
      ref
          .read(shoppingListsProvider.notifier)
          .applyItemDelta(
            listId,
            totalDelta: -1,
            checkedDelta: wasChecked ? -1 : 0,
          );
    } catch (e) {
      if (!ref.mounted) return;
      _errors(ref).report(e);
    }
  }

  bool _isChecked(int itemId) {
    for (final i in state.value ?? const <ShoppingItem>[]) {
      if (i.id == itemId) return i.isChecked;
    }
    return false;
  }
}

final shoppingItemsProvider = NotifierProvider.family
    .autoDispose<ShoppingItemsNotifier, AsyncValue<List<ShoppingItem>>, int>(
      (listId) => ShoppingItemsNotifier(listId),
    );

/// Le categorie di spesa disponibili (caricate on demand dal dettaglio).
final shoppingCategoriesProvider =
    FutureProvider.autoDispose<List<ShoppingCategory>>((ref) async {
      final repo = ref.watch(shoppingRepositoryProvider);
      return repo.fetchCategories();
    });
