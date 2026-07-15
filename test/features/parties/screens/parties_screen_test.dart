// test/features/parties/screens/parties_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/parties/screens/parties_screen.dart';
import 'package:marine_survey_app/features/parties/models/party_model.dart';
import 'package:marine_survey_app/features/parties/providers/parties_provider.dart';

import '../../../support/fakes/fake_parties_notifier.dart';
import '../../../support/fakes/fake_assured_contacts_notifier.dart';

const _caseId = 'case-1';

Future<void> _pump(
  WidgetTester tester, {
  List<AssuredContactModel> contacts = const [],
  CasePartiesModel? parties,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        partiesProvider.overrideWith(() => FakePartiesNotifier(parties)),
        assuredContactsProvider
            .overrideWith(() => FakeAssuredContactsNotifier(contacts)),
      ],
      child: const MaterialApp(home: PartiesScreen(caseId: _caseId)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows both tabs: Parties and Stakeholders', (tester) async {
    await _pump(tester);

    expect(find.text('Parties'), findsOneWidget);
    expect(find.text('Stakeholders'), findsOneWidget);
  });

  testWidgets('Stakeholders tab shows "No stakeholders" empty state', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Stakeholders'));
    await tester.pumpAndSettle();

    expect(find.text('No stakeholders added yet.'), findsOneWidget);
  });

  testWidgets('adding a stakeholder manually appears grouped by stakeholder group',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Stakeholders'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Full Name *'), 'Jane Doe');
    await tester.enterText(
        find.widgetWithText(TextField, 'Company / Organisation'), 'Gard AS');

    // Open the group dropdown and select "Underwriter".
    await tester.tap(find.byType(DropdownButtonFormField<StakeholderGroup>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Underwriter').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Stakeholder'));
    await tester.pumpAndSettle();

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('Gard AS'), findsOneWidget);
    expect(find.text('UNDERWRITER'), findsOneWidget);
  });

  testWidgets("a group header's Add link pre-selects that group in the sheet",
      (tester) async {
    const existing = AssuredContactModel(
      contactId: 'c1',
      caseId: _caseId,
      fullName: 'Gard AS Rep',
      stakeholderGroup: StakeholderGroup.underwriter,
    );
    await _pump(tester, contacts: const [existing]);
    await tester.tap(find.text('Stakeholders'));
    await tester.pumpAndSettle();

    // The group section's own "Add" link uses a plain Icons.add — distinct
    // from the tab's FAB (Icons.person_add_outlined, also labelled "Add"),
    // which would pre-select nothing.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButtonFormField<StakeholderGroup>>(
        find.byType(DropdownButtonFormField<StakeholderGroup>));
    expect(dropdown.initialValue, StakeholderGroup.underwriter);
  });

  testWidgets('group dropdown includes all 6 stakeholder groups', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Stakeholders'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<StakeholderGroup>));
    await tester.pumpAndSettle();

    for (final label in [
      'Insured', 'Underwriter', 'Broker', 'Surveyors', 'Technical Contractors', 'Other Parties',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'missing group option: $label');
    }
  });

  testWidgets('stakeholder card shows initials avatar, role chip, and contact rows',
      (tester) async {
    final contacts = [
      const AssuredContactModel(
        contactId: 'c1',
        caseId: _caseId,
        fullName: 'John Samuel',
        company: 'MinRes',
        roleTitle: 'Superintendent',
        stakeholderGroup: StakeholderGroup.insured,
        phone: '+61 400 000 000',
        email: 'john@minres.com',
      ),
    ];
    await _pump(tester, contacts: contacts);
    await tester.tap(find.text('Stakeholders'));
    await tester.pumpAndSettle();

    expect(find.text('JS'), findsOneWidget); // initials
    expect(find.text('Superintendent'), findsOneWidget);
    expect(find.text('+61 400 000 000'), findsOneWidget);
    expect(find.text('john@minres.com'), findsOneWidget);
  });

  testWidgets('deleting a stakeholder shows confirm dialog, removes on confirm',
      (tester) async {
    final contacts = [
      const AssuredContactModel(
        contactId: 'c1',
        caseId: _caseId,
        fullName: 'John Samuel',
        stakeholderGroup: StakeholderGroup.insured,
      ),
    ];
    await _pump(tester, contacts: contacts);
    await tester.tap(find.text('Stakeholders'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Remove stakeholder?'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('John Samuel'), findsNothing);
    expect(find.text('No stakeholders added yet.'), findsOneWidget);
  });

  testWidgets('Parties tab shows all 5 role cards', (tester) async {
    await _pump(tester);

    expect(find.text('Instructing Principal'), findsOneWidget);
    expect(find.text('Reviewer / QC'), findsOneWidget);
    expect(find.text('Assured / Owner\'s Representative'), findsOneWidget);
    expect(find.text('Underwriter / Insurer'), findsOneWidget);
    expect(find.text('Loss Adjuster'), findsOneWidget);
  });

  testWidgets('editing a Parties field shows the unsaved-changes SaveBar',
      (tester) async {
    await _pump(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Name').first, 'Jane Principal');
    await tester.pump();

    expect(find.text('Save changes'), findsOneWidget);
  });
}
