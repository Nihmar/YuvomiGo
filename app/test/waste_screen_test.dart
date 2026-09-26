import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/waste_repository.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/waste/waste_models.dart';
import 'package:yuvomigo/features/waste/waste_providers.dart';
import 'package:yuvomigo/features/waste/waste_screen.dart';

import 'utils/fake_auth_controller.dart';
import 'utils/in_memory_storage.dart';

String _dateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

final class FakeWasteRepository extends WasteRepository {
  FakeWasteRepository()
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  final List<WastePickup> pickups = [
    WastePickup(
      id: 1,
      typeId: 1,
      date: _dateKey(DateTime.now()),
      note: 'straordinaria',
    ),
  ];
  final List<int> created = [];
  int _nextId = 100;

  @override
  Future<List<WasteNextPickup>> fetchNextPickups() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      WasteNextPickup(typeId: 1, typeName: 'Carta', dateKey: _dateKey(today)),
      WasteNextPickup(
        typeId: 2,
        typeName: 'Plastica',
        dateKey: _dateKey(today.add(const Duration(days: 1))),
        moved: true,
      ),
      const WasteNextPickup(typeId: 3, typeName: 'Vetro'),
    ];
  }

  @override
  Future<List<WasteType>> fetchTypes() async => const [
    WasteType(id: 1, name: 'Carta', color: '#2196F3'),
    WasteType(id: 2, name: 'Plastica', color: '#FFEB3B'),
    WasteType(id: 3, name: 'Vetro'),
  ];

  @override
  Future<List<WastePickup>> fetchPickups() async => pickups.toList();

  @override
  Future<WastePickup> createPickup({
    required int typeId,
    required String date,
    String? note,
  }) async {
    created.add(typeId);
    final pickup = WastePickup(
      id: _nextId++,
      typeId: typeId,
      date: date,
      note: note,
    );
    pickups.add(pickup);
    return pickup;
  }

  @override
  Future<WastePickup> updatePickup(
    int id, {
    required String date,
    String? note,
  }) async {
    final index = pickups.indexWhere((p) => p.id == id);
    final updated = WastePickup(
      id: id,
      typeId: pickups[index].typeId,
      date: date,
      note: note,
    );
    pickups[index] = updated;
    return updated;
  }

  @override
  Future<void> deletePickup(int id) async {
    pickups.removeWhere((p) => p.id == id);
  }
}

Widget _pump(FakeWasteRepository repo) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => FakeAuthController(Authenticated(user: fakeUser())),
      ),
      wasteRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(home: WasteScreen()),
  );
}

void main() {
  testWidgets('Waste screen renders the next pickup per type', (tester) async {
    final repo = FakeWasteRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    expect(find.text('Carta'), findsOneWidget);
    expect(find.text('Plastica'), findsOneWidget);
    expect(find.text('Vetro'), findsOneWidget);
    expect(find.textContaining('oggi'), findsOneWidget);
    expect(find.textContaining('domani'), findsOneWidget);
    expect(find.textContaining('non pianificata'), findsOneWidget);
    expect(find.text('spostato'), findsOneWidget);
  });

  testWidgets('Extra pickups are listed, created and deleted', (tester) async {
    final repo = FakeWasteRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Extra'));
    await tester.pumpAndSettle();

    expect(find.textContaining('straordinaria'), findsOneWidget);

    // Aggiungi una raccolta.
    await tester.tap(find.byTooltip('Aggiungi raccolta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vetro').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .first,
      'vetro extra',
    );
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(repo.created, [3]);
    expect(find.textContaining('vetro extra'), findsOneWidget);

    // Elimina la raccolta appena creata.
    await tester.tap(find.byTooltip('Elimina').last);
    await tester.pumpAndSettle();

    expect(repo.pickups, hasLength(1));
  });
}
