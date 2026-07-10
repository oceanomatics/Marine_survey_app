import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/parties/providers/parties_provider.dart';
import 'package:marine_survey_app/features/survey/providers/attendees_provider.dart';
import 'package:marine_survey_app/features/survey/screens/attendees_screen.dart';
import 'package:marine_survey_app/features/surveyor_notes/providers/surveyor_notes_provider.dart';

import '../../../support/fakes/fake_assured_contacts_notifier.dart';
import '../../../support/fakes/fake_attendees_notifier.dart';
import '../../../support/fakes/fake_surveyor_notes_notifier.dart';
import '../../../support/fixtures/survey_fixtures.dart';
import '../../../support/pump_with_router.dart';

const _caseId = 'case-1';

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<AttendeeModel> attendees = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final container = ProviderContainer(overrides: [
    attendeesProvider.overrideWith(() => FakeAttendeesNotifier(attendees)),
    surveyorNotesProvider.overrideWith(() => FakeSurveyorNotesNotifier()),
    assuredContactsProvider.overrideWith(() => FakeAssuredContactsNotifier()),
  ]);
  addTearDown(container.dispose);

  await pumpWithRouter(
    tester,
    container: container,
    child: const AttendeesScreen(caseId: _caseId),
  );
  return container;
}

void main() {
  group('AttendeesScreen', () {
    testWidgets('empty state shows the add-first-person prompt', (tester) async {
      await _pump(tester);

      expect(find.text('No attendees recorded'), findsOneWidget);
      expect(find.text('Add first person'), findsOneWidget);
    });

    testWidgets('list loads and shows existing attendees', (tester) async {
      await _pump(tester, attendees: [
        fixtureAttendee(
            attendeeId: 'att-1', fullName: 'John Samuel', rankPosition: 'Master'),
      ]);

      // Rendered with a prefix ("Capt. John Samuel" — fixtureAttendee's
      // default roleType is master, and AttendeeModel.prefix always shows
      // something, real title or role-based fallback, per §3.13), on both
      // the card and the report-preview row, so a substring match against
      // two widgets is correct here, not findsOneWidget.
      expect(find.textContaining('John Samuel'), findsNWidgets(2));
      expect(find.text('Master'), findsWidgets); // card + report-preview row
    });

    testWidgets('adding an attendee via the FAB persists it to the list', (tester) async {
      final container = await _pump(tester);

      await tester.tap(find.text('Add Person'));
      await tester.pumpAndSettle();

      expect(find.text('Add Person'), findsWidgets); // sheet title + FAB
      await tester.enterText(
          find.widgetWithText(TextField, 'e.g. John Samuel'), 'Jane Doe');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to Attendees'));
      // Saving a brand-new attendee (not picked from Parties) offers
      // "Add to Parties?" (§3.13 row 48) next — the sheet's own Save button
      // keeps spinning until that second dialog is resolved, so
      // pumpAndSettle here (rather than a bounded pump) would time out
      // waiting for an animation that won't stop until we dismiss it below.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Add to Parties?'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      final attendees = container.read(attendeesProvider(_caseId)).value ?? [];
      expect(attendees, hasLength(1));
      expect(attendees.single.fullName, 'Jane Doe');
      // Card + report-preview row both render "{prefix} Jane Doe".
      expect(find.textContaining('Jane Doe'), findsNWidgets(2));
    });

    testWidgets(
        'setting a title on a new attendee persists it and updates the '
        'displayed prefix (docs/TODO.md §3.13 row 47)', (tester) async {
      final container = await _pump(tester);

      await tester.tap(find.text('Add Person'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'e.g. John Samuel'), 'Jane Doe');
      await tester.tap(find.byType(DropdownButtonFormField<AttendeeTitle?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dr.').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to Attendees'));
      // See the "adding an attendee via the FAB" test above for why this is
      // a bounded pump, not pumpAndSettle — the follow-up "Add to Parties?"
      // dialog needs dismissing first.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      final attendees = container.read(attendeesProvider(_caseId)).value ?? [];
      expect(attendees.single.title, AttendeeTitle.dr);
      expect(find.text('Dr.  Jane Doe'), findsOneWidget);
    });

    testWidgets('editing an attendee persists the change', (tester) async {
      final container = await _pump(tester, attendees: [
        fixtureAttendee(attendeeId: 'att-1', fullName: 'John Samuel'),
      ]);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Edit Attendee'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextField, 'e.g. John Samuel'), 'John A. Samuel');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      final attendees = container.read(attendeesProvider(_caseId)).value ?? [];
      expect(attendees.single.fullName, 'John A. Samuel');
      // Card + report-preview row both render "{prefix} John A. Samuel".
      expect(find.textContaining('John A. Samuel'), findsNWidgets(2));
    });

    testWidgets('deleting an attendee shows a confirm dialog and removes it', (tester) async {
      final container = await _pump(tester, attendees: [
        fixtureAttendee(attendeeId: 'att-1', fullName: 'John Samuel'),
      ]);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Remove attendee?'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(container.read(attendeesProvider(_caseId)).value, isEmpty);
      expect(find.text('No attendees recorded'), findsOneWidget);
    });
  });
}
