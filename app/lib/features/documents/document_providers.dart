import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/document_repository.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/documents/document_models.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) throw StateError('DocumentRepository senza sessione attiva');
  return DocumentRepository(api);
});

/// Ultimo errore di un'azione sui documenti (SnackBar).
final documentsActionErrorProvider =
    NotifierProvider<DocumentsActionErrorNotifier, Object?>(
      DocumentsActionErrorNotifier.new,
    );

final class DocumentsActionErrorNotifier extends Notifier<Object?> {
  @override
  Object? build() => null;

  void clear() => state = null;
  void report(Object error) => state = error;
}

/// Documenti attivi (ricerca filtrata in locale) + upload/archivio.
final documentsProvider =
    NotifierProvider.autoDispose<
      DocumentsNotifier,
      AsyncValue<List<DocumentItem>>
    >(DocumentsNotifier.new);

final class DocumentsNotifier extends Notifier<AsyncValue<List<DocumentItem>>> {
  bool _loading = false;

  @override
  AsyncValue<List<DocumentItem>> build() {
    Future.microtask(load);
    return const AsyncLoading();
  }

  Future<void> load() => _fetch(showLoading: true);

  /// Ricarica mantenendo i documenti correnti (pull-to-refresh).
  Future<void> refresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (!ref.mounted) return;
    if (_loading) return;
    _loading = true;
    final repo = ref.read(documentRepositoryProvider);
    if (showLoading) state = const AsyncLoading();
    try {
      final documents = await repo.fetchDocuments();
      if (!ref.mounted) return;
      state = AsyncData(documents);
    } catch (e, st) {
      if (!ref.mounted) return;
      if (state.hasValue) {
        ref.read(documentsActionErrorProvider.notifier).report(e);
      } else {
        state = AsyncError(e, st);
      }
    } finally {
      _loading = false;
    }
  }

  /// Carica il file; ritorna false se fallisce (dialog aperto).
  Future<bool> upload({
    required String name,
    required String originalName,
    required String mimeType,
    required Uint8List bytes,
    String category = 'other',
    String? description,
  }) async {
    if (!ref.mounted) return false;
    final repo = ref.read(documentRepositoryProvider);
    ref.read(documentsActionErrorProvider.notifier).clear();
    try {
      await repo.uploadDocument(
        name: name,
        originalName: originalName,
        mimeType: mimeType,
        bytes: bytes,
        category: category,
        description: description,
      );
      if (!ref.mounted) return true;
      await _fetch(showLoading: false);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      ref.read(documentsActionErrorProvider.notifier).report(e);
      return false;
    }
  }

  Future<void> archive(int id) async {
    if (!ref.mounted) return;
    final repo = ref.read(documentRepositoryProvider);
    ref.read(documentsActionErrorProvider.notifier).clear();
    try {
      await repo.archiveDocument(id);
      if (!ref.mounted) return;
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.where((d) => d.id != id).toList());
      }
    } catch (e) {
      if (!ref.mounted) return;
      ref.read(documentsActionErrorProvider.notifier).report(e);
    }
  }
}
