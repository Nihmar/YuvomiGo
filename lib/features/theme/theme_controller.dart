import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/features/auth/auth_providers.dart';

/// Chiave di persistenza del seed colore scelto.
const String themeSeedStorageKey = 'yuvomi.themeSeed';

/// Seed di default (l'arancione storico dell'app).
const int defaultThemeSeed = 0xFFFF6B35;

/// Un colore selezionabile: nome mostrato nel dialogo + seed ARGB.
final class ThemeChoice {
  const ThemeChoice({required this.name, required this.seed});

  final String name;
  final int seed;
}

/// I colori tra cui l'utente può scegliere.
const List<ThemeChoice> themeChoices = [
  ThemeChoice(name: 'Arancione', seed: 0xFFFF6B35),
  ThemeChoice(name: 'Blu', seed: 0xFF2196F3),
  ThemeChoice(name: 'Verde', seed: 0xFF43A047),
  ThemeChoice(name: 'Viola', seed: 0xFF8E24AA),
  ThemeChoice(name: 'Teal', seed: 0xFF00897B),
  ThemeChoice(name: 'Rosa', seed: 0xFFD81B60),
];

/// Stato del tema: il seed ARGB correntemente selezionato.
///
/// Non è `final` perché nei test può essere sostituito con un fake.
class ThemeController extends Notifier<int> {
  @override
  int build() {
    unawaited(_load());
    return defaultThemeSeed;
  }

  /// Ricarica la scelta persistita (se valida), altrimenti resta il default.
  Future<void> _load() async {
    try {
      final raw = await ref.read(secureStorageProvider).read(
            themeSeedStorageKey,
          );
      final seed = raw == null ? null : int.tryParse(raw);
      if (seed != null && themeChoices.any((c) => c.seed == seed)) {
        state = seed;
      }
    } catch (_) {
      // Storage non disponibile: resta il default, la scelta resta usabile.
    }
  }

  /// Seleziona un nuovo seed e lo persiste (best-effort).
  Future<void> select(int seed) async {
    state = seed;
    try {
      await ref
          .read(secureStorageProvider)
          .write(themeSeedStorageKey, '$seed');
    } catch (_) {
      // La selezione in memoria resta attiva anche senza persistenza.
    }
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, int>(ThemeController.new);
