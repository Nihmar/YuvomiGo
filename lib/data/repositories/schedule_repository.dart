import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/schedule/schedule_models.dart';

/// Repository per il modulo Turni (sola lettura: vista settimanale).
base class ScheduleRepository {
  ScheduleRepository(this._api);

  final YuvomiApi _api;

  /// Turni nel range [from, to] (estremi inclusi, 'YYYY-MM-DD').
  Future<List<ScheduleEntry>> fetchRange(String from, String to) {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/api/v1/schedule/entries',
        queryParameters: {'from': from, 'to': to},
      );
      final entries = ScheduleWeek.fromJson(
        res.data ?? const <String, dynamic>{},
      ).entries;
      entries.sort(
        (a, b) => a.dateKey.compareTo(b.dateKey) != 0
            ? a.dateKey.compareTo(b.dateKey)
            : compareScheduleEntries(a, b),
      );
      return entries;
    });
  }

  /// Membri del household, per etichettare i turni.
  Future<List<ScheduleMember>> fetchMembers() {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/api/v1/schedule/household-members',
      );
      final data = res.data?['data'];
      final raw = data is List ? data : const <dynamic>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ScheduleMember.fromJson)
          .toList();
    });
  }
}
