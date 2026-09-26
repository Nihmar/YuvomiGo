import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/waste_repository.dart';

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

  test('fetchNextPickups parses the types and sorts by date', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('GET', '/api/v1/waste/occurrences/next', {
      'data': [
        {
          'type': {
            'id': 1,
            'name': 'Carta',
            'icon': 'paper',
            'color': '#2196F3',
          },
          'next': {'date_key': '2026-09-10', 'moved': false},
        },
        {
          'type': {'id': 2, 'name': 'Plastica', 'color': '#FFEB3B'},
          'next': {'date_key': '2026-09-08', 'moved': true},
        },
        {
          'type': {'id': 3, 'name': 'Vetro'},
          'next': null,
        },
      ],
    });
    final repo = WasteRepository(apiWith(adapter));
    final pickups = await repo.fetchNextPickups();

    expect(adapter.requests.first.path, '/api/v1/waste/occurrences/next');
    expect(pickups, hasLength(3));
    expect(pickups.first.typeName, 'Plastica');
    expect(pickups.first.moved, isTrue);
    expect(pickups[1].typeName, 'Carta');
    expect(pickups.last.typeName, 'Vetro');
    expect(pickups.last.hasNext, isFalse);
    expect(pickups[1].typeColor, '#2196F3');
  });
}
