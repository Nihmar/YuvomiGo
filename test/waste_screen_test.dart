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
}
