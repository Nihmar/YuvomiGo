import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/features/tasks/task_models.dart';
import 'package:yuvomigo/core/utils/date_utils.dart';
import 'package:yuvomigo/features/tasks/task_providers.dart';
import 'package:yuvomigo/features/home/modules_button.dart';
import 'package:yuvomigo/features/settings/settings_button.dart';

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
      appBar: AppBar(
        title: const Text('Task'),
        actions: const [ModulesButton(), SettingsButton()],
      ),
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
        onPressed: () => _TaskEditorDialog.show(context),
        child: const Icon(Icons.add),
      ),
    );
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

/// Dialog di creazione task: titolo + data + priorità.
final class _TaskEditorDialog extends ConsumerStatefulWidget {
  const _TaskEditorDialog();

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const _TaskEditorDialog(),
    );
  }

  @override
  ConsumerState<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

final class _TaskEditorDialogState extends ConsumerState<_TaskEditorDialog> {
  static const _priorities = <String, String>{
    'none': 'Nessuna',
    'low': 'Bassa',
    'medium': 'Media',
    'high': 'Alta',
    'urgent': 'Urgente',
  };

  final _title = TextEditingController();
  String? _dueDate;
  String _priority = 'none';
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate == null ? now : DateTime.parse(_dueDate!),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(() => _dueDate = dateKey(picked));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final created = await ref
        .read(tasksProvider.notifier)
        .add(title: title, dueDate: _dueDate, priority: _priority);
    if (!mounted) return;
    if (!created) {
      setState(() => _busy = false);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuova task'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Titolo'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickDate,
                  icon: const Icon(Icons.event),
                  label: Text(_dueDate ?? 'Nessuna data'),
                ),
              ),
              if (_dueDate != null)
                IconButton(
                  tooltip: 'Rimuovi data',
                  icon: const Icon(Icons.clear),
                  onPressed: _busy
                      ? null
                      : () => setState(() => _dueDate = null),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: 'Priorità'),
            items: [
              for (final entry in _priorities.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _priority = value ?? 'none'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Aggiungi'),
        ),
      ],
    );
  }
}
