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
  Future<List<Task>> fetchTasks({String status = 'open'}) async {
    final res = await _api.dio.get<dynamic>(
      '/api/v1/tasks',
      queryParameters: {'status': status},
    );
    final data = (res.data is Map)
        ? (res.data as Map<String, dynamic>)['data']
        : res.data;
    final list = (data as List<dynamic>)
        .map((e) => Task.fromJson(e as Map<String, dynamic>))
        .toList();
    list.sort((a, b) {
      final ad = a.dueDate ?? '9999-99-99';
      final bd = b.dueDate ?? '9999-99-99';
      return ad.compareTo(bd);
    });
    return list;
  }

  Future<Task> createTask({
    required String title,
    String? dueDate,
    String priority = 'none',
    String? category,
  }) async {
    final res = await _api.dio.post<dynamic>(
      '/api/v1/tasks',
      data: {
        'title': title,
        'priority': priority,
        'due_date': dueDate,
        'category': category,
      },
    );
    final data = (res.data is Map)
        ? (res.data as Map<String, dynamic>)['data']
        : res.data;
    return Task.fromJson(data as Map<String, dynamic>);
  }

  /// Cambia lo status (open/done/in_progress).
  Future<Task> setStatus(int id, TaskStatus status) async {
    final res = await _api.dio.patch<dynamic>(
      '/api/v1/tasks/$id/status',
      data: {'status': status.wire},
    );
    final data = (res.data is Map)
        ? (res.data as Map<String, dynamic>)['data']
        : res.data;
    return Task.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteTask(int id) async {
    await _api.dio.delete<void>('/api/v1/tasks/$id');
  }
}
