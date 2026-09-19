import 'package:flutter/material.dart';
import 'package:yuvomigo/features/home/module_placeholder.dart';

/// Task (placeholder): implementato in M2.
final class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Task',
      icon: Icons.task_alt,
      detail: 'Lista task, filtri, dettaglio e azioni. In arrivo in M2.',
    );
  }
}
