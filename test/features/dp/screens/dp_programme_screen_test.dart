import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/dp/models/dp_models.dart';
import 'package:marine_survey_app/features/dp/providers/dp_programme_provider.dart';
import 'package:marine_survey_app/features/dp/screens/dp_programme_screen.dart';

import '../../../support/fakes/fake_dp_programme_notifier.dart';
import '../../../support/pump_with_router.dart';

const _caseId = 'case-1';

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  DpProgrammeModel? programme,
}) async {
  final container = ProviderContainer(overrides: [
    dpProgrammeProvider.overrideWith(() => FakeDpProgrammeNotifier(programme)),
  ]);
  addTearDown(container.dispose);
  await pumpWithRouter(
    tester,
    container: container,
    child: const DpProgrammeScreen(caseId: _caseId),
  );
  return container;
}

void main() {
  group('DpProgrammeScreen', () {
    testWidgets('renders result chips', (tester) async {
      await _pump(tester);
      expect(find.widgetWithText(ChoiceChip, 'Compliant'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Non-compliant'), findsOneWidget);
    });

    testWidgets('selecting a result updates the programme', (tester) async {
      final container = await _pump(tester);
      await tester
          .tap(find.widgetWithText(ChoiceChip, 'Compliant with findings'));
      await tester.pumpAndSettle();
      expect(container.read(dpProgrammeProvider(_caseId)).value?.overallResult,
          DpOverallResult.compliantWithFindings);
    });

    testWidgets('bump revision increments', (tester) async {
      final container = await _pump(tester,
          programme: const DpProgrammeModel(
              id: 'p', caseId: _caseId, revision: 2));
      await tester.tap(find.text('Bump revision'));
      await tester.pumpAndSettle();
      expect(
          container.read(dpProgrammeProvider(_caseId)).value?.revision, 3);
    });
  });
}
