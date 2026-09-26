import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/core/utils/url_utils.dart';
import 'package:yuvomigo/features/auth/auth_providers.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';

/// Controller dell'autenticazione: bootstrap, login, 2FA, logout.
///
/// Non è `final` perché nei test può essere sostituito con un fake.
class AuthController extends Notifier<AuthState> {
  YuvomiApi? _api;

  /// L'API corrente (dopo un login/bootstrap riuscito).
  YuvomiApi? get api => _api;

  @override
  AuthState build() {
    unawaited(_bootstrap());
    return const AuthLoading();
  }

  /// Pulizia best-effort dopo un fallimento: lo stato in memoria viene
  /// sempre azzerato anche se lo storage persistente lancia.
  Future<void> _resetAfterFailure(SessionManager sessions) async {
    _api = null;
    state = const AuthUnauthenticated();
    try {
      await sessions.clear();
    } catch (_) {
      // Storage non disponibile: la sessione in memoria è già azzerata.
    }
  }

  /// Verifica la sessione salvata all'avvio dell'app.
  Future<void> _bootstrap() async {
    final sessions = ref.read(sessionManagerProvider);
    final stored = await sessions.load();
    if (stored == null) {
      state = const AuthUnauthenticated();
      return;
    }
    _api = YuvomiApi(baseUrl: stored.serverUrl, sessions: sessions);
    try {
      final user = await _api!.me();
      state = Authenticated(user: user);
    } on ApiError {
      await _resetAfterFailure(sessions);
    } catch (_) {
      // Errori non-API (storage, parsing): niente splash infinito,
      // si torna al login come con una sessione scaduta.
      await _resetAfterFailure(sessions);
    }
  }

  /// Login con username/password sul server indicato.
  Future<void> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final sessions = ref.read(sessionManagerProvider);
    await sessions.clear();
    final normalized = normalizeServerUrl(serverUrl);
    _api = YuvomiApi(baseUrl: normalized, sessions: sessions);
    state = const AuthLoading();
    try {
      final result = await _api!.login(username, password);
      if (result is LoginTwoFactorRequired) {
        state = AuthPending2FA(recoveryAvailable: result.recoveryAvailable);
      } else if (result is LoginSuccess) {
        state = Authenticated(user: result.user);
      }
    } on ApiError {
      await _resetAfterFailure(sessions);
      rethrow;
    } catch (_) {
      // Errori non-API (storage, parsing risposta): lo stato non deve
      // restare bloccato su AuthLoading, e lo screen deve mostrare qualcosa.
      await _resetAfterFailure(sessions);
      rethrow;
    }
  }

  /// Secondo fattore dopo un login in attesa di 2FA.
  Future<void> verifyTwoFactor(String code) async {
    final sessions = ref.read(sessionManagerProvider);
    final api = _api;
    if (api == null) {
      state = const AuthUnauthenticated();
      return;
    }
    state = const AuthLoading();
    try {
      final user = await api.verifyTwoFactor(code);
      state = Authenticated(user: user);
    } on ApiError {
      await _resetAfterFailure(sessions);
      rethrow;
    } catch (_) {
      await _resetAfterFailure(sessions);
      rethrow;
    }
  }

  /// Logout: revoca la sessione lato server e azzera lo stato locale.
  Future<void> logout() async {
    final sessions = ref.read(sessionManagerProvider);
    await _api?.logout();
    await sessions.clear();
    _api = null;
    state = const AuthUnauthenticated();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
