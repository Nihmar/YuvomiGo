/// Riga di `GET /api/v1/budget?month=YYYY-MM`.
final class BudgetEntry {
  const BudgetEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    this.category = '',
    this.isPending = false,
  });

  final int id;
  final String title;
  final double amount; // positivo = entrata, negativo = uscita
  final String date; // 'YYYY-MM-DD'
  final String category;
  final bool isPending;

  factory BudgetEntry.fromJson(Map<String, dynamic> json) => BudgetEntry(
    id: (json['id'] as num?)?.toInt() ?? -1,
    title: json['title'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    date: json['date'] as String? ?? '',
    category: json['category'] as String? ?? '',
    isPending: _asBool(json['is_pending']),
  );
}

/// Totale per categoria nella summary.
final class BudgetCategoryTotal {
  const BudgetCategoryTotal({
    required this.category,
    required this.income,
    required this.expenses,
    required this.total,
  });

  final String category;
  final double income;
  final double expenses;
  final double total;

  factory BudgetCategoryTotal.fromJson(Map<String, dynamic> json) =>
      BudgetCategoryTotal(
        category: json['category'] as String? ?? '',
        income: (json['income'] as num?)?.toDouble() ?? 0,
        expenses: (json['expenses'] as num?)?.toDouble() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0,
      );
}

/// `GET /api/v1/budget/summary?month=YYYY-MM`.
final class BudgetSummary {
  const BudgetSummary({
    required this.month,
    required this.income,
    required this.expenses,
    required this.balance,
    this.byCategory = const [],
    this.pendingCount = 0,
  });

  final String month;
  final double income;
  final double expenses;
  final double balance;
  final List<BudgetCategoryTotal> byCategory;
  final int pendingCount;

  factory BudgetSummary.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final rawCategories = data['byCategory'] is List
        ? data['byCategory'] as List
        : const [];
    final pending = data['pending'] is Map<String, dynamic>
        ? data['pending'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return BudgetSummary(
      month: data['month'] as String? ?? '',
      income: (data['income'] as num?)?.toDouble() ?? 0,
      expenses: (data['expenses'] as num?)?.toDouble() ?? 0,
      balance: (data['balance'] as num?)?.toDouble() ?? 0,
      byCategory: rawCategories
          .whereType<Map<String, dynamic>>()
          .map(BudgetCategoryTotal.fromJson)
          .toList(),
      pendingCount: (pending['count'] as num?)?.toInt() ?? 0,
    );
  }
}

bool _asBool(Object? v) => v == true || (v is num && v != 0);

/// `GET /api/v1/budget/stats?range=month&anchor=YYYY-MM-DD` (sottoinsieme).
final class BudgetStats {
  const BudgetStats({
    required this.income,
    required this.expenses,
    required this.balance,
    this.prevIncome = 0,
    this.prevExpenses = 0,
    this.prevBalance = 0,
  });

  final double income;
  final double expenses;
  final double balance;
  final double prevIncome;
  final double prevExpenses;
  final double prevBalance;

  factory BudgetStats.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final totals = data['totals'] is Map<String, dynamic>
        ? data['totals'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final comparison = data['comparison'] is Map<String, dynamic>
        ? data['comparison'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return BudgetStats(
      income: (totals['income'] as num?)?.toDouble() ?? 0,
      expenses: (totals['expenses'] as num?)?.toDouble() ?? 0,
      balance: (totals['balance'] as num?)?.toDouble() ?? 0,
      prevIncome: (comparison['income'] as num?)?.toDouble() ?? 0,
      prevExpenses: (comparison['expenses'] as num?)?.toDouble() ?? 0,
      prevBalance: (comparison['balance'] as num?)?.toDouble() ?? 0,
    );
  }
}
