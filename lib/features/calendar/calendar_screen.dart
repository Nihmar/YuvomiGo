import 'package:flutter/material.dart';
import 'package:yuvomigo/features/home/module_placeholder.dart';

/// Calendario (placeholder): implementato in M2.
final class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Calendario',
      icon: Icons.calendar_month,
      detail: 'Vista mese/settimana, eventi e creazione. In arrivo in M2.',
    );
  }
}
