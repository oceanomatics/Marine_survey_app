import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marine_survey_app/features/cases/models/case_model.dart';
import 'package:marine_survey_app/features/cases/providers/cases_provider.dart';
import 'package:marine_survey_app/features/photos/models/photo_model.dart';
import 'package:marine_survey_app/features/photos/providers/photo_provider.dart';
import 'package:marine_survey_app/features/reports/providers/report_provider.dart';
import 'package:marine_survey_app/features/reports/screens/report_builder_screen.dart';
import 'package:marine_survey_app/features/reports/widgets/new_output_sheet.dart';

import '../../../support/fakes/fake_case_notifier.dart';
import '../../../support/fakes/fake_photo_notifier.dart';
import '../../../support/fakes/fake_report_outputs_notifier.dart';
import '../../../support/fakes/fake_section_draft_notifier.dart';
import '../../../support/fixtures/report_fixtures.dart';

const _caseId = 'case-1';

Future<void> _pump(
  WidgetTester tester, {
  required List<ReportOutput> outputs,
  Map<SectionType, ReportSection>? sections,
  CaseModel? caseModel,
  List<PhotoModel> photos = const [],
}) async {
  final seedSections = sections ?? fixtureAllSections();
  // The Editor tab is a ListView.builder with ~25 sections plus the cover
  // photo picker and Advice Summary card — at the default test surface size
  // most of them sit below the fold and are never built (ListView.builder
  // only builds what's within the viewport + cache extent). Widen the
  // surface so everything is built without needing to scroll.
  await tester.binding.setSurfaceSize(const Size(1000, 6000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // ReportBuilderScreen uses BackAppBar (Cluster A, 9 July 2026), which
  // calls GoRouterState.of(context)/context.canPop() during build — a bare
  // MaterialApp(home: ...) has no GoRouter ancestor and throws. Wrap in a
  // single-route GoRouter + MaterialApp.router instead (see also
  // test/support/pump_with_router.dart, used by other screen tests; this
  // one is inlined because it also needs setSurfaceSize before pumping).
  final router = GoRouter(
    initialLocation: '/test',
    routes: [GoRoute(path: '/test', builder: (_, __) => const ReportBuilderScreen(caseId: _caseId))],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reportOutputsProvider
            .overrideWith(() => FakeReportOutputsNotifier(outputs)),
        assembledDataProvider.overrideWith((ref, caseId) async => fixtureAssembledData()),
        caseProvider.overrideWith(() => FakeCaseNotifier(caseModel ?? fixtureCase())),
        photosProvider.overrideWith(() => FakePhotoNotifier(photos)),
        sectionDraftProvider.overrideWith(
          (ref, key) => FakeSectionDraftNotifier(key.caseId, key.outputId, seedSections),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('NewOutputSheet (standalone)', () {
    testWidgets('creates an output with the type/number entered', (tester) async {
      OutputType? capturedType;
      String? capturedNumber;
      int? capturedSequence;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NewOutputSheet(
            caseId: _caseId,
            technicalFileNo: 'AU-M53-056789',
            existingCount: 0,
            onCreate: (type, number, seq) async {
              capturedType = type;
              capturedNumber = number;
              capturedSequence = seq;
            },
          ),
        ),
      ));

      // Report number is pre-filled from the technical file no.
      expect(find.text('AU-M53-056789-R001'), findsOneWidget);

      await tester.tap(find.text('Create Preliminary Report'));
      await tester.pumpAndSettle();

      expect(capturedType, OutputType.preliminary);
      expect(capturedNumber, 'AU-M53-056789-R001');
      expect(capturedSequence, 1);
    });

    testWidgets('selecting Advice reveals the advice-number picker', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NewOutputSheet(
            caseId: _caseId,
            technicalFileNo: 'AU-M53-056789',
            existingCount: 0,
            onCreate: (_, __, ___) async {},
          ),
        ),
      ));

      expect(find.text('Advice Number:'), findsNothing);

      await tester.tap(find.text('Advice'));
      await tester.pumpAndSettle();

      expect(find.text('Advice Number:'), findsOneWidget);
    });
  });

  group('ReportBuilderScreen', () {
    testWidgets('with no outputs, shows "No reports yet" and a create button', (tester) async {
      await _pump(tester, outputs: const []);

      expect(find.text('No reports yet'), findsOneWidget);
      expect(find.text('Create first report'), findsOneWidget);
    });

    testWidgets('with multiple outputs and none selected, lists them for selection', (tester) async {
      await _pump(tester, outputs: [
        fixtureOutput(outputId: 'o1', outputType: OutputType.preliminary),
        fixtureOutput(outputId: 'o2', outputType: OutputType.final_, sequenceNo: 1),
      ]);

      expect(find.text('Select a report to edit'), findsOneWidget);
      expect(find.text('Preliminary Report'), findsOneWidget);
      expect(find.text('Final Report'), findsOneWidget);
    });

    testWidgets('selecting an output opens the Editor tab with all sections', (tester) async {
      await _pump(tester, outputs: [fixtureOutput(outputId: 'o1')]);

      await tester.tap(find.text('Preliminary Report'));
      await tester.pumpAndSettle();

      // Editor tab is active by default; a numbered section (Opening, §1)
      // and the Advice Summary card should both be present.
      expect(find.text('1.  opening'), findsOneWidget);
      expect(find.text('Advice Summary  ·  Page 2'), findsOneWidget);
    });

    testWidgets('cover photo picker shows "No cover photo" when none is set', (tester) async {
      await _pump(tester, outputs: [fixtureOutput(outputId: 'o1')]);
      await tester.tap(find.text('Preliminary Report'));
      await tester.pumpAndSettle();

      expect(find.text('No cover photo'), findsOneWidget);
    });

    testWidgets('editing a section\'s content and setting ACCEPTED updates the approved-count badge',
        (tester) async {
      await _pump(tester, outputs: [fixtureOutput(outputId: 'o1')], sections: {
        ...fixtureAllSections(),
        SectionType.opening: fixtureSection(SectionType.opening, approved: false),
      });
      await tester.tap(find.text('Preliminary Report'));
      await tester.pumpAndSettle();

      final total = fixtureAllSections().length;
      // One section (opening) starts unapproved.
      expect(find.text('${total - 1}/$total'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'Enter opening...'), 'Updated opening text.');
      await tester.tap(find.text('ACCEPTED').first);
      await tester.pumpAndSettle();

      expect(find.text('$total/$total'), findsOneWidget);
    });

    testWidgets('Preview tab renders the full document', (tester) async {
      await _pump(tester, outputs: [fixtureOutput(outputId: 'o1')]);
      await tester.tap(find.text('Preliminary Report'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();

      expect(find.text('TABLE OF CONTENTS'), findsOneWidget);
    });

    testWidgets('Postprocessing tab: status stepper advances through the workflow', (tester) async {
      await _pump(tester, outputs: [fixtureOutput(outputId: 'o1', status: ReportStatus.draft)]);
      await tester.tap(find.text('Preliminary Report'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Postprocessing'));
      await tester.pumpAndSettle();

      expect(find.text('Draft'), findsOneWidget);
      await tester.tap(find.text('Mark Self-Reviewed'));
      await tester.pumpAndSettle();

      expect(find.text('Self Reviewed'), findsOneWidget);
      expect(find.text('Submit for QC'), findsOneWidget);
    });

    testWidgets('Changes summary field only appears when the output supersedes a prior version',
        (tester) async {
      await _pump(tester, outputs: [fixtureOutput(outputId: 'o1', supersedesVersion: null)]);
      await tester.tap(find.text('Preliminary Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Postprocessing'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Changes from'), findsNothing);
    });

    testWidgets('Changes summary field appears when the output does supersede a prior version',
        (tester) async {
      await _pump(tester,
          outputs: [fixtureOutput(outputId: 'o1', supersedesVersion: 'R001')]);
      await tester.tap(find.text('Preliminary Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Postprocessing'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Changes from R001'), findsOneWidget);
    });

    testWidgets('Final report: per-role sign-off status reflects the case sign-off flags',
        (tester) async {
      await _pump(
        tester,
        outputs: [fixtureOutput(outputId: 'o1', outputType: OutputType.final_)],
        caseModel: fixtureCase(signedOffAttending: true, signedOffReviewing: false),
      );
      await tester.tap(find.text('Final Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Postprocessing'));
      await tester.pumpAndSettle();

      expect(find.text('Sign-off required (1/2)'), findsOneWidget);

      // Fully signed off — no "Sign Off" action shown and the label flips.
    });

    testWidgets('Final report: fully signed off shows the signed confirmation', (tester) async {
      await _pump(
        tester,
        outputs: [fixtureOutput(outputId: 'o1', outputType: OutputType.final_)],
        caseModel: fixtureCase(signedOffAttending: true, signedOffReviewing: true),
      );
      await tester.tap(find.text('Final Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Postprocessing'));
      await tester.pumpAndSettle();

      expect(find.text('Signed off (2/2)'), findsOneWidget);
      expect(find.text('Sign Off'), findsNothing);
    });

    testWidgets(
        'Export: pre-export validation sheet lists warnings for an incomplete report, '
        'and Cancel aborts without attempting export', (tester) async {
      // Leave every section unapproved and empty so buildExportWarnings()
      // (already unit-tested separately) has plenty to flag.
      final incompleteSections = {
        for (final t in oceanoSectionOrder)
          if (t != SectionType.executiveSummary)
            t: fixtureSection(t, content: '', approved: false),
      };
      await _pump(tester, outputs: [fixtureOutput(outputId: 'o1')], sections: incompleteSections);
      await tester.tap(find.text('Preliminary Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Postprocessing'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export .docx'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Pre-export check'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Export anyway'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Pre-export check'), findsNothing);
      // Back to idle — export was never attempted.
      expect(find.text('Export .docx'), findsOneWidget);
    });
  });
}
