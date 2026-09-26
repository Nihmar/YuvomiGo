import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/budget/budget_models.dart';

/// Repository per il modulo Budget (sottoinsieme MVP: mese in sola lettura).
base class BudgetRepository {
  BudgetRepository(this._api);

  final YuvomiApi _api;

  /// Riepilogo del mese: entrate, uscite, saldo e totali per categoria.
  Future<BudgetSummary> fetchSummary(String month) {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/api/v1/budget/summary',
        queryParameters: {'month': month},
      );
      return BudgetSummary.fromJson(res.data ?? const <String, dynamic>{});
    });
  }

  /// Movimenti del mese.
  Future<List<BudgetEntry>> fetchEntries(String month) {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/api/v1/budget',
        queryParameters: {'month': month},
      );
      final data = res.data?['data'];
      final raw = data is List ? data : const <dynamic>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(BudgetEntry.fromJson)
          .toList();
    });
  }

  /// Statistiche del periodo + confronto col precedente.
  /// [range] = 'week' | 'month' | 'year'.
  Future<BudgetStats> fetchStats(String month, {String range = 'month'}) {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/api/v1/budget/stats',
        queryParameters: {'range': range, 'anchor': '$month-01'},
      );
      return BudgetStats.fromJson(res.data ?? const <String, dynamic>{});
    });
  }

  /// Categorie disponibili per il form dei movimenti.
  Future<List<BudgetCategory>> fetchCategories() {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/api/v1/budget/categories',
      );
      final data = res.data?['data'];
      final raw = data is List ? data : const <dynamic>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(BudgetCategory.fromJson)
          .toList();
    });
  }

  /// Crea un movimento. [amount] negativo = uscita, positivo = entrata.
  Future<BudgetEntry> createEntry({
    required String title,
    required double amount,
    required String category,
    required String date,
  }) {
    return mapApiErrors(() async {
      final res = await _api.dio.post<dynamic>(
        '/api/v1/budget',
        data: {
          'title': title,
          'amount': amount,
          'category': category,
          'date': date,
        },
      );
      return BudgetEntry.fromJson(_data(res.data));
    });
  }

  /// Aggiorna un movimento (il server lascia invariati i campi assenti).
  Future<BudgetEntry> updateEntry(
    int id, {
    String? title,
    double? amount,
    String? category,
    String? date,
  }) {
    return mapApiErrors(() async {
      final res = await _api.dio.put<dynamic>(
        '/api/v1/budget/$id',
        data: {
          'title': ?title,
          'amount': ?amount,
          'category': ?category,
          'date': ?date,
        },
      );
      return BudgetEntry.fromJson(_data(res.data));
    });
  }

  Future<void> deleteEntry(int id) {
    return mapApiErrors(() => _api.dio.delete<void>('/api/v1/budget/$id'));
  }

  /// Conferma un movimento in attesa (lo rende contabilizzato).
  Future<void> confirmEntry(int id) {
    return mapApiErrors(
      () => _api.dio.patch<void>('/api/v1/budget/$id/confirm'),
    );
  }

  Map<String, dynamic> _data(Object? body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
    }
    throw const ApiServerError(200, 'Risposta inattesa dal server.');
  }
}
