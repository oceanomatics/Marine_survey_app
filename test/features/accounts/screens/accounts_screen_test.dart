// test/features/accounts/screens/accounts_screen_test.dart

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
import '../../../support/fakes/fake_cost_estimate_items_notifier.dart';
import '../../../support/fakes/fake_repair_periods_notifier.dart';

const _caseId = 'case-1';

// costEstimateStatus is seeded to match _CostEstimateSelector's own
// no-invoices auto-derive target ('no_invoices_yet') — otherwise its
// post-frame callback fires an updateCaseRefs() call on every pump (real
// notifiers only, FakeCaseNotifier doesn't override it) straight at
// SupabaseService.client, which isn't initialised in a widget test.
CaseModel _case({String? baseCurrency = 'AUD', bool hasInvoices = false}) =>
    CaseModel(
      caseId: _caseId,
      technicalFileNo: 'AU-M53-056789',
      caseType: CaseType.hm,
      status: CaseStatus.open,
      baseCurrency: baseCurrency,
      costEstimateStatus:
          hasInvoices ? 'ongoing_partial_invoices' : 'no_invoices_yet',
    );

Future<void> _pump(
  WidgetTester tester, {
  List<RepairDocumentModel> docs = const [],
  List<CostEstimateItemModel> costItems = const [],
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
        costEstimateItemsProvider
            .overrideWith(() => FakeCostEstimateItemsNotifier(costItems)),
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
  testWidgets('shows two top-level tabs: Cost Estimate and Accounts',
      (tester) async {
    await _pump(tester);

    // Both labels appear twice: once as the tab, once as the visible
    // section header inside the tab body (Cost Estimate) / app bar title
    // (Accounts).
    expect(find.text('Cost Estimate'), findsWidgets);
    expect(find.text('Accounts'), findsWidgets);
  });

  testWidgets('Cost Estimate tab is shown by default, no FAB', (tester) async {
    await _pump(tester);

    expect(find.text('Further invoices still expected?'), findsNothing);
    expect(find.text('Purely Estimated — no invoices received yet'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('switching to the Accounts tab shows the Import Invoice FAB',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Import Invoice'), findsOneWidget);
  });

  testWidgets('Accounts tab splits into Submitted / Context Archive sub-tabs',
      (tester) async {
    final docs = [
      const RepairDocumentModel(
          id: 'd1', caseId: _caseId, submittedToInsurance: true),
      const RepairDocumentModel(
          id: 'd2', caseId: _caseId, submittedToInsurance: false),
    ];
    await _pump(tester, docs: docs, caseModel: _case(hasInvoices: true));
    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();

    expect(find.text('Submitted (1)'), findsOneWidget);
    expect(find.text('Context Archive (1)'), findsOneWidget);
  });

  testWidgets('empty Submitted tab shows its own empty state', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();

    expect(find.text('No submitted invoices yet'), findsOneWidget);
  });

  testWidgets('cost estimate total sums all line items', (tester) async {
    final items = [
      const CostEstimateItemModel(
          id: 'ce1', caseId: _caseId, amount: 15000, description: 'Towing'),
      const CostEstimateItemModel(
          id: 'ce2', caseId: _caseId, amount: 2500.5, description: 'Survey fees'),
    ];
    await _pump(tester, costItems: items);

    // _fmtMoney groups thousands: "AUD 17,500.50"
    expect(find.text('AUD 17,500.50'), findsOneWidget);
  });

  testWidgets('summary banner shows the no-invoices empty state when nothing is submitted',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();

    expect(
      find.text(
          'No invoices submitted yet — the account summary will populate once invoices are imported and submitted.'),
      findsOneWidget,
    );
  });

  testWidgets('no repair-period budget rollup shown when no period has budget items',
      (tester) async {
    await _pump(tester, periods: const [
      RepairPeriodModel(periodId: 'p1', caseId: _caseId, periodNo: 1),
    ]);

    expect(find.text('REPAIR-PERIOD BUDGET ESTIMATES'), findsNothing);
  });

  testWidgets(
      'repair-period budget rollup shows on the Cost Estimate tab, separate from the manual total',
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

    expect(find.text('REPAIR-PERIOD BUDGET ESTIMATES'), findsOneWidget);
    expect(find.text('Singapore drydock'), findsOneWidget);
    expect(find.text('USD 15,000.00 (2)'), findsOneWidget);
  });
}
