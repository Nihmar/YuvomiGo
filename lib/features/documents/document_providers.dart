import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/document_repository.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/documents/document_models.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) throw StateError('DocumentRepository senza sessione attiva');
  return DocumentRepository(api);
});

/// Documenti attivi (ricerca filtrata in locale).
final documentsProvider = FutureProvider.autoDispose<List<DocumentItem>>((
  ref,
) async {
  final repo = ref.watch(documentRepositoryProvider);
  return repo.fetchDocuments();
});
