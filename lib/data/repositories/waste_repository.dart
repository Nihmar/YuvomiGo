import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/waste/waste_models.dart';

/// Repository per il modulo Rifiuti (sola lettura: prossime raccolte).
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
}
