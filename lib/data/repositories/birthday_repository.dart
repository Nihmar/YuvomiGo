import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/birthdays/birthday_models.dart';

/// Repository per il modulo Compleanni.
base class BirthdayRepository {
  BirthdayRepository(this._api);

  final YuvomiApi _api;

  Future<List<Birthday>> fetchBirthdays() {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>('/api/v1/birthdays');
      final data = res.data?['data'];
      final raw = data is List ? data : const <dynamic>[];
      final list = raw
          .whereType<Map<String, dynamic>>()
          .map(Birthday.fromJson)
          .toList();
      list.sort(compareBirthdays);
      return list;
    });
  }

  Future<Birthday> createBirthday({
    required String name,
    required String birthDate,
    String? notes,
  }) {
    return mapApiErrors(() async {
      final res = await _api.dio.post<dynamic>(
        '/api/v1/birthdays',
        data: {'name': name, 'birth_date': birthDate, 'notes': ?notes},
      );
      return Birthday.fromJson(_data(res.data));
    });
  }

  Future<Birthday> updateBirthday(
    int id, {
    required String name,
    required String birthDate,
    String? notes,
  }) {
    return mapApiErrors(() async {
      final res = await _api.dio.put<dynamic>(
        '/api/v1/birthdays/$id',
        data: {'name': name, 'birth_date': birthDate, 'notes': notes},
      );
      return Birthday.fromJson(_data(res.data));
    });
  }

  Future<void> deleteBirthday(int id) {
    return mapApiErrors(() => _api.dio.delete<void>('/api/v1/birthdays/$id'));
  }

  Map<String, dynamic> _data(Object? body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
    }
    throw const ApiServerError(200, 'Risposta inattesa dal server.');
  }
}
