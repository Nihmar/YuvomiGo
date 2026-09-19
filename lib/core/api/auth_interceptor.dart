import 'package:dio/dio.dart';

import '../auth/session_manager.dart';

const String _cookieHeader = 'Cookie';
const String _csrfHeader = 'X-CSRF-Token';

final Set<String> _stateChangingMethods = {
  'POST',
  'PUT',
  'PATCH',
  'DELETE',
};

/// Interceptor che gestisce l'autenticazione a sessione Yuvomi:
///
/// - sulle richieste: inietta il cookie di sessione e (per le richieste
///   che cambiano stato) il header `X-CSRF-Token`;
/// - sulle risposte: cattura eventuali `Set-Cookie` di rotazione.
final class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.sessions);

  final SessionManager sessions;

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
    handler.next(response);
  }
}
