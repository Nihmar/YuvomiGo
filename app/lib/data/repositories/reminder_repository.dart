import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/reminders/reminder_models.dart';

/// Repository per il modulo Promemoria (sottoinsieme: scaduti + azioni).
base class ReminderRepository {
  ReminderRepository(this._api);

  final YuvomiApi _api;

  /// Promemoria in scadenza (il server filtra `remind_at <= now`,
  /// non ancora archiviati).
  Future<List<Reminder>> fetchPending() {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/api/v1/reminders/pending',
      );
      final data = res.data?['data'];
      final raw = data is List ? data : const <dynamic>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(Reminder.fromJson)
          .toList();
    });
  }

  Future<void> dismiss(int id) {
    return mapApiErrors(
      () => _api.dio.patch<void>('/api/v1/reminders/$id/dismiss'),
    );
  }

  Future<void> deleteReminder(int id) {
    return mapApiErrors(() => _api.dio.delete<void>('/api/v1/reminders/$id'));
  }
}
