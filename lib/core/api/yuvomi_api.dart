import 'package:dio/dio.dart';

import '../auth/session_manager.dart';
import 'api_error.dart';
import 'auth_interceptor.dart';
import 'package:yuvomigo/data/generated/api_client.dart' as gen;
import 'package:yuvomigo/data/generated/models/user.dart';

/// Esito di un login.
sealed class LoginResult {
  const LoginResult();
}

/// Login completato (senza 2FA, o 2FA già verificato).
final class LoginSuccess extends LoginResult {
  const LoginSuccess({required this.user, required this.csrfToken});

  final User user;
  final String csrfToken;
}

/// Il server richiede un secondo fattore: serve `POST /auth/2fa/verify`.
final class LoginTwoFactorRequired extends LoginResult {
  const LoginTwoFactorRequired({required this.recoveryAvailable});

  final bool recoveryAvailable;
}

/// Wrapper sopra il client generato: crea il Dio con l'interceptor di
/// sessione e espone login / 2FA / me / logout.
final class YuvomiApi {
  YuvomiApi({
    required String baseUrl,
    required SessionManager sessions,
  }) {
    _sessions = sessions;
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    _dio.interceptors.add(AuthInterceptor(sessions));
    _client = gen.YuvomiApiClient(dio: _dio);
  }

  late final SessionManager _sessions;
  late final Dio _dio;
  late final gen.YuvomiApiClient _client;

  String get baseUrl => _dio.options.baseUrl;

  /// Il client generato (per i moduli): usa lo stesso Dio con l'interceptor.
  gen.YuvomiApiClient get client => _client;

  /// Login con username/password. Gesti il 2FA opzionale.
  Future<LoginResult> login(String username, String password) async {
    _sessions.beginSession(baseUrl);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: {'username': username, 'password': password},
      );
      final data = response.data ?? const <String, dynamic>{};
      if (data['twoFactorRequired'] == true) {
        // Cookie della sessione "pending" già catturato dall'interceptor.
        await _sessions.setServerUrl(baseUrl);
        return LoginTwoFactorRequired(
          recoveryAvailable: data['recoveryAvailable'] == true,
        );
      }
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      final csrfToken = data['csrfToken'] as String? ?? '';
      await _sessions.setSession(serverUrl: baseUrl, csrfToken: csrfToken);
      return LoginSuccess(user: user, csrfToken: csrfToken);
    } on DioException catch (e) {
      throw fromDioException(e);
    }
  }

  /// Secondo fattore (TOTP o recovery code).
  Future<User> verifyTwoFactor(String code) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/2fa/verify',
        data: {'code': code},
      );
      final data = response.data ?? const <String, dynamic>{};
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      final csrfToken = data['csrfToken'] as String? ?? '';
      await _sessions.setSession(serverUrl: baseUrl, csrfToken: csrfToken);
      return user;
    } on DioException catch (e) {
      throw fromDioException(e);
    }
  }

  /// Verifica la sessione corrente.
  Future<User> me() async {
    try {
      final result = await _client.auth.getApiV1authMe();
      return result.user;
    } on DioException catch (e) {
      throw fromDioException(e);
    }
  }

  /// Logout lato server (best-effort).
  Future<void> logout() async {
    try {
      await _client.auth.postApiV1authLogout();
    } on DioException {
      // best effort: la sessione locale viene comunque cancellata
    }
  }
}
