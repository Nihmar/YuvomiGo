import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/features/waste/waste_models.dart';
import 'package:yuvomigo/features/waste/waste_providers.dart';

/// Schermata Rifiuti: prossima raccolta per tipo.
final class WasteScreen extends ConsumerWidget {
  const WasteScreen({super.key});

  static const _scrollPhysics = AlwaysScrollableScrollPhysics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pickups = ref.watch(wasteNextProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rifiuti')),
      body: RefreshIndicator(
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
                final color = _parseColor(pickup.typeColor);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        color ??
                        Theme.of(context).colorScheme.secondaryContainer,
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

  Color? _parseColor(String? hex) {
    if (hex == null) return null;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return null;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }
}
