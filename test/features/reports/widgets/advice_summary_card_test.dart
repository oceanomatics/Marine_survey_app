// Locks the 21 July 2026 tabular Advice Summary rework:
//  * every field renders as a row even when the case value is missing (the
//    Astrolabe case: Assured / Instructing Party used to vanish), and
//  * the case-level identity fields are editable inline from the editor,
//    persisting via caseProvider.updateCaseRefs.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marine_survey_app/features/cases/models/case_model.dart';
import 'package:marine_survey_app/features/cases/providers/cases_provider.dart';
import 'package:marine_survey_app/features/photos/providers/photo_provider.dart';
import 'package:marine_survey_app/features/reports/providers/report_provider.dart';
import 'package:marine_survey_app/features/reports/screens/report_builder_screen.dart';

import '../../../support/fakes/fake_photo_notifier.dart';
import '../../../support/fakes/fake_report_outputs_notifier.dart';
import '../../../support/fakes/fake_section_draft_notifier.dart';
import '../../../support/fixtures/report_fixtures.dart';

const _caseId = 'case-1';

/// Records updateCaseRefs calls instead of hitting Supabase.
class _RecordingCaseNotifier extends CaseNotifier {
  _RecordingCaseNotifier(this._model);
  final CaseModel _model;
  final Map<String, dynamic> recorded = {};

  @override
  Future<CaseModel> build(String caseId) async => _model;

  @override
  Future<void> updateCaseRefs({
    String? technicalFileNo,
    String? claimReference,
    CaseStatus? status,
    CaseType? caseType,
    DateTime? instructionDate,
    OutputFormat? outputFormat,
    String? organisationId,
    String? baseCurrency,
    String? instructingParty,
    String? assured,
    String? costEstimateStatus,
    double? estimatedRepairCost,
    bool? costIncludesGeneralExpenses,
    String? costIncludesTowing,
    double? surveyFeeReserveHours,
    double? surveyFeeReserveExpenses,
    String? costEstimateComment,
    bool? followUpRequired,
    String? followUpDetail,
  }) async {
    if (technicalFileNo != null) recorded['technical_file_no'] = technicalFileNo;
    if (claimReference != null) recorded['claim_reference'] = claimReference;
    if (assured != null) recorded['assured'] = assured;
    if (instructingParty != null) recorded['instructing_party'] = instructingParty;
  }
}

// ignore: prefer_const_constructors
AssembledReportData _assembledMissingParties() => AssembledReportData(
      caseData: const {'technical_file_no': 'SI-M53-055873'},
      // Assured + Instructing Party absent — the reported Astrolabe case.
      vessel: const {'name': 'ASTROLABE'},
      occurrences: const [],
      damageItems: const [],
      attendees: const [],
      attendances: const [],
      certificates: const [],
      repairPeriods: const [],
      clauses: const [],
      outputFormat: 'oceano_services',
      repairDocuments: const [],
      timelineEvents: const [],
      surveyorNotes: const [],
      machinery: const [],
      classConditions: const [],
      detentions: const [],
      caseDocuments: const [],
      requestedDocuments: const [],
      photos: const [],
      aiGenerationLog: const [],
      allReportOutputs: const [],
    );

Future<_RecordingCaseNotifier> _pump(WidgetTester tester) async {
  final caseFake = _RecordingCaseNotifier(fixtureCase());
  await tester.binding.setSurfaceSize(const Size(1000, 6000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(initialLocation: '/test', routes: [
    GoRoute(path: '/test', builder: (_, __) => const ReportBuilderScreen(caseId: _caseId)),
  ]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reportOutputsProvider
            .overrideWith(() => FakeReportOutputsNotifier([fixtureOutput(outputId: 'o1')])),
        assembledDataProvider
            .overrideWith((ref, caseId) async => _assembledMissingParties()),
        caseProvider.overrideWith(() => caseFake),
        photosProvider.overrideWith(() => FakePhotoNotifier(const [])),
        sectionDraftProvider.overrideWith((ref, key) =>
            FakeSectionDraftNotifier(ref, key.caseId, key.outputId, fixtureAllSections())),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Preliminary Report'));
  await tester.pumpAndSettle();
  return caseFake;
}

void main() {
  testWidgets('Advice Summary shows Assured / Instructing Party rows even when missing',
      (tester) async {
    await _pump(tester);
    // Rows are present despite the case having no value for them.
    expect(find.text('Assured'), findsOneWidget);
    expect(find.text('Instructing Party'), findsOneWidget);
    // And they are editable fields, not hidden.
    expect(find.byKey(const ValueKey('advice-edit-assured')), findsOneWidget);
    expect(find.byKey(const ValueKey('advice-edit-instructing_party')), findsOneWidget);
  });

  testWidgets('editing Assured inline persists via updateCaseRefs', (tester) async {
    final caseFake = await _pump(tester);

    await tester.enterText(
        find.byKey(const ValueKey('advice-edit-assured')), 'Astro Marine Ltd');
    // Debounced save (800ms) then flush.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(caseFake.recorded['assured'], 'Astro Marine Ltd');
  });
}
