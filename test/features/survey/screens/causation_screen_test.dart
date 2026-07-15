// test/features/survey/screens/causation_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/survey/screens/causation_screen.dart';
import 'package:marine_survey_app/features/survey/providers/damage_provider.dart';
import 'package:marine_survey_app/features/surveyor_notes/providers/surveyor_notes_provider.dart';

import '../../../support/fixtures/survey_fixtures.dart';
import '../../../support/fakes/fake_damage_notifier.dart';
import '../../../support/fakes/fake_surveyor_notes_notifier.dart';

const _caseId = 'case-1';

Future<FakeDamageNotifier> _pump(
  WidgetTester tester, {
  required List<OccurrenceModel> occurrences,
}) async {
  // The causation bottom sheet is tall (many sections) — the default
  // 800x600 test surface clips its Save button below the visible area.
  await tester.binding.setSurfaceSize(const Size(400, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final fake = FakeDamageNotifier(fixtureDamageState(occurrences: occurrences));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        damageProvider.overrideWith(() => fake),
        surveyorNotesProvider.overrideWith(() => FakeSurveyorNotesNotifier()),
      ],
      child: const MaterialApp(home: CausationScreen(caseId: _caseId)),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('empty state when there are no occurrences', (tester) async {
    await _pump(tester, occurrences: []);

    expect(find.text('No occurrences recorded'), findsOneWidget);
  });

  testWidgets('shows a causation card per occurrence, sorted by date', (tester) async {
    final occ1 = OccurrenceModel(
      occurrenceId: 'occ-1',
      caseId: _caseId,
      occurrenceNo: 1,
      isPrimary: true,
      title: 'Engine failure',
      dateTime: DateTime(2026, 6, 10),
      createdAt: DateTime(2026, 1, 1),
    );
    final occ2 = OccurrenceModel(
      occurrenceId: 'occ-2',
      caseId: _caseId,
      occurrenceNo: 2,
      isPrimary: false,
      title: 'Hull contact',
      dateTime: DateTime(2026, 5, 1),
      createdAt: DateTime(2026, 1, 1),
    );
    // Passed in reverse-date order — the screen sorts ascending by date.
    await _pump(tester, occurrences: [occ1, occ2]);

    expect(find.text('Engine failure'), findsOneWidget);
    expect(find.text('Hull contact'), findsOneWidget);

    final positionA = tester.getTopLeft(find.text('Hull contact')).dy;
    final positionB = tester.getTopLeft(find.text('Engine failure')).dy;
    expect(positionA, lessThan(positionB));
  });

  testWidgets('cause type and allegation badges reflect occurrence data', (tester) async {
    final occ = OccurrenceModel(
      occurrenceId: 'occ-1',
      caseId: _caseId,
      occurrenceNo: 1,
      isPrimary: true,
      title: 'Engine failure',
      causeType: 'machinery_failure',
      allegationType: 'formal_allegation',
      causeAgreement: 'agree',
      createdAt: DateTime(2026, 1, 1),
    );
    await _pump(tester, occurrences: [occ]);

    expect(find.text('Machinery Failure'), findsOneWidget);
    expect(find.text('Formal Allegation'), findsOneWidget);
    expect(find.text('We Agree'), findsOneWidget);
  });

  testWidgets('unset cause type and allegation show "Not set" placeholders', (tester) async {
    final occ = OccurrenceModel(
      occurrenceId: 'occ-1',
      caseId: _caseId,
      occurrenceNo: 1,
      isPrimary: true,
      title: 'Undetermined event',
      createdAt: DateTime(2026, 1, 1),
    );
    await _pump(tester, occurrences: [occ]);

    expect(find.text('Not set'), findsNWidgets(2)); // cause type + allegation
  });

  testWidgets('tapping edit opens the causation sheet with existing data prefilled',
      (tester) async {
    final occ = OccurrenceModel(
      occurrenceId: 'occ-1',
      caseId: _caseId,
      occurrenceNo: 1,
      isPrimary: true,
      title: 'Engine failure',
      causeNarrative: 'Existing narrative text',
      createdAt: DateTime(2026, 1, 1),
    );
    await _pump(tester, occurrences: [occ]);

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Save Causation'), findsOneWidget);
    // Appears both as the card's preview text and prefilled in the sheet's
    // text field.
    expect(find.text('Existing narrative text'), findsNWidgets(2));
  });

  testWidgets('editing causation and saving persists via damageProvider.updateOccurrence',
      (tester) async {
    final occ = OccurrenceModel(
      occurrenceId: 'occ-1',
      caseId: _caseId,
      occurrenceNo: 1,
      isPrimary: true,
      title: 'Engine failure',
      createdAt: DateTime(2026, 1, 1),
    );
    final fake = await _pump(tester, occurrences: [occ]);

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();

    // Select a cause type chip.
    await tester.tap(find.text('Grounding / Stranding'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Causation'));
    await tester.pumpAndSettle();

    final updated = fake.state.value!.occurrences.single;
    expect(updated.causeType, 'grounding');
  });
}
