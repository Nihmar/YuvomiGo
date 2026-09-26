import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/recipes/recipe_models.dart';

/// Repository per il modulo Ricette (sola lettura in questo incremento).
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
}
