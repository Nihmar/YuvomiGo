import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/recipes/recipe_models.dart';

/// Repository per il modulo Ricette (elenco + CRUD delle ricette native).
base class RecipeRepository {
  RecipeRepository(this._api);

  final YuvomiApi _api;

  Future<List<Recipe>> fetchRecipes() {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>('/api/v1/recipes');
      final data = res.data?['data'];
      final raw = data is List ? data : const <dynamic>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(Recipe.fromJson)
          .toList();
    });
  }

  Future<Recipe> createRecipe({
    required String title,
    String? notes,
    String? recipeUrl,
    List<String> mealTypes = const [],
    List<RecipeIngredient> ingredients = const [],
  }) {
    return mapApiErrors(() async {
      final res = await _api.dio.post<dynamic>(
        '/api/v1/recipes',
        data: _payload(
          title: title,
          notes: notes,
          recipeUrl: recipeUrl,
          mealTypes: mealTypes,
          ingredients: ingredients,
        ),
      );
      return Recipe.fromJson(_data(res.data));
    });
  }

  /// PUT = sostituzione completa (ingredienti compresi).
  Future<Recipe> updateRecipe(
    int id, {
    required String title,
    String? notes,
    String? recipeUrl,
    List<String> mealTypes = const [],
    List<RecipeIngredient> ingredients = const [],
  }) {
    return mapApiErrors(() async {
      final res = await _api.dio.put<dynamic>(
        '/api/v1/recipes/$id',
        data: _payload(
          title: title,
          notes: notes,
          recipeUrl: recipeUrl,
          mealTypes: mealTypes,
          ingredients: ingredients,
        ),
      );
      return Recipe.fromJson(_data(res.data));
    });
  }

  /// Solo le ricette native: quelle dei provider sono read-only (403).
  Future<void> deleteRecipe(int id) {
    return mapApiErrors(() => _api.dio.delete<void>('/api/v1/recipes/$id'));
  }

  Map<String, dynamic> _payload({
    required String title,
    String? notes,
    String? recipeUrl,
    required List<String> mealTypes,
    required List<RecipeIngredient> ingredients,
  }) => {
    'title': title,
    'notes': notes,
    'recipe_url': recipeUrl,
    'meal_types': mealTypes,
    'ingredients': [
      for (final ingredient in ingredients)
        {
          'name': ingredient.name,
          'quantity': ?ingredient.quantity,
          if (ingredient.category.isNotEmpty) 'category': ingredient.category,
        },
    ],
  };

  Map<String, dynamic> _data(Object? body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
    }
    throw const ApiServerError(200, 'Risposta inattesa dal server.');
  }
}
