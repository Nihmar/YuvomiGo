import 'package:flutter/material.dart';
import 'package:yuvomigo/features/home/module_placeholder.dart';

/// Note (placeholder): implementato in M2.
final class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Note',
      icon: Icons.sticky_note_2,
      detail: 'Pinnwand: note, pin, categorie. In arrivo in M2.',
    );
  }
}
