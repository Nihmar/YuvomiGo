import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';

import 'utils/in_memory_storage.dart';

void main() {
  group('StoredSession', () {
    test('encode/tryDecode round-trip', () {
      final s = StoredSession(
        serverUrl: 'http://omvnas:4000',
        sessionCookie: 'abc123',
        csrfToken: 'csrf456',
      );
      final decoded = StoredSession.tryDecode(s.encode());
      expect(decoded, isNotNull);
      expect(decoded!.serverUrl, 'http://omvnas:4000');
      expect(decoded.sessionCookie, 'abc123');
      expect(decoded.csrfToken, 'csrf456');
    });

    test('tryDecode returns null on garbage', () {
      expect(StoredSession.tryDecode('not-json'), isNull);
    });
  });

  group('SessionManager', () {
    test('load returns null when empty', () async {
      final m = SessionManager(InMemoryStorage());
      expect(await m.load(), isNull);
    });

    test('setSession persists and loads', () async {
      final storage = InMemoryStorage();
      final m = SessionManager(storage);
      await m.setSession(
        serverUrl: 'http://omvnas:4000',
        sessionCookie: 'cookie1',
        csrfToken: 'csrf1',
      );
      expect(m.session, isNotNull);
      expect(m.hasSession, isTrue);

      // Un nuovo manager legge la stessa sessione.
      final m2 = SessionManager(storage);
      final loaded = await m2.load();
      expect(loaded, isNotNull);
      expect(loaded!.serverUrl, 'http://omvnas:4000');
      expect(loaded.sessionCookie, 'cookie1');
      expect(loaded.csrfToken, 'csrf1');
    });

    test('clear removes the session', () async {
      final storage = InMemoryStorage();
      final m = SessionManager(storage);
      await m.setSession(
        serverUrl: 'http://omvnas:4000',
        sessionCookie: 'cookie1',
        csrfToken: 'csrf1',
      );
      await m.clear();
      expect(m.session, isNull);
      final m2 = SessionManager(storage);
      expect(await m2.load(), isNull);
    });

    test('captureSetCookies updates the cookie', () async {
      final m = SessionManager(InMemoryStorage());
      await m.setSession(
        serverUrl: 'http://omvnas:4000',
        sessionCookie: 'old',
        csrfToken: 'csrf1',
      );
      await m.captureSetCookies([
        'yuvomi.sid=newCookie; Path=/; HttpOnly',
        'csrf-token=ignored; Path=/',
      ]);
      expect(m.session!.sessionCookie, 'newCookie');
      // csrfToken non toccato dai Set-Cookie.
      expect(m.session!.csrfToken, 'csrf1');
    });

    test('captureSetCookies keeps cookie when unchanged', () async {
      final storage = InMemoryStorage();
      final m = SessionManager(storage);
      await m.setSession(
        serverUrl: 'http://omvnas:4000',
        sessionCookie: 'same',
        csrfToken: 'csrf1',
      );
      await m.captureSetCookies(['yuvomi.sid=same; Path=/']);
      expect(m.session!.sessionCookie, 'same');
    });

    test('captureSetCookies without a session is a no-op', () async {
      final m = SessionManager(InMemoryStorage());
      await m.captureSetCookies(['yuvomi.sid=x; Path=/']);
      expect(m.session, isNull);
    });

    test('setCsrfToken updates only the token', () async {
      final m = SessionManager(InMemoryStorage());
      await m.setSession(
        serverUrl: 'http://omvnas:4000',
        sessionCookie: 'cookie1',
        csrfToken: 'old',
      );
      await m.setCsrfToken('new-csrf');
      expect(m.session!.csrfToken, 'new-csrf');
      expect(m.session!.sessionCookie, 'cookie1');
    });

    test('beginSession creates a placeholder (not persisted)', () async {
      final storage = InMemoryStorage();
      final m = SessionManager(storage);
      m.beginSession('http://omvnas:4000');
      expect(m.session, isNotNull);
      expect(m.session!.sessionCookie, '');
      expect(m.hasSession, isFalse);
      // Non persistita: un nuovo manager non la vede.
      final m2 = SessionManager(storage);
      expect(await m2.load(), isNull);
    });
  });
}
