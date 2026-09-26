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
  final List<String> created = [];
  final List<String> updated = [];
  final List<int> deleted = [];
  final List<int> confirmed = [];
  int _nextId = 100;

  final List<BudgetEntry> entries = [
    const BudgetEntry(
      id: 1,
      title: 'Stipendio',
      amount: 1000,
      date: '2026-09-01',
      category: 'Lavoro',
    ),
    const BudgetEntry(
      id: 2,
      title: 'Spesa',
      amount: -400,
      date: '2026-09-03',
      category: 'Alimentari',
      isPending: true,
    ),
  ];

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
  Future<List<BudgetEntry>> fetchEntries(String month) async =>
      entries.toList();

  @override
  Future<List<BudgetCategory>> fetchCategories() async => const [
    BudgetCategory(key: 'Alimentari', name: 'Alimentari', type: 'expense'),
    BudgetCategory(key: 'Lavoro', name: 'Lavoro', type: 'income'),
  ];

  @override
  Future<BudgetEntry> createEntry({
    required String title,
    required double amount,
    required String category,
    required String date,
  }) async {
    created.add(title);
    final entry = BudgetEntry(
      id: _nextId++,
      title: title,
      amount: amount,
      date: date,
      category: category,
    );
    entries.add(entry);
    return entry;
  }

  @override
  Future<BudgetEntry> updateEntry(
    int id, {
    String? title,
    double? amount,
    String? category,
    String? date,
  }) async {
    updated.add(title ?? '');
    final index = entries.indexWhere((e) => e.id == id);
    final entry = BudgetEntry(
      id: id,
      title: title ?? entries[index].title,
      amount: amount ?? entries[index].amount,
      date: date ?? entries[index].date,
      category: category ?? entries[index].category,
      isPending: entries[index].isPending,
    );
    entries[index] = entry;
    return entry;
  }

  @override
  Future<void> deleteEntry(int id) async {
    deleted.add(id);
    entries.removeWhere((e) => e.id == id);
  }

  @override
  Future<void> confirmEntry(int id) async {
    confirmed.add(id);
    final index = entries.indexWhere((e) => e.id == id);
    final entry = entries[index];
    entries[index] = BudgetEntry(
      id: entry.id,
      title: entry.title,
      amount: entry.amount,
      date: entry.date,
      category: entry.category,
    );
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

  testWidgets('A new movement can be added as an expense', (tester) async {
    final repo = FakeBudgetRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Aggiungi movimento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Benzina');
    await tester.enterText(find.byType(TextField).at(1), '55,50');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(repo.created, ['Benzina']);
    final entry = repo.entries.firstWhere((e) => e.title == 'Benzina');
    expect(entry.amount, -55.5); // default: Uscita
  });

  testWidgets('Tapping a movement opens the editor and saves changes', (
    tester,
  ) async {
    final repo = FakeBudgetRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Stipendio'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stipendio'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Stipendio settembre');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(repo.updated, ['Stipendio settembre']);
    expect(find.text('Stipendio settembre'), findsOneWidget);
  });

  testWidgets('A pending movement can be confirmed', (tester) async {
    final repo = FakeBudgetRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Spesa'), 200);
    await tester.pumpAndSettle();
    final spesaTile = find.ancestor(
      of: find.text('Spesa'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(
        of: spesaTile,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conferma'));
    await tester.pumpAndSettle();

    expect(repo.confirmed, [2]);
  });

  testWidgets('A movement can be deleted', (tester) async {
    final repo = FakeBudgetRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Stipendio'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();

    expect(repo.deleted, [1]);
    expect(repo.entries.map((e) => e.title), isNot(contains('Stipendio')));
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
