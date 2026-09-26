import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';

final class _SecureStorageAdapter implements SecureStringStorage {
  _SecureStorageAdapter(this._inner);

  final FlutterSecureStorage _inner;

  @override
  Future<String?> read(String key) => _inner.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _inner.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _inner.delete(key: key);
}

/// Backend di persistenza sicuro per la sessione.
final secureStorageProvider = Provider<SecureStringStorage>((ref) {
  return _SecureStorageAdapter(const FlutterSecureStorage());
});

final sessionManagerProvider = Provider<SessionManager>((ref) {
  return SessionManager(ref.watch(secureStorageProvider));
});
