import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/recipe_repository.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/recipes/recipe_models.dart';
import 'package:yuvomigo/features/recipes/recipe_providers.dart';
import 'package:yuvomigo/features/recipes/recipes_screen.dart';

import 'utils/fake_auth_controller.dart';
import 'utils/in_memory_storage.dart';

final class FakeRecipeRepository extends RecipeRepository {
  FakeRecipeRepository()
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  final List<Recipe> recipes = [
    const Recipe(
      id: 1,
      title: 'Pizza',
      notes: 'lievitazione 24h',
      recipeUrl: 'https://example.org/pizza',
      mealTypes: ['dinner'],
      ingredients: [
        RecipeIngredient(name: 'Farina', quantity: '500g'),
        RecipeIngredient(name: 'Pomodoro'),
      ],
    ),
    const Recipe(
      id: 2,
      title: 'Zuppa',
      mealTypes: ['lunch'],
      source: 'chefkoch',
    ),
  ];
  final List<String> created = [];
  final List<String> updated = [];
  final List<int> deleted = [];
  int _nextId = 100;

  @override
  Future<List<Recipe>> fetchRecipes() async => recipes.toList();

  @override
  Future<Recipe> createRecipe({
    required String title,
    String? notes,
    String? recipeUrl,
    List<String> mealTypes = const [],
    List<RecipeIngredient> ingredients = const [],
  }) async {
    created.add(title);
    final recipe = Recipe(
      id: _nextId++,
      title: title,
      notes: notes,
      recipeUrl: recipeUrl,
      mealTypes: mealTypes,
      ingredients: ingredients,
    );
    recipes.add(recipe);
    return recipe;
  }

  @override
  Future<Recipe> updateRecipe(
    int id, {
    required String title,
    String? notes,
    String? recipeUrl,
    List<String> mealTypes = const [],
    List<RecipeIngredient> ingredients = const [],
  }) async {
    updated.add(title);
    final index = recipes.indexWhere((r) => r.id == id);
    final recipe = Recipe(
      id: id,
      title: title,
      notes: notes,
      recipeUrl: recipeUrl,
      mealTypes: mealTypes,
      ingredients: ingredients,
      source: recipes[index].source,
    );
    recipes[index] = recipe;
    return recipe;
  }

  @override
  Future<void> deleteRecipe(int id) async {
    deleted.add(id);
    recipes.removeWhere((r) => r.id == id);
  }
}

Widget _pump(FakeRecipeRepository repo) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => FakeAuthController(Authenticated(user: fakeUser())),
      ),
      recipeRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(home: RecipesScreen()),
  );
}

void main() {
  testWidgets('Recipes screen renders title, ingredients and meal types', (
    tester,
  ) async {
    final repo = FakeRecipeRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    expect(find.text('Pizza'), findsOneWidget);
    expect(find.text('Zuppa'), findsOneWidget);
    expect(find.textContaining('2 ingredienti'), findsOneWidget);
    expect(find.textContaining('Cena'), findsOneWidget);
    expect(find.textContaining('esterna'), findsOneWidget);
  });

  testWidgets('Search filters the list', (tester) async {
    final repo = FakeRecipeRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zup');
    await tester.pumpAndSettle();

    expect(find.text('Zuppa'), findsOneWidget);
    expect(find.text('Pizza'), findsNothing);
  });

  testWidgets('Tapping a recipe opens the ingredient detail', (tester) async {
    final repo = FakeRecipeRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pizza'));
    await tester.pumpAndSettle();

    expect(find.text('Ingredienti'), findsOneWidget);
    expect(find.textContaining('Farina (500g)'), findsOneWidget);
    expect(find.textContaining('Pomodoro'), findsOneWidget);
    expect(find.text('lievitazione 24h'), findsOneWidget);
  });

  testWidgets('A recipe can be created with an ingredient', (tester) async {
    final repo = FakeRecipeRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Aggiungi ricetta'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'Risotto');
    await tester.enterText(fields.at(1), 'Riso');
    await tester.enterText(fields.at(2), '300g');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(repo.created, ['Risotto']);
    final recipe = repo.recipes.firstWhere((r) => r.title == 'Risotto');
    expect(recipe.ingredients.single.name, 'Riso');
    expect(recipe.ingredients.single.quantity, '300g');
    expect(find.text('Risotto'), findsOneWidget);
  });

  testWidgets('A recipe can be edited from the detail sheet', (tester) async {
    final repo = FakeRecipeRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pizza'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Modifica'));
    await tester.pumpAndSettle();
    expect(find.text('Modifica ricetta'), findsOneWidget);

    await tester.enterText(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .at(0),
      'Pizza napoletana',
    );
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(repo.updated, ['Pizza napoletana']);
    expect(find.text('Pizza napoletana'), findsOneWidget);
  });

  testWidgets('A native recipe can be deleted, a mirrored one cannot', (
    tester,
  ) async {
    final repo = FakeRecipeRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    // La ricetta esterna non offre Modifica/Elimina.
    await tester.tap(find.text('Zuppa'));
    await tester.pumpAndSettle();
    expect(find.textContaining('importata da un provider'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Modifica'), findsNothing);
    await tester.tapAt(const Offset(10, 10)); // chiude il foglio
    await tester.pumpAndSettle();

    // Quella nativa sì.
    await tester.tap(find.text('Pizza'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Elimina'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Elimina'));
    await tester.pumpAndSettle();

    expect(repo.deleted, [1]);
    expect(find.text('Pizza'), findsNothing);
  });
}
