import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/pantry_repository.dart';

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

  test('fetchPantry parses items, locations and categories', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('GET', '/api/v1/pantry', {
      'data': [
        {
          'id': 1,
          'name': 'Farina',
          'quantity': 2,
          'unit': 'kg',
          'location_id': 1,
          'location_name': 'Dispensa',
          'category': 'Dolci',
          'expires_on': '2027-01-01',
          'min_quantity': 1,
        },
      ],
      'locations': [
        {'id': 1, 'name': 'Dispensa'},
      ],
      'categories': [
        {'id': 1, 'name': 'Dolci'},
        {'id': 2, 'name': 'Latticini'},
      ],
    });
    final repo = PantryRepository(apiWith(adapter));
    final data = await repo.fetchPantry();

    expect(data.items, hasLength(1));
    expect(data.items.first.name, 'Farina');
    expect(data.items.first.quantity, 2);
    expect(data.items.first.unit, 'kg');
    expect(data.items.first.locationName, 'Dispensa');
    expect(data.items.first.isLowStock, isFalse);
    expect(data.locations.single.name, 'Dispensa');
    expect(data.categories, ['Dolci', 'Latticini']);
  });

  test('createItem posts the provided fields only', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('POST', '/api/v1/pantry', {
      'data': {'id': 7, 'name': 'Latte', 'quantity': 2},
    });
    final repo = PantryRepository(apiWith(adapter));
    final created = await repo.createItem(name: 'Latte', quantity: 2);

    expect(created.id, 7);
    expect(adapter.requests.first.data, {'name': 'Latte', 'quantity': 2});
  });

  test('deleteItem issues a DELETE', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('DELETE', '/api/v1/pantry/7', {});
    final repo = PantryRepository(apiWith(adapter));
    await repo.deleteItem(7);

    expect(adapter.requests.first.method, 'DELETE');
    expect(adapter.requests.first.path, '/api/v1/pantry/7');
  });

  test('updateItem PUTs the full payload', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('PUT', '/api/v1/pantry/7', {
      'data': {'id': 7, 'name': 'Farina', 'quantity': 1.5, 'unit': 'kg'},
    });
    final repo = PantryRepository(apiWith(adapter));
    final updated = await repo.updateItem(
      7,
      name: 'Farina',
      quantity: 1.5,
      unit: 'kg',
      minQuantity: 1,
    );

    expect(updated.quantity, 1.5);
    expect(adapter.requests.first.method, 'PUT');
    expect(adapter.requests.first.path, '/api/v1/pantry/7');
    expect(adapter.requests.first.data, {
      'name': 'Farina',
      'quantity': 1.5,
      'unit': 'kg',
      'min_quantity': 1.0,
    });
  });
}
