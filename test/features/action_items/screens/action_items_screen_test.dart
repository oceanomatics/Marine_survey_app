// §4.7 (13 July 2026): case-level Action Items screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/action_items/providers/action_items_provider.dart';
import 'package:marine_survey_app/features/action_items/screens/action_items_screen.dart';
import 'package:marine_survey_app/features/correspondence/models/correspondence_model.dart';
import 'package:marine_survey_app/features/correspondence/providers/correspondence_provider.dart';

import '../../../support/fakes/fake_action_items_notifier.dart';
import '../../../support/fakes/fake_correspondence_notifier.dart';
import '../../../support/pump_with_router.dart';

const _caseId = 'case-1';

ActionItemModel _item({
  required String id,
  required String text,
  ActionItemStatus status = ActionItemStatus.open,
  bool pendingReview = false,
  String? sourceType,
  String? sourceId,
}) =>
    ActionItemModel(
      id: id,
      caseId: _caseId,
      text: text,
      status: status,
      pendingReview: pendingReview,
      sourceType: sourceType,
      sourceId: sourceId,
    );

CorrespondenceModel _corr({
  required String id,
  List<String> actions = const [],
}) =>
    CorrespondenceModel(
      id: id,
      caseId: _caseId,
      title: 'Test email',
      actions: actions,
      createdAt: DateTime(2026, 1, 1),
    );

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<ActionItemModel> items = const [],
  List<CorrespondenceModel> correspondence = const [],
}) async {
  final container = ProviderContainer(overrides: [
    actionItemsProvider.overrideWith(() => FakeActionItemsNotifier(items)),
    correspondenceProvider
        .overrideWith(() => FakeCorrespondenceNotifier(correspondence)),
  ]);
  addTearDown(container.dispose);
  await pumpWithRouter(
    tester,
    container: container,
    child: const ActionItemsScreen(caseId: _caseId),
  );
  return container;
}

void main() {
  group('ActionItemsScreen', () {
    testWidgets('empty state shows the no-tasks message for the Open filter',
        (tester) async {
      await _pump(tester);
      expect(find.text('No open tasks.'), findsOneWidget);
    });

    testWidgets('open tasks are listed under the Tasks section', (tester) async {
      await _pump(tester, items: [
        _item(id: '1', text: 'Book flights'),
        _item(id: '2', text: 'Send invoice', status: ActionItemStatus.done),
      ]);
      expect(find.text('Book flights'), findsOneWidget);
      // "Send invoice" is done, not open — not shown under the default Open
      // filter.
      expect(find.text('Send invoice'), findsNothing);
    });

    testWidgets('switching to the Done filter shows completed tasks',
        (tester) async {
      await _pump(tester, items: [
        _item(id: '1', text: 'Book flights'),
        _item(id: '2', text: 'Send invoice', status: ActionItemStatus.done),
      ]);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Send invoice'), findsOneWidget);
      expect(find.text('Book flights'), findsNothing);
    });

    testWidgets('tapping the checkbox marks an open task done', (tester) async {
      await _pump(tester, items: [_item(id: '1', text: 'Book flights')]);
      expect(find.text('Book flights'), findsOneWidget);

      await tester.tap(find.byKey(const Key('task-checkbox-1')));
      await tester.pumpAndSettle();

      // Still on the Open filter — a now-done item drops out of view.
      expect(find.text('Book flights'), findsNothing);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Book flights'), findsOneWidget);
    });

    testWidgets('a pendingReview item shows in its own section with '
        'confirm/dismiss actions, not in the Tasks list', (tester) async {
      await _pump(tester, items: [
        _item(
            id: '1',
            text: 'Call the broker',
            pendingReview: true,
            sourceType: 'correspondence'),
      ]);
      expect(find.text('Pending Review'), findsOneWidget);
      expect(find.text('Call the broker'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('confirming a pending-review item moves it into the open '
        'task list', (tester) async {
      await _pump(tester, items: [
        _item(
            id: '1',
            text: 'Call the broker',
            pendingReview: true,
            sourceType: 'correspondence'),
      ]);
      expect(find.text('Pending Review'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      expect(find.text('Pending Review'), findsNothing);
      expect(find.text('Call the broker'), findsOneWidget); // now in Tasks
    });

    testWidgets(
        'an un-tracked action string from correspondence shows under '
        '"New from Correspondence", and tracking it creates a pending-review '
        'item', (tester) async {
      await _pump(
        tester,
        correspondence: [
          _corr(id: 'corr-1', actions: ['Confirm crew list with Master']),
        ],
      );

      expect(find.text('New from Correspondence'), findsOneWidget);
      expect(find.text('Confirm crew list with Master'), findsOneWidget);

      await tester.tap(find.text('Track'));
      await tester.pumpAndSettle();

      // Once tracked it's a pendingReview candidate, not a raw suggestion
      // anymore.
      expect(find.text('New from Correspondence'), findsNothing);
      expect(find.text('Pending Review'), findsOneWidget);
    });

    testWidgets(
        'an already-tracked correspondence action is not offered again '
        'under "New from Correspondence"', (tester) async {
      await _pump(
        tester,
        items: [
          _item(
            id: '1',
            text: 'Confirm crew list with Master',
            pendingReview: true,
            sourceType: 'correspondence',
            sourceId: 'corr-1',
          ),
        ],
        correspondence: [
          _corr(id: 'corr-1', actions: ['Confirm crew list with Master']),
        ],
      );

      // Already tracked (as a pending-review item) — must not also appear
      // as an untracked suggestion.
      expect(find.text('New from Correspondence'), findsNothing);
      expect(find.text('Pending Review'), findsOneWidget);
      expect(find.text('Confirm crew list with Master'), findsOneWidget);
    });

    testWidgets('FAB opens the add-task sheet and submitting adds a manual '
        'task', (tester) async {
      await _pump(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Add Task'), findsOneWidget);
      await tester.enterText(
          find.byType(TextField), 'Chase the loss adjuster');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('Add Task'), findsNothing);
      expect(find.text('Chase the loss adjuster'), findsOneWidget);
    });
  });
}
