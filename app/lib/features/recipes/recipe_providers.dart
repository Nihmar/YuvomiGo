import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/recipe_repository.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/recipes/recipe_models.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) throw StateError('RecipeRepository senza sessione attiva');
  return RecipeRepository(api);
});

/// Tutte le ricette (sola lettura; la ricerca è filtrata in locale).
final recipesProvider = FutureProvider.autoDispose<List<Recipe>>((ref) async {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.fetchRecipes();
});
