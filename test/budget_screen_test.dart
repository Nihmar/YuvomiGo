import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/budget_repository.dart';
import 'package:yuvomigo/data/repositories/preferences_repository.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/budget/budget_models.dart';
import 'package:yuvomigo/features/budget/budget_providers.dart';
import 'package:yuvomigo/features/budget/budget_screen.dart';
import 'package:yuvomigo/features/settings/preferences_providers.dart';

import 'utils/fake_auth_controller.dart';
import 'utils/in_memory_storage.dart';

final class FakeBudgetRepository extends BudgetRepository {
  FakeBudgetRepository()
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  final List<String> requestedMonths = [];

  @override
  Future<BudgetSummary> fetchSummary(String month) async {
    requestedMonths.add(month);
    return BudgetSummary(
      month: month,
      income: 1000,
      expenses: -400,
      balance: 600,
      byCategory: const [
        BudgetCategoryTotal(
          category: 'Casa',
          income: 0,
          expenses: -400,
          total: -400,
        ),
      ],
      pendingCount: 1,
    );
  }

  @override
  Future<List<BudgetEntry>> fetchEntries(String month) async {
    return const [
      BudgetEntry(
        id: 1,
        title: 'Stipendio',
        amount: 1000,
        date: '2026-09-01',
        category: 'Lavoro',
      ),
      BudgetEntry(
        id: 2,
        title: 'Spesa',
        amount: -400,
        date: '2026-09-03',
        category: 'Alimentari',
      ),
    ];
  }

  @override
  Future<BudgetStats> fetchStats(String month, {String range = 'month'}) async {
    if (range == 'year') {
      final year = month.split('-').first;
      return BudgetStats(
        income: 12000,
        expenses: -8000,
        balance: 4000,
        series: [
          for (var m = 1; m <= 12; m++)
            BudgetPeriod(
              period: '$year-${m.toString().padLeft(2, '0')}',
              income: 1000,
              expenses: -700,
              balance: m.isEven ? -200 : 300,
            ),
        ],
      );
    }
    return const BudgetStats(
      income: 1000,
      expenses: -400,
      balance: 600,
      prevIncome: 900,
      prevExpenses: -500,
      prevBalance: 400,
    );
  }
}

Widget _pump(FakeBudgetRepository repo) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => FakeAuthController(Authenticated(user: fakeUser())),
      ),
      budgetRepositoryProvider.overrideWithValue(repo),
      appPreferencesProvider.overrideWithValue(
        const AsyncData(AppPreferences(currency: 'EUR')),
      ),
    ],
    child: const MaterialApp(home: BudgetScreen()),
  );
}

void main() {
  testWidgets('Budget screen renders totals, categories and entries', (
    tester,
  ) async {
    final repo = FakeBudgetRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    expect(find.text('Entrate'), findsWidgets);
    expect(find.text('Uscite'), findsWidgets);
    expect(find.text('Saldo'), findsWidgets);
    expect(find.textContaining('1 movimenti in attesa'), findsOneWidget);

    final money = NumberFormat.currency(
      locale: 'en_US',
      name: 'EUR',
      decimalDigits: 2,
    );
    expect(find.text(money.format(1000)), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Confronto col mese precedente'),
      200,
    );
    await tester.pumpAndSettle();
    expect(find.text('Confronto col mese precedente'), findsOneWidget);
    // Delta entrate: 1000 - 900 = +100.
    expect(find.text('+${money.format(100)}'), findsWidgets);

    await tester.scrollUntilVisible(find.text('Casa'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Casa'), findsOneWidget);

    // La lista dei movimenti sta sotto la card di confronto: scorro per
    // raggiungerla (ListView costruisce i figli su richiesta).
    await tester.dragUntilVisible(
      find.text('Spesa'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Stipendio'), findsOneWidget);
    expect(find.text('Spesa'), findsOneWidget);
  });

  testWidgets('The next-month button requests another month', (tester) async {
    final repo = FakeBudgetRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();
    final first = repo.requestedMonths.last;

    await tester.tap(find.byTooltip('Mese successivo'));
    await tester.pumpAndSettle();

    expect(repo.requestedMonths.length, greaterThanOrEqualTo(2));
    expect(repo.requestedMonths.last, isNot(first));
  });

  testWidgets('Budget screen shows the year trend chart', (tester) async {
    final repo = FakeBudgetRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    final year = DateTime.now().year;
    await tester.scrollUntilVisible(find.text('Andamento $year'), 200);
    await tester.pumpAndSettle();

    expect(find.text('Andamento $year'), findsOneWidget);
    // Locale del test MaterialApp = en_US → "Dec".
    expect(find.text('Dec'), findsOneWidget);
  });
}
