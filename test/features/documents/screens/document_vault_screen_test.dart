// test/features/documents/screens/document_vault_screen_test.dart
//
// Scoped to what's safely testable without a live device: loading, the
// empty state, and grouped list rendering (TEST_SHEET.md row 47). Rows
// 48-50 (upload PDF/DOCX/image) need file_picker/image_picker — real
// platform-channel plugins with no test-mode support in this codebase (same
// class of blocker hit with local_auth/just_audio elsewhere this session).
// Rows 51-52 (tap to preview) call SupabaseService.client.storage.
// createSignedUrl() directly in _previewDocument() with no injection seam,
// so a tap silently no-ops in a widget test (Supabase not initialised)
// rather than navigating — not exercised here. Flagging rather than forcing
// either, consistent with how the Interview recording provider blocker was
// handled.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/documents/screens/document_vault_screen.dart';
import 'package:marine_survey_app/features/documents/providers/document_provider.dart';
import 'package:marine_survey_app/features/photos/providers/photo_provider.dart';

import '../../../support/fakes/fake_document_notifier.dart';
import '../../../support/fakes/fake_photo_notifier.dart';

const _caseId = 'case-1';

Future<void> _pump(
  WidgetTester tester, {
  List<DocumentModel> docs = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        documentProvider.overrideWith(() => FakeDocumentNotifier(docs)),
        photosProvider.overrideWith(() => FakePhotoNotifier([])),
      ],
      child: const MaterialApp(home: DocumentVaultScreen(caseId: _caseId)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty vault shows the empty state with an Import action', (tester) async {
    await _pump(tester);

    expect(find.text('Import'), findsWidgets); // FAB + empty-state action
  });

  testWidgets('loads and shows documents grouped by category', (tester) async {
    final docs = [
      const DocumentModel(
        docId: 'd1',
        caseId: _caseId,
        title: 'Class Survey Report 2025',
        docCategory: DocCategory.classSurveyReport,
      ),
      const DocumentModel(
        docId: 'd2',
        caseId: _caseId,
        title: 'Statement of Facts',
        docCategory: DocCategory.statementOfFacts,
      ),
    ];
    await _pump(tester, docs: docs);

    expect(find.text('Class Survey Report 2025'), findsOneWidget);
    expect(find.text('Statement of Facts'), findsOneWidget);
  });

  testWidgets('AppBar shows the AI processing status and log-requested actions',
      (tester) async {
    await _pump(tester);

    expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
    expect(find.byIcon(Icons.playlist_add), findsOneWidget);
  });

  testWidgets('Export-to-Drive action is disabled when the vault is empty',
      (tester) async {
    await _pump(tester);

    final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add_to_drive_outlined));
    expect(button.onPressed, isNull);
  });

  testWidgets('Export-to-Drive action is enabled once a document exists',
      (tester) async {
    await _pump(tester, docs: [
      const DocumentModel(docId: 'd1', caseId: _caseId, title: 'Some doc'),
    ]);

    final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add_to_drive_outlined));
    expect(button.onPressed, isNotNull);
  });
}
