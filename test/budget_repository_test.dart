import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/budget_repository.dart';

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

  test('fetchSummary parses totals, categories and pending', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('GET', '/api/v1/budget/summary', {
      'data': {
        'month': '2026-09',
        'income': 1000,
        'expenses': -400,
        'balance': 600,
        'byCategory': [
          {'category': 'Casa', 'income': 0, 'expenses': -400, 'total': -400},
        ],
        'pending': {'count': 2, 'income': 0, 'expenses': -50},
      },
    });
    final repo = BudgetRepository(apiWith(adapter));
    final summary = await repo.fetchSummary('2026-09');

    expect(adapter.requests.first.queryParameters['month'], '2026-09');
    expect(summary.month, '2026-09');
    expect(summary.balance, 600);
    expect(summary.byCategory.single.category, 'Casa');
    expect(summary.pendingCount, 2);
  });

  test('fetchEntries parses the month entries', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('GET', '/api/v1/budget', {
      'data': [
        {
          'id': 1,
          'title': 'Stipendio',
          'amount': 2000,
          'category': 'Lavoro',
          'date': '2026-09-01',
        },
        {
          'id': 2,
          'title': 'Spesa',
          'amount': -80.5,
          'category': 'Alimentari',
          'date': '2026-09-03',
          'is_pending': 1,
        },
      ],
    });
    final repo = BudgetRepository(apiWith(adapter));
    final entries = await repo.fetchEntries('2026-09');

    expect(entries, hasLength(2));
    expect(entries.first.title, 'Stipendio');
    expect(entries[1].amount, -80.5);
    expect(entries[1].isPending, isTrue);
  });
}
