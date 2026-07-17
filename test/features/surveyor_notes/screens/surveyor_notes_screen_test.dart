// test/features/surveyor_notes/screens/surveyor_notes_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/surveyor_notes/screens/surveyor_notes_screen.dart';
import 'package:marine_survey_app/features/surveyor_notes/models/surveyor_note_model.dart';
import 'package:marine_survey_app/features/surveyor_notes/providers/surveyor_notes_provider.dart';
import 'package:marine_survey_app/features/survey/providers/repair_period_provider.dart';

import '../../../support/fakes/fake_surveyor_notes_notifier.dart';
import '../../../support/fakes/fake_repair_periods_notifier.dart';

const _caseId = 'case-1';

SurveyorNote _note({
  String id = 'n1',
  String content = 'A context cue',
  CaseSection? caseSection,
  CuePriority priority = CuePriority.normal,
  bool pendingReview = false,
}) =>
    SurveyorNote(
      id: id,
      caseId: _caseId,
      content: content,
      caseSection: caseSection,
      priority: priority,
      pendingReview: pendingReview,
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );

Future<FakeSurveyorNotesNotifier> _pump(
  WidgetTester tester, {
  List<SurveyorNote> notes = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final fake = FakeSurveyorNotesNotifier(notes);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        surveyorNotesProvider.overrideWith(() => fake),
        repairPeriodsProvider.overrideWith(() => FakeRepairPeriodsNotifier([])),
      ],
      child: const MaterialApp(home: SurveyorNotesScreen(caseId: _caseId)),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('loads and shows all four tabs', (tester) async {
    await _pump(tester);

    expect(find.text('Retained'), findsOneWidget);
    expect(find.text('Suggested'), findsOneWidget);
    expect(find.text('Unallocated'), findsOneWidget);
    expect(find.text('Ignored'), findsOneWidget);
  });

  testWidgets('retained tab groups notes by case section, unallocated tab has ones with no section',
      (tester) async {
    final notes = [
      _note(id: 'n1', content: 'Damage-scoped cue', caseSection: CaseSection.damage),
      _note(id: 'n2', content: 'Untagged cue'),
    ];
    await _pump(tester, notes: notes);

    // Retained tab is the default.
    expect(find.text('Damage-scoped cue'), findsOneWidget);
    expect(find.text('Untagged cue'), findsNothing);

    await tester.tap(find.text('Unallocated'));
    await tester.pumpAndSettle();

    expect(find.text('Untagged cue'), findsOneWidget);
  });

  testWidgets('suggested tab shows pending-review notes with a confirm button',
      (tester) async {
    final notes = [
      _note(id: 'n1', content: 'AI-suggested cue', pendingReview: true),
    ];
    final fake = await _pump(tester, notes: notes);

    await tester.tap(find.text('Suggested'));
    await tester.pumpAndSettle();

    expect(find.text('AI-suggested cue'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check_circle_outline));
    await tester.pumpAndSettle();

    expect(fake.state.value!.single.pendingReview, isFalse);
  });

  testWidgets('ignored tab shows ignored notes dimmed', (tester) async {
    final notes = [
      _note(id: 'n1', content: 'Ignored cue', priority: CuePriority.ignored),
    ];
    await _pump(tester, notes: notes);

    await tester.tap(find.text('Ignored'));
    await tester.pumpAndSettle();

    expect(find.text('Ignored cue'), findsOneWidget);
  });

  testWidgets('empty retained tab shows the empty state with Add Cue', (tester) async {
    await _pump(tester);

    expect(find.text('No retained cues yet'), findsOneWidget);
  });

  testWidgets('adding a new cue via the FAB creates it with selected priority and section',
      (tester) async {
    final fake = await _pump(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('New Context Cue'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'A brand new cue');
    await tester.tap(find.text('Important'));
    await tester.pumpAndSettle();

    // Pick a case section chip (short label, e.g. "Damage").
    await tester.tap(find.text('Damage'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Cue'));
    await tester.pumpAndSettle();

    final saved = fake.state.value!.single;
    expect(saved.content, 'A brand new cue');
    expect(saved.priority, CuePriority.important);
    expect(saved.caseSection, CaseSection.damage);
  });

  testWidgets('a lowercase-dictated cue is saved with a capitalised first '
      'character (item 3)', (tester) async {
    final fake = await _pump(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextField).first, 'the master reported flooding');
    await tester.tap(find.text('Save Cue'));
    await tester.pumpAndSettle();

    expect(fake.state.value!.single.content, 'The master reported flooding');
  });

  testWidgets('classification sub-sections left-align with PRIORITY in the '
      'cue sheet (item 4)', (tester) async {
    await _pump(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Default priority is Normal, so the Nature/Weight/Origin rows are shown.
    final priorityX = tester.getTopLeft(find.text('PRIORITY')).dx;
    final natureX = tester.getTopLeft(find.text('Nature of content')).dx;
    final weightX = tester.getTopLeft(find.text('Evidentiary weight')).dx;
    final originX = tester.getTopLeft(find.text('Origin')).dx;

    expect(natureX, moreOrLessEquals(priorityX, epsilon: 0.5));
    expect(weightX, moreOrLessEquals(priorityX, epsilon: 0.5));
    expect(originX, moreOrLessEquals(priorityX, epsilon: 0.5));
  });

  testWidgets('editing an existing cue prefills its content and updates on save',
      (tester) async {
    final notes = [_note(id: 'n1', content: 'Original text', caseSection: CaseSection.damage)];
    final fake = await _pump(tester, notes: notes);

    await tester.tap(find.text('Original text'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Cue'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Updated text');
    await tester.tap(find.text('Update Cue'));
    await tester.pumpAndSettle();

    expect(fake.state.value!.single.content, 'Updated text');
  });

  testWidgets('deleting a cue via the overflow menu removes it', (tester) async {
    final notes = [_note(id: 'n1', content: 'Delete me', caseSection: CaseSection.damage)];
    final fake = await _pump(tester, notes: notes);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(fake.state.value, isEmpty);
    expect(find.text('No retained cues yet'), findsOneWidget);
  });
}
