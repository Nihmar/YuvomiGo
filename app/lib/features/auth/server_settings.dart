import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/features/auth/auth_providers.dart';

/// Chiave per il server URL dell'ultimo login (precompila il campo).
const String _lastServerUrlKey = 'yuvomi.lastServerUrl';

/// Chiave per la scelta "accetta certificati self-signed".
const String _acceptBadCertificatesKey = 'yuvomi.acceptBadCertificates';

/// Memorizza le preferenze di connessione dell'ultimo login (URL del server e
/// accettazione dei certificati self-signed), così i login successivi le
/// ripresentano già impostate.
final class ServerUrlMemory {
  ServerUrlMemory(this._storage);
  final SecureStringStorage _storage;

  Future<String?> read() async => _storage.read(_lastServerUrlKey);

  Future<void> remember(String url) async {
    await _storage.write(_lastServerUrlKey, url);
  }

  /// True se l'utente ha scelto di accettare certificati TLS non fidati.
  Future<bool> readAcceptBadCertificates() async =>
      (await _storage.read(_acceptBadCertificatesKey)) == 'true';

  Future<void> rememberAcceptBadCertificates(bool value) async {
    await _storage.write(_acceptBadCertificatesKey, value ? 'true' : 'false');
  }
}

final serverUrlMemoryProvider = Provider<ServerUrlMemory>((ref) {
  return ServerUrlMemory(ref.watch(secureStorageProvider));
});
