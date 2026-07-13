// §4.1 (13 July 2026): Production Manager — combines documents.dart's
// extraction_status and repair_documents.dart's new (same-shaped)
// extraction_status column into one per-case "what's AI-processed, what's
// pending, what failed" view.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marine_survey_app/features/accounts/models/accounts_models.dart';
import 'package:marine_survey_app/features/accounts/providers/accounts_provider.dart';
import 'package:marine_survey_app/features/documents/providers/document_provider.dart';
import 'package:marine_survey_app/features/documents/screens/production_manager_screen.dart';

import '../../../support/fakes/fake_document_notifier.dart';
import '../../../support/fakes/fake_repair_documents_notifier.dart';

const _caseId = 'case-1';

DocumentModel _doc({
  required String id,
  required String title,
  String? extractionStatus,
}) =>
    DocumentModel(
      docId: id,
      caseId: _caseId,
      title: title,
      filePath: 'some/path.pdf',
      extractionStatus: extractionStatus,
      pendingExtraction: extractionStatus == 'ready_for_review'
          ? {'hard_fields': {}}
          : null,
    );

RepairDocumentModel _invoice({
  required String id,
  required String name,
  String? extractionStatus,
}) =>
    RepairDocumentModel(
      id: id,
      caseId: _caseId,
      displayName: name,
      extractionStatus: extractionStatus,
    );

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<DocumentModel> docs = const [],
  List<RepairDocumentModel> invoices = const [],
}) async {
  final container = ProviderContainer(overrides: [
    documentProvider.overrideWith(() => FakeDocumentNotifier(docs)),
    repairDocumentsProvider
        .overrideWith(() => FakeRepairDocumentsNotifier(invoices)),
  ]);
  addTearDown(container.dispose);

  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const ProductionManagerScreen(caseId: _caseId),
    ),
  ]);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  // Not pumpAndSettle(): a 'processing' item renders an indeterminate
  // CircularProgressIndicator, which animates forever and would time out.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return container;
}

void main() {
  group('ProductionManagerScreen', () {
    testWidgets('empty state when nothing has ever entered the pipeline',
        (tester) async {
      await _pump(tester, docs: [
        // No file / never queued (extraction_status null) — must NOT show up.
        _doc(id: 'd1', title: 'Requested doc, no file yet'),
      ]);

      expect(find.text('No AI extraction activity yet'), findsOneWidget);
    });

    testWidgets(
        'summary counts and per-item badges reflect mixed document + '
        'invoice statuses', (tester) async {
      await _pump(
        tester,
        docs: [
          _doc(id: 'd1', title: 'Class Certificate', extractionStatus: 'processing'),
          _doc(id: 'd2', title: 'Survey Report', extractionStatus: 'ready_for_review'),
          _doc(id: 'd3', title: 'Old Invoice Scan', extractionStatus: 'failed'),
          _doc(id: 'd4', title: 'Already Done', extractionStatus: 'completed'),
        ],
        invoices: [
          _invoice(id: 'i1', name: 'Supplier Invoice #9', extractionStatus: 'failed'),
        ],
      );

      // Summary strip.
      expect(find.text('1 Processing'), findsOneWidget);
      expect(find.text('1 Ready to review'), findsOneWidget);
      expect(find.text('2 Failed'), findsOneWidget);

      // Every eligible item is listed.
      expect(find.text('Class Certificate'), findsOneWidget);
      expect(find.text('Survey Report'), findsOneWidget);
      expect(find.text('Old Invoice Scan'), findsOneWidget);
      expect(find.text('Already Done'), findsOneWidget);
      expect(find.text('Supplier Invoice #9'), findsOneWidget);

      // Retry action only offered for failed items.
      expect(find.widgetWithIcon(IconButton, Icons.refresh), findsNWidgets(2));
    });

    testWidgets('a doc with no extraction_status (never queued) is excluded',
        (tester) async {
      await _pump(tester, docs: [
        _doc(id: 'd1', title: 'Requested, not yet received'),
        _doc(id: 'd2', title: 'Actively Processing', extractionStatus: 'processing'),
      ]);

      expect(find.text('Requested, not yet received'), findsNothing);
      expect(find.text('Actively Processing'), findsOneWidget);
    });
  });
}
