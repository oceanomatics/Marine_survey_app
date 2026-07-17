// §2.18: proves the auto-populated-section pattern on two representative
// types — vesselParticulars (table-mode, Slice 1) and occurrence
// (prose-mode, Slice 2) — the same two branches drive every type in
// autoPopulatedSectionTypes, so this is enough to cover the mechanism (see
// docs/TODO.md §2.18 for the full section-by-section list).
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
  VoidCallback? onDraftWithAi,
  bool settle = true,
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
            onDraftWithAi: onDraftWithAi,
          ),
        ),
      ),
      GoRoute(
        path: '/cases/:caseId/vessel',
        builder: (context, state) =>
            Scaffold(body: Text('Vessel screen for ${state.pathParameters['caseId']}')),
      ),
      GoRoute(
        path: '/cases/:caseId/occurrence',
        builder: (context, state) => Scaffold(
            body: Text('Occurrence screen for ${state.pathParameters['caseId']}')),
      ),
      GoRoute(
        path: '/cases/:caseId/damage',
        builder: (context, state) => Scaffold(
            body: Text('Damage screen for ${state.pathParameters['caseId']}')),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  // pumpAndSettle never returns while a persistent animation (the drafting
  // spinner) is on screen — one bounded pump is enough for the router/tree
  // to build.
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
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
      detentions: [],
      caseDocuments: [],
      requestedDocuments: [],
      photos: [],
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

  group('SectionEditor — damageDescription (§2.18 Slice 3, table-mode)', () {
    const damageAssembled = AssembledReportData(
      caseData: {},
      vessel: null,
      occurrences: [],
      damageItems: [
        {
          'component_name': 'Generator 3',
          'damage_description': 'Cracked block, ejected rods.',
          'condition_status': 'damaged',
          'average_status': 'yes',
        },
      ],
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
      detentions: [],
      caseDocuments: [],
      requestedDocuments: [],
      photos: [],
      aiGenerationLog: [],
      allReportOutputs: [],
    );

    testWidgets(
        'shows the Damage Schedule table, not a free-text box, and no '
        'duplicate reference panel', (tester) async {
      const section = ReportSection(
        type: SectionType.damageDescription,
        title: 'Extent of Damage',
        content: 'Stale disconnected free text, never actually exported.',
      );
      await _pump(tester, section: section, assembled: damageAssembled);

      expect(find.byType(TextField), findsOneWidget); // Remarks only
      expect(find.text('Generator 3'), findsOneWidget);
      expect(find.text('Cracked block, ejected rods.'), findsOneWidget);
      expect(
          find.text(
              'Stale disconnected free text, never actually exported.'),
          findsNothing);
      // Table-mode types show the reference panel as primary content —
      // exactly once, not repeated again as supplementary context below it.
      expect(find.text('Damage schedule on file'), findsOneWidget);
    });

    testWidgets('Edit button deep-links to the Damage Register screen',
        (tester) async {
      const section = ReportSection(
        type: SectionType.damageDescription,
        title: 'Extent of Damage',
        content: '',
      );
      await _pump(tester, section: section, assembled: damageAssembled);

      await tester.tap(find.text('Edit in Damage Register →'));
      await tester.pumpAndSettle();

      expect(find.text('Damage screen for $_caseId'), findsOneWidget);
    });
  });

  group('SectionEditor — prose-mode auto-populated sections (§2.18 Slice 2)',
      () {
    const occurrenceAssembled = AssembledReportData(
      caseData: {},
      vessel: null,
      occurrences: [
        {
          'brief_description': 'Engine room fire during passage.',
          'vessel_status_at_casualty': 'at_sea',
          'aftermath_status': 'own_power',
        },
      ],
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
      detentions: [],
      caseDocuments: [],
      requestedDocuments: [],
      photos: [],
      aiGenerationLog: [],
      allReportOutputs: [],
    );

    testWidgets(
        'shows the full computed text read-only, not a free-text box',
        (tester) async {
      const section = ReportSection(
        type: SectionType.occurrence,
        title: 'Occurrence',
        content: 'Engine room fire during passage.',
      );
      await _pump(tester, section: section, assembled: occurrenceAssembled);

      // Remarks TextField is the only TextField — content itself is
      // read-only. The text appears twice: the primary read-only content
      // block, and the supplementary reference panel's own occurrence row
      // (same underlying brief_description) — both expected, see the next
      // test for the reference-panel assertion specifically.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Engine room fire during passage.'), findsWidgets);
    });

    testWidgets(
        'keeps the supplementary reference panel (unlike table-mode types)',
        (tester) async {
      const section = ReportSection(
        type: SectionType.occurrence,
        title: 'Occurrence',
        content: 'Engine room fire during passage.',
      );
      await _pump(tester, section: section, assembled: occurrenceAssembled);

      // section_reference_panel.dart's occurrence case surfaces the raw
      // brief_description as a labelled reference row too — proves the
      // panel is still rendered as supplementary context, not suppressed.
      expect(find.text('Occurrence data on file'), findsOneWidget);
    });

    testWidgets('Edit button deep-links to the Occurrence screen',
        (tester) async {
      const section = ReportSection(
        type: SectionType.occurrence,
        title: 'Occurrence',
        content: 'Engine room fire during passage.',
      );
      await _pump(tester, section: section, assembled: occurrenceAssembled);

      await tester.tap(find.text('Edit in Occurrence →'));
      await tester.pumpAndSettle();

      expect(find.text('Occurrence screen for $_caseId'), findsOneWidget);
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

    test('table-mode is exactly the 7 confirmed-dead-weight-content types',
        () {
      expect(
        autoPopulatedTableModeTypes,
        {
          SectionType.vesselParticulars,
          SectionType.attendees,
          SectionType.machineryParticulars,
          SectionType.accounts,
          SectionType.repairTimes,
          SectionType.documentsOnFile,
          SectionType.damageDescription,
        },
      );
    });

    test(
        'prose-mode adds exactly the 3 verified-safe live-prose types '
        '(occurrence/natureOfRepairs/documentsRequested — no table exists '
        'for these, unlike damageDescription which moved to table-mode)',
        () {
      expect(
        autoPopulatedSectionTypes.difference(autoPopulatedTableModeTypes),
        {
          SectionType.occurrence,
          SectionType.natureOfRepairs,
          SectionType.documentsRequested,
        },
      );
    });

    test('table-mode is a subset of the full auto-populated set', () {
      expect(
          autoPopulatedTableModeTypes.every(autoPopulatedSectionTypes.contains),
          isTrue);
    });
  });

  group('SectionEditor — "Draft with AI" drafting state (§13/§17/§23)', () {
    testWidgets('idle: button is enabled and shows the normal label',
        (tester) async {
      var tapped = false;
      const section = ReportSection(
        type: SectionType.background,
        title: 'Background',
        content: '',
      );
      await _pump(tester, section: section, onDraftWithAi: () => tapped = true);

      expect(find.text('Draft with AI'), findsOneWidget);
      expect(find.text('Drafting…'), findsNothing);

      await tester.tap(find.text('Draft with AI'));
      expect(tapped, isTrue);
    });

    testWidgets(
        'drafting: button is disabled, shows a spinner and "Drafting…", '
        'and does not fire onDraftWithAi when tapped', (tester) async {
      var tapped = false;
      const section = ReportSection(
        type: SectionType.background,
        title: 'Background',
        content: '',
        drafting: true,
      );
      await _pump(tester,
          section: section, onDraftWithAi: () => tapped = true, settle: false);

      expect(find.text('Drafting…'), findsOneWidget);
      expect(find.text('Draft with AI'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Drafting…'));
      expect(tapped, isFalse);
    });
  });
}
