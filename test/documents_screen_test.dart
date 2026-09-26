import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/document_repository.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
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

  @override
  Future<List<DocumentItem>> fetchDocuments() async => const [
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
    DocumentItem(id: 2, name: 'Pagella', category: 'school', fileSize: 1024),
  ];
}

Widget _pump(FakeDocumentRepository repo) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => FakeAuthController(Authenticated(user: fakeUser())),
      ),
      documentRepositoryProvider.overrideWithValue(repo),
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
    expect(find.text('Pagella'), findsOneWidget);
    expect(find.textContaining('Casa'), findsOneWidget);
    expect(find.textContaining('Assicurazioni'), findsOneWidget);
    expect(find.textContaining('200 KB'), findsOneWidget);
  });

  testWidgets('Search filters the list', (tester) async {
    final repo = FakeDocumentRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'pagella');
    await tester.pumpAndSettle();

    expect(find.text('Pagella'), findsOneWidget);
    expect(find.text('Assicurazione casa'), findsNothing);
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
}
