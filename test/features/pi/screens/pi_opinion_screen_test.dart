import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/pi/models/pi_models.dart';
import 'package:marine_survey_app/features/pi/providers/pi_opinion_provider.dart';
import 'package:marine_survey_app/features/pi/screens/pi_opinion_screen.dart';

import '../../../support/fakes/fake_pi_opinion_notifier.dart';
import '../../../support/pump_with_router.dart';

const _caseId = 'case-1';

PiOpinionModel _op({
  required String id,
  required String text,
  String? heading,
  bool notConcluded = false,
}) =>
    PiOpinionModel(
      id: id,
      caseId: _caseId,
      opinionText: text,
      heading: heading,
      notConcluded: notConcluded,
    );

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<PiOpinionModel> opinions = const [],
}) async {
  final container = ProviderContainer(overrides: [
    piOpinionProvider.overrideWith(() => FakePiOpinionNotifier(opinions)),
  ]);
  addTearDown(container.dispose);
  await pumpWithRouter(
    tester,
    container: container,
    child: const PiOpinionScreen(caseId: _caseId),
  );
  return container;
}

void main() {
  group('PiOpinionScreen', () {
    testWidgets('empty state', (tester) async {
      await _pump(tester);
      expect(find.textContaining('No opinions yet'), findsOneWidget);
    });

    testWidgets('lists opinions with heading + text', (tester) async {
      await _pump(tester, opinions: [
        _op(id: '1', heading: 'Root cause', text: 'The failure was pre-existing.'),
      ]);
      expect(find.text('Root cause'), findsOneWidget);
      expect(find.text('The failure was pre-existing.'), findsOneWidget);
    });

    testWidgets('toggling a qualifier chip updates state', (tester) async {
      final container = await _pump(tester, opinions: [
        _op(id: '1', text: 'x'),
      ]);
      await tester.tap(find.widgetWithText(FilterChip, 'Not concluded (want of data)'));
      await tester.pumpAndSettle();
      final o = container.read(piOpinionProvider(_caseId)).value!.single;
      expect(o.notConcluded, true);
    });

    testWidgets('delete removes the opinion', (tester) async {
      final container = await _pump(tester, opinions: [_op(id: '1', text: 'x')]);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(container.read(piOpinionProvider(_caseId)).value, isEmpty);
    });

    testWidgets('add dialog inserts an opinion', (tester) async {
      final container = await _pump(tester);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Opinion'), 'New opinion');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      final ops = container.read(piOpinionProvider(_caseId)).value!;
      expect(ops.single.opinionText, 'New opinion');
    });
  });
}
