// test/features/analyst/screens/insert_into_report_sheet_test.dart
//
// InsertIntoReportSheet is the Case Analyst's "put this reply into the
// report" flow (14 July 2026 walkthrough §21). Tested directly (not via the
// full CaseAnalystScreen) since that screen has no test double for its
// Supabase Edge Function chat call yet — this covers the sheet's own logic:
// output auto-select vs. picker, section filtering (locked/auto-populated
// excluded), markdown flattening, and the actual content write.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/analyst/screens/case_analyst_screen.dart';
import 'package:marine_survey_app/features/reports/providers/report_provider.dart';

import '../../../support/fakes/fake_report_outputs_notifier.dart';
import '../../../support/fakes/fake_section_draft_notifier.dart';
import '../../../support/fixtures/report_fixtures.dart';

const _caseId = 'case-1';

ReportSection _section(SectionType type, {String content = '', bool isLocked = false}) =>
    ReportSection(
      type: type,
      title: type.name,
      content: content,
      isLocked: isLocked,
    );

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required List<ReportOutput> outputs,
  Map<SectionType, ReportSection> seedSections = const {},
}) async {
  final container = ProviderContainer(overrides: [
    reportOutputsProvider.overrideWith(() => FakeReportOutputsNotifier(outputs)),
    sectionDraftProvider.overrideWith(
      (ref, key) => FakeSectionDraftNotifier(ref, key.caseId, key.outputId, seedSections),
    ),
    assembledDataProvider.overrideWith((ref, caseId) async => fixtureAssembledData()),
  ]);
  addTearDown(container.dispose);

  // Opened via showModalBottomSheet, not pumped directly as the route body —
  // the sheet calls Navigator.pop(context) on insert, which needs an actual
  // route to pop (matches how it's really invoked from _Bubble).
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => const InsertIntoReportSheet(
                  caseId: _caseId,
                  rawContent: '**Findings:** the shaft was worn.',
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return container;
}

ReportOutput _output(String id, {int sequenceNo = 1}) => ReportOutput(
      outputId: id,
      caseId: _caseId,
      outputType: OutputType.preliminary,
      status: ReportStatus.draft,
      sections: const [],
      sequenceNo: sequenceNo,
    );

void main() {
  testWidgets('single output: skips the output picker, shows sections directly',
      (tester) async {
    await _pump(tester, outputs: [
      _output('out-1'),
    ], seedSections: {
      SectionType.background: _section(SectionType.background),
    });

    expect(find.text('Preliminary Report'), findsNothing); // no picker shown
    expect(find.text('background'), findsOneWidget);
  });

  testWidgets('multiple outputs: shows the output picker first', (tester) async {
    await _pump(tester, outputs: [
      _output('out-1'),
      _output('out-2', sequenceNo: 2),
    ]);

    expect(find.text('Preliminary Report'), findsOneWidget);
    expect(find.text('Preliminary Report No.2'), findsOneWidget);
  });

  testWidgets('locked and auto-populated sections are excluded from the picker',
      (tester) async {
    await _pump(tester, outputs: [
      _output('out-1'),
    ], seedSections: {
      SectionType.background: _section(SectionType.background),
      SectionType.opening:
          _section(SectionType.opening, isLocked: true),
      SectionType.vesselParticulars:
          _section(SectionType.vesselParticulars),
    });

    expect(find.text('background'), findsOneWidget);
    expect(find.text('opening'), findsNothing);
    expect(find.text('vesselParticulars'), findsNothing);
  });

  testWidgets('tapping a section flattens markdown and inserts, marking aiDrafted',
      (tester) async {
    final container = await _pump(tester, outputs: [
      _output('out-1'),
    ], seedSections: {
      SectionType.background: _section(SectionType.background),
    });

    await tester.tap(find.text('background'));
    await tester.pumpAndSettle();

    final sections = container.read(
        sectionDraftProvider((caseId: _caseId, outputId: 'out-1')));
    expect(sections[SectionType.background]!.content, 'Findings: the shaft was worn.');
    expect(sections[SectionType.background]!.aiDrafted, isTrue);
    expect(find.text('Inserted into report — review it in Report Builder.'),
        findsOneWidget);
  });

  testWidgets('no report outputs: shows a create-one-first message', (tester) async {
    await _pump(tester, outputs: []);

    expect(
        find.textContaining('No report exists yet for this case'), findsOneWidget);
  });
}
