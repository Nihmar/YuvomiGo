import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/features/birthdays/birthday_models.dart';
import 'package:yuvomigo/features/birthdays/birthday_providers.dart';

/// Schermata Compleanni: lista ordinata per prossimo compleanno.
final class BirthdaysScreen extends ConsumerWidget {
  const BirthdaysScreen({super.key});

  static const _scrollPhysics = AlwaysScrollableScrollPhysics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final birthdays = ref.watch(birthdaysProvider);
    ref.listen<Object?>(birthdaysActionErrorProvider, (_, err) {
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operazione non riuscita: $err')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Compleanni')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(birthdaysProvider.notifier).refresh(),
        child: birthdays.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: _scrollPhysics,
            padding: const EdgeInsets.all(16),
            children: [
              ErrorRetryTile(
                message: 'Impossibile caricare i compleanni.',
                detail: e.toString(),
                onRetry: () => ref.read(birthdaysProvider.notifier).load(),
              ),
            ],
          ),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                physics: _scrollPhysics,
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Nessun compleanno.\nUsa "Aggiungi" per inserirne uno.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: _scrollPhysics,
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 88),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final birthday = list[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .secondaryContainer,
                    child: Icon(
                      Icons.cake_outlined,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  title: Text(birthday.name),
                  subtitle: Text(_subtitle(birthday)),
                  onTap: () =>
                      _BirthdayEditorDialog.show(context, birthday: birthday),
                  trailing: IconButton(
                    tooltip: 'Elimina',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref, birthday),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _BirthdayEditorDialog.show(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _subtitle(Birthday birthday) {
    final parts = <String>[];
    final countdown = birthdayCountdown(birthday.daysUntil);
    if (countdown.isNotEmpty) {
      parts.add(countdown);
    } else if (birthday.birthDate.isNotEmpty) {
      parts.add(birthday.birthDate);
    }
    if (birthday.nextAge != null) {
      parts.add('compie ${birthday.nextAge}');
    }
    return parts.join(' · ');
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Birthday birthday,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Elimina compleanno'),
        content: Text('Vuoi eliminare "${birthday.name}"?'),
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
    if (confirmed == true) {
      await ref.read(birthdaysProvider.notifier).remove(birthday.id);
    }
  }
}

/// Dialog per creare/modificare un compleanno.
final class _BirthdayEditorDialog extends ConsumerStatefulWidget {
  const _BirthdayEditorDialog({this.birthday});

  final Birthday? birthday;

  static Future<void> show(BuildContext context, {Birthday? birthday}) {
    return showDialog<void>(
      context: context,
      builder: (_) => _BirthdayEditorDialog(birthday: birthday),
    );
  }

  @override
  ConsumerState<_BirthdayEditorDialog> createState() =>
      _BirthdayEditorDialogState();
}

final class _BirthdayEditorDialogState
    extends ConsumerState<_BirthdayEditorDialog> {
  final _name = TextEditingController();
  final _notes = TextEditingController();
  DateTime _birthDate = DateTime.now();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.text = widget.birthday?.name ?? '';
    _notes.text = widget.birthday?.notes ?? '';
    final parsed = DateTime.tryParse(widget.birthday?.birthDate ?? '');
    if (parsed != null) _birthDate = parsed;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final notes = _notes.text.trim();
    final navigator = Navigator.of(context);
    final notifier = ref.read(birthdaysProvider.notifier);
    setState(() => _busy = true);
    final birthday = widget.birthday;
    final success = birthday == null
        ? await notifier.add(
            name: name,
            birthDate: _dateKey(_birthDate),
            notes: notes.isEmpty ? null : notes,
          )
        : await notifier.update(
            birthday.id,
            name: name,
            birthDate: _dateKey(_birthDate),
            notes: notes.isEmpty ? null : notes,
          );
    if (!mounted) return;
    if (!success) {
      setState(() => _busy = false);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.birthday != null;
    return AlertDialog(
      title: Text(isEdit ? 'Modifica compleanno' : 'Nuovo compleanno'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickDate,
            icon: const Icon(Icons.event),
            label: Text(_formatDate(_birthDate)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Note (opzionale)'),
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
              : const Text('Salva'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    // La data di nascita è nel passato: mostro la forma gg/mm/aaaa.
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

String _dateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
