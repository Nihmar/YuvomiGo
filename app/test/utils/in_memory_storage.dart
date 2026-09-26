import 'package:yuvomigo/core/auth/session_manager.dart';

/// [SecureStringStorage] in-memory per i test.
final class InMemoryStorage implements SecureStringStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}
