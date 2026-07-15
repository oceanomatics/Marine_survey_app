import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/survey/providers/damage_provider.dart';
import 'package:marine_survey_app/features/survey/screens/occurrence_screen.dart';
import 'package:marine_survey_app/features/surveyor_notes/providers/surveyor_notes_provider.dart';

import '../../../support/fakes/fake_damage_notifier.dart';
import '../../../support/fakes/fake_surveyor_notes_notifier.dart';
import '../../../support/fixtures/survey_fixtures.dart';
import '../../../support/pump_with_router.dart';

const _caseId = 'case-1';

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<OccurrenceModel> occurrences = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final container = ProviderContainer(overrides: [
    damageProvider.overrideWith(
        () => FakeDamageNotifier(fixtureDamageState(occurrences: occurrences))),
    surveyorNotesProvider.overrideWith(() => FakeSurveyorNotesNotifier()),
  ]);
  addTearDown(container.dispose);

  await pumpWithRouter(
    tester,
    container: container,
    child: const OccurrenceScreen(caseId: _caseId),
  );
  return container;
}

void main() {
  group('OccurrenceScreen', () {
    testWidgets('empty state shows the add-first-occurrence prompt', (tester) async {
      await _pump(tester);

      expect(find.text('No occurrences recorded'), findsOneWidget);
      expect(find.text('Add first occurrence'), findsOneWidget);
    });

    testWidgets('list loads and shows existing occurrences', (tester) async {
      await _pump(tester, occurrences: [
        fixtureOccurrence(
          occurrenceId: 'occ-1',
          title: 'Main engine failure',
          location: '12 NM off Onslow',
        ),
      ]);

      expect(find.text('Main engine failure'), findsOneWidget);
      expect(find.text('12 NM off Onslow'), findsOneWidget);
    });

    testWidgets('adding an occurrence via the FAB persists it to the list', (tester) async {
      final container = await _pump(tester);

      await tester.tap(find.text('Add Occurrence'));
      await tester.pumpAndSettle();

      expect(find.text('Add Occurrence'), findsWidgets); // sheet title + FAB
      await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Main diesel generator No.3 — connecting rod cap failure'),
          'Grounding on approach to Dampier');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Occurrence').last);
      await tester.pumpAndSettle();

      final occs = container.read(damageProvider(_caseId)).value?.occurrences ?? [];
      expect(occs, hasLength(1));
      expect(occs.single.title, 'Grounding on approach to Dampier');
      expect(find.text('Grounding on approach to Dampier'), findsOneWidget);
    });

    testWidgets('editing an occurrence via the popup menu persists the change', (tester) async {
      final container = await _pump(tester, occurrences: [
        fixtureOccurrence(occurrenceId: 'occ-1', title: 'Original title'),
      ]);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      // Full-screen two-tab editor (TODO.md, "Occurrence: full-screen
      // two-tab editor" commit) — the AppBar shows the occurrence's own
      // title rather than a fixed "Edit Occurrence" label, and the Details
      // tab (default) leads with the title field.
      // Appears twice — the AppBar title, and the still-mounted list card
      // underneath (MaterialPageRoute keeps the previous route in the tree).
      expect(find.text('Original title'), findsWidgets);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Narrative'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Updated title');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final occs = container.read(damageProvider(_caseId)).value?.occurrences ?? [];
      expect(occs.single.title, 'Updated title');
      expect(find.text('Updated title'), findsOneWidget);
    });

    testWidgets('deleting an occurrence shows a confirm dialog and cascades to its damage items',
        (tester) async {
      final container = await _pump(tester, occurrences: [
        fixtureOccurrence(occurrenceId: 'occ-1', title: 'Grounding'),
      ]);
      // Seed a damage item under this occurrence directly on the fake's state
      // via the notifier's addDamageItem, so the cascade has something to
      // remove.
      await container
          .read(damageProvider(_caseId).notifier)
          .addDamageItem(fixtureDamageItem(occurrenceId: 'occ-1'));

      await tester.pump();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete occurrence?'), findsOneWidget);
      expect(find.textContaining('linked damage items and repairs will also be removed'),
          findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      final state = container.read(damageProvider(_caseId)).value!;
      expect(state.occurrences, isEmpty);
      expect(state.damageItems, isEmpty);
    });

    testWidgets(
        'multi-occurrence case: adding a cue shows a "Route to" picker and '
        'routes it to the chosen occurrence (14 July 2026 walkthrough §4)',
        (tester) async {
      final container = await _pump(tester, occurrences: [
        fixtureOccurrence(occurrenceId: 'occ-1', title: 'Main engine failure'),
        fixtureOccurrence(occurrenceId: 'occ-2', title: 'Grounding'),
      ]);

      // Expand the Context Cues panel and add a cue.
      await tester.tap(find.text('+ Add'));
      await tester.pumpAndSettle();

      expect(find.text('Route to'), findsOneWidget);
      expect(find.text('Main engine failure'), findsWidgets);
      expect(find.text('Grounding'), findsWidgets);

      await tester.enterText(
          find.byType(TextField).first, 'Owner disputes cause');
      await tester.tap(find.text('Grounding').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Cue'));
      await tester.pumpAndSettle();

      final notes =
          container.read(surveyorNotesProvider(_caseId)).value ?? [];
      expect(notes, hasLength(1));
      expect(notes.single.linkedToType, 'occurrence');
      expect(notes.single.linkedToId, 'occ-2');
    });

    testWidgets(
        'single-occurrence case: no "Route to" picker shown, cue auto-scopes',
        (tester) async {
      final container = await _pump(tester, occurrences: [
        fixtureOccurrence(occurrenceId: 'occ-1', title: 'Main engine failure'),
      ]);

      await tester.tap(find.text('+ Add'));
      await tester.pumpAndSettle();

      expect(find.text('Route to'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'Single-occ cue');
      await tester.tap(find.text('Save Cue'));
      await tester.pumpAndSettle();

      final notes =
          container.read(surveyorNotesProvider(_caseId)).value ?? [];
      expect(notes.single.linkedToType, 'occurrence');
      expect(notes.single.linkedToId, 'occ-1');
    });
  });
}
