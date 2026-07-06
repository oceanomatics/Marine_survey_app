import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/checklist/providers/checklist_provider.dart';
import 'package:marine_survey_app/features/checklist/screens/checklist_screen.dart';

import '../../../support/fakes/fake_checklist_notifier.dart';

const _caseId = 'case-1';

ChecklistItem _item({
  required String id,
  required ChecklistStage stage,
  required int itemNo,
  required String text,
  bool completed = false,
  bool isCustom = false,
}) =>
    ChecklistItem(
      checklistId: id,
      caseId: _caseId,
      stage: stage,
      itemNo: itemNo,
      itemText: text,
      completed: completed,
      isCustom: isCustom,
    );

Future<void> _pump(WidgetTester tester, List<ChecklistItem> seed) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        checklistProvider.overrideWith(() => FakeChecklistNotifier(seed)),
      ],
      child: const MaterialApp(
        home: ChecklistScreen(caseId: _caseId),
      ),
    ),
  );
  await tester.pumpAndSettle();
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

    testWidgets('progress header reflects the ticked/total item count', (tester) async {
      await _pump(tester, [
        _item(id: '1', stage: ChecklistStage.preSurvey, itemNo: 1, text: 'Item A', completed: true),
        _item(id: '2', stage: ChecklistStage.preSurvey, itemNo: 2, text: 'Item B'),
      ]);

      expect(find.text('1 of 2 complete'), findsOneWidget);
    });

    testWidgets('per-stage tab shows its own done/total count', (tester) async {
      await _pump(tester, [
        _item(id: '1', stage: ChecklistStage.preSurvey, itemNo: 1, text: 'Item A', completed: true),
        _item(id: '2', stage: ChecklistStage.preSurvey, itemNo: 2, text: 'Item B'),
        _item(id: '3', stage: ChecklistStage.onVessel, itemNo: 1, text: 'Item C'),
      ]);

      expect(find.text('1/2'), findsOneWidget); // Pre-Survey tab
      expect(find.text('0/1'), findsOneWidget); // On Vessel tab
    });

    testWidgets('tapping an item toggles it complete', (tester) async {
      await _pump(tester, [
        _item(id: '1', stage: ChecklistStage.preSurvey, itemNo: 1, text: 'Check tide tables'),
      ]);

      // Not completed yet — no checkmark icon rendered for the item box.
      expect(find.byIcon(Icons.check), findsNothing);

      await tester.tap(find.text('Check tide tables'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('1 of 1 complete'), findsOneWidget);
    });

    testWidgets('tapping a completed item toggles it back to incomplete', (tester) async {
      await _pump(tester, [
        _item(id: '1', stage: ChecklistStage.preSurvey, itemNo: 1, text: 'Check tide tables', completed: true),
      ]);

      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.text('Check tide tables'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNothing);
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
  });
}
