import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/notes/note_models.dart';

/// Repository per il modulo Note.
///
/// La response usa il wrapping `{ data: ... }`: richiesta raw via Dio +
/// parsing nei model di dominio (più comodi di quelli generati, es. `pinned`
/// bool invece di `dynamic`).
base class NoteRepository {
  NoteRepository(this._api);

  final YuvomiApi _api;

  /// Categorie visibili (personali + household).
  Future<List<NoteCategory>> fetchCategories() {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/api/v1/notes/categories',
      );
      final data = res.data?['data'];
      final raw = data is List ? data : const <dynamic>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(NoteCategory.fromJson)
          .toList();
    });
  }

  /// Crea una categoria [scope] 'personal' o 'household'.
  Future<NoteCategory> createCategory(
    String name, {
    String scope = 'personal',
  }) {
    return mapApiErrors(() async {
      final res = await _api.dio.post<dynamic>(
        '/api/v1/notes/categories',
        data: {'name': name, 'scope': scope},
      );
      return NoteCategory.fromJson(_noteData(res.data));
    });
  }

  Future<NoteCategory> renameCategory(int id, String name) {
    return mapApiErrors(() async {
      final res = await _api.dio.put<dynamic>(
        '/api/v1/notes/categories/$id',
        data: {'name': name},
      );
      return NoteCategory.fromJson(_noteData(res.data));
    });
  }

  Future<void> deleteCategory(int id) {
    return mapApiErrors(
      () => _api.dio.delete<void>('/api/v1/notes/categories/$id'),
    );
  }

  Map<String, dynamic> _noteData(Object? body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
    }
    throw const ApiServerError(200, 'Risposta inattesa dal server.');
  }

  Future<List<Note>> fetchNotes() {
    return mapApiErrors(() async {
      final res = await _api.dio.get<dynamic>('/api/v1/notes');
      final data = (res.data is Map)
          ? (res.data as Map<String, dynamic>)['data']
          : res.data;
      // `data` assente/non-lista (risposta inattesa con 200): lista vuota
      // invece di un TypeError che oscura l'errore vero.
      final raw = data is List ? data : const <dynamic>[];
      final list = raw
          .map((e) => Note.fromJson(e as Map<String, dynamic>))
          .toList();
      return sortNotesPinnedFirst(list);
    });
  }

  Future<Note> fetchNote(int id) {
    return mapApiErrors(() async {
      final res = await _api.dio.get<dynamic>('/api/v1/notes/$id');
      final data = (res.data is Map)
          ? (res.data as Map<String, dynamic>)['data']
          : res.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiServerError(200, 'Risposta inattesa dal server.');
      }
      return Note.fromJson(data);
    });
  }

  Future<Note> createNote({
    required String content,
    String? title,
    String? color,
    bool pinned = false,
    List<int>? categoryIds,
  }) {
    return mapApiErrors(() async {
      final res = await _api.dio.post<dynamic>(
        '/api/v1/notes',
        data: {
          'content': content,
          'title': title,
          'color': color,
          'pinned': pinned ? 1 : 0,
          'category_ids': ?categoryIds,
        },
      );
      final data = (res.data is Map)
          ? (res.data as Map<String, dynamic>)['data']
          : res.data;
      return Note.fromJson(data as Map<String, dynamic>);
    });
  }

  /// Solo i campi valorizzati vengono inviati: il PUT interpreta una chiave
  /// presente (anche null) come "sovrascrivi" — ad es. `title: null`
  /// cancellerebbe il titolo (il toggle del pin manda solo `pinned`).
  /// Per azzerare il titolo passare stringa vuota (il server la normalizza).
  Future<Note> updateNote(
    int id, {
    String? content,
    String? title,
    String? color,
    bool? pinned,
    List<int>? categoryIds,
  }) {
    return mapApiErrors(() async {
      final res = await _api.dio.put<dynamic>(
        '/api/v1/notes/$id',
        data: {
          'content': ?content,
          'title': ?title,
          'color': ?color,
          if (pinned case final p?) 'pinned': p ? 1 : 0,
          'category_ids': ?categoryIds,
        },
      );
      final data = (res.data is Map)
          ? (res.data as Map<String, dynamic>)['data']
          : res.data;
      return Note.fromJson(data as Map<String, dynamic>);
    });
  }

  Future<void> deleteNote(int id) {
    return mapApiErrors(() => _api.dio.delete<void>('/api/v1/notes/$id'));
  }
}
