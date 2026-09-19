import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/data/repositories/dashboard_repository.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/dashboard/dashboard_models.dart';

/// L'API corrente (dopo login/bootstrap). Null se non autenticato.
final yuvomiApiProvider = Provider<YuvomiApi?>((ref) {
  // Riattiva su ogni cambio di auth state.
  ref.watch(authControllerProvider);
  return ref.read(authControllerProvider.notifier).api;
});

/// Repository dashboard: valido solo quando c'è un'API attiva.
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) {
    throw StateError(
      'DashboardRepository richiesto senza sessione attiva',
    );
  }
  return DashboardRepository(api);
});

/// Dati della dashboard (fetch una volta; lo screen refresha su pull).
final dashboardProvider =
    FutureProvider.autoDispose<DashboardData>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.fetch();
});
