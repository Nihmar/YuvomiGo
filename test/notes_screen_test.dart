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
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  final List<Note> notes = [
    Note(
      id: 1,
      content: 'lista',
      title: 'Spesa',
      categories: const [
        NoteCategory(id: 1, name: 'Casa', scope: 'household', sortOrder: 0),
      ],
    ),
    Note(id: 2, content: 'solo contenuto'),
  ];
  int _nextId = 100;

  List<int>? lastCreateCategoryIds;
  List<int>? lastUpdateCategoryIds;

  static const _allCategories = [
    NoteCategory(id: 1, name: 'Casa', scope: 'household', sortOrder: 0),
    NoteCategory(
      id: 2,
      name: 'Lavoro',
      scope: 'personal',
      ownerUserId: 1,
      sortOrder: 1,
    ),
  ];

  @override
  Future<List<Note>> fetchNotes() async => notes.toList();

  @override
  Future<List<NoteCategory>> fetchCategories() async => _allCategories;

  List<NoteCategory> _byIds(List<int>? ids) => [
    for (final category in _allCategories)
      if (ids?.contains(category.id) == true) category,
  ];

  @override
  Future<Note> createNote({
    required String content,
    String? title,
    String? color,
    bool pinned = false,
    List<int>? categoryIds,
  }) {
    lastCreateCategoryIds = categoryIds;
    final n = Note(
      id: _nextId++,
      content: content,
      title: title,
      color: color,
      pinned: pinned,
      categories: _byIds(categoryIds),
    );
    notes.add(n);
    return Future.value(n);
  }

  @override
  Future<Note> updateNote(
    int id, {
    String? content,
    String? title,
    String? color,
    bool? pinned,
    List<int>? categoryIds,
  }) {
    lastUpdateCategoryIds = categoryIds;
    final idx = notes.indexWhere((n) => n.id == id);
    final old = notes[idx];
    final updated = Note(
      id: id,
      content: content ?? old.content,
      title: title,
      color: color ?? old.color,
      pinned: pinned ?? old.pinned,
      categories: categoryIds == null ? old.categories : _byIds(categoryIds),
    );
    notes[idx] = updated;
    return Future.value(updated);
  }

  @override
  Future<void> deleteNote(int id) async => notes.removeWhere((n) => n.id == id);
}

/// Il server non raggiungibile: il salvataggio fallisce.
final class FailingNoteRepository extends FakeNoteRepository {
  @override
  Future<Note> createNote({
    required String content,
    String? title,
    String? color,
    bool pinned = false,
    List<int>? categoryIds,
  }) => Future.error(Exception('offline'));
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
    // Le categorie compaiono nella sottotitolo.
    expect(find.textContaining('Casa'), findsWidgets);
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

  testWidgets('Creating a note can set a color', (tester) async {
    final repo = FakeNoteRepository();
    await tester.pumpWidget(_pump(const NotesScreen(), repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'nota blu');
    await tester.ensureVisible(
      find.byKey(const ValueKey('note-color-#BBDEFB')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-color-#BBDEFB')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(repo.notes.last.color, '#BBDEFB');
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

  testWidgets('Pinning a note moves it to the top', (tester) async {
    final repo = FakeNoteRepository();
    await tester.pumpWidget(_pump(const NotesScreen(), repo));
    await tester.pumpAndSettle();

    // Prima tile = 'Spesa', seconda = 'solo contenuto'. Il bottone pin è il
    // primo IconButton del trailing della seconda tile.
    final secondTile = find.byType(ListTile).at(1);
    final pinButton = find
        .descendant(of: secondTile, matching: find.byType(IconButton))
        .first;
    await tester.tap(pinButton);
    await tester.pumpAndSettle();

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect((tiles.first.title as Text).data, 'solo contenuto');
  });

  testWidgets('A failed save keeps the editor open with the draft', (
    tester,
  ) async {
    final repo = FailingNoteRepository();
    await tester.pumpWidget(_pump(const NotesScreen(), repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'bozza importante');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(find.text('Nuova nota'), findsOneWidget);
    expect(find.text('bozza importante'), findsWidgets);
    expect(find.textContaining('Operazione non riuscita'), findsOneWidget);
  });

  testWidgets('The editor can assign categories', (tester) async {
    final repo = FakeNoteRepository();
    await tester.pumpWidget(_pump(const NotesScreen(), repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'nota nuova');
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Casa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Casa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(repo.lastCreateCategoryIds, contains(1));
  });

  test('sortNotesPinnedFirst keeps the relative order', () {
    final notes = [
      const Note(id: 1, content: 'a'),
      const Note(id: 2, content: 'b', pinned: true),
      const Note(id: 3, content: 'c'),
      const Note(id: 4, content: 'd', pinned: true),
    ];

    expect(sortNotesPinnedFirst(notes).map((n) => n.id).toList(), [2, 4, 1, 3]);
  });
}
