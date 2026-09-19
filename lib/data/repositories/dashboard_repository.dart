import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/dashboard/dashboard_models.dart';

/// Repository per la dashboard.
///
/// `GET /api/v1/dashboard` non è in spec OpenAPI (il client generato
/// restituisce `void`), quindi qui si fa la richiesta raw con il Dio e si
/// parsea la risposta con i model di dominio.
final class DashboardRepository {
  DashboardRepository(this._api);

  final YuvomiApi _api;

  Future<DashboardData> fetch() async {
    final response = await _api.dio.get<Map<String, dynamic>>(
      '/api/v1/dashboard',
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return DashboardData.fromJson(data);
    }
    // Il server risponde sempre con un oggetto; se arriva qualcosa di
    // inatteso lo trattiamo come dashboard vuota.
    return const DashboardData();
  }
}
