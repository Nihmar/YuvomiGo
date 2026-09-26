import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/documents/document_models.dart';

/// Repository per il modulo Documenti (sola lettura: metadati).
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
}
