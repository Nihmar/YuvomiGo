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
      list.sort((a, b) {
        if (a.pinned == b.pinned) return 0;
        return a.pinned ? -1 : 1; // pinned prima
      });
      return list;
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
  }) {
    return mapApiErrors(() async {
      final res = await _api.dio.post<dynamic>(
        '/api/v1/notes',
        data: {
          'content': content,
          'title': title,
          'color': color,
          'pinned': pinned ? 1 : 0,
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
  }) {
    return mapApiErrors(() async {
      final res = await _api.dio.put<dynamic>(
        '/api/v1/notes/$id',
        data: {
          'content': ?content,
          'title': ?title,
          'color': ?color,
          if (pinned case final p?) 'pinned': p ? 1 : 0,
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
