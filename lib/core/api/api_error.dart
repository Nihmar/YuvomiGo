import 'package:dio/dio.dart';

/// Errori tipizzati derivati da [DioException], così la UI può distinguere
/// "server non raggiungibile" da "credenziali sbagliate" da "errore server".
sealed class ApiError implements Exception {
  const ApiError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Il server non è raggiungibile (rete, timeout, DNS).
final class ApiNetworkError extends ApiError {
  const ApiNetworkError(super.message);
}

/// Credenziali o sessione non valide (401).
final class ApiAuthError extends ApiError {
  const ApiAuthError(super.message);
}

/// Il server ha risposto con un errore (4xx/5xx diverso da 401).
final class ApiServerError extends ApiError {
  const ApiServerError(this.statusCode, super.message);

  final int statusCode;
}

ApiError fromDioException(DioException e) {
  final statusCode = e.response?.statusCode;
  if (statusCode == null) {
    // Errore di rete: timeout, DNS, connessione rifiutata, certificato.
    return ApiNetworkError(
      'Impossibile raggiungere il server: ${e.message}',
    );
  }
  if (statusCode == 401) {
    final body = e.response?.data;
    final serverMsg = body is Map ? body['error'] : null;
    return ApiAuthError(
      serverMsg is String && serverMsg.isNotEmpty
          ? serverMsg
          : 'Credenziali non valide.',
    );
  }
  final body = e.response?.data;
  final serverMsg = body is Map ? body['error'] : null;
  return ApiServerError(
    statusCode,
    serverMsg is String && serverMsg.isNotEmpty
        ? serverMsg
        : 'Errore del server (HTTP $statusCode).',
  );
}
