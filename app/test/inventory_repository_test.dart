import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/inventory_repository.dart';
import 'package:yuvomigo/features/inventory/inventory_models.dart';

import 'utils/in_memory_storage.dart';

final class _RoutingAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> routes = [];
  final List<RequestOptions> requests = [];

  void addRoute(String method, String path, Object body) {
    routes.add({'method': method, 'path': path, 'body': body});
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    for (final r in routes) {
      if (r['method'] == options.method && r['path'] == options.path) {
        return ResponseBody.fromString(
          jsonEncode(r['body']),
          200,
          headers: const {
            'content-type': ['application/json'],
          },
        );
      }
    }
    return ResponseBody.fromString(
      jsonEncode({'data': <Object>[]}),
      200,
      headers: const {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  YuvomiApi apiWith(_RoutingAdapter adapter) {
    final api = YuvomiApi(
      baseUrl: 'http://test.local',
      sessions: SessionManager(InMemoryStorage()),
    );
    api.dio.httpClientAdapter = adapter;
    return api;
  }

  test(
    'fetchItems parses items, category, location and tracked dates',
    () async {
      final adapter = _RoutingAdapter();
      adapter.addRoute('GET', '/api/v1/inventory/items', {
        'data': [
          {
            'id': 1,
            'name': 'Frigorifero',
            'brand': 'Bosch',
            'model': 'KGN39',
            'serial_number': 'SN123',
            'category': 'appliances',
            'category_name': 'Elettrodomestici',
            'location_path': 'Cucina',
            'purchase_date': '2024-05-01',
            'purchase_price': 799.9,
            'currency': 'EUR',
            'warranty_months': 24,
            'condition': 'good',
            'status': 'active',
            'tracked_dates': [
              {'id': 5, 'label': 'Garanzia', 'date': '2026-05-01'},
            ],
          },
        ],
      });
      final repo = InventoryRepository(apiWith(adapter));
      final items = await repo.fetchItems();

      expect(items, hasLength(1));
      expect(items.first.name, 'Frigorifero');
      expect(items.first.categoryName, 'Elettrodomestici');
      expect(items.first.locationPath, 'Cucina');
      expect(items.first.purchasePrice, 799.9);
      expect(items.first.trackedDates.single.label, 'Garanzia');
    },
  );

  test('fetchItems forwards the query to the server', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('GET', '/api/v1/inventory/items', {'data': <Object>[]});
    final repo = InventoryRepository(apiWith(adapter));
    await repo.fetchItems(query: 'bosch');

    expect(adapter.requests.first.queryParameters['q'], 'bosch');
  });

  test('fetchCategories and fetchLocations parse the lists', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('GET', '/api/v1/inventory/categories', {
      'data': [
        {'id': 1, 'key': 'household', 'name': 'Casa'},
      ],
    });
    adapter.addRoute('GET', '/api/v1/inventory/locations', {
      'data': [
        {
          'id': 1,
          'name': 'Casa',
          'subcategories': [
            {'id': 2, 'name': 'Cantina'},
          ],
        },
      ],
    });
    final repo = InventoryRepository(apiWith(adapter));

    final categories = await repo.fetchCategories();
    final locations = await repo.fetchLocations();
    final flattened = flattenInventoryLocations(locations);

    expect(categories.single.key, 'household');
    expect(categories.single.name, 'Casa');
    expect(flattened.map((l) => l.label), ['Casa', 'Casa / Cantina']);
    expect(flattened.last.id, 2);
  });

  test('createItem posts the full payload', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('POST', '/api/v1/inventory/items', {
      'data': {'id': 7, 'name': 'Trapano', 'category': 'household'},
    });
    final repo = InventoryRepository(apiWith(adapter));
    final created = await repo.createItem(
      name: 'Trapano',
      brand: 'Makita',
      category: 'household',
      locationId: 2,
      purchasePrice: 99.9,
      warrantyMonths: 24,
    );

    expect(created.id, 7);
    expect(adapter.requests.first.data, {
      'name': 'Trapano',
      'brand': 'Makita',
      'model': null,
      'serial_number': null,
      'category': 'household',
      'location_id': 2,
      'purchase_date': null,
      'purchase_price': 99.9,
      'vendor': null,
      'warranty_months': 24,
      'condition': 'good',
      'status': 'active',
      'notes': null,
    });
  });

  test('updateItem PUTs the full payload', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('PUT', '/api/v1/inventory/items/7', {
      'data': {'id': 7, 'name': 'Trapano', 'category': 'household'},
    });
    final repo = InventoryRepository(apiWith(adapter));
    await repo.updateItem(
      7,
      name: 'Trapano',
      category: 'household',
      status: 'sold',
    );

    expect(adapter.requests.first.method, 'PUT');
    expect(adapter.requests.first.path, '/api/v1/inventory/items/7');
    expect(adapter.requests.first.data['status'], 'sold');
  });

  test('deleteItem issues a DELETE', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('DELETE', '/api/v1/inventory/items/7', {});
    final repo = InventoryRepository(apiWith(adapter));
    await repo.deleteItem(7);

    expect(adapter.requests.first.method, 'DELETE');
    expect(adapter.requests.first.path, '/api/v1/inventory/items/7');
  });
}
