import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/inventory/inventory_models.dart';

/// Repository per il modulo Inventario.
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

  Future<List<InventoryCategory>> fetchCategories() {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/api/v1/inventory/categories',
      );
      final data = res.data?['data'];
      final raw = data is List ? data : const <dynamic>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(InventoryCategory.fromJson)
          .toList();
    });
  }

  Future<List<InventoryLocation>> fetchLocations() {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/api/v1/inventory/locations',
      );
      final data = res.data?['data'];
      final raw = data is List ? data : const <dynamic>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(InventoryLocation.fromJson)
          .toList();
    });
  }

  Future<InventoryItem> createItem({
    required String name,
    String? brand,
    String? model,
    String? serialNumber,
    required String category,
    int? locationId,
    String? purchaseDate,
    double? purchasePrice,
    String? vendor,
    int? warrantyMonths,
    String condition = 'good',
    String status = 'active',
    String? notes,
  }) {
    return mapApiErrors(() async {
      final res = await _api.dio.post<dynamic>(
        '/api/v1/inventory/items',
        data: _payload(
          name: name,
          brand: brand,
          model: model,
          serialNumber: serialNumber,
          category: category,
          locationId: locationId,
          purchaseDate: purchaseDate,
          purchasePrice: purchasePrice,
          vendor: vendor,
          warrantyMonths: warrantyMonths,
          condition: condition,
          status: status,
          notes: notes,
        ),
      );
      return InventoryItem.fromJson(_data(res.data));
    });
  }

  /// PUT = sostituzione completa dell'oggetto (come il server).
  Future<InventoryItem> updateItem(
    int id, {
    required String name,
    String? brand,
    String? model,
    String? serialNumber,
    required String category,
    int? locationId,
    String? purchaseDate,
    double? purchasePrice,
    String? vendor,
    int? warrantyMonths,
    String condition = 'good',
    String status = 'active',
    String? notes,
  }) {
    return mapApiErrors(() async {
      final res = await _api.dio.put<dynamic>(
        '/api/v1/inventory/items/$id',
        data: _payload(
          name: name,
          brand: brand,
          model: model,
          serialNumber: serialNumber,
          category: category,
          locationId: locationId,
          purchaseDate: purchaseDate,
          purchasePrice: purchasePrice,
          vendor: vendor,
          warrantyMonths: warrantyMonths,
          condition: condition,
          status: status,
          notes: notes,
        ),
      );
      return InventoryItem.fromJson(_data(res.data));
    });
  }

  Future<void> deleteItem(int id) {
    return mapApiErrors(
      () => _api.dio.delete<void>('/api/v1/inventory/items/$id'),
    );
  }

  Map<String, dynamic> _payload({
    required String name,
    String? brand,
    String? model,
    String? serialNumber,
    required String category,
    int? locationId,
    String? purchaseDate,
    double? purchasePrice,
    String? vendor,
    int? warrantyMonths,
    required String condition,
    required String status,
    String? notes,
  }) => {
    'name': name,
    'brand': brand,
    'model': model,
    'serial_number': serialNumber,
    'category': category,
    'location_id': locationId,
    'purchase_date': purchaseDate,
    'purchase_price': purchasePrice,
    'vendor': vendor,
    'warranty_months': warrantyMonths,
    'condition': condition,
    'status': status,
    'notes': notes,
  };

  Map<String, dynamic> _data(Object? body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
    }
    throw const ApiServerError(200, 'Risposta inattesa dal server.');
  }
}
