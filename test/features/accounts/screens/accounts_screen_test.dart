// test/features/accounts/screens/accounts_screen_test.dart
//
// Widget tests for the reconciliation-era Accounts screen. The screen shows a
// single view: an Estimate-vs-Actual + Reconciliation summary banner, a Cost
// Estimate Status editor, and Submitted / Context Archive sub-tabs listing the
// repair documents. The Import Invoice FAB is always available.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/accounts/screens/accounts_screen.dart';
import 'package:marine_survey_app/features/accounts/models/accounts_models.dart';
import 'package:marine_survey_app/features/accounts/providers/accounts_provider.dart';
import 'package:marine_survey_app/features/cases/models/case_model.dart';
import 'package:marine_survey_app/features/cases/providers/cases_provider.dart';
import 'package:marine_survey_app/features/survey/providers/damage_provider.dart';
import 'package:marine_survey_app/features/survey/providers/repair_period_provider.dart';
import 'package:marine_survey_app/features/survey/models/repair_period_model.dart';

import '../../../support/fakes/fake_repair_documents_notifier.dart';
import '../../../support/fakes/fake_case_notifier.dart';
import '../../../support/fakes/fake_damage_notifier.dart';
import '../../../support/fakes/fake_repair_periods_notifier.dart';

const _caseId = 'case-1';

// costEstimateStatus is seeded to match _CostEstimateSelector's own
// no-invoices auto-derive target ('no_invoices_yet') — otherwise its
// post-frame callback fires an updateCaseRefs() call on every pump (real
// notifiers only, FakeCaseNotifier doesn't override it) straight at
// SupabaseService.client, which isn't initialised in a widget test.
CaseModel _case({
  String? baseCurrency = 'AUD',
  bool hasInvoices = false,
  double? estimatedRepairCost,
}) =>
    CaseModel(
      caseId: _caseId,
      technicalFileNo: 'AU-M53-056789',
      caseType: CaseType.hm,
      status: CaseStatus.open,
      baseCurrency: baseCurrency,
      estimatedRepairCost: estimatedRepairCost,
      costEstimateStatus:
          hasInvoices ? 'ongoing_partial_invoices' : 'no_invoices_yet',
    );

Future<void> _pump(
  WidgetTester tester, {
  List<RepairDocumentModel> docs = const [],
  List<RepairPeriodModel> periods = const [],
  CaseModel? caseModel,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repairDocumentsProvider
            .overrideWith(() => FakeRepairDocumentsNotifier(docs)),
        caseProvider.overrideWith(() => FakeCaseNotifier(caseModel ?? _case())),
        damageProvider.overrideWith(() => FakeDamageNotifier(
              const DamageState(occurrences: [], damageItems: [], repairs: []),
            )),
        repairPeriodsProvider
            .overrideWith(() => FakeRepairPeriodsNotifier(periods)),
      ],
      child: const MaterialApp(home: AccountsScreen(caseId: _caseId)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the Estimate-vs-Actual and Reconciliation summary',
      (tester) async {
    await _pump(tester);

    expect(find.text('Accounts'), findsWidgets); // app bar title
    expect(find.text('ESTIMATE vs ACTUAL'), findsOneWidget);
    expect(find.text('RECONCILIATION'), findsOneWidget);
    expect(find.text('Submitted (actual gross)'), findsOneWidget);
    expect(find.text('Total (gross)'), findsOneWidget);
  });

  testWidgets('Import Invoice FAB is always available', (tester) async {
    await _pump(tester);

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Import Invoice'), findsOneWidget);
  });

  testWidgets('Cost Estimate Status editor shows its options and inclusions',
      (tester) async {
    await _pump(tester);

    expect(find.text('Cost Estimate Status'), findsOneWidget);
    expect(find.text('No Invoices Yet'), findsOneWidget);
    expect(find.text('Ongoing — Partial Invoices'), findsOneWidget);
    expect(find.text('Completed — All Invoices In'), findsOneWidget);
    expect(find.text('Cost Inclusions'), findsOneWidget);
    expect(find.text('Survey Fee Reserve'), findsOneWidget);
  });

  testWidgets('Submitted / Context Archive sub-tabs count the documents',
      (tester) async {
    final docs = [
      const RepairDocumentModel(
          id: 'd1', caseId: _caseId, submittedToInsurance: true),
      const RepairDocumentModel(
          id: 'd2', caseId: _caseId, submittedToInsurance: false),
    ];
    await _pump(tester, docs: docs, caseModel: _case(hasInvoices: true));

    expect(find.text('Submitted (1)'), findsOneWidget);
    expect(find.text('Context Archive (1)'), findsOneWidget);
  });

  testWidgets('empty Submitted sub-tab shows its own empty state',
      (tester) async {
    await _pump(tester);

    // Submitted is the default sub-tab.
    expect(find.text('No submitted invoices yet'), findsOneWidget);
  });

  testWidgets(
      'estimate vs actual: surveyor estimate, submitted total and variance',
      (tester) async {
    final docs = [
      const RepairDocumentModel(
        id: 'd1',
        caseId: _caseId,
        currency: 'AUD',
        totalIncTax: 30000,
        submittedToInsurance: true,
      ),
    ];
    await _pump(
      tester,
      docs: docs,
      caseModel: _case(hasInvoices: true, estimatedRepairCost: 50000),
    );

    expect(find.text('Estimated repair cost'), findsOneWidget);
    expect(find.text('AUD 50,000.00'), findsOneWidget);
    // Actual submitted is under the estimate: 30,000 vs 50,000.
    expect(find.text('Under estimate'), findsOneWidget);
    expect(find.text('AUD 20,000.00'), findsOneWidget);
  });

  testWidgets('repair-period budget rollup appears in the summary banner',
      (tester) async {
    final periods = [
      const RepairPeriodModel(
        periodId: 'p1',
        caseId: _caseId,
        periodNo: 1,
        title: 'Singapore drydock',
        budgetItems: [
          BudgetItem(
              itemId: 'b1',
              description: 'Steel renewal',
              amount: 12000,
              currency: 'USD'),
          BudgetItem(
              itemId: 'b2',
              description: 'Propeller repair',
              amount: 3000,
              currency: 'USD'),
        ],
        budgetBaseCurrency: 'USD',
      ),
      const RepairPeriodModel(periodId: 'p2', caseId: _caseId, periodNo: 2),
    ];
    await _pump(tester, periods: periods);

    // Face-value rollup of the two budget items (12,000 + 3,000).
    expect(find.text('Repair-period budget'), findsOneWidget);
    expect(find.text('AUD 15,000.00'), findsWidgets);
  });

  testWidgets('no repair-period budget row when no period has budget items',
      (tester) async {
    await _pump(tester, periods: const [
      RepairPeriodModel(periodId: 'p1', caseId: _caseId, periodNo: 1),
    ]);

    expect(find.text('Repair-period budget'), findsNothing);
  });
}
