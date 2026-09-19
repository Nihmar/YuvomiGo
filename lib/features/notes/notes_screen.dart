import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/features/notes/note_models.dart';
import 'package:yuvomigo/features/notes/note_providers.dart';

/// Tab Note: elenco note + creazione/modifica.
final class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Note')),
      body: notes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Impossibile caricare le note.',
                        style: TextStyle(
                            color: scheme.onErrorContainer,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(e.toString(),
                        style: TextStyle(color: scheme.onErrorContainer)),
                  ],
                ),
              ),
            ),
          ],
        ),
        data: (notes) {
          if (notes.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Nessuna nota.\nUsa "Aggiungi" per crearne una.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            );
          }
          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              final title = note.title?.trim();
              final hasTitle = (title?.isNotEmpty ?? false);
              final firstLine = note.content.split('\n').first;
              return ListTile(
                leading: Icon(
                  note.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: note.pinned
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(
                  hasTitle ? title! : firstLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  hasTitle ? firstLine : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        note.pinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                      ),
                      onPressed: () => ref
                          .read(notesProvider.notifier)
                          .update(note.id, pinned: !note.pinned),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDelete(context, ref, note),
                    ),
                  ],
                ),
                onTap: () => _openEditor(context, ref, note),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, [Note? note]) {
    _NoteEditorDialog.show(context, note: note);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Note note) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Elimina nota'),
        content: const Text('Vuoi eliminare questa nota?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(notesProvider.notifier).remove(note.id);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}

/// Dialog per creare/modificare una nota.
final class _NoteEditorDialog extends ConsumerStatefulWidget {
  const _NoteEditorDialog({this.note});

  final Note? note;

  static void show(BuildContext context, {Note? note}) {
    showDialog<void>(
      context: context,
      builder: (_) => _NoteEditorDialog(note: note),
    );
  }

  @override
  ConsumerState<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

final class _NoteEditorDialogState extends ConsumerState<_NoteEditorDialog> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  bool _pinned = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _title.text = widget.note?.title ?? '';
    _content.text = widget.note?.content ?? '';
    _pinned = widget.note?.pinned ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.note != null;
    return AlertDialog(
      title: Text(isEdit ? 'Modifica nota' : 'Nuova nota'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Titolo (opzionale)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Contenuto'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(value: _pinned, onChanged: (v) => setState(() => _pinned = v ?? false)),
              const Text('Fissa in alto'),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () {
                  _save(context);
                },
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salva'),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context) async {
    final content = _content.text.trim();
    if (content.isEmpty) return;
    final title = _title.text.trim().isEmpty ? null : _title.text.trim();
    // Capture navigator prima dell'await (il context non è valido dopo).
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final notifier = ref.read(notesProvider.notifier);
    final note = widget.note;
    if (note == null) {
      await notifier.add(content: content, title: title, pinned: _pinned);
    } else {
      await notifier.update(
        note.id,
        content: content,
        title: title,
        pinned: _pinned,
      );
    }
    if (mounted) navigator.pop();
  }
}
