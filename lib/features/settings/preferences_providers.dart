import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/preferences_repository.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) {
    throw StateError('PreferencesRepository senza sessione attiva');
  }
  return PreferencesRepository(api);
});

/// Preferenze del server (valuta, festività, …).
final appPreferencesProvider = FutureProvider.autoDispose<AppPreferences>((
  ref,
) async {
  final repo = ref.watch(preferencesRepositoryProvider);
  return repo.fetch();
});

/// Le preferenze correnti, o i default mentre caricano.
final appPreferencesValueProvider = Provider<AppPreferences>((ref) {
  return ref.watch(appPreferencesProvider).value ?? const AppPreferences();
});

/// Paesi selezionabili per le festività (richiede rete lato server).
final holidayCountriesProvider =
    FutureProvider.autoDispose<List<HolidayCountry>>((ref) async {
      final repo = ref.watch(preferencesRepositoryProvider);
      return repo.fetchHolidayCountries();
    });
