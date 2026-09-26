import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/data/generated/models/user.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';

User fakeUser() => User(
  avatarColor: '#FF6B35',
  displayName: 'Utente Test',
  familyRole: 'parent',
  id: 1,
  role: 'admin',
  username: 'test',
);

/// AuthController fake condiviso: niente HTTP, stato fisso, login/2FA simulati.
class FakeAuthController extends AuthController {
  FakeAuthController(this._initial);
  final AuthState _initial;

  bool loginCalled = false;
  bool verifyCalled = false;
  bool cancelTwoFactorCalled = false;
  String? lastServerUrl;
  String? lastUsername;
  String? lastPassword;

  @override
  AuthState build() => _initial;

  @override
  Future<void> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    loginCalled = true;
    lastServerUrl = serverUrl;
    lastUsername = username;
    lastPassword = password;
    state = Authenticated(user: fakeUser());
  }

  @override
  Future<void> verifyTwoFactor(String code) async {
    verifyCalled = true;
    state = Authenticated(user: fakeUser());
  }

  @override
  Future<void> cancelTwoFactor() async {
    cancelTwoFactorCalled = true;
    state = const AuthUnauthenticated();
  }
}
