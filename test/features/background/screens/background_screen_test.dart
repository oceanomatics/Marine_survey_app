// test/features/background/screens/background_screen_test.dart
//
// Row 132 (TEST_SHEET.md) — "cues stay consistent between Background panel
// and repair-period-scoped cues" — isn't a separate test here: both screens
// render the exact same shared ContextCuesPanel widget (see that file's own
// header comment, "one implementation of the cue register, not five"), so
// divergence isn't structurally possible; there's nothing screen-specific
// to test beyond what's covered here and in causation_screen_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/background/screens/background_screen.dart';
import 'package:marine_survey_app/features/background/providers/background_provider.dart';
import 'package:marine_survey_app/features/surveyor_notes/models/surveyor_note_model.dart';
import 'package:marine_survey_app/features/surveyor_notes/providers/surveyor_notes_provider.dart';

import '../../../support/fakes/fake_background_notifier.dart';
import '../../../support/fakes/fake_surveyor_notes_notifier.dart';

const _caseId = 'case-1';

Future<FakeSurveyorNotesNotifier> _pump(
  WidgetTester tester, {
  String backgroundText = '',
  List<SurveyorNote> notes = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final notesFake = FakeSurveyorNotesNotifier(notes);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        backgroundProvider.overrideWith(() => FakeBackgroundNotifier(backgroundText)),
        surveyorNotesProvider.overrideWith(() => notesFake),
      ],
      child: const MaterialApp(home: BackgroundScreen(caseId: _caseId)),
    ),
  );
  await tester.pumpAndSettle();
  return notesFake;
}

void main() {
  testWidgets('loads existing background text', (tester) async {
    await _pump(tester, backgroundText: 'The vessel was under charter to...');

    expect(find.text('The vessel was under charter to...'), findsOneWidget);
  });

  testWidgets('editing text marks dirty and autosaves after the debounce window',
      (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'New background narrative');
    await tester.pump();

    // SaveBar visible while dirty, before the debounce fires.
    expect(find.text('Save changes'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    // Debounced autosave completed -> no longer dirty -> SaveBar hides.
    expect(find.text('Save changes'), findsNothing);
  });

  testWidgets('manually tapping Save persists immediately', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'Manual save narrative');
    // pumpAndSettle, not a single pump — the SaveBar grows in via
    // AnimatedSize; tapping mid-animation can hit-test against whatever
    // was underneath before it finished settling into place.
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // SaveBar hides once no longer dirty.
    expect(find.text('Save changes'), findsNothing);
  });

  testWidgets('Context Cues panel is present and defaults expanded', (tester) async {
    await _pump(tester);

    expect(find.text('Context Cues'), findsOneWidget);
    // Per-section panels show ACTIVE cues only — the Active/Ignored toggle was
    // removed (16 July 2026 occurrence/cue UX sweep, item 1); ignoring lives
    // on the Notes screen's Ignored tab, not here.
    expect(find.text('Active'), findsNothing);
    expect(find.text('Ignored'), findsNothing);
  });

  testWidgets('adding a cue via the panel creates it scoped to Background', (tester) async {
    final fake = await _pump(tester);

    await tester.tap(find.text('+ Add'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Vessel history note');
    await tester.tap(find.text('Save Cue'));
    await tester.pumpAndSettle();

    final saved = fake.state.value!.single;
    expect(saved.content, 'Vessel history note');
    expect(saved.caseSection, CaseSection.background);
  });

  testWidgets('editing a cue via the panel updates its content', (tester) async {
    final note = SurveyorNote(
      id: 'n1',
      caseId: _caseId,
      content: 'Original cue text',
      caseSection: CaseSection.background,
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );
    final fake = await _pump(tester, notes: [note]);

    await tester.tap(find.text('Original cue text'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Updated cue text');
    await tester.tap(find.text('Update Cue'));
    await tester.pumpAndSettle();

    expect(fake.state.value!.single.content, 'Updated cue text');
  });

  testWidgets('deleting a cue via the panel removes it', (tester) async {
    final note = SurveyorNote(
      id: 'n1',
      caseId: _caseId,
      content: 'Cue to delete',
      caseSection: CaseSection.background,
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );
    final fake = await _pump(tester, notes: [note]);

    expect(find.text('Cue to delete'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(fake.state.value, isEmpty);
  });
}
