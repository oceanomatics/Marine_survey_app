import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/pi/models/pi_models.dart';
import 'package:marine_survey_app/features/pi/providers/pi_relied_upon_provider.dart';
import 'package:marine_survey_app/features/pi/screens/pi_relied_upon_screen.dart';

import '../../../support/fakes/fake_pi_relied_upon_notifier.dart';
import '../../../support/pump_with_router.dart';

const _caseId = 'case-1';

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<PiReliedUponModel> items = const [],
}) async {
  final container = ProviderContainer(overrides: [
    piReliedUponProvider.overrideWith(() => FakePiReliedUponNotifier(items)),
  ]);
  addTearDown(container.dispose);
  await pumpWithRouter(
    tester,
    container: container,
    child: const PiReliedUponScreen(caseId: _caseId),
  );
  return container;
}

void main() {
  group('PiReliedUponScreen', () {
    testWidgets('empty state', (tester) async {
      await _pump(tester);
      expect(find.text('Nothing relied upon recorded yet'), findsOneWidget);
    });

    testWidgets('lists items with numbering + reference', (tester) async {
      await _pump(tester, items: const [
        PiReliedUponModel(
            id: '1',
            caseId: _caseId,
            description: 'Class survey report',
            reference: 'DNV, 12 Jan 2026'),
      ]);
      expect(find.text('Class survey report'), findsOneWidget);
      expect(find.text('DNV, 12 Jan 2026'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('delete removes the item', (tester) async {
      final container = await _pump(tester, items: const [
        PiReliedUponModel(id: '1', caseId: _caseId, description: 'x'),
      ]);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(container.read(piReliedUponProvider(_caseId)).value, isEmpty);
    });

    testWidgets('add dialog inserts an item', (tester) async {
      final container = await _pump(tester);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Fact or document relied upon'),
          'Engine log');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      final items = container.read(piReliedUponProvider(_caseId)).value!;
      expect(items.single.description, 'Engine log');
    });
  });
}
