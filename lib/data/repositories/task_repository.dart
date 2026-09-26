import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/tasks/task_models.dart';

/// Repository per il modulo Task (sottoinsieme MVP).
///
/// L'API task non espone schema response: richiesta raw via Dio + parsing.
/// Le response usano il wrapping `{ data: ... }`.
base class TaskRepository {
  TaskRepository(this._api);

  final YuvomiApi _api;

  /// Task aperte (default) — `status` opzionale.
  Future<List<Task>> fetchTasks({String status = 'open'}) {
    return mapApiErrors(() async {
      final res = await _api.dio.get<dynamic>(
        '/api/v1/tasks',
        queryParameters: {'status': status},
      );
      final data = (res.data is Map)
          ? (res.data as Map<String, dynamic>)['data']
          : res.data;
      // `data` assente/non-lista (es. risposta inattesa con 200): lista vuota
      // invece di un TypeError che oscura l'errore vero.
      final raw = (data as List<dynamic>?) ?? const <dynamic>[];
      final list = raw
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort(compareTasksByDueDate);
      return list;
    });
  }

  Future<Task> createTask({
    required String title,
    String? dueDate,
    String priority = 'none',
    String? category,
  }) {
    return mapApiErrors(() async {
      final res = await _api.dio.post<dynamic>(
        '/api/v1/tasks',
        // Solo i campi valorizzati: i null espliciti non aggiungono nulla
        // e alcuni endpoint li interpretano come "azzera".
        data: {
          'title': title,
          'priority': priority,
          'due_date': ?dueDate,
          'category': ?category,
        },
      );
      final data = (res.data is Map)
          ? (res.data as Map<String, dynamic>)['data']
          : res.data;
      return Task.fromJson(data as Map<String, dynamic>);
    });
  }

  /// Cambia lo status (open/done/in_progress).
  Future<Task> setStatus(int id, TaskStatus status) {
    return mapApiErrors(() async {
      final res = await _api.dio.patch<dynamic>(
        '/api/v1/tasks/$id/status',
        data: {'status': status.wire},
      );
      final data = (res.data is Map)
          ? (res.data as Map<String, dynamic>)['data']
          : res.data;
      return Task.fromJson(data as Map<String, dynamic>);
    });
  }

  Future<void> deleteTask(int id) {
    return mapApiErrors(() => _api.dio.delete<void>('/api/v1/tasks/$id'));
  }
}
