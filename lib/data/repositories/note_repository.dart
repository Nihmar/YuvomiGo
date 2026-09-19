import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/features/notes/note_models.dart';

/// Repository per il modulo Note.
///
/// Le note SONO in spec OpenAPI, ma la response usa il wrapping `{ data: ... }`
/// che il client generato non mappa qui: richiesta raw via Dio + parsing.
base class NoteRepository {
  NoteRepository(this._api);

  final YuvomiApi _api;

  Future<List<Note>> fetchNotes() async {
    final res = await _api.dio.get<dynamic>('/api/v1/notes');
    final data = (res.data is Map)
        ? (res.data as Map<String, dynamic>)['data']
        : res.data;
    final list = (data as List<dynamic>)
        .map((e) => Note.fromJson(e as Map<String, dynamic>))
        .toList();
    list.sort((a, b) {
      if (a.pinned == b.pinned) return 0;
      return a.pinned ? -1 : 1; // pinned prima
    });
    return list;
  }

  Future<Note> fetchNote(int id) async {
    final res = await _api.dio.get<dynamic>('/api/v1/notes/$id');
    final data = (res.data is Map)
        ? (res.data as Map<String, dynamic>)['data']
        : res.data;
    return Note.fromJson(data as Map<String, dynamic>);
  }

  Future<Note> createNote({
    required String content,
    String? title,
    String? color,
    bool pinned = false,
  }) async {
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
  }

  Future<Note> updateNote(
    int id, {
    String? content,
    String? title,
    String? color,
    bool? pinned,
  }) async {
    final res = await _api.dio.put<dynamic>(
      '/api/v1/notes/$id',
      data: {
        'content': content,
        'title': title,
        'color': color,
        'pinned': pinned ?? false,
      },
    );
    final data = (res.data is Map)
        ? (res.data as Map<String, dynamic>)['data']
        : res.data;
    return Note.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteNote(int id) async {
    await _api.dio.delete<void>('/api/v1/notes/$id');
  }
}
