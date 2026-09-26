import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/task_repository.dart';
import 'package:yuvomigo/features/tasks/task_models.dart';
import 'package:yuvomigo/features/tasks/task_providers.dart';

import 'utils/in_memory_storage.dart';

final class _FlakyTaskRepository extends TaskRepository {
  _FlakyTaskRepository()
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  bool fail = false;
  int calls = 0;

  @override
  Future<List<Task>> fetchTasks({
    List<String> statuses = const ['open', 'in_progress'],
  }) async {
    calls++;
    if (fail) throw const ApiNetworkError('offline');
    return const [Task(id: 1, title: 'A')];
  }
}

void main() {
  test('refresh keeps the current list when the fetch fails', () async {
    final repo = _FlakyTaskRepository();
    final container = ProviderContainer.test(
      overrides: [taskRepositoryProvider.overrideWithValue(repo)],
    );
    // Tiene vivo l'autoDispose provider per tutta la durata del test.
    final sub = container.listen(tasksProvider, (_, _) {});
    addTearDown(sub.close);

    container.read(tasksProvider);
    await pumpEventQueue();
    expect(container.read(tasksProvider).value, hasLength(1));

    repo.fail = true;
    await container.read(tasksProvider.notifier).refresh();

    // I dati a schermo restano validi e l'errore va allo SnackBar.
    expect(container.read(tasksProvider).value, hasLength(1));
    expect(container.read(tasksActionErrorProvider), isA<ApiNetworkError>());
  });

  test('refresh replaces the list when the fetch succeeds', () async {
    final repo = _FlakyTaskRepository();
    final container = ProviderContainer.test(
      overrides: [taskRepositoryProvider.overrideWithValue(repo)],
    );
    final sub = container.listen(tasksProvider, (_, _) {});
    addTearDown(sub.close);

    container.read(tasksProvider);
    await pumpEventQueue();

    await container.read(tasksProvider.notifier).refresh();

    expect(repo.calls, 2);
    expect(container.read(tasksProvider).value, hasLength(1));
  });

  test('disposing right after build does not throw', () async {
    final repo = _FlakyTaskRepository();
    final container = ProviderContainer.test(
      overrides: [taskRepositoryProvider.overrideWithValue(repo)],
    );

    // Il microtask di caricamento parte dopo il build: se il provider viene
    // smontato subito, la guardia deve fermarlo senza errori asincroni.
    container.read(tasksProvider);
    container.dispose();
    await pumpEventQueue();

    expect(repo.calls, lessThanOrEqualTo(1));
  });
}
