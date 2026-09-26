import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/note_repository.dart';

import 'utils/in_memory_storage.dart';

final class _RoutingAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> routes = [];
  final List<RequestOptions> requests = [];

  void addRoute(String method, String path, Object body) {
    routes.add({'method': method, 'path': path, 'body': body});
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    for (final r in routes) {
      if (r['method'] == options.method && r['path'] == options.path) {
        return ResponseBody.fromString(
          jsonEncode(r['body']),
          200,
          headers: const {
            'content-type': ['application/json'],
          },
        );
      }
    }
    return ResponseBody.fromString(
      jsonEncode({'data': <Object>[]}),
      200,
      headers: const {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  YuvomiApi apiWith(_RoutingAdapter adapter) {
    final api = YuvomiApi(
      baseUrl: 'http://test.local',
      sessions: SessionManager(InMemoryStorage()),
    );
    api.dio.httpClientAdapter = adapter;
    return api;
  }

  test('fetchNotes parses the list and sorts pinned first', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('GET', '/api/v1/notes', {
      'data': [
        {'id': 1, 'content': 'ordinaria', 'pinned': 0},
        {'id': 2, 'content': 'pinned', 'pinned': 1, 'title': 'Top'},
      ],
    });
    final repo = NoteRepository(apiWith(adapter));
    final notes = await repo.fetchNotes();

    expect(notes, hasLength(2));
    expect(notes.first.id, 2); // pinned prima
    expect(notes.first.pinned, isTrue);
    expect(notes.first.title, 'Top');
    expect(notes[1].pinned, isFalse);
  });

  test('createNote posts the payload', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('POST', '/api/v1/notes', {
      'data': {'id': 5, 'content': 'ciao', 'pinned': 0},
    });
    final repo = NoteRepository(apiWith(adapter));
    final created = await repo.createNote(content: 'ciao');

    expect(created.id, 5);
    expect(created.content, 'ciao');
    expect(adapter.requests.first.method, 'POST');
    expect(adapter.requests.first.data['content'], 'ciao');
  });

  test('updateNote sends only the provided fields', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('PUT', '/api/v1/notes/9', {
      'data': {'id': 9, 'content': 'x', 'title': 'T', 'pinned': 1},
    });
    final repo = NoteRepository(apiWith(adapter));
    final updated = await repo.updateNote(9, pinned: true);

    // Il PUT sovrascrive le chiavi presenti: il toggle del pin non deve
    // mandare title/content null (azzererebbero il titolo sul server).
    expect(adapter.requests.first.data, {'pinned': 1});
    expect(updated.pinned, isTrue);
    expect(updated.title, 'T');
  });

  test('deleteNote issues a DELETE on the id', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('DELETE', '/api/v1/notes/3', {});
    final repo = NoteRepository(apiWith(adapter));
    await repo.deleteNote(3);

    expect(adapter.requests.first.method, 'DELETE');
    expect(adapter.requests.first.path, '/api/v1/notes/3');
  });
}
