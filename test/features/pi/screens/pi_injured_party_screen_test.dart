import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/pi/models/pi_models.dart';
import 'package:marine_survey_app/features/pi/providers/pi_injured_party_provider.dart';
import 'package:marine_survey_app/features/pi/screens/pi_injured_party_screen.dart';

import '../../../support/fakes/fake_pi_injured_party_notifier.dart';
import '../../../support/pump_with_router.dart';

const _caseId = 'case-1';

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<PiInjuredPartyModel> parties = const [],
}) async {
  final container = ProviderContainer(overrides: [
    piInjuredPartyProvider
        .overrideWith(() => FakePiInjuredPartyNotifier(parties)),
  ]);
  addTearDown(container.dispose);
  await pumpWithRouter(
    tester,
    container: container,
    child: const PiInjuredPartyScreen(caseId: _caseId),
  );
  return container;
}

void main() {
  group('PiInjuredPartyScreen', () {
    testWidgets('empty state', (tester) async {
      await _pump(tester);
      expect(find.text('No injured parties recorded'), findsOneWidget);
    });

    testWidgets('lists a party (role · name + condition)', (tester) async {
      await _pump(tester, parties: const [
        PiInjuredPartyModel(
          id: '1',
          caseId: _caseId,
          personRole: 'Crew',
          personName: 'AB',
          condition: 'Fractured wrist',
        ),
      ]);
      expect(find.text('Crew · AB'), findsOneWidget);
      expect(find.text('Fractured wrist'), findsOneWidget);
    });

    testWidgets('delete removes the entry', (tester) async {
      final container = await _pump(tester, parties: const [
        PiInjuredPartyModel(id: '1', caseId: _caseId, personRole: 'Crew'),
      ]);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(container.read(piInjuredPartyProvider(_caseId)).value, isEmpty);
    });

    testWidgets('add dialog inserts an entry', (tester) async {
      final container = await _pump(tester);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Condition'), 'Concussion');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      final parties = container.read(piInjuredPartyProvider(_caseId)).value!;
      expect(parties.single.condition, 'Concussion');
    });
  });
}
