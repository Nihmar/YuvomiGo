import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/document_repository.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/documents/document_file_picker.dart';
import 'package:yuvomigo/features/documents/document_models.dart';
import 'package:yuvomigo/features/documents/document_providers.dart';
import 'package:yuvomigo/features/documents/documents_screen.dart';

import 'utils/fake_auth_controller.dart';
import 'utils/in_memory_storage.dart';

final class FakeDocumentRepository extends DocumentRepository {
  FakeDocumentRepository()
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  final List<DocumentItem> documents = [
    DocumentItem(
      id: 1,
      name: 'Assicurazione casa',
      description: 'polizza 2026',
      category: 'insurance',
      originalName: 'polizza.pdf',
      mimeType: 'application/pdf',
      fileSize: 204800,
      folderName: 'Casa',
      creatorName: 'Utente Test',
      updatedAt: '2026-09-01T10:00:00Z',
    ),
  ];
  final List<String> uploaded = [];
  final List<int> archived = [];
  int _nextId = 100;

  @override
  Future<List<DocumentItem>> fetchDocuments() async => documents.toList();

  @override
  Future<DocumentItem> uploadDocument({
    required String name,
    required String originalName,
    required String mimeType,
    required Uint8List bytes,
    String category = 'other',
    String? description,
  }) async {
    uploaded.add(name);
    final document = DocumentItem(
      id: _nextId++,
      name: name,
      originalName: originalName,
      mimeType: mimeType,
      fileSize: bytes.length,
      category: category,
      description: description,
    );
    documents.add(document);
    return document;
  }

  @override
  Future<void> archiveDocument(int id) async {
    archived.add(id);
    documents.removeWhere((d) => d.id == id);
  }
}

final class FakeDocumentFilePicker implements DocumentFilePicker {
  FakeDocumentFilePicker(this.file);

  final PickedDocumentFile? file;

  @override
  Future<PickedDocumentFile?> pick() async => file;
}

final class ThrowingDocumentFilePicker implements DocumentFilePicker {
  @override
  Future<PickedDocumentFile?> pick() async => throw Exception('boom');
}

Widget _pump(FakeDocumentRepository repo, {DocumentFilePicker? picker}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => FakeAuthController(Authenticated(user: fakeUser())),
      ),
      documentRepositoryProvider.overrideWithValue(repo),
      if (picker != null) documentFilePickerProvider.overrideWithValue(picker),
    ],
    child: const MaterialApp(home: DocumentsScreen()),
  );
}

void main() {
  testWidgets('Documents screen renders name, folder, category and size', (
    tester,
  ) async {
    final repo = FakeDocumentRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    expect(find.text('Assicurazione casa'), findsOneWidget);
    expect(find.textContaining('Casa'), findsOneWidget);
    expect(find.textContaining('Assicurazioni'), findsOneWidget);
    expect(find.textContaining('200 KB'), findsOneWidget);
  });

  testWidgets('Search filters the list', (tester) async {
    final repo = FakeDocumentRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'polizza');
    await tester.pumpAndSettle();

    expect(find.text('Assicurazione casa'), findsOneWidget);
  });

  testWidgets('Tapping a document opens the detail', (tester) async {
    final repo = FakeDocumentRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assicurazione casa'));
    await tester.pumpAndSettle();

    expect(find.text('Cartella'), findsOneWidget);
    expect(find.text('polizza.pdf'), findsOneWidget);
    expect(find.text('polizza 2026'), findsOneWidget);
    expect(find.text('Utente Test'), findsOneWidget);
  });

  testWidgets('A picked file is uploaded with its metadata', (tester) async {
    final repo = FakeDocumentRepository();
    await tester.pumpWidget(
      _pump(
        repo,
        picker: FakeDocumentFilePicker(
          PickedDocumentFile(
            name: 'nuovo.pdf',
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Carica documento'));
    await tester.pumpAndSettle();

    expect(find.textContaining('nuovo.pdf · 3 B'), findsOneWidget);

    await tester.tap(find.text('Carica'));
    await tester.pumpAndSettle();

    expect(repo.uploaded, ['nuovo']);
    expect(find.text('nuovo'), findsOneWidget);
  });

  testWidgets('An unsupported file type is rejected with a message', (
    tester,
  ) async {
    final repo = FakeDocumentRepository();
    await tester.pumpWidget(
      _pump(
        repo,
        picker: FakeDocumentFilePicker(
          PickedDocumentFile(name: 'virus.exe', bytes: Uint8List(0)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Carica documento'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tipo di file non supportato'), findsOneWidget);
    expect(repo.uploaded, isEmpty);
  });

  testWidgets('A picker failure shows a message instead of crashing', (
    tester,
  ) async {
    final repo = FakeDocumentRepository();
    await tester.pumpWidget(_pump(repo, picker: ThrowingDocumentFilePicker()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Carica documento'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Selezione del file non riuscita'),
      findsOneWidget,
    );
  });

  testWidgets('A document can be archived', (tester) async {
    final repo = FakeDocumentRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Archivia').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archivia'));
    await tester.pumpAndSettle();

    expect(repo.archived, [1]);
    expect(find.text('Assicurazione casa'), findsNothing);
  });
}
