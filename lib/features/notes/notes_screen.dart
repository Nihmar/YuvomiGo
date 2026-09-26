import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/core/utils/color_utils.dart';
import 'package:yuvomigo/features/notes/note_models.dart';
import 'package:yuvomigo/features/notes/note_providers.dart';
import 'package:yuvomigo/features/home/modules_button.dart';
import 'package:yuvomigo/features/settings/settings_button.dart';

/// Tab Note: elenco note + creazione/modifica.
final class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  static const _scrollPhysics = AlwaysScrollableScrollPhysics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    ref.listen<Object?>(notesActionErrorProvider, (_, err) {
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operazione non riuscita: $err')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.label_outline),
            tooltip: 'Categorie',
            onPressed: () => _ManageCategoriesDialog.show(context),
          ),
          const ModulesButton(),
          const SettingsButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notesProvider.notifier).refresh(),
        child: notes.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: _scrollPhysics,
            padding: const EdgeInsets.all(16),
            children: [
              ErrorRetryTile(
                message: 'Impossibile caricare le note.',
                detail: e.toString(),
                onRetry: () => ref.read(notesProvider.notifier).load(),
              ),
            ],
          ),
          data: (notes) {
            if (notes.isEmpty) {
              return ListView(
                physics: _scrollPhysics,
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Nessuna nota.\nUsa "Aggiungi" per crearne una.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: _scrollPhysics,
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
                        : parseHexColor(note.color),
                  ),
                  title: Text(
                    hasTitle ? title! : firstLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      if (hasTitle) firstLine,
                      if (note.categories.isNotEmpty)
                        note.categories.map((c) => c.name).join(', '),
                    ].join(' · '),
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
  /// Palette proposta nel dialog (hex accettati dal server).
  static const _colors = <String>[
    '#FFEB3B',
    '#FFCDD2',
    '#BBDEFB',
    '#C8E6C9',
    '#F8BBD0',
    '#E1BEE7',
  ];

  final _title = TextEditingController();
  final _content = TextEditingController();
  bool _pinned = false;
  bool _busy = false;
  String? _color;
  late Set<int> _categoryIds;

  @override
  void initState() {
    super.initState();
    _title.text = widget.note?.title ?? '';
    _content.text = widget.note?.content ?? '';
    _pinned = widget.note?.pinned ?? false;
    _color = widget.note?.color;
    _categoryIds = widget.note?.categories.map((c) => c.id).toSet() ?? {};
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
    final categories =
        ref.watch(noteCategoriesProvider).value ?? const <NoteCategory>[];
    return AlertDialog(
      title: Text(isEdit ? 'Modifica nota' : 'Nuova nota'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Titolo (opzionale)',
              ),
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
                Checkbox(
                  value: _pinned,
                  onChanged: (v) => setState(() => _pinned = v ?? false),
                ),
                const Text('Fissa in alto'),
              ],
            ),
            const SizedBox(height: 12),
            if (categories.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Categorie',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  for (final category in categories)
                    FilterChip(
                      label: Text(category.name),
                      selected: _categoryIds.contains(category.id),
                      onSelected: _busy
                          ? null
                          : (selected) => setState(() {
                              if (selected) {
                                _categoryIds.add(category.id);
                              } else {
                                _categoryIds.remove(category.id);
                              }
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Colore',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final hex in _colors)
                  _ColorDot(
                    hex: hex,
                    selected: _color?.toUpperCase() == hex,
                    onTap: _busy ? null : () => setState(() => _color = hex),
                  ),
              ],
            ),
          ],
        ),
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
    // Stringa vuota = "azzera il titolo" (il server la normalizza a null);
    // null = "non toccare" (usato dal toggle del pin).
    final title = _title.text.trim();
    // Capture navigator prima dell'await (il context non è valido dopo).
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final notifier = ref.read(notesProvider.notifier);
    final note = widget.note;
    final success = note == null
        ? await notifier.add(
            content: content,
            title: title,
            color: _color,
            pinned: _pinned,
            categoryIds: _categoryIds.toList(),
          )
        : await notifier.update(
            note.id,
            content: content,
            title: title,
            color: _color,
            pinned: _pinned,
            categoryIds: _categoryIds.toList(),
          );
    if (!mounted) return;
    if (!success) {
      // Salvataggio fallito: il dialog resta aperto con il testo digitato,
      // l'errore è mostrato dallo SnackBar della schermata Note.
      setState(() => _busy = false);
      return;
    }
    navigator.pop();
  }
}

/// Pallino colore selezionabile nel dialog delle note.
final class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('note-color-$hex'),
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: parseHexColor(hex),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 18, color: Colors.black54)
            : null,
      ),
    );
  }
}

/// Converte un colore `#RRGGBB` della nota in [Color]; null se non valido.

/// Dialog di gestione delle categorie delle note (crea/rinomina/elimina).
final class _ManageCategoriesDialog extends ConsumerStatefulWidget {
  const _ManageCategoriesDialog();

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const _ManageCategoriesDialog(),
    );
  }

  @override
  ConsumerState<_ManageCategoriesDialog> createState() =>
      _ManageCategoriesDialogState();
}

final class _ManageCategoriesDialogState
    extends ConsumerState<_ManageCategoriesDialog> {
  final _name = TextEditingController();
  String _scope = 'personal';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    final created = await ref
        .read(noteCategoriesProvider.notifier)
        .add(name, scope: _scope);
    if (!mounted) return;
    setState(() => _busy = false);
    if (created) _name.clear();
  }

  Future<void> _rename(NoteCategory category) async {
    final controller = TextEditingController(text: category.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rinomina categoria'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    await ref
        .read(noteCategoriesProvider.notifier)
        .rename(category.id, newName);
  }

  Future<void> _delete(NoteCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Elimina categoria'),
        content: Text('Vuoi eliminare "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(noteCategoriesProvider.notifier).remove(category.id);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(noteCategoriesProvider);
    return AlertDialog(
      title: const Text('Categorie note'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Nuova categoria',
                      ),
                      onSubmitted: (_) => _create(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Aggiungi',
                    icon: const Icon(Icons.add),
                    onPressed: _busy ? null : _create,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'personal', label: Text('Personale')),
                  ButtonSegment(value: 'household', label: Text('Condivisa')),
                ],
                selected: {_scope},
                onSelectionChanged: _busy
                    ? null
                    : (selection) => setState(() => _scope = selection.first),
              ),
              const SizedBox(height: 12),
              categories.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorRetryTile(
                  message: 'Impossibile caricare le categorie.',
                  detail: e.toString(),
                  onRetry: () =>
                      ref.read(noteCategoriesProvider.notifier).load(),
                ),
                data: (list) => Column(
                  children: [
                    if (list.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Nessuna categoria.'),
                      ),
                    for (final category in list)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(category.name),
                        subtitle: Text(
                          category.scope == 'household'
                              ? 'Condivisa'
                              : 'Personale',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Rinomina',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _rename(category),
                            ),
                            IconButton(
                              tooltip: 'Elimina',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(category),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Chiudi'),
        ),
      ],
    );
  }
}
