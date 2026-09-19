import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/note_repository.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/notes/note_models.dart';
import 'package:yuvomigo/features/notes/note_providers.dart';
import 'package:yuvomigo/features/notes/notes_screen.dart';

import 'utils/fake_auth_controller.dart';
import 'utils/in_memory_storage.dart';

final class FakeNoteRepository extends NoteRepository {
  FakeNoteRepository()
      : super(YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ));

  final List<Note> notes = [
    Note(id: 1, content: 'lista', title: 'Spesa'),
    Note(id: 2, content: 'solo contenuto'),
  ];
  int _nextId = 100;

  @override
  Future<List<Note>> fetchNotes() async => notes.toList();

  @override
  Future<Note> createNote(
      {required String content,
      String? title,
      String? color,
      bool pinned = false}) {
    final n = Note(
        id: _nextId++, content: content, title: title, pinned: pinned);
    notes.add(n);
    return Future.value(n);
  }

  @override
  Future<Note> updateNote(int id,
      {String? content, String? title, String? color, bool? pinned}) {
    final idx = notes.indexWhere((n) => n.id == id);
    final old = notes[idx];
    final updated = Note(
      id: id,
      content: content ?? old.content,
      title: title,
      color: color ?? old.color,
      pinned: pinned ?? old.pinned,
      categories: old.categories,
    );
    notes[idx] = updated;
    return Future.value(updated);
  }

  @override
  Future<void> deleteNote(int id) async => notes.removeWhere((n) => n.id == id);
}

Widget _pump(Widget child, FakeNoteRepository repo) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => FakeAuthController(Authenticated(user: fakeUser())),
      ),
      noteRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('Notes screen renders the notes', (tester) async {
    final repo = FakeNoteRepository();
    await tester.pumpWidget(_pump(const NotesScreen(), repo));
    await tester.pumpAndSettle();

    // La nota con titolo mostra il titolo; quella senza mostra la 1ª riga.
    expect(find.text('Spesa'), findsOneWidget);
    expect(find.text('solo contenuto'), findsWidgets);
  });

  testWidgets('Creating a note adds it', (tester) async {
    final repo = FakeNoteRepository();
    await tester.pumpWidget(_pump(const NotesScreen(), repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    // Nel dialog: TextField[0]=titolo, TextField[1]=contenuto.
    await tester.enterText(find.byType(TextField).at(1), 'nuova nota');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(find.text('nuova nota'), findsWidgets);
    expect(repo.notes.map((n) => n.content), contains('nuova nota'));
  });

  testWidgets('Deleting a note removes it', (tester) async {
    final repo = FakeNoteRepository();
    await tester.pumpWidget(_pump(const NotesScreen(), repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();

    expect(repo.notes, hasLength(1));
  });
}
