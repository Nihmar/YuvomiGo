import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/inventory_repository.dart';

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
}
