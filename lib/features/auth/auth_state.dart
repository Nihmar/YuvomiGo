import 'package:yuvomigo/data/generated/models/user.dart';

/// Stato dell'autenticazione dell'app.
sealed class AuthState {
  const AuthState();
}

/// Si sta verificando la sessione salvata (avvio app).
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Nessuna sessione attiva: va mostrato lo screen di login.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Login fatto ma server richiede un secondo fattore.
final class AuthPending2FA extends AuthState {
  const AuthPending2FA({required this.recoveryAvailable});

  final bool recoveryAvailable;
}

/// Sessione attiva.
final class Authenticated extends AuthState {
  const Authenticated({required this.user});

  final User user;
}
