import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/features/tasks/task_models.dart';
import 'package:yuvomigo/features/tasks/task_providers.dart';

/// Tab Task: task aperte + creazione/complete/delete.
final class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  static const _scrollPhysics = AlwaysScrollableScrollPhysics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    ref.listen<Object?>(tasksActionErrorProvider, (_, err) {
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operazione non riuscita: $err')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Task')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(tasksProvider.notifier).refresh(),
        child: tasks.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: _scrollPhysics,
            padding: const EdgeInsets.all(16),
            children: [
              ErrorRetryTile(
                message: 'Impossibile caricare le task.',
                detail: e.toString(),
                onRetry: () => ref.read(tasksProvider.notifier).load(),
              ),
            ],
          ),
          data: (tasks) {
            if (tasks.isEmpty) {
              return ListView(
                physics: _scrollPhysics,
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Nessuna task aperta.\nUsa "Aggiungi" per crearne una.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: _scrollPhysics,
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                final isDone = task.status == TaskStatus.done;
                return ListTile(
                  leading: Checkbox(
                    value: isDone,
                    onChanged: (v) =>
                        ref.read(tasksProvider.notifier).toggle(task.id),
                  ),
                  title: Text(
                    task.title,
                    style: TextStyle(
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: _TaskSubtitle(task: task),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref, task),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _promptForTask(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _promptForTask(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuova task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Titolo'),
          onSubmitted: (value) => _submit(controller, dialogContext, ref),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => _submit(controller, dialogContext, ref),
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
  }

  void _submit(
    TextEditingController controller,
    BuildContext dialogContext,
    WidgetRef ref,
  ) {
    final title = controller.text.trim();
    if (title.isNotEmpty) {
      ref.read(tasksProvider.notifier).add(title: title);
    }
    Navigator.of(dialogContext).pop();
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Task task) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Elimina task'),
        content: const Text('Vuoi eliminare questa task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(tasksProvider.notifier).remove(task.id);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}

final class _TaskSubtitle extends StatelessWidget {
  const _TaskSubtitle({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (task.dueDate != null) parts.add(task.dueDate!);
    if (task.status == TaskStatus.inProgress) parts.add('in corso');
    if (task.priority != 'none') parts.add(task.priority);
    if (task.isRecurring) parts.add('ricorrente');
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(parts.join(' · '));
  }
}
