import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/inventory/inventory_models.dart';

/// Repository per il modulo Inventario (sola lettura in questo incremento).
base class InventoryRepository {
  InventoryRepository(this._api);

  final YuvomiApi _api;

  /// Oggetti, opzionalmente filtrati dal server con [query].
  Future<List<InventoryItem>> fetchItems({String? query}) {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/api/v1/inventory/items',
        queryParameters: {
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        },
      );
      final data = res.data?['data'];
      final raw = data is List ? data : const <dynamic>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(InventoryItem.fromJson)
          .toList();
    });
  }
}
