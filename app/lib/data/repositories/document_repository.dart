import 'dart:convert';
import 'dart:typed_data';

import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/documents/document_models.dart';

/// Repository per il modulo Documenti (metadati + upload/archivio).
base class DocumentRepository {
  DocumentRepository(this._api);

  final YuvomiApi _api;

  Future<List<DocumentItem>> fetchDocuments() {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>('/api/v1/documents');
      final data = res.data?['data'];
      final raw = data is List ? data : const <dynamic>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(DocumentItem.fromJson)
          .toList();
    });
  }

  /// Carica un documento: il server accetta il contenuto come data URL base64.
  Future<DocumentItem> uploadDocument({
    required String name,
    required String originalName,
    required String mimeType,
    required Uint8List bytes,
    String category = 'other',
    String? description,
  }) {
    return mapApiErrors(() async {
      final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
      final res = await _api.dio.post<dynamic>(
        '/api/v1/documents',
        data: {
          'name': name,
          'original_name': originalName,
          'category': category,
          'content_data': dataUrl,
          'description': ?description,
        },
      );
      return DocumentItem.fromJson(_data(res.data));
    });
  }

  /// Archivia il documento (sparisce dall'elenco attivo).
  Future<void> archiveDocument(int id) {
    return mapApiErrors(
      () => _api.dio.patch<void>(
        '/api/v1/documents/$id/archive',
        data: {'archived': true},
      ),
    );
  }

  Map<String, dynamic> _data(Object? body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
    }
    throw const ApiServerError(200, 'Risposta inattesa dal server.');
  }
}
