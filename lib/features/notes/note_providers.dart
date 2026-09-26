import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/note_repository.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/notes/note_models.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) throw StateError('NoteRepository senza sessione attiva');
  return NoteRepository(api);
});

/// Ultimo errore di un'azione (add/update/remove). La lista resta intatta:
/// lo screen lo mostra come SnackBar. Null = nessuna azione fallita di recente.
final notesActionErrorProvider =
    NotifierProvider<NotesActionErrorNotifier, Object?>(
      NotesActionErrorNotifier.new,
    );

final class NotesActionErrorNotifier extends Notifier<Object?> {
  @override
  Object? build() => null;

  void clear() => state = null;
  void report(Object error) => state = error;
}

final notesProvider =
    NotifierProvider.autoDispose<NotesNotifier, AsyncValue<List<Note>>>(
      NotesNotifier.new,
    );

final class NotesNotifier extends Notifier<AsyncValue<List<Note>>> {
  bool _loading = false;

  @override
  AsyncValue<List<Note>> build() {
    Future.microtask(load);
    return const AsyncLoading();
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    final repo = ref.read(noteRepositoryProvider);
    try {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => repo.fetchNotes());
    } finally {
      _loading = false;
    }
  }

  Future<void> add({
    required String content,
    String? title,
    String? color,
    bool pinned = false,
  }) async {
    final repo = ref.read(noteRepositoryProvider);
    ref.read(notesActionErrorProvider.notifier).clear();
    try {
      final created = await repo.createNote(
        content: content,
        title: title,
        color: color,
        pinned: pinned,
      );
      final notes = [...state.value ?? const <Note>[], created];
      state = AsyncData(notes);
    } catch (e) {
      ref.read(notesActionErrorProvider.notifier).report(e);
    }
  }

  Future<void> update(
    int id, {
    String? content,
    String? title,
    String? color,
    bool? pinned,
  }) async {
    final repo = ref.read(noteRepositoryProvider);
    ref.read(notesActionErrorProvider.notifier).clear();
    try {
      final updated = await repo.updateNote(
        id,
        content: content,
        title: title,
        color: color,
        pinned: pinned,
      );
      final prev = state.value ?? const <Note>[];
      state = AsyncData(prev.map((n) => n.id == id ? updated : n).toList());
    } catch (e) {
      ref.read(notesActionErrorProvider.notifier).report(e);
    }
  }

  Future<void> remove(int id) async {
    final prev = state.value ?? const <Note>[];
    final repo = ref.read(noteRepositoryProvider);
    ref.read(notesActionErrorProvider.notifier).clear();
    try {
      await repo.deleteNote(id);
      state = AsyncData(prev.where((n) => n.id != id).toList());
    } catch (e) {
      ref.read(notesActionErrorProvider.notifier).report(e);
    }
  }
}
