import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/shopping_repository.dart';

import 'utils/in_memory_storage.dart';

/// Adapter fake che smista per metodo+path e registra le richieste.
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
    final body = _resolve(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: const {
        'content-type': ['application/json'],
      },
    );
  }

  Object? _resolve(RequestOptions options) {
    for (final r in routes) {
      if (r['method'] == options.method && r['path'] == options.path) {
        return r['body'];
      }
    }
    return {'data': <Object>[]};
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

  test('fetchLists parses the list summary', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('GET', '/api/v1/shopping', {
      'data': [
        {'id': 1, 'name': 'Super', 'item_total': 5, 'item_checked': 2},
        {'id': 2, 'name': 'Farmacia', 'item_total': 1, 'item_checked': 0},
      ],
    });
    final repo = ShoppingRepository(apiWith(adapter));
    final lists = await repo.fetchLists();

    expect(lists, hasLength(2));
    expect(lists.first.name, 'Super');
    expect(lists.first.itemTotal, 5);
    expect(lists.first.openCount, 3);
    expect(lists[1].openCount, 1);
  });

  test('fetchItems parses the items of a list', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('GET', '/api/v1/shopping/1/items', {
      'data': [
        {'id': 10, 'name': 'Latte', 'quantity': '2', 'is_checked': 0},
        {'id': 11, 'name': 'Pane', 'is_checked': 1},
      ],
    });
    final repo = ShoppingRepository(apiWith(adapter));
    final items = await repo.fetchItems(1);

    expect(items, hasLength(2));
    expect(items.first.name, 'Latte');
    expect(items.first.quantity, '2');
    expect(items.first.isChecked, isFalse);
    expect(items[1].isChecked, isTrue);
  });

  test('createList posts the name and parses the response', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('POST', '/api/v1/shopping', {
      'data': {'id': 3, 'name': 'Nuova'},
    });
    final repo = ShoppingRepository(apiWith(adapter));
    final created = await repo.createList('Nuova');

    expect(created.id, 3);
    expect(created.name, 'Nuova');
    expect(adapter.requests.first.method, 'POST');
    expect(adapter.requests.first.data, {'name': 'Nuova'});
  });

  test('toggleItem PATCHes is_checked', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('PATCH', '/api/v1/shopping/items/10', {
      'data': {'id': 10, 'name': 'Latte', 'is_checked': 1},
    });
    final repo = ShoppingRepository(apiWith(adapter));
    final updated = await repo.toggleItem(10, true);

    expect(updated.isChecked, isTrue);
    expect(adapter.requests.first.data, {'is_checked': 1});
  });

  test('addItem sends name and optional quantity', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('POST', '/api/v1/shopping/1/items', {
      'data': {'id': 12, 'name': 'Uova', 'quantity': '12'},
    });
    final repo = ShoppingRepository(apiWith(adapter));
    final created = await repo.addItem(1, name: 'Uova', quantity: '12');

    expect(created.name, 'Uova');
    expect(created.quantity, '12');
    expect(adapter.requests.first.data, {'name': 'Uova', 'quantity': '12'});
  });
}
