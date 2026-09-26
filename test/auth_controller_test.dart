import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_providers.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';

/// Storage che fallisce sempre: simula un secure storage non disponibile
/// (es. libsecret assente su Linux).
final class ThrowingStorage implements SecureStringStorage {
  @override
  Future<String?> read(String key) async => throw StateError('storage down');

  @override
  Future<void> write(String key, String value) async =>
      throw StateError('storage down');

  @override
  Future<void> delete(String key) async => throw StateError('storage down');
}

ProviderContainer _containerWith(SecureStringStorage storage) {
  return ProviderContainer.test(
    overrides: [secureStorageProvider.overrideWithValue(storage)],
  );
}

void main() {
  test('bootstrap survives a storage failure and shows the login', () async {
    final container = _containerWith(ThrowingStorage());

    expect(container.read(authControllerProvider), isA<AuthLoading>());

    await pumpEventQueue();

    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });

  test('logout succeeds (locally) even if the storage fails', () async {
    final container = _containerWith(ThrowingStorage());
    await pumpEventQueue();

    await container.read(authControllerProvider.notifier).logout();

    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });
}
