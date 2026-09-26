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
}
