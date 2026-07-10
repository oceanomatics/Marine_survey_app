// §2.18: proves the auto-populated-section pattern on one representative
// type (vesselParticulars) — the same branch drives all 6 types in
// autoPopulatedSectionTypes, so one widget test is enough to cover the
// mechanism (see docs/TODO.md §2.18 for the full section-by-section list).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marine_survey_app/features/reports/providers/report_provider.dart';
import 'package:marine_survey_app/features/reports/widgets/section_editor.dart';

const _caseId = 'case-1';

Future<void> _pump(
  WidgetTester tester, {
  required ReportSection section,
  AssembledReportData? assembled,
  ValueChanged<String>? onRemarksChanged,
}) async {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(
        path: '/test',
        builder: (context, state) => Scaffold(
          body: SectionEditor(
            section: section,
            isLocked: false,
            caseId: _caseId,
            assembled: assembled,
            onContentChanged: (_) {},
            onRemarksChanged: onRemarksChanged ?? (_) {},
            onSurveyorReviewChanged: (_) {},
          ),
        ),
      ),
      GoRoute(
        path: '/cases/:caseId/vessel',
        builder: (context, state) =>
            Scaffold(body: Text('Vessel screen for ${state.pathParameters['caseId']}')),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  group('SectionEditor — auto-populated sections (§2.18)', () {
    const vesselAssembled = AssembledReportData(
      caseData: {},
      vessel: {'name': 'MV Test Vessel', 'imo_number': '1234567'},
      occurrences: [],
      damageItems: [],
      attendees: [],
      attendances: [],
      certificates: [],
      repairPeriods: [],
      clauses: [],
      outputFormat: 'oceano_services',
      repairDocuments: [],
      timelineEvents: [],
      surveyorNotes: [],
      machinery: [],
      classConditions: [],
      caseDocuments: [],
      requestedDocuments: [],
      aiGenerationLog: [],
      allReportOutputs: [],
    );

    testWidgets('shows the read-only reference table, not a free-text box',
        (tester) async {
      const section = ReportSection(
        type: SectionType.vesselParticulars,
        title: 'Vessel Particulars',
        content: 'Some stale auto-generated prose that is never rendered.',
      );
      await _pump(tester, section: section, assembled: vesselAssembled);

      expect(find.byType(TextField), findsOneWidget); // Remarks only
      expect(find.text('MV Test Vessel'), findsOneWidget);
      expect(
          find.text(
              'Some stale auto-generated prose that is never rendered.'),
          findsNothing);
    });

    testWidgets('Edit button deep-links to the case screen', (tester) async {
      const section = ReportSection(
        type: SectionType.vesselParticulars,
        title: 'Vessel Particulars',
        content: '',
      );
      await _pump(tester, section: section, assembled: vesselAssembled);

      await tester.tap(find.text('Edit in Vessel Particulars →'));
      await tester.pumpAndSettle();

      expect(find.text('Vessel screen for $_caseId'), findsOneWidget);
    });

    testWidgets('Remarks field renders and calls onRemarksChanged',
        (tester) async {
      String? captured;
      const section = ReportSection(
        type: SectionType.vesselParticulars,
        title: 'Vessel Particulars',
        content: '',
        remarks: 'Existing remark',
      );
      await _pump(
        tester,
        section: section,
        assembled: vesselAssembled,
        onRemarksChanged: (v) => captured = v,
      );

      expect(find.text('Existing remark'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'New remark');
      expect(captured, 'New remark');
    });

    testWidgets(
        'narrative sections (unaffected) still show the free-text box',
        (tester) async {
      const section = ReportSection(
        type: SectionType.background,
        title: 'Background',
        content: 'Free narrative text.',
      );
      await _pump(tester, section: section, assembled: vesselAssembled);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Edit in Vessel Particulars →'), findsNothing);
    });
  });

  group('autoPopulatedSectionTypes / autoPopulatedEditRoute', () {
    test('every auto-populated type has a route entry', () {
      for (final type in autoPopulatedSectionTypes) {
        expect(autoPopulatedEditRoute.containsKey(type), isTrue,
            reason: '$type is in autoPopulatedSectionTypes but has no '
                'autoPopulatedEditRoute entry');
      }
    });

    test('route map has no entries outside the auto-populated set', () {
      for (final type in autoPopulatedEditRoute.keys) {
        expect(autoPopulatedSectionTypes.contains(type), isTrue);
      }
    });

    test('exactly the 6 confirmed-dead-weight-content types are included',
        () {
      expect(
        autoPopulatedSectionTypes,
        {
          SectionType.vesselParticulars,
          SectionType.attendees,
          SectionType.machineryParticulars,
          SectionType.accounts,
          SectionType.repairTimes,
          SectionType.documentsOnFile,
        },
      );
    });
  });
}
