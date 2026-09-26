import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/waste/waste_models.dart';

/// Repository per il modulo Rifiuti: prossime raccolte + raccolte extra.
base class WasteRepository {
  WasteRepository(this._api);

  final YuvomiApi _api;

  Future<List<WasteNextPickup>> fetchNextPickups() {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/api/v1/waste/occurrences/next',
      );
      final data = res.data?['data'];
      final raw = data is List ? data : const <dynamic>[];
      final list = raw
          .whereType<Map<String, dynamic>>()
          .map(WasteNextPickup.fromJson)
          .toList();
      list.sort(compareWastePickups);
      return list;
    });
  }

  /// Tipi di raccolta configurati (per i form).
  Future<List<WasteType>> fetchTypes() {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/api/v1/waste/types',
      );
      final data = res.data?['data'];
      final raw = data is List ? data : const <dynamic>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(WasteType.fromJson)
          .toList();
    });
  }

  /// Raccolte straordinarie, ordinate per data.
  Future<List<WastePickup>> fetchPickups() {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/api/v1/waste/pickups',
      );
      final data = res.data?['data'];
      final raw = data is List ? data : const <dynamic>[];
      final list = raw
          .whereType<Map<String, dynamic>>()
          .map(WastePickup.fromJson)
          .toList();
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    });
  }

  Future<WastePickup> createPickup({
    required int typeId,
    required String date,
    String? note,
  }) {
    return mapApiErrors(() async {
      final res = await _api.dio.post<dynamic>(
        '/api/v1/waste/pickups',
        data: {'type_id': typeId, 'date': date, 'note': note},
      );
      return WastePickup.fromJson(_data(res.data));
    });
  }

  Future<WastePickup> updatePickup(
    int id, {
    required String date,
    String? note,
  }) {
    return mapApiErrors(() async {
      final res = await _api.dio.put<dynamic>(
        '/api/v1/waste/pickups/$id',
        data: {'date': date, 'note': note},
      );
      return WastePickup.fromJson(_data(res.data));
    });
  }

  Future<void> deletePickup(int id) {
    return mapApiErrors(
      () => _api.dio.delete<void>('/api/v1/waste/pickups/$id'),
    );
  }

  Map<String, dynamic> _data(Object? body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
    }
    throw const ApiServerError(200, 'Risposta inattesa dal server.');
  }
}
