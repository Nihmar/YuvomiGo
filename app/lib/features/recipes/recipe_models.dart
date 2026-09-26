/// Un ingrediente di ricetta (server: `recipe_ingredients`).
final class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    this.quantity,
    this.category = '',
  });

  final String name;
  final String? quantity;
  final String category;

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        name: json['name'] as String? ?? '',
        quantity: json['quantity'] as String?,
        category: json['category'] as String? ?? '',
      );
}

/// Una ricetta (server: `recipes` + ingredienti + campi calcolati).
final class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    this.notes,
    this.recipeUrl,
    this.mealTypes = const [],
    this.ingredients = const [],
    this.source = 'native',
  });

  final int id;
  final String title;
  final String? notes;
  final String? recipeUrl;

  /// Tipi pasto consigliati (breakfast|lunch|dinner|snack).
  final List<String> mealTypes;
  final List<RecipeIngredient> ingredients;

  /// 'native' se creata nell'app/household, altrimenti il provider.
  final String source;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final rawIngredients = json['ingredients'] is List
        ? json['ingredients'] as List
        : const [];
    final rawTypes = json['meal_types'] is List
        ? json['meal_types'] as List
        : const [];
    return Recipe(
      id: (json['id'] as num?)?.toInt() ?? -1,
      title: json['title'] as String? ?? '',
      notes: json['notes'] as String?,
      recipeUrl: json['recipe_url'] as String?,
      mealTypes: rawTypes.whereType<String>().toList(),
      ingredients: rawIngredients
          .whereType<Map<String, dynamic>>()
          .map(RecipeIngredient.fromJson)
          .toList(),
      source: json['source'] as String? ?? 'native',
    );
  }
}
