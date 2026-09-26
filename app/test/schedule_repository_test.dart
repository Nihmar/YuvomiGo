import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/schedule_repository.dart';

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
    'fetchRange parses entries and sorts them by day and start time',
    () async {
      final adapter = _RoutingAdapter();
      adapter.addRoute('GET', '/api/v1/schedule/entries', {
        'data': {
          'entries': [
            {
              'user_id': 1,
              'date_key': '2026-09-02',
              'source': 'pattern',
              'shift_type_id': 1,
              'shift_type': {
                'id': 1,
                'name': 'Mattina',
                'short_code': 'M',
                'start_time': '08:00',
                'end_time': '14:00',
                'color': '#FF9800',
              },
              'is_free': false,
              'crosses_midnight': false,
            },
            {
              'user_id': 2,
              'date_key': '2026-09-01',
              'source': 'override',
              'shift_type_id': 2,
              'shift_type': {
                'id': 2,
                'name': 'Notte',
                'start_time': '22:00',
                'end_time': '06:00',
              },
              'is_free': false,
              'crosses_midnight': true,
            },
            {
              'user_id': 2,
              'date_key': '2026-09-01',
              'source': 'override',
              'shift_type_id': null,
              'shift_type': null,
              'is_free': true,
            },
          ],
          'warnings': <Object>[],
        },
      });
      final repo = ScheduleRepository(apiWith(adapter));
      final entries = await repo.fetchRange('2026-08-31', '2026-09-06');

      expect(adapter.requests.first.queryParameters['from'], '2026-08-31');
      expect(adapter.requests.first.queryParameters['to'], '2026-09-06');
      expect(entries, hasLength(3));
      expect(entries.first.dateKey, '2026-09-01');
      expect(entries.first.shiftType!.name, 'Notte');
      expect(entries.first.timeLabel, '22:00–06:00 (+1)');
      expect(entries[1].isFree, isTrue);
      expect(entries.last.shiftType!.name, 'Mattina');
    },
  );

  test('fetchMembers parses the household list', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('GET', '/api/v1/schedule/household-members', {
      'data': [
        {'id': 1, 'display_name': 'Mario', 'avatar_color': '#FF0000'},
      ],
    });
    final repo = ScheduleRepository(apiWith(adapter));
    final members = await repo.fetchMembers();

    expect(members, hasLength(1));
    expect(members.first.displayName, 'Mario');
  });
}
