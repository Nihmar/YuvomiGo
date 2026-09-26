import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/shopping_repository.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/shopping/shopping_models.dart';
import 'package:yuvomigo/features/shopping/shopping_providers.dart';
import 'package:yuvomigo/features/shopping/shopping_screen.dart';
import 'package:yuvomigo/features/shopping/shopping_list_detail_screen.dart';

import 'utils/fake_auth_controller.dart';
import 'utils/in_memory_storage.dart';

/// Repository Spesa in memoria: sostituisce il network per i widget test.
final class FakeShoppingRepository extends ShoppingRepository {
  FakeShoppingRepository()
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  final List<ShoppingList> lists = [
    ShoppingList(id: 1, name: 'Super', itemTotal: 5, itemChecked: 2),
    ShoppingList(id: 2, name: 'Farmacia', itemTotal: 1, itemChecked: 0),
  ];
  final Map<int, List<ShoppingItem>> itemsByList = {
    1: [
      ShoppingItem(id: 10, name: 'Latte', quantity: '2'),
      ShoppingItem(id: 11, name: 'Pane', isChecked: true),
    ],
    2: [ShoppingItem(id: 20, name: 'Tisane')],
  };
  int _nextId = 100;

  @override
  Future<List<ShoppingList>> fetchLists() async => lists.toList();

  @override
  Future<ShoppingList> createList(String name) async {
    final l = ShoppingList(id: _nextId++, name: name);
    lists.add(l);
    return l;
  }

  @override
  Future<ShoppingList> renameList(int id, String name) async {
    final idx = lists.indexWhere((l) => l.id == id);
    if (idx >= 0) lists[idx] = ShoppingList(id: id, name: name);
    return ShoppingList(id: id, name: name);
  }

  @override
  Future<void> deleteList(int id) async => lists.removeWhere((l) => l.id == id);

  @override
  Future<List<ShoppingItem>> fetchItems(int listId) async =>
      (itemsByList[listId] ?? const <ShoppingItem>[]).toList();

  @override
  Future<ShoppingItem> addItem(
    int listId, {
    required String name,
    String? quantity,
    String? category,
  }) {
    final item = ShoppingItem(id: _nextId++, name: name, quantity: quantity);
    itemsByList.putIfAbsent(listId, () => []).add(item);
    return Future.value(item);
  }

  @override
  Future<ShoppingItem> toggleItem(int itemId, bool isChecked) {
    for (final items in itemsByList.values) {
      final idx = items.indexWhere((i) => i.id == itemId);
      if (idx >= 0) {
        items[idx] = ShoppingItem(
          id: itemId,
          name: items[idx].name,
          quantity: items[idx].quantity,
          isChecked: isChecked,
        );
        return Future.value(items[idx]);
      }
    }
    return Future.value(
      ShoppingItem(id: itemId, name: '?', isChecked: isChecked),
    );
  }

  @override
  Future<void> deleteItem(int itemId) async {
    for (final items in itemsByList.values) {
      items.removeWhere((i) => i.id == itemId);
    }
  }
}

/// Il server non raggiungibile: le azioni falliscono, lo stato resta intatto.
final class FailingShoppingRepository extends FakeShoppingRepository {
  @override
  Future<ShoppingItem> toggleItem(int itemId, bool isChecked) =>
      Future.error(Exception('offline'));
}

Widget _pump(Widget child, FakeShoppingRepository repo) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => FakeAuthController(Authenticated(user: fakeUser())),
      ),
      shoppingRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('Lists screen renders the shopping lists', (tester) async {
    final repo = FakeShoppingRepository();
    await tester.pumpWidget(_pump(const ShoppingScreen(), repo));
    await tester.pumpAndSettle();

    expect(find.text('Super'), findsOneWidget);
    expect(find.text('Farmacia'), findsOneWidget);
    // "3 aperti" = 5 total - 2 spuntati della lista Super.
    expect(find.textContaining('3 aperti'), findsOneWidget);
  });

  testWidgets('Creating a list adds it to the list', (tester) async {
    final repo = FakeShoppingRepository();
    await tester.pumpWidget(_pump(const ShoppingScreen(), repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Mercato');
    await tester.tap(find.text('Aggiungi'));
    await tester.pumpAndSettle();

    expect(find.text('Mercato'), findsOneWidget);
    expect(repo.lists.map((l) => l.name), contains('Mercato'));
  });

  testWidgets('Detail screen renders items with checkboxes', (tester) async {
    final repo = FakeShoppingRepository();
    await tester.pumpWidget(
      _pump(const ShoppingListDetailScreen(listId: 1), repo),
    );
    await tester.pumpAndSettle();

    expect(find.text('Latte (2)'), findsOneWidget);
    expect(find.text('Pane'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));
  });

  testWidgets('Toggling an item updates its checked state', (tester) async {
    final repo = FakeShoppingRepository();
    await tester.pumpWidget(
      _pump(const ShoppingListDetailScreen(listId: 1), repo),
    );
    await tester.pumpAndSettle();

    // Spunta "Latte" (id 10, inizialmente non spuntato).
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(
      repo.itemsByList[1]!.firstWhere((i) => i.id == 10).isChecked,
      isTrue,
    );
  });

  testWidgets('Adding an item appends it', (tester) async {
    final repo = FakeShoppingRepository();
    await tester.pumpWidget(
      _pump(const ShoppingListDetailScreen(listId: 1), repo),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Uova');
    await tester.tap(find.text('Aggiungi'));
    await tester.pumpAndSettle();

    // "Uova" compare nella lista (e, prima della chiusura, nel dialog).
    expect(find.text('Uova'), findsWidgets);
    // Verifica sul repository: esattamente un articolo "Uova" nella lista 1.
    expect(repo.itemsByList[1]!.where((i) => i.name == 'Uova'), hasLength(1));
  });

  testWidgets('Adding an item with quantity sends it to the server', (
    tester,
  ) async {
    final repo = FakeShoppingRepository();
    await tester.pumpWidget(
      _pump(const ShoppingListDetailScreen(listId: 1), repo),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Uova');
    await tester.enterText(find.byType(TextField).at(1), '6');
    await tester.tap(find.text('Aggiungi'));
    await tester.pumpAndSettle();

    expect(find.text('Uova (6)'), findsOneWidget);
    final created = repo.itemsByList[1]!.firstWhere((i) => i.name == 'Uova');
    expect(created.quantity, '6');
  });

  testWidgets('Failed toggle keeps the item and shows an error', (
    tester,
  ) async {
    final repo = FailingShoppingRepository();
    await tester.pumpWidget(
      _pump(const ShoppingListDetailScreen(listId: 1), repo),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.text('Latte (2)'), findsOneWidget);
    expect(find.textContaining('Operazione non riuscita'), findsOneWidget);
  });

  testWidgets('Renaming a list updates it', (tester) async {
    final repo = FakeShoppingRepository();
    await tester.pumpWidget(_pump(const ShoppingScreen(), repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rinomina'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Supermercato');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(find.text('Supermercato'), findsOneWidget);
    expect(repo.lists.map((l) => l.name), contains('Supermercato'));
  });

  testWidgets('Deleting a list removes it', (tester) async {
    final repo = FakeShoppingRepository();
    await tester.pumpWidget(_pump(const ShoppingScreen(), repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();

    expect(repo.lists, hasLength(1));
    expect(find.text('Super'), findsNothing);
  });
}
