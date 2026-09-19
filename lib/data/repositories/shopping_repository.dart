import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/shopping/shopping_models.dart';

/// Repository per il modulo Spesa.
///
/// Le risposte non sono in spec OpenAPI: richieste raw via Dio, parsing nei
/// model di dominio. Le response usano il wrapping `{ data: ... }`.
base class ShoppingRepository {
  ShoppingRepository(this._api);

  final YuvomiApi _api;

  Map<String, dynamic> _data(Object? body) {
    if (body is Map<String, dynamic>) {
      final d = body['data'];
      if (d is Map<String, dynamic>) return d;
    }
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _dataList(Object? body) {
    if (body is Map<String, dynamic>) {
      final d = body['data'];
      if (d is List) return d.whereType<Map<String, dynamic>>().toList();
    }
    return const <Map<String, dynamic>>[];
  }

  Future<List<ShoppingList>> fetchLists() async {
    final response = await _api.dio.get<Map<String, dynamic>>('/api/v1/shopping');
    return _dataList(response.data).map(ShoppingList.fromJson).toList();
  }

  Future<ShoppingList> createList(String name) async {
    final response = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/shopping',
      data: {'name': name},
    );
    return ShoppingList.fromJson(_data(response.data));
  }

  Future<ShoppingList> renameList(int id, String name) async {
    final response = await _api.dio.put<Map<String, dynamic>>(
      '/api/v1/shopping/$id',
      data: {'name': name},
    );
    return ShoppingList.fromJson(_data(response.data));
  }

  Future<void> deleteList(int id) async {
    await _api.dio.delete<void>('/api/v1/shopping/$id');
  }

  Future<List<ShoppingItem>> fetchItems(int listId) async {
    final response = await _api.dio.get<Map<String, dynamic>>(
      '/api/v1/shopping/$listId/items',
    );
    return _dataList(response.data).map(ShoppingItem.fromJson).toList();
  }

  Future<ShoppingItem> addItem(
    int listId, {
    required String name,
    String? quantity,
    String? category,
  }) async {
    final response = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/shopping/$listId/items',
      data: {
        'name': name,
        if (quantity != null && quantity.isNotEmpty) 'quantity': quantity,
        if (category != null && category.isNotEmpty) 'category': category,
      },
    );
    return ShoppingItem.fromJson(_data(response.data));
  }

  Future<ShoppingItem> toggleItem(int itemId, bool isChecked) async {
    final response = await _api.dio.patch<Map<String, dynamic>>(
      '/api/v1/shopping/items/$itemId',
      data: {'is_checked': isChecked ? 1 : 0},
    );
    return ShoppingItem.fromJson(_data(response.data));
  }

  Future<void> deleteItem(int itemId) async {
    await _api.dio.delete<void>('/api/v1/shopping/items/$itemId');
  }
}
