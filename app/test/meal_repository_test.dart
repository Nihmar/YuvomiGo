import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/meal_repository.dart';

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

  test('fetchWeek sends the week and parses meals + range', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('GET', '/api/v1/meals', {
      'data': [
        {'id': 1, 'date': '2026-09-01', 'meal_type': 'lunch', 'title': 'Pasta'},
        {
          'id': 2,
          'date': '2026-09-01',
          'meal_type': 'dinner',
          'title': 'Zuppa',
          'notes': 'con pane',
        },
      ],
      'weekStart': '2026-08-31',
      'weekEnd': '2026-09-06',
    });
    final repo = MealRepository(apiWith(adapter));
    final week = await repo.fetchWeek('2026-09-01');

    expect(adapter.requests.first.queryParameters['week'], '2026-09-01');
    expect(week.weekStart, '2026-08-31');
    expect(week.weekEnd, '2026-09-06');
    expect(week.meals, hasLength(2));
    expect(week.meals.first.title, 'Pasta');
    expect(week.meals[1].notes, 'con pane');
  });

  test('createMeal posts date, type and title', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('POST', '/api/v1/meals', {
      'data': {
        'id': 7,
        'date': '2026-09-01',
        'meal_type': 'dinner',
        'title': 'Pizza',
      },
    });
    final repo = MealRepository(apiWith(adapter));
    final created = await repo.createMeal(
      date: '2026-09-01',
      mealType: 'dinner',
      title: 'Pizza',
    );

    expect(created.id, 7);
    expect(adapter.requests.first.data, {
      'date': '2026-09-01',
      'meal_type': 'dinner',
      'title': 'Pizza',
    });
  });

  test('deleteMeal issues a DELETE', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('DELETE', '/api/v1/meals/7', {});
    final repo = MealRepository(apiWith(adapter));
    await repo.deleteMeal(7);

    expect(adapter.requests.first.method, 'DELETE');
    expect(adapter.requests.first.path, '/api/v1/meals/7');
  });
}
