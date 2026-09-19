import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/auth_interceptor.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';

import 'utils/in_memory_storage.dart';

/// Adapter HTTP fake: restituisce una risposta fissa e cattura gli header
/// della richiesta finale (dopo l'interceptor).
final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.setCookies = const []});

  final List<String> setCookies;
  final Map<String, dynamic> lastRequestHeaders = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestHeaders
      ..clear()
      ..addAll(options.headers);
    final headers = <String, List<String>>{};
    if (setCookies.isNotEmpty) {
      headers['set-cookie'] = setCookies;
    }
    return ResponseBody.fromString('{}', 200, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

Future<Map<String, dynamic>> _request(
  String method,
  SessionManager sessions, {
  List<String> setCookies = const [],
}) async {
  final adapter = _FakeAdapter(setCookies: setCookies);
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
  dio.interceptors.add(AuthInterceptor(sessions));
  dio.httpClientAdapter = adapter;

  final path = '/test';
  switch (method) {
    case 'POST':
      await dio.post<void>(path);
    case 'GET':
      await dio.get<void>(path);
    case 'PATCH':
      await dio.patch<void>(path);
    case 'DELETE':
      await dio.delete<void>(path);
    default:
      throw ArgumentError(method);
  }
  return adapter.lastRequestHeaders;
}

void main() {
  group('AuthInterceptor', () {
    test('adds Cookie + X-CSRF-Token to state-changing requests', () async {
      final sessions = SessionManager(InMemoryStorage());
      await sessions.setSession(
        serverUrl: 'http://test.local',
        sessionCookie: 'cookie1',
        csrfToken: 'csrf1',
      );

      final headers = await _request('POST', sessions);
      expect(headers['Cookie'], 'yuvomi.sid=cookie1');
      expect(headers['X-CSRF-Token'], 'csrf1');
    });

    test('adds Cookie but not CSRF to GET', () async {
      final sessions = SessionManager(InMemoryStorage());
      await sessions.setSession(
        serverUrl: 'http://test.local',
        sessionCookie: 'cookie1',
        csrfToken: 'csrf1',
      );

      final headers = await _request('GET', sessions);
      expect(headers['Cookie'], 'yuvomi.sid=cookie1');
      expect(headers.containsKey('X-CSRF-Token'), isFalse);
    });

    test('adds CSRF on PATCH and DELETE', () async {
      final sessions = SessionManager(InMemoryStorage());
      await sessions.setSession(
        serverUrl: 'http://test.local',
        sessionCookie: 'cookie1',
        csrfToken: 'csrf1',
      );

      for (final method in ['PATCH', 'DELETE']) {
        final headers = await _request(method, sessions);
        expect(headers['X-CSRF-Token'], 'csrf1', reason: method);
      }
    });

    test('adds no headers when there is no session', () async {
      final sessions = SessionManager(InMemoryStorage());

      final headers = await _request('POST', sessions);
      expect(headers.containsKey('Cookie'), isFalse);
      expect(headers.containsKey('X-CSRF-Token'), isFalse);
    });

    test('rotates the session cookie from Set-Cookie', () async {
      final storage = InMemoryStorage();
      final sessions = SessionManager(storage);
      await sessions.setSession(
        serverUrl: 'http://test.local',
        sessionCookie: 'old',
        csrfToken: 'csrf1',
      );

      await _request(
        'GET',
        sessions,
        setCookies: ['yuvomi.sid=rotated; Path=/; HttpOnly'],
      );
      expect(sessions.session!.sessionCookie, 'rotated');
      // Persistita.
      final m2 = SessionManager(storage);
      final loaded = await m2.load();
      expect(loaded!.sessionCookie, 'rotated');
    });
  });
}
