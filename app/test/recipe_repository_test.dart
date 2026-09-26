import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/recipe_repository.dart';

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
  test('fetchRecipes parses ingredients, meal types and source', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('GET', '/api/v1/recipes', {
      'data': [
        {
          'id': 1,
          'title': 'Pizza',
          'notes': 'lievitazione 24h',
          'meal_types': ['dinner'],
          'source': 'native',
          'ingredients': [
            {'id': 10, 'name': 'Farina', 'quantity': '500g'},
            {'id': 11, 'name': 'Pomodoro', 'quantity': null},
          ],
        },
        {
          'id': 2,
          'title': 'Zuppa',
          'meal_types': ['lunch'],
          'source': 'chefkoch',
          'ingredients': [],
        },
      ],
    });
    final api = YuvomiApi(
      baseUrl: 'http://test.local',
      sessions: SessionManager(InMemoryStorage()),
    );
    api.dio.httpClientAdapter = adapter;
    final repo = RecipeRepository(api);
    final recipes = await repo.fetchRecipes();

    expect(adapter.requests.first.path, '/api/v1/recipes');
    expect(recipes, hasLength(2));
    expect(recipes.first.title, 'Pizza');
    expect(recipes.first.ingredients, hasLength(2));
    expect(recipes.first.ingredients.first.name, 'Farina');
    expect(recipes.first.mealTypes, ['dinner']);
    expect(recipes[1].source, 'chefkoch');
  });

  test('fetchRecipes tolerates an unexpected payload', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('GET', '/api/v1/recipes', {'data': null});
    final api = YuvomiApi(
      baseUrl: 'http://test.local',
      sessions: SessionManager(InMemoryStorage()),
    );
    api.dio.httpClientAdapter = adapter;
    final repo = RecipeRepository(api);

    expect(await repo.fetchRecipes(), isEmpty);
  });
}
