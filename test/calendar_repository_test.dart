import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/calendar_repository.dart';

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

  test('fetchRange passes the date window and parses events', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('GET', '/api/v1/calendar', {
      'data': [
        {
          'id': 1,
          'title': 'Dentista',
          'start_datetime': '2026-09-01T09:00:00',
          'end_datetime': '2026-09-01T10:00:00',
        },
        {
          'id': 2,
          'title': 'Festa',
          'start_datetime': '2026-09-02T00:00:00',
          'all_day': 1,
        },
      ],
    });
    final repo = CalendarRepository(apiWith(adapter));
    final events = await repo.fetchRange('2026-08-30', '2026-09-06');

    expect(events, hasLength(2));
    expect(events.first.title, 'Dentista');
    expect(events.first.allDay, isFalse);
    expect(events[1].allDay, isTrue);
    // La query porta il range.
    expect(adapter.requests.first.queryParameters['from'], '2026-08-30');
    expect(adapter.requests.first.queryParameters['to'], '2026-09-06');
  });

  test('events are sorted by start datetime', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('GET', '/api/v1/calendar', {
      'data': [
        {'id': 1, 'title': 'poi', 'start_datetime': '2026-09-02T00:00:00'},
        {'id': 2, 'title': 'prima', 'start_datetime': '2026-09-01T00:00:00'},
      ],
    });
    final repo = CalendarRepository(apiWith(adapter));
    final events = await repo.fetchRange('2026-08-30', '2026-09-06');

    expect(events.first.id, 2); // prima
    expect(events[1].id, 1);
  });
}
