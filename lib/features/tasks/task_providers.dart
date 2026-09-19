import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/task_repository.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/tasks/task_models.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) throw StateError('TaskRepository senza sessione attiva');
  return TaskRepository(api);
});

final tasksProvider =
    NotifierProvider.autoDispose<TasksNotifier, AsyncValue<List<Task>>>(
  TasksNotifier.new,
);

final class TasksNotifier extends Notifier<AsyncValue<List<Task>>> {
  bool _loading = false;

  @override
  AsyncValue<List<Task>> build() {
    Future.microtask(load);
    return const AsyncLoading();
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    final repo = ref.read(taskRepositoryProvider);
    try {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => repo.fetchTasks());
    } finally {
      _loading = false;
    }
  }

  Future<void> add({
    required String title,
    String? dueDate,
    String priority = 'none',
  }) async {
    final repo = ref.read(taskRepositoryProvider);
    try {
      final created =
          await repo.createTask(title: title, dueDate: dueDate, priority: priority);
      final tasks = (state.value ?? const <Task>[]).toSet()..add(created);
      state = AsyncData(tasks.toList());
    } catch (e, st) {
      state = AsyncError<List<Task>>(e, st);
    }
  }

  Future<void> toggle(int id) async {
    final current = state.value?.firstWhere(
      (t) => t.id == id,
      orElse: () => Task(id: id, title: ''),
    ) ??
        Task(id: id, title: '');
    final next = current.status == TaskStatus.done
        ? TaskStatus.open
        : TaskStatus.done;
    final repo = ref.read(taskRepositoryProvider);
    try {
      final updated = await repo.setStatus(id, next);
      final tasks =
          state.value?.map((t) => t.id == id ? updated : t).toList();
      state = AsyncData(tasks ?? const <Task>[]);
    } catch (e, st) {
      state = AsyncError<List<Task>>(e, st);
    }
  }

  Future<void> remove(int id) async {
    final repo = ref.read(taskRepositoryProvider);
    try {
      await repo.deleteTask(id);
      final tasks =
          state.value?.where((t) => t.id != id).toList() ?? const <Task>[];
      state = AsyncData(tasks);
    } catch (e, st) {
      state = AsyncError<List<Task>>(e, st);
    }
  }
}
