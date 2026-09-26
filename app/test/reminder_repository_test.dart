import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/reminder_repository.dart';

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

  test('fetchPending parses the reminder list', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('GET', '/api/v1/reminders/pending', {
      'data': [
        {
          'id': 1,
          'entity_type': 'task',
          'entity_title': 'Pagare bolletta',
          'remind_at': '2026-09-01T08:00:00Z',
        },
      ],
    });
    final repo = ReminderRepository(apiWith(adapter));
    final reminders = await repo.fetchPending();

    expect(adapter.requests.first.path, '/api/v1/reminders/pending');
    expect(reminders, hasLength(1));
    expect(reminders.first.entityTitle, 'Pagare bolletta');
    expect(reminders.first.entityType, 'task');
  });

  test('dismiss PATCHes the dismiss endpoint', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('PATCH', '/api/v1/reminders/4/dismiss', {});
    final repo = ReminderRepository(apiWith(adapter));
    await repo.dismiss(4);

    expect(adapter.requests.first.method, 'PATCH');
    expect(adapter.requests.first.path, '/api/v1/reminders/4/dismiss');
  });

  test('deleteReminder issues a DELETE', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('DELETE', '/api/v1/reminders/4', {});
    final repo = ReminderRepository(apiWith(adapter));
    await repo.deleteReminder(4);

    expect(adapter.requests.first.method, 'DELETE');
    expect(adapter.requests.first.path, '/api/v1/reminders/4');
  });
}
