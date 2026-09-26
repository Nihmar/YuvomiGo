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

  @override
  Future<List<InventoryItem>> fetchItems({String? query}) async => const [
    InventoryItem(
      id: 1,
      name: 'Frigorifero',
      brand: 'Bosch',
      model: 'KGN39',
      serialNumber: 'SN123',
      categoryName: 'Elettrodomestici',
      locationPath: 'Cucina',
      purchasePrice: 799.9,
      warrantyMonths: 24,
      trackedDates: [
        InventoryTrackedDate(id: 5, label: 'Garanzia', date: '2026-05-01'),
      ],
    ),
    InventoryItem(id: 2, name: 'Trapano', brand: 'Makita', status: 'lost'),
  ];
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
}
