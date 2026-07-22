import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/cs/models/cs_models.dart';
import 'package:marine_survey_app/features/cs/providers/cs_inspection_provider.dart';
import 'package:marine_survey_app/features/cs/providers/cs_recommendation_provider.dart';
import 'package:marine_survey_app/features/cs/providers/cs_template_provider.dart';
import 'package:marine_survey_app/features/cs/screens/cs_inspection_screen.dart';

import '../../../support/fakes/fake_cs_inspection_notifier.dart';
import '../../../support/fakes/fake_cs_recommendation_notifier.dart';
import '../../../support/pump_with_router.dart';

const _caseId = 'case-1';

final _template = <CsTemplateItemModel>[
  const CsTemplateItemModel(
    id: 't-h',
    templateId: 'tmpl',
    section: '5.0',
    refNo: '5.0',
    label: 'Hull Structure & Condition',
    gradeApplicable: false,
    sortOrder: 500,
  ),
  const CsTemplateItemModel(
    id: 't-1',
    templateId: 'tmpl',
    section: '5.0',
    refNo: '5.1',
    label: 'Deck & shell plating',
    gradeApplicable: true,
    sortOrder: 510,
  ),
];

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<CsTemplateItemModel>? template,
  List<CsInspectionItemModel> inspection = const [],
}) async {
  final container = ProviderContainer(overrides: [
    csTemplateItemsProvider
        .overrideWith((ref, vesselType) async => template ?? _template),
    csInspectionProvider
        .overrideWith(() => FakeCsInspectionNotifier(inspection)),
    csRecommendationProvider
        .overrideWith(() => FakeCsRecommendationNotifier(const [])),
  ]);
  addTearDown(container.dispose);
  await pumpWithRouter(
    tester,
    container: container,
    child: const CsInspectionScreen(caseId: _caseId),
  );
  return container;
}

void main() {
  group('CsInspectionScreen', () {
    testWidgets('empty template shows the seed hint', (tester) async {
      await _pump(tester, template: const []);
      expect(find.textContaining('No AHTS template seeded'), findsOneWidget);
    });

    testWidgets('renders the section header and gradable item', (tester) async {
      await _pump(tester);
      expect(find.textContaining('Hull Structure & Condition'), findsOneWidget);
      expect(find.text('Deck & shell plating'), findsOneWidget);
      // all four grade chips present for the gradable item
      expect(find.widgetWithText(ChoiceChip, 'Satisfactory'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Unsatisfactory'), findsOneWidget);
    });

    testWidgets('tapping a grade chip creates an inspection item',
        (tester) async {
      final container = await _pump(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Good'));
      await tester.pumpAndSettle();
      final items = container.read(csInspectionProvider(_caseId)).value!;
      expect(items, hasLength(1));
      expect(items.single.grade, CsGrade.good);
      expect(items.single.templateItemId, 't-1');
    });

    testWidgets('marking unsatisfactory offers to add a recommendation',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Unsatisfactory'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Add recommendation'), findsOneWidget);
    });
  });
}
