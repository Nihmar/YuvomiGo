import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/dashboard_repository.dart';

import 'utils/in_memory_storage.dart';

final class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.body);

  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(jsonEncode(body), 200,
        headers: const {'content-type': ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('fetch parses the dashboard payload', () async {
    final sessions = SessionManager(InMemoryStorage());
    final api = YuvomiApi(baseUrl: 'http://test.local', sessions: sessions);
    api.dio.httpClientAdapter = _JsonAdapter(
      {
        'urgentTasks': [
          {'id': 1, 'title': 'Paga bolletta', 'priority': 'urgent'},
        ],
        'openTaskCount': 7,
        'pinnedNotes': [
          {'id': 2, 'title': 'WIFI', 'content': '1234', 'pinned': 1},
        ],
        'pinnedNotesCount': 1,
      },
    );

    final repo = DashboardRepository(api);
    final data = await repo.fetch();

    expect(data.urgentTasks, hasLength(1));
    expect(data.urgentTasks.first.title, 'Paga bolletta');
    expect(data.openTaskCount, 7);
    expect(data.pinnedNotesCount, 1);
  });

  test('fetch returns empty dashboard on unexpected body', () async {
    final sessions = SessionManager(InMemoryStorage());
    final api = YuvomiApi(baseUrl: 'http://test.local', sessions: sessions);
    api.dio.httpClientAdapter = _JsonAdapter({'unexpected': 'shape'});

    final repo = DashboardRepository(api);
    final data = await repo.fetch();
    expect(data.urgentTasks, isEmpty);
    expect(data.pinnedNotesCount, 0);
  });
}
