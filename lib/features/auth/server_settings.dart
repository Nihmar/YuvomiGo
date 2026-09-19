import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/features/auth/auth_providers.dart';

/// Chiave per il server URL dell'ultimo login (precompila il campo).
const String _lastServerUrlKey = 'yuvomi.lastServerUrl';

/// Memorizza l'URL del server usato all'ultimo login, così la prossima
/// volta lo screen lo precompila.
final class ServerUrlMemory {
  ServerUrlMemory(this._storage);
  final SecureStringStorage _storage;

  Future<String?> read() async => _storage.read(_lastServerUrlKey);

  Future<void> remember(String url) async {
    await _storage.write(_lastServerUrlKey, url);
  }
}

final serverUrlMemoryProvider = Provider<ServerUrlMemory>((ref) {
  return ServerUrlMemory(ref.watch(secureStorageProvider));
});
