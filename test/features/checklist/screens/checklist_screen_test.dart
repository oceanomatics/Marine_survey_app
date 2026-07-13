import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/accounts/providers/accounts_provider.dart';
import 'package:marine_survey_app/features/attendances/providers/attendances_provider.dart';
import 'package:marine_survey_app/features/cases/models/case_model.dart';
import 'package:marine_survey_app/features/cases/providers/cases_provider.dart';
import 'package:marine_survey_app/features/background/providers/background_provider.dart';
import 'package:marine_survey_app/features/checklist/providers/checklist_provider.dart';
import 'package:marine_survey_app/features/checklist/screens/checklist_screen.dart';
import 'package:marine_survey_app/features/documents/providers/document_provider.dart';
import 'package:marine_survey_app/features/reports/providers/report_provider.dart';
import 'package:marine_survey_app/features/survey/providers/damage_provider.dart';
import 'package:marine_survey_app/features/survey/providers/repair_period_provider.dart';
import 'package:marine_survey_app/features/vessel/providers/certificates_provider.dart';
import 'package:marine_survey_app/features/vessel/providers/vessel_provider.dart';

import '../../../support/fakes/fake_attendances_notifier.dart';
import '../../../support/fakes/fake_background_notifier.dart';
import '../../../support/fakes/fake_case_notifier.dart';
import '../../../support/fakes/fake_certificates_notifier.dart';
import '../../../support/fakes/fake_checklist_notifier.dart';
import '../../../support/fakes/fake_damage_notifier.dart';
import '../../../support/fakes/fake_document_notifier.dart';
import '../../../support/fakes/fake_repair_documents_notifier.dart';
import '../../../support/fakes/fake_repair_periods_notifier.dart';
import '../../../support/fakes/fake_report_outputs_notifier.dart';
import '../../../support/fakes/fake_vessel_for_case_notifier.dart';
import '../../../support/fixtures/report_fixtures.dart';
import '../../../support/fixtures/survey_fixtures.dart';
import '../../../support/pump_with_router.dart';

const _caseId = 'case-1';

ChecklistItem _item({
  required String id,
  required ChecklistStage stage,
  required int itemNo,
  required String text,
  ChecklistResponse? response,
  bool isCustom = false,
  String? linkedSection,
  bool autoTickAttempted = false,
}) =>
    ChecklistItem(
      checklistId: id,
      caseId: _caseId,
      stage: stage,
      itemNo: itemNo,
      itemText: text,
      response: response,
      isCustom: isCustom,
      linkedSection: linkedSection,
      autoTickAttempted: autoTickAttempted,
    );

Future<void> _pump(
  WidgetTester tester,
  List<ChecklistItem> seed, {
  VesselModel? vessel,
}) async {
  final container = ProviderContainer(overrides: [
    checklistProvider.overrideWith(() => FakeChecklistNotifier(seed)),
    // §4.4: ChecklistScreen now also watches the same case-data providers
    // Case Home's completeness card does, to drive auto-tick — none of
    // these are exercised by most of these tests, so seed them empty/off
    // rather than letting them fall through to the real Supabase-backed
    // provider. [vessel] is the one exception a dedicated test overrides.
    caseProvider.overrideWith(() => FakeCaseNotifier(fixtureCase(caseId: _caseId))),
    damageProvider.overrideWith(() => FakeDamageNotifier(fixtureDamageState())),
    attendancesProvider.overrideWith(() => FakeAttendancesNotifier()),
    repairPeriodsProvider.overrideWith(() => FakeRepairPeriodsNotifier(const [])),
    repairDocumentsProvider
        .overrideWith(() => FakeRepairDocumentsNotifier(const [])),
    certificatesProvider.overrideWith(() => FakeCertificatesNotifier(const [])),
    reportOutputsProvider.overrideWith(() => FakeReportOutputsNotifier(const [])),
    vesselForCaseProvider.overrideWith(() => FakeVesselForCaseNotifier(vessel)),
    documentProvider.overrideWith(() => FakeDocumentNotifier(const [])),
    backgroundProvider.overrideWith(() => FakeBackgroundNotifier()),
  ]);
  addTearDown(container.dispose);
  await pumpWithRouter(
    tester,
    container: container,
    child: const ChecklistScreen(caseId: _caseId),
  );
}

void main() {
  group('ChecklistScreen', () {
    testWidgets('loads with all 4 stage tabs visible', (tester) async {
      await _pump(tester, [
        _item(id: '1', stage: ChecklistStage.preSurvey, itemNo: 1, text: 'Check tide tables'),
      ]);

      // TabBar renders each label twice internally (a hidden pass used to
      // size the indicator), so assert presence rather than an exact count.
      expect(find.text('Pre-Survey'), findsWidgets);
      expect(find.text('On Vessel'), findsWidgets);
      expect(find.text('Before Leaving'), findsWidgets);
      expect(find.text('Post-Survey'), findsWidgets);
    });

    testWidgets('progress header reflects the answered-yes/total item count', (tester) async {
      await _pump(tester, [
        _item(id: '1', stage: ChecklistStage.preSurvey, itemNo: 1, text: 'Item A', response: ChecklistResponse.yes),
        _item(id: '2', stage: ChecklistStage.preSurvey, itemNo: 2, text: 'Item B'),
      ]);

      expect(find.text('1 of 2 complete'), findsOneWidget);
    });

    testWidgets('per-stage tab shows its own done/total count', (tester) async {
      await _pump(tester, [
        _item(id: '1', stage: ChecklistStage.preSurvey, itemNo: 1, text: 'Item A', response: ChecklistResponse.yes),
        _item(id: '2', stage: ChecklistStage.preSurvey, itemNo: 2, text: 'Item B'),
        _item(id: '3', stage: ChecklistStage.onVessel, itemNo: 1, text: 'Item C'),
      ]);

      expect(find.text('1/2'), findsOneWidget); // Pre-Survey tab
      expect(find.text('0/1'), findsOneWidget); // On Vessel tab
    });

    testWidgets('tapping Yes on an item marks it complete', (tester) async {
      await _pump(tester, [
        _item(id: '1', stage: ChecklistStage.preSurvey, itemNo: 1, text: 'Check tide tables'),
      ]);

      expect(find.text('0 of 1 complete'), findsOneWidget);

      await tester.tap(find.byKey(const Key('response-yes-1')));
      await tester.pumpAndSettle();

      expect(find.text('1 of 1 complete'), findsOneWidget);
    });

    testWidgets('tapping No on a completed item makes it outstanding again', (tester) async {
      await _pump(tester, [
        _item(id: '1', stage: ChecklistStage.preSurvey, itemNo: 1, text: 'Check tide tables', response: ChecklistResponse.yes),
      ]);

      expect(find.text('1 of 1 complete'), findsOneWidget);

      await tester.tap(find.byKey(const Key('response-no-1')));
      await tester.pumpAndSettle();

      expect(find.text('0 of 1 complete'), findsOneWidget);
    });

    testWidgets('tapping N/A on an item excludes it from the total entirely', (tester) async {
      await _pump(tester, [
        _item(id: '1', stage: ChecklistStage.preSurvey, itemNo: 1, text: 'Telegraph data logger'),
        _item(id: '2', stage: ChecklistStage.preSurvey, itemNo: 2, text: 'Crew list'),
      ]);

      expect(find.text('0 of 2 complete'), findsOneWidget);

      await tester.tap(find.byKey(const Key('response-na-1')));
      await tester.pumpAndSettle();

      // Item 1 is now N/A and no longer counts toward the denominator.
      expect(find.text('0 of 1 complete'), findsOneWidget);
    });

    testWidgets('empty stage shows the "no items" placeholder', (tester) async {
      await _pump(tester, [
        _item(id: '1', stage: ChecklistStage.preSurvey, itemNo: 1, text: 'Only pre-survey item'),
      ]);

      await tester.tap(find.text('On Vessel'));
      await tester.pumpAndSettle();

      expect(find.text('No items for On Vessel'), findsOneWidget);
    });

    testWidgets('FAB opens the add-custom-item sheet, and submitting adds it to the list',
        (tester) async {
      await _pump(tester, [
        _item(id: '1', stage: ChecklistStage.preSurvey, itemNo: 1, text: 'Check tide tables'),
      ]);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Add custom item'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Confirm crew list with Master');
      await tester.tap(find.text('Add to Checklist'));
      await tester.pumpAndSettle();

      // Sheet closes and the new item shows up in the Pre-Survey list.
      expect(find.text('Add custom item'), findsNothing);
      expect(find.text('Confirm crew list with Master'), findsOneWidget);
      expect(find.text('0 of 2 complete'), findsOneWidget);
    });

    // §4.4 (13 July 2026): checklist auto-ticking.
    testWidgets(
        'an item linked to a completeness section auto-ticks once that '
        "section's data condition is met, and shows the auto badge",
        (tester) async {
      await _pump(
        tester,
        [
          _item(
            id: '1',
            stage: ChecklistStage.preSurvey,
            itemNo: 1,
            text: 'Confirm vessel identity',
            linkedSection: 'vessel_particulars',
          ),
        ],
        vessel: const VesselModel(vesselId: 'v1', name: 'MV Test Vessel'),
      );

      expect(find.text('auto'), findsOneWidget);
      expect(find.text('1 of 1 complete'), findsOneWidget);
    });

    testWidgets(
        'an item with no linkedSection never auto-ticks, even with '
        'matching case data available', (tester) async {
      await _pump(
        tester,
        [
          _item(
            id: '1',
            stage: ChecklistStage.preSurvey,
            itemNo: 1,
            text: 'Attended site', // no clean data signal — stays manual
          ),
        ],
        vessel: const VesselModel(vesselId: 'v1', name: 'MV Test Vessel'),
      );

      expect(find.text('auto'), findsNothing);
      expect(find.text('0 of 1 complete'), findsOneWidget);
    });

    testWidgets(
        'a previously auto-ticked-then-manually-unticked item is not '
        're-ticked by the next pass (one-shot, not perpetually enforced)',
        (tester) async {
      await _pump(
        tester,
        [
          _item(
            id: '1',
            stage: ChecklistStage.preSurvey,
            itemNo: 1,
            text: 'Confirm vessel identity',
            linkedSection: 'vessel_particulars',
            autoTickAttempted: true, // already offered once, surveyor unticked it
          ),
        ],
        vessel: const VesselModel(vesselId: 'v1', name: 'MV Test Vessel'),
      );

      expect(find.text('auto'), findsNothing);
      expect(find.text('0 of 1 complete'), findsOneWidget);
    });
  });
}
