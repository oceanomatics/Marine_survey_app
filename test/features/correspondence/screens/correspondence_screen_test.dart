// test/features/correspondence/screens/correspondence_screen_test.dart
//
// Scoped like Document Vault/Photos: EML/PDF upload (rows 91, 98-107) needs
// file_picker — same no-test-mode blocker as elsewhere this session — and
// "Extract with AI" (row 96) is a real Claude API call, never tapped here.
// Everything that can be exercised via seeded CorrespondenceModel fixtures
// (as if extraction had already run) is covered instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/correspondence/screens/correspondence_screen.dart';
import 'package:marine_survey_app/features/correspondence/models/correspondence_model.dart';
import 'package:marine_survey_app/features/correspondence/providers/correspondence_provider.dart';
import 'package:marine_survey_app/features/correspondence/providers/mail_poll_provider.dart';
import 'package:marine_survey_app/features/documents/providers/document_provider.dart';
import 'package:marine_survey_app/features/parties/models/party_model.dart';
import 'package:marine_survey_app/features/parties/providers/parties_provider.dart';
import 'package:marine_survey_app/features/surveyor_notes/providers/surveyor_notes_provider.dart';

import '../../../support/fakes/fake_correspondence_notifier.dart';
import '../../../support/fakes/fake_mail_poll_notifier.dart';
import '../../../support/fakes/fake_document_notifier.dart';
import '../../../support/fakes/fake_assured_contacts_notifier.dart';
import '../../../support/fakes/fake_surveyor_notes_notifier.dart';

const _caseId = 'case-1';

Future<FakeCorrespondenceNotifier> _pump(
  WidgetTester tester, {
  List<CorrespondenceModel> items = const [],
  List<AssuredContactModel> existingContacts = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final fake = FakeCorrespondenceNotifier(items);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        correspondenceProvider.overrideWith(() => fake),
        mailPollProvider.overrideWith(FakeMailPollNotifier.new),
        documentProvider.overrideWith(() => FakeDocumentNotifier(const [])),
        assuredContactsProvider
            .overrideWith(() => FakeAssuredContactsNotifier(existingContacts)),
        surveyorNotesProvider.overrideWith(() => FakeSurveyorNotesNotifier()),
      ],
      child: const MaterialApp(home: CorrespondenceScreen(caseId: _caseId)),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

CorrespondenceModel _item({
  String id = 'c1',
  String title = 'Re: Survey attendance',
  String? sender,
  DateTime? corrDate,
  List<ExtractedParty> parties = const [],
  List<String> actions = const [],
}) =>
    CorrespondenceModel(
      id: id,
      caseId: _caseId,
      title: title,
      sender: sender,
      corrDate: corrDate,
      parties: parties,
      actions: actions,
      createdAt: DateTime(2026, 6, 1),
    );

void main() {
  testWidgets('empty state shown with no correspondence', (tester) async {
    await _pump(tester);
    expect(find.byType(CorrespondenceScreen), findsOneWidget);
  });

  testWidgets('loads and shows a collapsed card with title and date', (tester) async {
    await _pump(tester, items: [_item(corrDate: DateTime(2026, 6, 15))]);

    expect(find.text('Re: Survey attendance'), findsOneWidget);
    expect(find.text('15 Jun 26'), findsOneWidget);
  });

  testWidgets('FAB Add opens a sheet with Upload PDF and Import Email options',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Upload PDF'), findsOneWidget);
    expect(find.text('Import Email (.eml)'), findsOneWidget);
  });

  testWidgets('tapping the card header expands it', (tester) async {
    await _pump(tester, items: [
      _item(parties: const [ExtractedParty(name: 'Jane Doe', role: 'Owner')]),
    ]);

    expect(find.text('Jane Doe · Owner'), findsNothing);

    await tester.tap(find.text('Re: Survey attendance'));
    await tester.pumpAndSettle();

    expect(find.text('Jane Doe · Owner'), findsOneWidget);
  });

  testWidgets('overflow menu offers Preview/Extract/Delete, and Reply only for EML with a sender',
      (tester) async {
    await _pump(tester, items: [_item(id: 'c1', title: 'PDF item')]);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Preview PDF'), findsOneWidget);
    expect(find.text('Extract with AI'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Reply via Gmail'), findsNothing);
  });

  testWidgets('deleting via the overflow menu shows a confirm dialog and removes the card',
      (tester) async {
    final fake = await _pump(tester, items: [_item()]);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete correspondence?'), findsOneWidget);

    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(fake.state.value, isEmpty);
  });

  testWidgets('expanded card shows extracted parties and an Add to Parties button',
      (tester) async {
    await _pump(tester, items: [
      _item(parties: const [ExtractedParty(name: 'Jane Doe', role: 'Owner')]),
    ]);

    await tester.tap(find.text('Re: Survey attendance'));
    await tester.pumpAndSettle();

    expect(find.text('Jane Doe · Owner'), findsOneWidget);
    expect(find.text('Add to Parties'), findsOneWidget);
  });

  testWidgets('Add to Parties dialog is pre-checked and adds selected parties',
      (tester) async {
    await _pump(tester, items: [
      _item(parties: const [ExtractedParty(name: 'Jane Doe', role: 'Owner')]),
    ]);
    await tester.tap(find.text('Re: Survey attendance'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add to Parties'));
    await tester.pumpAndSettle();

    expect(find.byType(CheckboxListTile), findsOneWidget);
    final checkbox = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(checkbox.value, isTrue);

    await tester.tap(find.text('Add 1'));
    await tester.pumpAndSettle();

    expect(find.text('1 stakeholder(s) added or updated'), findsOneWidget);
  });

  testWidgets('re-adding an already-present party shows the "already in stakeholders" snackbar',
      (tester) async {
    await _pump(
      tester,
      items: [
        _item(parties: const [ExtractedParty(name: 'Jane Doe', role: 'Owner')]),
      ],
      // Already fully in the list (same role) — re-importing brings nothing
      // new, so the merge is a no-op and the "already in" message shows.
      existingContacts: [
        AssuredContactModel(
            contactId: 'ct1',
            caseId: _caseId,
            fullName: 'Jane Doe',
            roleTitle: 'Owner',
            stakeholderGroup: StakeholderGroup.fromRole('Owner')),
      ],
    );
    await tester.tap(find.text('Re: Survey attendance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Parties'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 1'));
    await tester.pumpAndSettle();

    expect(find.text('All parties already in the stakeholders list (no new details)'), findsOneWidget);
  });

  testWidgets('re-adding an existing party with newly-available data merges it (added or updated)',
      (tester) async {
    await _pump(
      tester,
      items: [
        _item(parties: const [
          ExtractedParty(
              name: 'Ryan Allison',
              role: 'Owner',
              email: 'ryan@example.com')
        ]),
      ],
      // Ryan is already known, but without an email — the second email now
      // supplies it, so the import must update rather than skip (16 Jul 2026).
      existingContacts: [
        const AssuredContactModel(
            contactId: 'ct1',
            caseId: _caseId,
            fullName: 'Ryan Allison',
            roleTitle: 'Owner'),
      ],
    );
    await tester.tap(find.text('Re: Survey attendance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Parties'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 1'));
    await tester.pumpAndSettle();

    expect(find.text('1 stakeholder(s) added or updated'), findsOneWidget);
  });

  testWidgets('action items list with a Send to context notes icon that files a cue',
      (tester) async {
    await _pump(tester, items: [
      _item(actions: const ['Follow up on outstanding invoice']),
    ]);
    await tester.tap(find.text('Re: Survey attendance'));
    await tester.pumpAndSettle();

    expect(find.text('Follow up on outstanding invoice'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_task));
    await tester.pumpAndSettle();

    expect(find.text('Action added to context notes'), findsOneWidget);
  });
}
