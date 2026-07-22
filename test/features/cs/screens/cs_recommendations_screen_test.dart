import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/cs/models/cs_models.dart';
import 'package:marine_survey_app/features/cs/providers/cs_recommendation_provider.dart';
import 'package:marine_survey_app/features/cs/screens/cs_recommendations_screen.dart';

import '../../../support/fakes/fake_cs_recommendation_notifier.dart';
import '../../../support/pump_with_router.dart';

const _caseId = 'case-1';

CsRecommendationModel _rec({
  required String id,
  required String text,
  CsRecommendationStatus status = CsRecommendationStatus.open,
  String? sourceItemId,
}) =>
    CsRecommendationModel(
      id: id,
      caseId: _caseId,
      text: text,
      status: status,
      sourceItemId: sourceItemId,
    );

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<CsRecommendationModel> recs = const [],
}) async {
  final container = ProviderContainer(overrides: [
    csRecommendationProvider
        .overrideWith(() => FakeCsRecommendationNotifier(recs)),
  ]);
  addTearDown(container.dispose);
  await pumpWithRouter(
    tester,
    container: container,
    child: const CsRecommendationsScreen(caseId: _caseId),
  );
  return container;
}

void main() {
  group('CsRecommendationsScreen', () {
    testWidgets('empty state', (tester) async {
      await _pump(tester);
      expect(find.text('No recommendations yet'), findsOneWidget);
    });

    testWidgets('lists recommendations with an open-count header',
        (tester) async {
      await _pump(tester, recs: [
        _rec(id: '1', text: 'Repair crash rail'),
        _rec(id: '2', text: 'Replace tow wire', status: CsRecommendationStatus.closed),
      ]);
      expect(find.text('Repair crash rail'), findsOneWidget);
      expect(find.text('Replace tow wire'), findsOneWidget);
      expect(find.text('1 open of 2'), findsOneWidget);
    });

    testWidgets('closing an open recommendation flips its icon', (tester) async {
      final container = await _pump(tester, recs: [
        _rec(id: '1', text: 'Repair crash rail'),
      ]);
      // open → unchecked icon present
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      await tester.tap(find.byIcon(Icons.radio_button_unchecked));
      await tester.pumpAndSettle();
      final recs = container.read(csRecommendationProvider(_caseId)).value!;
      expect(recs.single.status, CsRecommendationStatus.closed);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('delete removes the recommendation', (tester) async {
      final container = await _pump(tester, recs: [
        _rec(id: '1', text: 'Repair crash rail'),
      ]);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(container.read(csRecommendationProvider(_caseId)).value, isEmpty);
    });

    testWidgets('add dialog inserts a recommendation', (tester) async {
      final container = await _pump(tester);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'New finding');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      final recs = container.read(csRecommendationProvider(_caseId)).value!;
      expect(recs.single.text, 'New finding');
    });
  });
}
