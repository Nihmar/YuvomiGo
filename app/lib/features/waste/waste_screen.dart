import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/core/utils/color_utils.dart';
import 'package:yuvomigo/core/utils/date_utils.dart';
import 'package:yuvomigo/features/waste/waste_models.dart';
import 'package:yuvomigo/features/waste/waste_providers.dart';

/// Schermata Rifiuti: prossime raccolte per tipo + raccolte straordinarie.
final class WasteScreen extends ConsumerStatefulWidget {
  const WasteScreen({super.key});

  @override
  ConsumerState<WasteScreen> createState() => _WasteScreenState();
}

final class _WasteScreenState extends ConsumerState<WasteScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Object?>(wasteActionErrorProvider, (_, err) {
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operazione non riuscita: $err')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rifiuti'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Prossime'),
            Tab(text: 'Extra'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_NextPickupsTab(), _PickupsTab()],
      ),
      floatingActionButton: _tabs.index == 1
          ? FloatingActionButton(
              tooltip: 'Aggiungi raccolta',
              onPressed: () => _PickupEditorDialog.show(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

final class _NextPickupsTab extends ConsumerWidget {
  const _NextPickupsTab();

  static const _scrollPhysics = AlwaysScrollableScrollPhysics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pickups = ref.watch(wasteNextProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(wasteNextProvider);
        try {
          await ref.read(wasteNextProvider.future);
        } catch (_) {
          // L'errore è già nello stato del provider.
        }
      },
      child: pickups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          physics: _scrollPhysics,
          padding: const EdgeInsets.all(16),
          children: [
            ErrorRetryTile(
              message: 'Impossibile caricare le raccolte.',
              detail: e.toString(),
              onRetry: () => ref.invalidate(wasteNextProvider),
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
                  'Nessun tipo di raccolta configurato.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            );
          }
          return ListView.builder(
            physics: _scrollPhysics,
            itemCount: list.length,
            itemBuilder: (context, index) {
              final pickup = list[index];
              final color = parseHexColor(pickup.typeColor);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      color ?? Theme.of(context).colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.recycling,
                    color: color == null
                        ? Theme.of(context).colorScheme.onSecondaryContainer
                        : Colors.white,
                  ),
                ),
                title: Text(pickup.typeName),
                subtitle: Text(_subtitle(context, pickup)),
                trailing: pickup.moved
                    ? const Chip(
                        label: Text('spostato'),
                        visualDensity: VisualDensity.compact,
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  String _subtitle(BuildContext context, WasteNextPickup pickup) {
    final countdown = wasteCountdown(pickup.dateKey);
    final date = pickup.dateKey == null
        ? null
        : DateTime.tryParse(pickup.dateKey!);
    if (date == null) return countdown;
    final locale = Localizations.localeOf(context).toString();
    return '$countdown · ${DateFormat('EEEE d MMMM', locale).format(date)}';
  }
}

final class _PickupsTab extends ConsumerWidget {
  const _PickupsTab();

  static const _scrollPhysics = AlwaysScrollableScrollPhysics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pickups = ref.watch(wastePickupsProvider);
    final types = ref.watch(wasteTypesProvider).value ?? const <WasteType>[];
    final typesById = {for (final type in types) type.id: type};

    return RefreshIndicator(
      onRefresh: () => ref.read(wastePickupsProvider.notifier).refresh(),
      child: pickups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          physics: _scrollPhysics,
          padding: const EdgeInsets.all(16),
          children: [
            ErrorRetryTile(
              message: 'Impossibile caricare le raccolte extra.',
              detail: e.toString(),
              onRetry: () => ref.read(wastePickupsProvider.notifier).load(),
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
                  'Nessuna raccolta straordinaria.\nUsa "Aggiungi" per crearne una.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            );
          }
          return ListView.builder(
            physics: _scrollPhysics,
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final pickup = list[index];
              final type = typesById[pickup.typeId];
              final color = parseHexColor(type?.color);
              final date = DateTime.tryParse(pickup.date);
              final locale = Localizations.localeOf(context).toString();
              final subtitle = <String>[
                if (date != null)
                  DateFormat('EEEE d MMMM', locale).format(date)
                else
                  pickup.date,
                wasteCountdown(pickup.date),
                if (pickup.note?.isNotEmpty == true) pickup.note!,
              ];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      color ?? Theme.of(context).colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.event_available,
                    color: color == null
                        ? Theme.of(context).colorScheme.onSecondaryContainer
                        : Colors.white,
                  ),
                ),
                title: Text(type?.name ?? 'Tipo #${pickup.typeId}'),
                subtitle: Text(subtitle.join(' · ')),
                onTap: () => _PickupEditorDialog.show(context, pickup: pickup),
                trailing: IconButton(
                  tooltip: 'Elimina',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      ref.read(wastePickupsProvider.notifier).remove(pickup.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Dialog per creare/modificare una raccolta straordinaria.
final class _PickupEditorDialog extends ConsumerStatefulWidget {
  const _PickupEditorDialog({this.pickup});

  final WastePickup? pickup;

  static Future<void> show(BuildContext context, {WastePickup? pickup}) {
    return showDialog<void>(
      context: context,
      builder: (_) => _PickupEditorDialog(pickup: pickup),
    );
  }

  @override
  ConsumerState<_PickupEditorDialog> createState() =>
      _PickupEditorDialogState();
}

final class _PickupEditorDialogState
    extends ConsumerState<_PickupEditorDialog> {
  final _note = TextEditingController();
  int? _typeId;
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final pickup = widget.pickup;
    if (pickup == null) return;
    _typeId = pickup.typeId;
    _date = DateTime.tryParse(pickup.date) ?? _date;
    _note.text = pickup.note ?? '';
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  Future<void> _save() async {
    final typeId = _typeId;
    if (typeId == null) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final notifier = ref.read(wastePickupsProvider.notifier);
    final note = _note.text.trim();
    final pickup = widget.pickup;
    final success = pickup == null
        ? await notifier.add(
            typeId: typeId,
            date: dateKey(_date),
            note: note.isEmpty ? null : note,
          )
        : await notifier.update(
            pickup.id,
            date: dateKey(_date),
            note: note.isEmpty ? null : note,
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
    final types = ref.watch(wasteTypesProvider).value ?? const <WasteType>[];
    final isEdit = widget.pickup != null;
    final selectedType = types.any((t) => t.id == _typeId) ? _typeId : null;

    return AlertDialog(
      title: Text(isEdit ? 'Modifica raccolta' : 'Nuova raccolta extra'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  for (final type in types)
                    DropdownMenuItem(value: type.id, child: Text(type.name)),
                ],
                onChanged: (isEdit || _busy)
                    ? null
                    : (value) => setState(() => _typeId = value),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickDate,
                  icon: const Icon(Icons.event),
                  label: Text(DateFormat('EEEE d MMMM').format(_date)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'Nota (opzionale)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _busy || selectedType == null ? null : _save,
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
}
