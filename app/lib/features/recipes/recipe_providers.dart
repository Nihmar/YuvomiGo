import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/recipe_repository.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/recipes/recipe_models.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) throw StateError('RecipeRepository senza sessione attiva');
  return RecipeRepository(api);
});

/// Ultimo errore di un'azione sulle ricette (SnackBar).
final recipesActionErrorProvider =
    NotifierProvider<RecipesActionErrorNotifier, Object?>(
      RecipesActionErrorNotifier.new,
    );

final class RecipesActionErrorNotifier extends Notifier<Object?> {
  @override
  Object? build() => null;

  void clear() => state = null;
  void report(Object error) => state = error;
}

/// Tutte le ricette (ricerca filtrata in locale) + CRUD.
final recipesProvider =
    NotifierProvider.autoDispose<RecipesNotifier, AsyncValue<List<Recipe>>>(
      RecipesNotifier.new,
    );

final class RecipesNotifier extends Notifier<AsyncValue<List<Recipe>>> {
  bool _loading = false;

  @override
  AsyncValue<List<Recipe>> build() {
    Future.microtask(load);
    return const AsyncLoading();
  }

  Future<void> load() => _fetch(showLoading: true);

  /// Ricarica mantenendo le ricette correnti (pull-to-refresh).
  Future<void> refresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (!ref.mounted) return;
    if (_loading) return;
    _loading = true;
    final repo = ref.read(recipeRepositoryProvider);
    if (showLoading) state = const AsyncLoading();
    try {
      final recipes = await repo.fetchRecipes();
      if (!ref.mounted) return;
      state = AsyncData(recipes);
    } catch (e, st) {
      if (!ref.mounted) return;
      if (state.hasValue) {
        ref.read(recipesActionErrorProvider.notifier).report(e);
      } else {
        state = AsyncError(e, st);
      }
    } finally {
      _loading = false;
    }
  }

  /// Crea la ricetta; false se fallisce (dialog aperto).
  Future<bool> add({
    required String title,
    String? notes,
    String? recipeUrl,
    List<String> mealTypes = const [],
    List<RecipeIngredient> ingredients = const [],
  }) async {
    if (!ref.mounted) return false;
    final repo = ref.read(recipeRepositoryProvider);
    ref.read(recipesActionErrorProvider.notifier).clear();
    try {
      await repo.createRecipe(
        title: title,
        notes: notes,
        recipeUrl: recipeUrl,
        mealTypes: mealTypes,
        ingredients: ingredients,
      );
      if (!ref.mounted) return true;
      await _fetch(showLoading: false);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      ref.read(recipesActionErrorProvider.notifier).report(e);
      return false;
    }
  }

  /// Aggiorna la ricetta (sostituzione completa); false se fallisce.
  Future<bool> update(
    int id, {
    required String title,
    String? notes,
    String? recipeUrl,
    List<String> mealTypes = const [],
    List<RecipeIngredient> ingredients = const [],
  }) async {
    if (!ref.mounted) return false;
    final repo = ref.read(recipeRepositoryProvider);
    ref.read(recipesActionErrorProvider.notifier).clear();
    try {
      await repo.updateRecipe(
        id,
        title: title,
        notes: notes,
        recipeUrl: recipeUrl,
        mealTypes: mealTypes,
        ingredients: ingredients,
      );
      if (!ref.mounted) return true;
      await _fetch(showLoading: false);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      ref.read(recipesActionErrorProvider.notifier).report(e);
      return false;
    }
  }

  Future<void> remove(int id) async {
    if (!ref.mounted) return;
    final repo = ref.read(recipeRepositoryProvider);
    ref.read(recipesActionErrorProvider.notifier).clear();
    try {
      await repo.deleteRecipe(id);
      if (!ref.mounted) return;
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.where((r) => r.id != id).toList());
      }
    } catch (e) {
      if (!ref.mounted) return;
      ref.read(recipesActionErrorProvider.notifier).report(e);
    }
  }
}
