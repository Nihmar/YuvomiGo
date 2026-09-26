import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';

import 'utils/in_memory_storage.dart';

void main() {
  test('acceptBadCertificates defaults to false', () {
    final api = YuvomiApi(
      baseUrl: 'https://nas.local',
      sessions: SessionManager(InMemoryStorage()),
    );

    expect(api.acceptBadCertificates, isFalse);
  });

  test('acceptBadCertificates is stored when requested', () {
    final api = YuvomiApi(
      baseUrl: 'https://nas.local',
      sessions: SessionManager(InMemoryStorage()),
      acceptBadCertificates: true,
    );

    expect(api.acceptBadCertificates, isTrue);
  });
}
