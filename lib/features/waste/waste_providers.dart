import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/waste_repository.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/waste/waste_models.dart';

final wasteRepositoryProvider = Provider<WasteRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) throw StateError('WasteRepository senza sessione attiva');
  return WasteRepository(api);
});

/// Prossima raccolta per tipo.
final wasteNextProvider = FutureProvider.autoDispose<List<WasteNextPickup>>((
  ref,
) async {
  final repo = ref.watch(wasteRepositoryProvider);
  return repo.fetchNextPickups();
});
