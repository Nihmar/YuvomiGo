import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/task_repository.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/tasks/task_models.dart';
import 'package:yuvomigo/features/tasks/task_providers.dart';
import 'package:yuvomigo/features/tasks/tasks_screen.dart';

import 'utils/fake_auth_controller.dart';
import 'utils/in_memory_storage.dart';

final class FakeTaskRepository extends TaskRepository {
  FakeTaskRepository()
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  final List<Task> tasks = [
    Task(id: 1, title: 'Spesa', dueDate: '2026-09-01'),
    Task(id: 2, title: 'Pagare bolletta', priority: 'high'),
  ];
  int _nextId = 100;

  @override
  Future<List<Task>> fetchTasks({String status = 'open'}) async =>
      tasks.toList();

  @override
  Future<Task> createTask({
    required String title,
    String? dueDate,
    String priority = 'none',
    String? category,
  }) {
    final t = Task(
      id: _nextId++,
      title: title,
      dueDate: dueDate,
      priority: priority,
    );
    tasks.add(t);
    return Future.value(t);
  }

  @override
  Future<Task> setStatus(int id, TaskStatus status) {
    final idx = tasks.indexWhere((t) => t.id == id);
    final old = tasks[idx];
    final updated = Task(
      id: id,
      title: old.title,
      status: status,
      priority: old.priority,
      dueDate: old.dueDate,
    );
    tasks[idx] = updated;
    return Future.value(updated);
  }

  @override
  Future<void> deleteTask(int id) async => tasks.removeWhere((t) => t.id == id);
}

/// Il server non raggiungibile: le azioni falliscono, la lista resta intatta.
final class FailingTaskRepository extends FakeTaskRepository {
  @override
  Future<Task> setStatus(int id, TaskStatus status) =>
      Future.error(Exception('offline'));
}

Widget _pump(Widget child, FakeTaskRepository repo) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => FakeAuthController(Authenticated(user: fakeUser())),
      ),
      taskRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('Tasks screen renders the open tasks', (tester) async {
    final repo = FakeTaskRepository();
    await tester.pumpWidget(_pump(const TasksScreen(), repo));
    await tester.pumpAndSettle();

    expect(find.text('Spesa'), findsOneWidget);
    expect(find.text('Pagare bolletta'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));
  });

  testWidgets('Toggling a task to done removes it from the open list', (
    tester,
  ) async {
    final repo = FakeTaskRepository();
    await tester.pumpWidget(_pump(const TasksScreen(), repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(repo.tasks.first.status, TaskStatus.done);
    // La lista mostra le task aperte: quella completata esce di scena.
    expect(find.text('Spesa'), findsNothing);
    expect(find.text('Pagare bolletta'), findsOneWidget);
  });

  testWidgets('Failed toggle keeps the task and shows an error', (
    tester,
  ) async {
    final repo = FailingTaskRepository();
    await tester.pumpWidget(_pump(const TasksScreen(), repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.text('Spesa'), findsOneWidget);
    expect(find.textContaining('Operazione non riuscita'), findsOneWidget);
  });

  testWidgets('Creating a task adds it', (tester) async {
    final repo = FakeTaskRepository();
    await tester.pumpWidget(_pump(const TasksScreen(), repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Nuova task');
    await tester.tap(find.text('Aggiungi'));
    await tester.pumpAndSettle();

    expect(find.text('Nuova task'), findsOneWidget);
    expect(repo.tasks.map((t) => t.title), contains('Nuova task'));
  });

  testWidgets('Deleting a task removes it', (tester) async {
    final repo = FakeTaskRepository();
    await tester.pumpWidget(_pump(const TasksScreen(), repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();

    expect(repo.tasks, hasLength(1));
  });
}
