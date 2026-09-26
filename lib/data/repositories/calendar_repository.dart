import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/calendar/calendar_models.dart';

/// Repository per il modulo Calendario (read-only, MVP).
///
/// L'API calendar non espone schema response: richiesta raw via Dio +
/// parsing. La response usa il wrapping `{ data: [...] }`.
base class CalendarRepository {
  CalendarRepository(this._api);

  final YuvomiApi _api;

  /// Eventi nel range [from, to] (chiuso).
  Future<List<CalendarEvent>> fetchRange(String from, String to) {
    return mapApiErrors(() async {
      final res = await _api.dio.get<dynamic>(
        '/api/v1/calendar',
        queryParameters: {'from': from, 'to': to},
      );
      final data = (res.data is Map)
          ? (res.data as Map<String, dynamic>)['data']
          : res.data;
      // Risposta inattesa con 200: lista vuota invece di un TypeError.
      final raw = data is List ? data : const <dynamic>[];
      final list = raw
          .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => a.startDatetime.compareTo(b.startDatetime));
      return list;
    });
  }
}
