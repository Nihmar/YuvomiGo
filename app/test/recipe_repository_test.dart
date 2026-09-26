import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/recipe_repository.dart';
import 'package:yuvomigo/features/recipes/recipe_models.dart';

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

  test('createRecipe posts title, meal types and ingredients', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('POST', '/api/v1/recipes', {
      'data': {'id': 9, 'title': 'Pizza', 'ingredients': <Object>[]},
    });
    final api = YuvomiApi(
      baseUrl: 'http://test.local',
      sessions: SessionManager(InMemoryStorage()),
    );
    api.dio.httpClientAdapter = adapter;
    final repo = RecipeRepository(api);
    final created = await repo.createRecipe(
      title: 'Pizza',
      mealTypes: const ['dinner'],
      ingredients: const [
        RecipeIngredient(name: 'Farina', quantity: '500g'),
        RecipeIngredient(name: 'Pomodoro'),
      ],
    );

    expect(created.id, 9);
    expect(adapter.requests.first.data, {
      'title': 'Pizza',
      'notes': null,
      'recipe_url': null,
      'meal_types': ['dinner'],
      'ingredients': [
        {'name': 'Farina', 'quantity': '500g'},
        {'name': 'Pomodoro'},
      ],
    });
  });

  test('updateRecipe PUTs the full recipe', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('PUT', '/api/v1/recipes/9', {
      'data': {'id': 9, 'title': 'Pizza nuova', 'ingredients': <Object>[]},
    });
    final api = YuvomiApi(
      baseUrl: 'http://test.local',
      sessions: SessionManager(InMemoryStorage()),
    );
    api.dio.httpClientAdapter = adapter;
    final repo = RecipeRepository(api);
    await repo.updateRecipe(
      9,
      title: 'Pizza nuova',
      notes: 'nota',
      mealTypes: const ['lunch'],
      ingredients: const [RecipeIngredient(name: 'Farina')],
    );

    expect(adapter.requests.first.method, 'PUT');
    expect(adapter.requests.first.path, '/api/v1/recipes/9');
    expect(adapter.requests.first.data['title'], 'Pizza nuova');
    expect(adapter.requests.first.data['notes'], 'nota');
  });

  test('deleteRecipe issues a DELETE', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('DELETE', '/api/v1/recipes/9', {});
    final api = YuvomiApi(
      baseUrl: 'http://test.local',
      sessions: SessionManager(InMemoryStorage()),
    );
    api.dio.httpClientAdapter = adapter;
    final repo = RecipeRepository(api);
    await repo.deleteRecipe(9);

    expect(adapter.requests.first.method, 'DELETE');
    expect(adapter.requests.first.path, '/api/v1/recipes/9');
  });
}
