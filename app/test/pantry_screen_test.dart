import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/pantry_repository.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/pantry/pantry_models.dart';
import 'package:yuvomigo/features/pantry/pantry_providers.dart';
import 'package:yuvomigo/features/pantry/pantry_screen.dart';

import 'utils/fake_auth_controller.dart';
import 'utils/in_memory_storage.dart';

String _dateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

final class FakePantryRepository extends PantryRepository {
  FakePantryRepository()
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  static final _soon = DateTime.now().add(const Duration(days: 3));

  PantryData data = PantryData(
    items: [
      const PantryItem(
        id: 1,
        name: 'Farina',
        quantity: 2,
        unit: 'kg',
        locationName: 'Dispensa',
        category: 'Dolci',
      ),
      PantryItem(
        id: 2,
        name: 'Latte',
        quantity: 1,
        unit: 'l',
        minQuantity: 2,
        expiresOn: _dateKey(_soon),
      ),
    ],
    locations: const [PantryLocation(id: 1, name: 'Dispensa')],
    categories: const ['Dolci', 'Latticini'],
  );

  final List<String> created = [];
  final List<String> updated = [];

  @override
  Future<PantryData> fetchPantry() async => data;

  @override
  Future<PantryItem> createItem({
    required String name,
    double? quantity,
    String? unit,
    int? locationId,
    String? category,
    String? expiresOn,
    double? minQuantity,
    String? notes,
  }) async {
    created.add(name);
    final item = PantryItem(
      id: 99,
      name: name,
      quantity: quantity ?? 1,
      unit: unit ?? 'pcs',
    );
    data = PantryData(
      items: [...data.items, item],
      locations: data.locations,
      categories: data.categories,
    );
    return item;
  }

  @override
  Future<PantryItem> updateItem(
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
    updated.add(name);
    final index = data.items.indexWhere((i) => i.id == id);
    final item = PantryItem(
      id: id,
      name: name,
      quantity: quantity ?? data.items[index].quantity,
      unit: unit ?? data.items[index].unit,
      locationId: locationId,
      category: category ?? '',
      expiresOn: expiresOn,
      minQuantity: minQuantity,
      notes: notes,
    );
    data = PantryData(
      items: [
        for (final existing in data.items)
          if (existing.id == id) item else existing,
      ],
      locations: data.locations,
      categories: data.categories,
    );
    return item;
  }

  @override
  Future<void> deleteItem(int id) async {
    data = PantryData(
      items: data.items.where((i) => i.id != id).toList(),
      locations: data.locations,
      categories: data.categories,
    );
  }
}

Widget _pump(FakePantryRepository repo) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => FakeAuthController(Authenticated(user: fakeUser())),
      ),
      pantryRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(home: PantryScreen()),
  );
}

void main() {
  testWidgets('Pantry screen renders quantity, location, low stock, expiry', (
    tester,
  ) async {
    final repo = FakePantryRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    expect(find.text('Farina'), findsOneWidget);
    expect(find.text('Latte'), findsOneWidget);
    expect(find.textContaining('2 kg'), findsOneWidget);
    expect(find.textContaining('Dispensa'), findsWidgets);
    expect(find.textContaining('scorta minima'), findsOneWidget);
    expect(find.textContaining('scade tra 3 g'), findsOneWidget);
  });

  testWidgets('Adding an item reloads the pantry', (tester) async {
    final repo = FakePantryRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Riso');
    await tester.tap(find.text('Aggiungi'));
    await tester.pumpAndSettle();

    expect(repo.created, ['Riso']);
    expect(find.text('Riso'), findsOneWidget);
  });

  testWidgets('Deleting an item removes it', (tester) async {
    final repo = FakePantryRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Elimina').first);
    await tester.pumpAndSettle();

    expect(find.text('Farina'), findsNothing);
    expect(repo.data.items.map((i) => i.name), isNot(contains('Farina')));
  });

  testWidgets('Editing an item updates it', (tester) async {
    final repo = FakePantryRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Farina'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .first,
      'Farina 00',
    );
    await tester.tap(find.text('Salva').first);
    await tester.pumpAndSettle();

    expect(repo.updated, ['Farina 00']);
    expect(find.text('Farina 00'), findsOneWidget);
  });
}
