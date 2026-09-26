import 'package:dio/dio.dart';

import '../auth/session_manager.dart';

const String _cookieHeader = 'Cookie';
const String _csrfHeader = 'X-CSRF-Token';
const String _csrfResponseHeader = 'x-csrf-token';

final Set<String> _stateChangingMethods = {'POST', 'PUT', 'PATCH', 'DELETE'};

/// Endpoint di autenticazione: un loro 401 (credenziali o codice 2FA
/// sbagliati) non deve far scattare il logout globale, la UI lo gestisce
/// inline sul form.
final Set<String> _authPaths = {
  '/api/v1/auth/login',
  '/api/v1/auth/2fa/verify',
};

/// Interceptor che gestisce l'autenticazione a sessione Yuvomi:
///
/// - sulle richieste: inietta il cookie di sessione e (per le richieste
///   che cambiano stato) il header `X-CSRF-Token`;
/// - sulle risposte: cattura eventuali `Set-Cookie` di rotazione e il
///   `X-CSRF-Token` che il server rimanda (e rigenera) a ogni risposta;
/// - sugli errori: su 401 fuori dalle route di auth invoca [onUnauthorized],
///   così la sessione scaduta riporta l'app al login.
final class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.sessions, {this.onUnauthorized});

  final SessionManager sessions;

  /// Chiamata quando una richiesta autenticata riceve 401 (sessione scaduta).
  final Future<void> Function()? onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final session = sessions.session;
    if (session != null && session.sessionCookie.isNotEmpty) {
      options.headers[_cookieHeader] =
          '$sessionCookieName=${session.sessionCookie}';
      if (_stateChangingMethods.contains(options.method) &&
          session.csrfToken.isNotEmpty) {
        options.headers[_csrfHeader] = session.csrfToken;
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      await sessions.captureSetCookies(setCookie);
    }
    // Il server rigenera il CSRF token quando manca e lo rimanda a ogni
    // risposta: tenerlo allineato evita 403 sui POST dopo un ripristino.
    final csrf = response.headers[_csrfResponseHeader];
    if (csrf != null && csrf.isNotEmpty && csrf.first.isNotEmpty) {
      await sessions.setCsrfToken(csrf.first);
    }
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    if (isUnauthorized && !_authPaths.contains(err.requestOptions.path)) {
      final callback = onUnauthorized;
      if (callback != null) {
        try {
          await callback();
        } catch (_) {
          // Best-effort: l'errore originale va comunque propagato.
        }
      }
    }
    handler.next(err);
  }
}
