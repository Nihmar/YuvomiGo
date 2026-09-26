import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/pantry/pantry_models.dart';

/// Repository per il modulo Dispensa.
base class PantryRepository {
  PantryRepository(this._api);

  final YuvomiApi _api;

  Future<PantryData> fetchPantry() {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>('/api/v1/pantry');
      final body = res.data ?? const <String, dynamic>{};
      final rawItems = body['data'] is List ? body['data'] as List : const [];
      final rawLocations = body['locations'] is List
          ? body['locations'] as List
          : const [];
      final rawCategories = body['categories'] is List
          ? body['categories'] as List
          : const [];
      return PantryData(
        items: rawItems
            .whereType<Map<String, dynamic>>()
            .map(PantryItem.fromJson)
            .toList(),
        locations: rawLocations
            .whereType<Map<String, dynamic>>()
            .map(PantryLocation.fromJson)
            .toList(),
        categories: rawCategories
            .whereType<Map<String, dynamic>>()
            .map((c) => c['name'] as String? ?? '')
            .where((name) => name.isNotEmpty)
            .toList(),
      );
    });
  }

  Future<PantryItem> createItem({
    required String name,
    double? quantity,
    String? unit,
    int? locationId,
    String? category,
    String? expiresOn,
    double? minQuantity,
    String? notes,
  }) {
    return mapApiErrors(() async {
      final res = await _api.dio.post<dynamic>(
        '/api/v1/pantry',
        data: {
          'name': name,
          'quantity': ?quantity,
          'unit': ?unit,
          'location_id': ?locationId,
          'category': ?category,
          'expires_on': ?expiresOn,
          'min_quantity': ?minQuantity,
          'notes': ?notes,
        },
      );
      return PantryItem.fromJson(_data(res.data));
    });
  }

  /// PUT = sostituzione completa dell'articolo (come il server).
  Future<PantryItem> updateItem(
    int id, {
    required String name,
    double? quantity,
    String? unit,
    int? locationId,
    String? category,
    String? expiresOn,
    double? minQuantity,
    String? notes,
  }) {
    return mapApiErrors(() async {
      final res = await _api.dio.put<dynamic>(
        '/api/v1/pantry/$id',
        data: {
          'name': name,
          'quantity': ?quantity,
          'unit': ?unit,
          'location_id': ?locationId,
          'category': ?category,
          'expires_on': ?expiresOn,
          'min_quantity': ?minQuantity,
          'notes': ?notes,
        },
      );
      return PantryItem.fromJson(_data(res.data));
    });
  }

  Future<void> deleteItem(int id) {
    return mapApiErrors(() => _api.dio.delete<void>('/api/v1/pantry/$id'));
  }

  Map<String, dynamic> _data(Object? body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
    }
    throw const ApiServerError(200, 'Risposta inattesa dal server.');
  }
}
