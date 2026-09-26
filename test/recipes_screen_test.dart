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

  @override
  Future<List<Recipe>> fetchRecipes() async => const [
    Recipe(
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
    Recipe(id: 2, title: 'Zuppa', mealTypes: ['lunch'], source: 'chefkoch'),
  ];
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
}
