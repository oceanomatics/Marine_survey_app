import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/dp/models/dp_models.dart';
import 'package:marine_survey_app/features/dp/providers/dp_test_provider.dart';
import 'package:marine_survey_app/features/dp/screens/dp_test_screen.dart';

import '../../../support/fakes/fake_dp_test_notifier.dart';
import '../../../support/pump_with_router.dart';

const _caseId = 'case-1';

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<DpTestModel> tests = const [],
}) async {
  final container = ProviderContainer(overrides: [
    dpTestProvider.overrideWith(() => FakeDpTestNotifier(tests)),
  ]);
  addTearDown(container.dispose);
  await pumpWithRouter(
    tester,
    container: container,
    child: const DpTestScreen(caseId: _caseId),
  );
  return container;
}

void main() {
  group('DpTestScreen', () {
    testWidgets('empty state', (tester) async {
      await _pump(tester);
      expect(find.text('No tests recorded yet'), findsOneWidget);
    });

    testWidgets('lists a test with number + name', (tester) async {
      await _pump(tester, tests: const [
        DpTestModel(
            testId: '1',
            caseId: _caseId,
            testNo: 26,
            testName: 'Network storm'),
      ]);
      expect(find.textContaining('Network storm'), findsOneWidget);
      expect(find.textContaining('#26'), findsOneWidget);
    });

    testWidgets('tapping a result chip sets the result', (tester) async {
      final container = await _pump(tester, tests: const [
        DpTestModel(testId: '1', caseId: _caseId, testName: 'x'),
      ]);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Fail'));
      await tester.pumpAndSettle();
      final t = container.read(dpTestProvider(_caseId)).value!.single;
      expect(t.result, DpTestResult.fail);
    });

    testWidgets('WCF tested checkbox toggles the flag', (tester) async {
      final container = await _pump(tester, tests: const [
        DpTestModel(testId: '1', caseId: _caseId, testName: 'x'),
      ]);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(
          container.read(dpTestProvider(_caseId)).value!.single.wcfTested, true);
    });

    testWidgets('add dialog inserts a test', (tester) async {
      final container = await _pump(tester);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Test name'), 'Blackout recovery');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(container.read(dpTestProvider(_caseId)).value!.single.testName,
          'Blackout recovery');
    });
  });
}
