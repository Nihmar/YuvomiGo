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

/// Categorie delle note (lista + gestione).
final noteCategoriesProvider =
    NotifierProvider.autoDispose<
      NoteCategoriesNotifier,
      AsyncValue<List<NoteCategory>>
    >(NoteCategoriesNotifier.new);

final class NoteCategoriesNotifier
    extends Notifier<AsyncValue<List<NoteCategory>>> {
  bool _loading = false;

  @override
  AsyncValue<List<NoteCategory>> build() {
    Future.microtask(load);
    return const AsyncLoading();
  }

  Future<void> load() => _fetch(showLoading: true);

  Future<void> _fetch({required bool showLoading}) async {
    if (_loading) return;
    _loading = true;
    final repo = ref.read(noteRepositoryProvider);
    if (showLoading) state = const AsyncLoading();
    try {
      final categories = await repo.fetchCategories();
      if (!ref.mounted) return;
      state = AsyncData(categories);
    } catch (e, st) {
      if (!ref.mounted) return;
      if (state.hasValue) {
        ref.read(notesActionErrorProvider.notifier).report(e);
      } else {
        state = AsyncError(e, st);
      }
    } finally {
      _loading = false;
    }
  }

  /// Crea la categoria; ritorna false se fallisce (dialog aperto).
  Future<bool> add(String name, {String scope = 'personal'}) async {
    final repo = ref.read(noteRepositoryProvider);
    ref.read(notesActionErrorProvider.notifier).clear();
    try {
      await repo.createCategory(name, scope: scope);
      if (!ref.mounted) return true;
      await _fetch(showLoading: false);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      ref.read(notesActionErrorProvider.notifier).report(e);
      return false;
    }
  }

  Future<bool> rename(int id, String name) async {
    final repo = ref.read(noteRepositoryProvider);
    ref.read(notesActionErrorProvider.notifier).clear();
    try {
      await repo.renameCategory(id, name);
      if (!ref.mounted) return true;
      await _fetch(showLoading: false);
      ref.invalidate(notesProvider);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      ref.read(notesActionErrorProvider.notifier).report(e);
      return false;
    }
  }

  Future<void> remove(int id) async {
    final repo = ref.read(noteRepositoryProvider);
    ref.read(notesActionErrorProvider.notifier).clear();
    try {
      await repo.deleteCategory(id);
      if (!ref.mounted) return;
      await _fetch(showLoading: false);
      ref.invalidate(notesProvider);
    } catch (e) {
      if (!ref.mounted) return;
      ref.read(notesActionErrorProvider.notifier).report(e);
    }
  }
}

final class NotesNotifier extends Notifier<AsyncValue<List<Note>>> {
  bool _loading = false;

  @override
  AsyncValue<List<Note>> build() {
    Future.microtask(load);
    return const AsyncLoading();
  }

  Future<void> load() => _fetch(showLoading: true);

  /// Ricarica mantenendo le note correnti (pull-to-refresh).
  Future<void> refresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (_loading) return;
    _loading = true;
    final repo = ref.read(noteRepositoryProvider);
    if (showLoading) state = const AsyncLoading();
    try {
      final notes = await repo.fetchNotes();
      if (!ref.mounted) return;
      state = AsyncData(notes);
    } catch (e, st) {
      if (!ref.mounted) return;
      if (state.hasValue) {
        ref.read(notesActionErrorProvider.notifier).report(e);
      } else {
        state = AsyncError(e, st);
      }
    } finally {
      _loading = false;
    }
  }

  /// Crea la nota; ritorna false se il salvataggio fallisce (la UI resta
  /// aperta e l'errore è già nello [notesActionErrorProvider]).
  Future<bool> add({
    required String content,
    String? title,
    String? color,
    bool pinned = false,
    List<int>? categoryIds,
  }) async {
    final repo = ref.read(noteRepositoryProvider);
    ref.read(notesActionErrorProvider.notifier).clear();
    try {
      final created = await repo.createNote(
        content: content,
        title: title,
        color: color,
        pinned: pinned,
        categoryIds: categoryIds,
      );
      if (!ref.mounted) return false;
      final notes = sortNotesPinnedFirst([
        ...state.value ?? const <Note>[],
        created,
      ]);
      state = AsyncData(notes);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      ref.read(notesActionErrorProvider.notifier).report(e);
      return false;
    }
  }

  /// Aggiorna la nota; ritorna false se il salvataggio fallisce.
  Future<bool> update(
    int id, {
    String? content,
    String? title,
    String? color,
    bool? pinned,
    List<int>? categoryIds,
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
        categoryIds: categoryIds,
      );
      if (!ref.mounted) return false;
      final prev = state.value ?? const <Note>[];
      state = AsyncData(
        sortNotesPinnedFirst(prev.map((n) => n.id == id ? updated : n)),
      );
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      ref.read(notesActionErrorProvider.notifier).report(e);
      return false;
    }
  }

  Future<void> remove(int id) async {
    final prev = state.value ?? const <Note>[];
    final repo = ref.read(noteRepositoryProvider);
    ref.read(notesActionErrorProvider.notifier).clear();
    try {
      await repo.deleteNote(id);
      if (!ref.mounted) return;
      state = AsyncData(prev.where((n) => n.id != id).toList());
    } catch (e) {
      if (!ref.mounted) return;
      ref.read(notesActionErrorProvider.notifier).report(e);
    }
  }
}
