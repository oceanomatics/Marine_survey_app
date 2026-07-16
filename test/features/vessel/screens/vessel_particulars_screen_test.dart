import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/cases/models/case_model.dart';
import 'package:marine_survey_app/features/settings/providers/account_provider.dart';
import 'package:marine_survey_app/features/survey/providers/damage_provider.dart';
import 'package:marine_survey_app/features/vessel/models/class_condition_model.dart';
import 'package:marine_survey_app/features/vessel/providers/certificates_provider.dart';
import 'package:marine_survey_app/features/vessel/providers/class_conditions_provider.dart';
import 'package:marine_survey_app/features/vessel/providers/vessel_provider.dart';
import 'package:marine_survey_app/features/vessel/screens/vessel_particulars_screen.dart';
import 'package:marine_survey_app/features/photos/providers/photo_provider.dart';

import '../../../support/fakes/fake_account_notifier.dart';
import '../../../support/fakes/fake_certificates_notifier.dart';
import '../../../support/fakes/fake_class_conditions_notifier.dart';
import '../../../support/fakes/fake_damage_notifier.dart';
import '../../../support/fakes/fake_machinery_notifier.dart';
import '../../../support/fakes/fake_photo_notifier.dart';
import '../../../support/fakes/fake_vessel_for_case_notifier.dart';
import '../../../support/fixtures/survey_fixtures.dart';
import '../../../support/fixtures/vessel_fixtures.dart';
import '../../../support/pump_with_router.dart';

const _caseId = 'case-1';

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  VesselModel? vessel,
  List<MachineryModel> machinery = const [],
  List<CertificateModel> certificates = const [],
  List<ClassConditionModel> classConditions = const [],
  AccountState account = const AccountState(),
}) async {
  // Identity/Dimensions/Class & Stat. tabs are plain ListViews with a lot of
  // content — widen the surface so fields below the fold are still built and
  // hit-testable without needing to scroll first (see report_builder pattern).
  // 1400 wide so the scrollable tab bar shows all five tabs without the
  // later ones (Dimensions/Machinery) sitting off-screen — the "Registration
  // & Insurance" label widened the bar past the old 1000 (16 July 2026).
  await tester.binding.setSurfaceSize(const Size(1400, 4000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final container = ProviderContainer(overrides: [
    vesselForCaseProvider.overrideWith(() => FakeVesselForCaseNotifier(vessel)),
    machineryProvider.overrideWith(() => FakeMachineryNotifier(machinery)),
    certificatesProvider.overrideWith(() => FakeCertificatesNotifier(certificates)),
    classConditionsProvider.overrideWith(() => FakeClassConditionsNotifier(classConditions)),
    damageProvider.overrideWith(() => FakeDamageNotifier(fixtureDamageState())),
    photosProvider.overrideWith(() => FakePhotoNotifier(const [])),
    accountProvider.overrideWith(() => FakeAccountNotifier(account)),
  ]);
  addTearDown(container.dispose);

  // Real GoRouter, not a bare MaterialApp — the Equasis "no credentials"
  // flow calls GoRouter.of(context) to link to /account.
  await pumpWithRouter(
    tester,
    container: container,
    child: const VesselParticularsScreen(caseId: _caseId),
    extraRoutes: [placeholderRoute('/account')],
  );
  return container;
}

/// Finds the TextField inside the SurveyField labelled [label].
Finder _fieldByLabel(String label) => find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == 'SurveyField'),
      ),
      matching: find.byType(TextField),
    );

void main() {
  group('VesselParticularsScreen — Identity tab', () {
    testWidgets('shows existing vessel data', (tester) async {
      await _pump(tester,
          vessel: fixtureVessel(name: 'MINRES ODIN', imoNumber: '9374935'));

      expect(find.text('MINRES ODIN'), findsWidgets); // AppBar subtitle + field
      expect(_fieldByLabel('Vessel Name *'), findsOneWidget);
      final nameField = tester.widget<TextField>(_fieldByLabel('Vessel Name *'));
      expect(nameField.controller!.text, 'MINRES ODIN');
      final imoField = tester.widget<TextField>(_fieldByLabel('IMO Number'));
      expect(imoField.controller!.text, '9374935');
    });

    testWidgets('editing a field and saving persists the change', (tester) async {
      final container =
          await _pump(tester, vessel: fixtureVessel(name: 'MINRES ODIN'));

      await tester.enterText(_fieldByLabel('Owners'), 'MinRes Marine Pty Ltd');
      await tester.pumpAndSettle();

      expect(find.text('Save changes'), findsOneWidget);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Vessel particulars saved'), findsOneWidget);
      final saved = container.read(vesselForCaseProvider(_caseId)).value;
      expect(saved?.owners, 'MinRes Marine Pty Ltd');
    });
  });

  group('VesselParticularsScreen — create from scratch', () {
    testWidgets('entering a name and saving creates a new vessel', (tester) async {
      final container = await _pump(tester, vessel: null);

      // No vessel yet — Save bar is visible unconditionally.
      expect(find.text('Save changes'), findsOneWidget);

      await tester.enterText(_fieldByLabel('Vessel Name *'), 'NEW VESSEL');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Vessel particulars saved'), findsOneWidget);
      final saved = container.read(vesselForCaseProvider(_caseId)).value;
      expect(saved, isNotNull);
      expect(saved!.name, 'NEW VESSEL');
    });

    testWidgets('saving with an empty name shows a validation snackbar and does not create',
        (tester) async {
      final container = await _pump(tester, vessel: null);

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Vessel name is required'), findsOneWidget);
      expect(container.read(vesselForCaseProvider(_caseId)).value, isNull);
    });
  });

  group('VesselParticularsScreen — Dimensions tab', () {
    testWidgets('editing tonnage fields and saving persists them', (tester) async {
      final container =
          await _pump(tester, vessel: fixtureVessel(name: 'MINRES ODIN'));

      await tester.tap(find.text('Dimensions').first);
      await tester.pumpAndSettle();

      await tester.enterText(_fieldByLabel('Gross Tonnage (GT)'), '1311');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      final saved = container.read(vesselForCaseProvider(_caseId)).value;
      expect(saved?.grossTonnage, 1311);
    });

    testWidgets(
        'Principal Dimensions is regrouped into Longitudinal/Transversal/Vertical '
        '(14 July 2026 walkthrough §3)', (tester) async {
      await _pump(tester, vessel: fixtureVessel());

      await tester.tap(find.text('Dimensions').first);
      await tester.pumpAndSettle();

      expect(find.text('LONGITUDINAL'), findsOneWidget);
      expect(find.text('TRANSVERSAL'), findsOneWidget);
      expect(find.text('VERTICAL'), findsOneWidget);
    });
  });

  group('VesselParticularsScreen — Machinery tab', () {
    testWidgets('shows the empty-state hint with no machinery', (tester) async {
      await _pump(tester, vessel: fixtureVessel());

      await tester.tap(find.text('Machinery').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('No machinery recorded yet'), findsOneWidget);
    });

    testWidgets(
        'Propulsion Particulars is reorganised into screw count / prime mover / '
        'thruster type (14 July 2026 walkthrough §3 Q5)', (tester) async {
      final container =
          await _pump(tester, vessel: fixtureVessel(vesselId: 'vessel-1'));

      await tester.tap(find.text('Machinery').first);
      await tester.pumpAndSettle();

      expect(find.text('Number of Screws'), findsOneWidget);
      expect(find.text('Type of Prime Mover'), findsOneWidget);
      expect(find.text('Thruster Type'), findsOneWidget);
      expect(find.text('Propulsion Type'), findsNothing);
      expect(find.text('Propulsion Drive Type'), findsNothing);
      expect(find.text('Propeller / Thruster Type'), findsNothing);

      await tester.enterText(_fieldByLabel('Number of Screws'), '2');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Electric'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Azipods'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      final saved = container.read(vesselForCaseProvider(_caseId)).value;
      expect(saved?.screwCount, 2);
      expect(saved?.propulsionType, 'Electric');
      expect(saved?.propellerType, 'Azipods');
    });

    testWidgets('adding an item persists it to the list', (tester) async {
      final container = await _pump(tester, vessel: fixtureVessel(vesselId: 'vessel-1'));

      await tester.tap(find.text('Machinery').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Machinery / Equipment'));
      await tester.pumpAndSettle();

      expect(find.text('Add Machinery / System'), findsOneWidget);
      await tester.enterText(_fieldByLabel('Make'), 'MAN B&W');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add System'));
      await tester.pumpAndSettle();

      final machinery = container.read(machineryProvider('vessel-1')).value ?? [];
      expect(machinery, hasLength(1));
      expect(machinery.single.make, 'MAN B&W');
      expect(find.textContaining('MAN B&W'), findsOneWidget);
    });

    testWidgets('delete shows a confirm dialog and removes the item on confirm',
        (tester) async {
      final container = await _pump(
        tester,
        vessel: fixtureVessel(vesselId: 'vessel-1'),
        machinery: [fixtureMachinery(vesselId: 'vessel-1', make: 'Caterpillar')],
      );

      await tester.tap(find.text('Machinery').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete machinery?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(container.read(machineryProvider('vessel-1')).value, isEmpty);
    });
  });

  group('VesselParticularsScreen — Equasis affordance', () {
    testWidgets('tapping Equasis with no IMO shows a snackbar', (tester) async {
      await _pump(tester, vessel: fixtureVessel(imoNumber: null));

      await tester.tap(find.byIcon(Icons.travel_explore));
      await tester.pumpAndSettle();

      expect(find.text('Enter an IMO number first'), findsOneWidget);
    });

    testWidgets('tapping Equasis with an IMO but no credentials shows a snackbar with an Account link',
        (tester) async {
      await _pump(
        tester,
        vessel: fixtureVessel(imoNumber: '9374935'),
        account: const AccountState(), // no externalAccounts configured
      );

      await tester.tap(find.byIcon(Icons.travel_explore));
      await tester.pumpAndSettle();

      expect(find.text('No Equasis account configured'), findsOneWidget);
      expect(find.text('Set up'), findsOneWidget);
    });
  });

  // The Cluster B restructure (docs/TODO.md §2.17 row 11, 9 July 2026)
  // deleted the old 4th "Class & Stat." tab from this screen entirely —
  // certificates, conditions of class, PSC, and ISPS all moved to the
  // case-level VesselComplianceScreen, confirmed live in
  // vessel_particulars_screen.dart (no ClassConditionsTab / ISPS chip / PSC
  // fields anywhere in this file any more). What's left here is a
  // "Classification" tab with static class-society/notation/P&I fields plus
  // a deep link to VesselComplianceScreen. A prior version of this test
  // file targeted the deleted tab by name ("Class & Stat.") and failed with
  // "Bad state: No element" — corrected to test what's actually here.
  // Certificates/conditions-of-class/PSC/ISPS coverage belongs in a
  // dedicated vessel_compliance_screen_test.dart, not written yet.
  group('VesselParticularsScreen — Classification tab', () {
    testWidgets('shows the static class fields and a deep link to Certificates & Class',
        (tester) async {
      await _pump(tester, vessel: fixtureVessel(vesselId: 'vessel-1'));

      await tester.tap(find.text('Classification').first);
      await tester.pumpAndSettle();

      expect(find.text('Open Certificates & Class'), findsOneWidget);
    });
  });
}
