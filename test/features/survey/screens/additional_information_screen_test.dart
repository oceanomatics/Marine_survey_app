// test/features/survey/screens/additional_information_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/survey/screens/additional_information_screen.dart';
import 'package:marine_survey_app/features/survey/providers/other_matters_clauses_provider.dart';
import 'package:marine_survey_app/features/cases/models/case_model.dart';
import 'package:marine_survey_app/features/cases/providers/cases_provider.dart';
import 'package:marine_survey_app/features/reports/providers/report_provider.dart' show ClauseModel;
import 'package:marine_survey_app/features/surveyor_notes/providers/surveyor_notes_provider.dart';

import '../../../support/fakes/fake_case_notifier.dart';
import '../../../support/fakes/fake_surveyor_notes_notifier.dart';

const _caseId = 'case-1';

CaseModel _case() => const CaseModel(
      caseId: _caseId,
      technicalFileNo: 'AU-M53-056789',
      caseType: CaseType.hm,
      status: CaseStatus.open,
    );

Future<FakeCaseNotifier> _pump(
  WidgetTester tester, {
  List<ClauseModel> clauses = const [],
  CaseModel? caseModel,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final fake = FakeCaseNotifier(caseModel ?? _case());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        caseProvider.overrideWith(() => fake),
        otherMattersClausesProvider.overrideWith((ref, format) async => clauses),
        surveyorNotesProvider.overrideWith(() => FakeSurveyorNotesNotifier()),
      ],
      child: const MaterialApp(home: AdditionalInformationScreen(caseId: _caseId)),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('loads and shows all 4 cue-register subsections plus Advice to Assured',
      (tester) async {
    await _pump(tester);

    expect(find.text('Previous Work on the Damaged Item'), findsOneWidget);
    expect(find.text('Extra Expenses to Reduce Delay'), findsOneWidget);
    expect(find.text('Contractual / Hire'), findsOneWidget);
    expect(find.text('Other Matters of Relevance'), findsOneWidget);
    expect(find.text('Advice to Assured'), findsOneWidget);
  });

  testWidgets('no clauses configured shows the empty message', (tester) async {
    await _pump(tester);

    expect(find.text('No candidate clauses configured.'), findsOneWidget);
  });

  testWidgets('ticking a clause persists it via updateOtherMattersClauses',
      (tester) async {
    final fake = await _pump(tester, clauses: const [
      ClauseModel(
        clauseId: 'cl1',
        formatType: 'abl',
        clauseType: 'other_matters',
        clauseLabel: 'Salvage rights reserved',
        clauseText: 'The Assured\'s rights of salvage are expressly reserved.',
      ),
    ]);

    expect(find.text('Salvage rights reserved'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(fake.state.value!.otherMattersClauseIds, contains('cl1'));
  });

  testWidgets('an already-ticked clause shows checked and unticking removes it',
      (tester) async {
    final fake = await _pump(
      tester,
      clauses: const [
        ClauseModel(
          clauseId: 'cl1',
          formatType: 'abl',
          clauseType: 'other_matters',
          clauseLabel: 'Salvage rights reserved',
          clauseText: 'Text',
        ),
      ],
      caseModel: _case().copyWith(otherMattersClauseIds: ['cl1']),
    );

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(fake.state.value!.otherMattersClauseIds, isNot(contains('cl1')));
  });

  testWidgets('typing additional notes saves after the debounce', (tester) async {
    final fake = await _pump(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Enter additional notes…'),
        'Charter party terminated 1 August 2026.');
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(fake.state.value!.otherMattersNotes,
        'Charter party terminated 1 August 2026.');
  });
}
