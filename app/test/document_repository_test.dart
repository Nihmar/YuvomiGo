import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/document_repository.dart';
import 'package:yuvomigo/features/documents/document_models.dart';

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

  test('fetchDocuments parses metadata', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('GET', '/api/v1/documents', {
      'data': [
        {
          'id': 1,
          'name': 'Assicurazione casa',
          'description': 'polizza 2026',
          'category': 'insurance',
          'status': 'active',
          'original_name': 'polizza.pdf',
          'mime_type': 'application/pdf',
          'file_size': 204800,
          'folder_id': 3,
          'folder_name': 'Casa',
          'creator_name': 'Utente Test',
          'updated_at': '2026-09-01T10:00:00Z',
        },
      ],
    });
    final repo = DocumentRepository(apiWith(adapter));
    final documents = await repo.fetchDocuments();

    expect(adapter.requests.first.path, '/api/v1/documents');
    expect(documents, hasLength(1));
    expect(documents.first.name, 'Assicurazione casa');
    expect(documents.first.folderName, 'Casa');
    expect(documents.first.category, 'insurance');
    expect(documents.first.fileSize, 204800);
  });

  test('category and size labels are localized/readable', () {
    expect(documentCategoryLabel('insurance'), 'Assicurazioni');
    expect(documentCategoryLabel('unknown'), 'unknown');
    expect(formatFileSize(512), '512 B');
    expect(formatFileSize(2048), '2 KB');
    expect(formatFileSize(2 * 1024 * 1024), '2.0 MB');
  });

  test('documentMimeForName maps allowed extensions only', () {
    expect(documentMimeForName('polizza.pdf'), 'application/pdf');
    expect(documentMimeForName('foto.JPG'), 'image/jpeg');
    expect(documentMimeForName('foglio.xlsx'), contains('spreadsheetml'));
    expect(documentMimeForName('virus.exe'), isNull);
    expect(documentMimeForName('senzaestensione'), isNull);
  });

  test('uploadDocument posts a base64 data URL with the metadata', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('POST', '/api/v1/documents', {
      'data': {
        'id': 9,
        'name': 'Polizza',
        'original_name': 'polizza.pdf',
        'mime_type': 'application/pdf',
        'file_size': 3,
      },
    });
    final repo = DocumentRepository(apiWith(adapter));
    final uploaded = await repo.uploadDocument(
      name: 'Polizza',
      originalName: 'polizza.pdf',
      mimeType: 'application/pdf',
      bytes: Uint8List.fromList([1, 2, 3]),
      category: 'insurance',
    );

    expect(uploaded.id, 9);
    expect(adapter.requests.first.data, {
      'name': 'Polizza',
      'original_name': 'polizza.pdf',
      'category': 'insurance',
      'content_data': 'data:application/pdf;base64,AQID',
    });
  });

  test('archiveDocument PATCHes the archive endpoint', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('PATCH', '/api/v1/documents/9/archive', {
      'data': {'id': 9, 'status': 'archived'},
    });
    final repo = DocumentRepository(apiWith(adapter));
    await repo.archiveDocument(9);

    expect(adapter.requests.first.method, 'PATCH');
    expect(adapter.requests.first.path, '/api/v1/documents/9/archive');
    expect(adapter.requests.first.data, {'archived': true});
  });
}
