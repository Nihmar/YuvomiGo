import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/meals/meal_models.dart';

/// Repository per il modulo Pasti.
///
/// La response usa `{ data: [...], weekStart, weekEnd }`: richiesta raw via
/// Dio + parsing nei model di dominio.
base class MealRepository {
  MealRepository(this._api);

  final YuvomiApi _api;

  /// Pasti della settimana che contiene [week] (`YYYY-MM-DD`).
  Future<MealWeek> fetchWeek(String week) {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/api/v1/meals',
        queryParameters: {'week': week},
      );
      return MealWeek.fromJson(res.data ?? const <String, dynamic>{});
    });
  }

  Future<Meal> createMeal({
    required String date,
    required String mealType,
    required String title,
    String? notes,
  }) {
    return mapApiErrors(() async {
      final res = await _api.dio.post<dynamic>(
        '/api/v1/meals',
        data: {
          'date': date,
          'meal_type': mealType,
          'title': title,
          'notes': ?notes,
        },
      );
      final data = (res.data is Map)
          ? (res.data as Map<String, dynamic>)['data']
          : res.data;
      return Meal.fromJson(data as Map<String, dynamic>);
    });
  }

  Future<void> deleteMeal(int id) {
    return mapApiErrors(() => _api.dio.delete<void>('/api/v1/meals/$id'));
  }
}
