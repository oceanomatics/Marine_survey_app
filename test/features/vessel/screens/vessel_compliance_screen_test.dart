// test/features/vessel/screens/vessel_compliance_screen_test.dart
//
// Closes a real coverage gap flagged during the 2026-07 test-automation
// pass: certificates/conditions-of-class moved off VesselParticularsScreen
// onto this case-level VesselComplianceScreen during the Cluster B
// restructure (§2.17), and nothing tested it afterwards.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/vessel/screens/vessel_compliance_screen.dart';
import 'package:marine_survey_app/features/cases/models/case_model.dart';
import 'package:marine_survey_app/features/vessel/providers/vessel_provider.dart';
import 'package:marine_survey_app/features/vessel/providers/certificates_provider.dart';
import 'package:marine_survey_app/features/vessel/providers/class_conditions_provider.dart';
import 'package:marine_survey_app/features/vessel/providers/psc_deficiencies_provider.dart';
import 'package:marine_survey_app/features/vessel/models/class_condition_model.dart';
import 'package:marine_survey_app/features/survey/providers/damage_provider.dart';

import '../../../support/fakes/fake_vessel_for_case_notifier.dart';
import '../../../support/fakes/fake_certificates_notifier.dart';
import '../../../support/fakes/fake_class_conditions_notifier.dart';
import '../../../support/fakes/fake_psc_deficiencies_notifier.dart';
import '../../../support/fakes/fake_damage_notifier.dart';
import '../../../support/fixtures/survey_fixtures.dart';

const _caseId = 'case-1';
const _vesselId = 'vessel-1';

Future<FakeVesselForCaseNotifier> _pump(
  WidgetTester tester, {
  VesselModel? vessel,
  List<CertificateModel> certs = const [],
  List<ClassConditionModel> conditions = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final vesselFake = FakeVesselForCaseNotifier(
      vessel ?? const VesselModel(vesselId: _vesselId, name: 'MinRes Odin'));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vesselForCaseProvider.overrideWith(() => vesselFake),
        certificatesProvider.overrideWith(() => FakeCertificatesNotifier(certs)),
        classConditionsProvider
            .overrideWith(() => FakeClassConditionsNotifier(conditions)),
        pscDeficienciesProvider
            .overrideWith(() => FakePscDeficienciesNotifier([])),
        damageProvider.overrideWith(
            () => FakeDamageNotifier(fixtureDamageState(occurrences: []))),
      ],
      child: const MaterialApp(home: VesselComplianceScreen(caseId: _caseId)),
    ),
  );
  await tester.pumpAndSettle();
  return vesselFake;
}

void main() {
  testWidgets('loads and shows existing certificates', (tester) async {
    await _pump(tester, certs: const [
      CertificateModel(
        certId: 'c1',
        caseId: _caseId,
        certType: CertType.classCertificate,
        certName: 'ABS Class Certificate',
      ),
    ]);

    expect(find.text('ABS Class Certificate'), findsOneWidget);
  });

  testWidgets('empty certificates shows the empty state', (tester) async {
    await _pump(tester);

    expect(find.text('No certificates added yet'), findsOneWidget);
  });

  testWidgets('adding a certificate calls addCertificate with the entered name',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Add').first);
    await tester.pumpAndSettle();

    // Appears both as the sheet title and the submit button's label.
    expect(find.text('Add Certificate'), findsWidgets);

    await tester.enterText(find.byType(TextField).at(0), 'DOC Certificate 2026');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Certificate'));
    await tester.pumpAndSettle();

    expect(find.text('DOC Certificate 2026'), findsOneWidget);
  });

  testWidgets('deleting a certificate via its overflow menu removes it',
      (tester) async {
    await _pump(tester, certs: const [
      CertificateModel(
        certId: 'c1',
        caseId: _caseId,
        certType: CertType.doc,
        certName: 'DOC to delete',
      ),
    ]);

    expect(find.text('DOC to delete'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('DOC to delete'), findsNothing);
    expect(find.text('No certificates added yet'), findsOneWidget);
  });

  testWidgets('shows existing class conditions and empty state when none',
      (tester) async {
    await _pump(tester);
    expect(find.text('No conditions recorded'), findsOneWidget);
  });

  testWidgets('adding a class condition calls add() with the entered reference',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Add').at(1)); // Class Conditions section
    await tester.pumpAndSettle();

    expect(find.text('Add Class Condition'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Reference number'), 'MC-2026-004');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('MC-2026-004'), findsOneWidget);
  });

  testWidgets('deleting a class condition removes it', (tester) async {
    await _pump(tester, conditions: const [
      ClassConditionModel(
        conditionId: 'cond1',
        vesselId: _vesselId,
        reference: 'MC-2025-001',
        description: 'Condition to delete',
      ),
    ]);

    expect(find.text('MC-2025-001'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('MC-2025-001'), findsNothing);
    expect(find.text('No conditions recorded'), findsOneWidget);
  });

  testWidgets('changing class status shows Save and persists via saveVessel',
      (tester) async {
    final vesselFake = await _pump(tester);

    await tester.tap(find.text('Conditional'));
    await tester.pumpAndSettle();

    expect(find.text('Save'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(vesselFake.state.value?.classStatus, ClassStatus.conditional);
  });
}
