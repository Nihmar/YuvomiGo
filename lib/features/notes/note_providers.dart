import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/note_repository.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/notes/note_models.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) throw StateError('NoteRepository senza sessione attiva');
  return NoteRepository(api);
});

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
    try {
      final created = await repo.createNote(
        content: content,
        title: title,
        color: color,
        pinned: pinned,
      );
      final notes = (state.value ?? const <Note>[]).toSet()..add(created);
      state = AsyncData(notes.toList());
    } catch (e, st) {
      state = AsyncError<List<Note>>(e, st);
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
    try {
      final updated = await repo.updateNote(
        id,
        content: content,
        title: title,
        color: color,
        pinned: pinned,
      );
      final notes = state.value?.map((n) => n.id == id ? updated : n).toList();
      state = AsyncData(notes ?? const <Note>[]);
    } catch (e, st) {
      state = AsyncError<List<Note>>(e, st);
    }
  }

  Future<void> remove(int id) async {
    final repo = ref.read(noteRepositoryProvider);
    try {
      await repo.deleteNote(id);
      final notes =
          state.value?.where((n) => n.id != id).toList() ?? const <Note>[];
      state = AsyncData(notes);
    } catch (e, st) {
      state = AsyncError<List<Note>>(e, st);
    }
  }
}
