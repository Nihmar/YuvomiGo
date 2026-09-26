import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/task_repository.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/tasks/task_models.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) throw StateError('TaskRepository senza sessione attiva');
  return TaskRepository(api);
});

/// Ultimo errore di un'azione (add/toggle/remove). La lista resta intatta:
/// lo screen lo mostra come SnackBar. Null = nessuna azione fallita di recente.
final tasksActionErrorProvider =
    NotifierProvider<TasksActionErrorNotifier, Object?>(
      TasksActionErrorNotifier.new,
    );

final class TasksActionErrorNotifier extends Notifier<Object?> {
  @override
  Object? build() => null;

  void clear() => state = null;
  void report(Object error) => state = error;
}

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

  Future<void> load() => _fetch(showLoading: true);

  /// Ricarica mantenendo i dati correnti (pull-to-refresh).
  Future<void> refresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (!ref.mounted) return;
    if (_loading) return;
    _loading = true;
    final repo = ref.read(taskRepositoryProvider);
    if (showLoading) state = const AsyncLoading();
    try {
      final tasks = await repo.fetchTasks();
      if (!ref.mounted) return;
      state = AsyncData(tasks);
    } catch (e, st) {
      if (!ref.mounted) return;
      if (state.hasValue) {
        // La lista mostrata è ancora valida: l'errore va allo SnackBar.
        ref.read(tasksActionErrorProvider.notifier).report(e);
      } else {
        state = AsyncError(e, st);
      }
    } finally {
      _loading = false;
    }
  }

  /// Crea la task; ritorna false se il salvataggio fallisce (il dialog
  /// resta aperto e l'errore va allo SnackBar).
  Future<bool> add({
    required String title,
    String? dueDate,
    String priority = 'none',
  }) async {
    if (!ref.mounted) return false;
    final repo = ref.read(taskRepositoryProvider);
    ref.read(tasksActionErrorProvider.notifier).clear();
    try {
      final created = await repo.createTask(
        title: title,
        dueDate: dueDate,
        priority: priority,
      );
      if (!ref.mounted) return false;
      final tasks = [...state.value ?? const <Task>[], created]
        ..sort(compareTasksByDueDate);
      state = AsyncData(tasks);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      // La lista resta quella di prima: l'errore va allo SnackBar.
      ref.read(tasksActionErrorProvider.notifier).report(e);
      return false;
    }
  }

  Future<void> toggle(int id) async {
    if (!ref.mounted) return;
    final prev = state.value ?? const <Task>[];
    final current = prev.firstWhere(
      (t) => t.id == id,
      orElse: () => Task(id: id, title: ''),
    );
    final next = current.status == TaskStatus.done
        ? TaskStatus.open
        : TaskStatus.done;
    final repo = ref.read(taskRepositoryProvider);
    ref.read(tasksActionErrorProvider.notifier).clear();
    try {
      final updated = await repo.setStatus(id, next);
      if (!ref.mounted) return;
      // La lista mostra le task aperte: quelle completate escono di scena
      // (come nel web, che dopo il toggle ricarica la vista filtrata).
      final tasks = next == TaskStatus.done
          ? prev.where((t) => t.id != id).toList()
          : prev.map((t) => t.id == id ? updated : t).toList();
      state = AsyncData(tasks);
    } catch (e) {
      if (!ref.mounted) return;
      ref.read(tasksActionErrorProvider.notifier).report(e);
    }
  }

  Future<void> remove(int id) async {
    if (!ref.mounted) return;
    final prev = state.value ?? const <Task>[];
    final repo = ref.read(taskRepositoryProvider);
    ref.read(tasksActionErrorProvider.notifier).clear();
    try {
      await repo.deleteTask(id);
      if (!ref.mounted) return;
      state = AsyncData(prev.where((t) => t.id != id).toList());
    } catch (e) {
      if (!ref.mounted) return;
      ref.read(tasksActionErrorProvider.notifier).report(e);
    }
  }
}
