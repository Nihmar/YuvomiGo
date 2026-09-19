import 'dart:convert';

/// Nome del cookie di sessione Yuvomi (vedi server: `SESSION_COOKIE`).
const String sessionCookieName = 'yuvomi.sid';

/// Abstrazione minima sul backend di persistenza sicuro, così i test
/// possono usare una fake in-memory al posto di [FlutterSecureStorage].
abstract interface class SecureStringStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class StoredSession {
  const StoredSession({
    required this.serverUrl,
    required this.sessionCookie,
    required this.csrfToken,
  });

  final String serverUrl;
  final String sessionCookie;
  final String csrfToken;

  Map<String, String> toMap() => {
        'serverUrl': serverUrl,
        'sessionCookie': sessionCookie,
        'csrfToken': csrfToken,
      };

  factory StoredSession.fromMap(Map<String, String> map) => StoredSession(
        serverUrl: map['serverUrl']!,
        sessionCookie: map['sessionCookie']!,
        csrfToken: map['csrfToken']!,
      );

  String encode() => jsonEncode(toMap());

  static StoredSession? tryDecode(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return StoredSession.fromMap(map.cast<String, String>());
    } catch (_) {
      return null;
    }
  }
}

/// Tiene lo stato della sessione Yuvomi (cookie + CSRF + server) in memoria
/// e lo persiste nel [SecureStringStorage].
final class SessionManager {
  SessionManager(this._storage);

  static const _key = 'yuvomi.session';

  final SecureStringStorage _storage;
  StoredSession? _session;

  StoredSession? get session => _session;
  bool get hasSession =>
      _session != null && _session!.sessionCookie.isNotEmpty;

  Future<StoredSession?> load() async {
    final raw = await _storage.read(_key);
    if (raw == null) return null;
    _session = StoredSession.tryDecode(raw);
    return _session;
  }

  Future<void> save() async {
    final s = _session;
    if (s == null) return;
    await _storage.write(_key, s.encode());
  }

  Future<void> clear() async {
    _session = null;
    await _storage.delete(_key);
  }

  /// Crea una sessione placeholder (cookie vuoto) in memoria, senza
  /// persistere: serve così l'interceptor può catturare il cookie di
  /// `Set-Cookie` della risposta di login.
  void beginSession(String serverUrl) {
    _session = StoredSession(
      serverUrl: serverUrl,
      sessionCookie: '',
      csrfToken: '',
    );
  }

  /// Imposta la sessione completa (server + cookie + csrf) e persiste.
  Future<void> setSession({
    required String serverUrl,
    String? sessionCookie,
    String? csrfToken,
  }) async {
    final existing = _session;
    _session = StoredSession(
      serverUrl: serverUrl,
      sessionCookie: sessionCookie ?? existing?.sessionCookie ?? '',
      csrfToken: csrfToken ?? existing?.csrfToken ?? '',
    );
    await save();
  }

  /// Aggiorna solo il CSRF token (dopo login/2fa) e persiste.
  Future<void> setCsrfToken(String token) async {
    final existing = _session;
    if (existing == null) return;
    _session = StoredSession(
      serverUrl: existing.serverUrl,
      sessionCookie: existing.sessionCookie,
      csrfToken: token,
    );
    await save();
  }

  /// Registra solo il server (login in attesa di 2FA).
  Future<void> setServerUrl(String serverUrl) async {
    final existing = _session;
    _session = StoredSession(
      serverUrl: serverUrl,
      sessionCookie: existing?.sessionCookie ?? '',
      csrfToken: existing?.csrfToken ?? '',
    );
    await save();
  }

  /// Aggiorna il cookie di sessione dai valori `Set-Cookie` di una risposta
  /// (il server può ruotare `yuvomi.sid`). Persiste se cambia.
  Future<void> captureSetCookies(List<String> setCookies) async {
    String? newCookie;
    for (final entry in setCookies) {
      final first = entry.split(';').first.trim();
      final idx = first.indexOf('=');
      if (idx <= 0) continue;
      if (first.substring(0, idx).trim() == sessionCookieName) {
        newCookie = first.substring(idx + 1);
      }
    }
    if (newCookie == null) return;
    final existing = _session;
    if (existing == null) return;
    if (existing.sessionCookie == newCookie) return;
    _session = StoredSession(
      serverUrl: existing.serverUrl,
      sessionCookie: newCookie,
      csrfToken: existing.csrfToken,
    );
    await save();
  }
}
