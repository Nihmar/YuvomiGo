/// Un pasto pianificato (server: tabella `meals`).
final class Meal {
  const Meal({
    required this.id,
    required this.date,
    required this.mealType,
    required this.title,
    this.notes,
  });

  final int id;
  final String date; // 'YYYY-MM-DD'
  final String mealType; // breakfast|lunch|dinner|snack
  final String title;
  final String? notes;

  factory Meal.fromJson(Map<String, dynamic> json) => Meal(
    id: (json['id'] as num?)?.toInt() ?? -1,
    date: json['date'] as String? ?? '',
    mealType: json['meal_type'] as String? ?? 'dinner',
    title: json['title'] as String? ?? '',
    notes: json['notes'] as String?,
  );
}

/// La settimana (lunedì–domenica) restituita da `GET /api/v1/meals?week=`.
final class MealWeek {
  const MealWeek({
    required this.weekStart,
    required this.weekEnd,
    this.meals = const [],
  });

  final String weekStart;
  final String weekEnd;
  final List<Meal> meals;

  factory MealWeek.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] is List ? json['data'] as List : const [];
    return MealWeek(
      weekStart: json['weekStart'] as String? ?? '',
      weekEnd: json['weekEnd'] as String? ?? '',
      meals: raw.whereType<Map<String, dynamic>>().map(Meal.fromJson).toList(),
    );
  }
}

/// Etichetta italiana del tipo pasto.
String mealTypeLabel(String type) => switch (type) {
  'breakfast' => 'Colazione',
  'lunch' => 'Pranzo',
  'dinner' => 'Cena',
  'snack' => 'Spuntino',
  _ => type,
};

/// Ordine dei pasti nella giornata (come il server).
int mealTypeOrder(String type) => switch (type) {
  'breakfast' => 0,
  'lunch' => 1,
  'dinner' => 2,
  'snack' => 3,
  _ => 4,
};
