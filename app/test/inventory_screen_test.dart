import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/inventory_repository.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/inventory/inventory_models.dart';
import 'package:yuvomigo/features/inventory/inventory_providers.dart';
import 'package:yuvomigo/features/inventory/inventory_screen.dart';

import 'utils/fake_auth_controller.dart';
import 'utils/in_memory_storage.dart';

final class FakeInventoryRepository extends InventoryRepository {
  FakeInventoryRepository()
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  final List<InventoryItem> items = [
    const InventoryItem(
      id: 1,
      name: 'Frigorifero',
      brand: 'Bosch',
      model: 'KGN39',
      serialNumber: 'SN123',
      category: 'household',
      categoryName: 'Elettrodomestici',
      locationPath: 'Cucina',
      purchasePrice: 799.9,
      warrantyMonths: 24,
      trackedDates: [
        InventoryTrackedDate(id: 5, label: 'Garanzia', date: '2026-05-01'),
      ],
    ),
    const InventoryItem(
      id: 2,
      name: 'Trapano',
      brand: 'Makita',
      status: 'lost',
    ),
  ];
  final List<String> created = [];
  final List<String> updated = [];
  int _nextId = 100;

  @override
  Future<List<InventoryItem>> fetchItems({String? query}) async =>
      items.toList();

  @override
  Future<List<InventoryCategory>> fetchCategories() async => const [
    InventoryCategory(id: 1, key: 'household', name: 'Casa'),
  ];

  @override
  Future<List<InventoryLocation>> fetchLocations() async => const [
    InventoryLocation(id: 1, name: 'Cantina'),
  ];

  @override
  Future<InventoryItem> createItem({
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
    created.add(name);
    final item = InventoryItem(
      id: _nextId++,
      name: name,
      brand: brand,
      model: model,
      serialNumber: serialNumber,
      category: category,
      status: status,
      condition: condition,
    );
    items.add(item);
    return item;
  }

  @override
  Future<InventoryItem> updateItem(
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
    updated.add(name);
    final index = items.indexWhere((i) => i.id == id);
    final item = InventoryItem(
      id: id,
      name: name,
      brand: brand,
      model: model,
      serialNumber: serialNumber,
      category: category,
      status: status,
      condition: condition,
      trackedDates: items[index].trackedDates,
    );
    items[index] = item;
    return item;
  }

  @override
  Future<void> deleteItem(int id) async {
    items.removeWhere((i) => i.id == id);
  }
}

Widget _pump(FakeInventoryRepository repo) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => FakeAuthController(Authenticated(user: fakeUser())),
      ),
      inventoryRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(home: InventoryScreen()),
  );
}

void main() {
  testWidgets('Inventory screen renders items with category and location', (
    tester,
  ) async {
    final repo = FakeInventoryRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    expect(find.text('Frigorifero'), findsOneWidget);
    expect(find.text('Trapano'), findsOneWidget);
    expect(find.textContaining('Bosch KGN39'), findsOneWidget);
    expect(find.textContaining('Cucina'), findsOneWidget);
    expect(find.textContaining('Perso'), findsOneWidget);
  });

  testWidgets('Search filters the list', (tester) async {
    final repo = FakeInventoryRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'trap');
    await tester.pumpAndSettle();

    expect(find.text('Trapano'), findsOneWidget);
    expect(find.text('Frigorifero'), findsNothing);
  });

  testWidgets('Tapping an item opens the detail', (tester) async {
    final repo = FakeInventoryRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Frigorifero'));
    await tester.pumpAndSettle();

    expect(find.text('Posizione'), findsOneWidget);
    expect(find.text('Seriale'), findsOneWidget);
    expect(find.text('SN123'), findsOneWidget);
    expect(find.text('Garanzia'), findsOneWidget);
    expect(find.textContaining('2026-05-01'), findsOneWidget);
  });

  testWidgets('Creating an item adds it', (tester) async {
    final repo = FakeInventoryRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .first,
      'Trapano nuovo',
    );
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(repo.created, ['Trapano nuovo']);
    expect(find.text('Trapano nuovo'), findsOneWidget);
  });

  testWidgets('Editing an item updates it', (tester) async {
    final repo = FakeInventoryRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifica'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .first,
      'Frigo cantina',
    );
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(repo.updated, ['Frigo cantina']);
    expect(find.text('Frigo cantina'), findsOneWidget);
  });

  testWidgets('Deleting an item removes it', (tester) async {
    final repo = FakeInventoryRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Elimina'));
    await tester.pumpAndSettle();

    expect(find.text('Frigorifero'), findsNothing);
    expect(repo.items.map((i) => i.name), isNot(contains('Frigorifero')));
  });
}
