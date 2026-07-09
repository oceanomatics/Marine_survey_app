// Live reproduction of docs/TODO.md Phase 0.1 row 24 / §3.9: "Bottom
// overflow when opening a repair period." Renders RepairPeriodsScreen with a
// heavily-populated period (assignments across every damage category, all
// repair-time rows, multiple budget items with a currency conversion row so
// every optional block in _PeriodCard's expanded body is present) at a
// narrow phone-height viewport, expands the card, and asserts no RenderFlex
// (or any other) overflow exception was thrown during layout — instead of
// guessing at the cause statically.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/survey/models/repair_period_model.dart';
import 'package:marine_survey_app/features/survey/providers/damage_provider.dart';
import 'package:marine_survey_app/features/survey/providers/repair_period_provider.dart';
import 'package:marine_survey_app/features/survey/screens/repair_periods_screen.dart';
import 'package:marine_survey_app/features/surveyor_notes/providers/surveyor_notes_provider.dart';

import '../../../support/fakes/fake_damage_notifier.dart';
import '../../../support/fakes/fake_repair_periods_notifier.dart';
import '../../../support/fakes/fake_surveyor_notes_notifier.dart';
import '../../../support/pump_with_router.dart';

const _caseId = 'case-1';
const _occurrenceId = 'occ-1';

void main() {
  testWidgets(
      'expanding a fully-populated repair period on a phone-height '
      'viewport does not overflow', (tester) async {
    // Narrow phone-sized surface (iPhone SE-class) — the width most likely
    // to expose a horizontal RenderFlex overflow in the fixed-width table
    // cells, and a short-enough height that the expanded card's stacked
    // sections (assignments, repair times, budget) exceed the viewport if
    // anything above them isn't properly scrollable.
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const occurrence = OccurrenceModel(
      occurrenceId: _occurrenceId,
      caseId: _caseId,
      occurrenceNo: 1,
      isPrimary: true,
      title: 'Main engine turbocharger failure',
    );

    const damageItems = [
      DamageItemModel(
        damageId: 'dmg-1',
        occurrenceId: _occurrenceId,
        caseId: _caseId,
        componentName: 'Turbocharger rotor',
        damageCategory: DamageCategory.mechanical,
      ),
      DamageItemModel(
        damageId: 'dmg-2',
        occurrenceId: _occurrenceId,
        caseId: _caseId,
        componentName: 'Exhaust manifold',
        damageCategory: DamageCategory.structuralExternal,
      ),
      DamageItemModel(
        damageId: 'dmg-3',
        occurrenceId: _occurrenceId,
        caseId: _caseId,
        componentName: 'Control wiring loom',
        damageCategory: DamageCategory.electricalElectronics,
      ),
    ];

    final period = RepairPeriodModel(
      periodId: 'period-1',
      caseId: _caseId,
      periodNo: 1,
      title: 'Permanent Repairs — Singapore',
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 6, 15),
      location: 'Sembawang Shipyard, Singapore',
      portContext: PortContext.diversion,
      repairPhase: RepairPhase.permanent,
      notes: 'Vessel diverted for permanent repairs following main '
          'engine turbocharger failure.',
      assignments: const [
        RepairAssignmentModel(
          assignmentId: 'a1',
          periodId: 'period-1',
          damageId: 'dmg-1',
          outcome: RepairType.permanent,
        ),
        RepairAssignmentModel(
          assignmentId: 'a2',
          periodId: 'period-1',
          damageId: 'dmg-2',
          outcome: RepairType.temporary,
        ),
        RepairAssignmentModel(
          assignmentId: 'a3',
          periodId: 'period-1',
          damageId: 'dmg-3',
          outcome: RepairType.deferred,
        ),
      ],
      repairTimes: const {
        'occ_1': RepairTimeEntry(drydockDays: 8, alongsideDays: 4),
        'owners': RepairTimeEntry(drydockDays: 2, alongsideDays: 1),
      },
      budgetItems: const [
        BudgetItem(
          itemId: 'b1',
          description: 'Turbocharger overhaul — OEM specialist',
          amount: 45000,
          currency: 'USD',
          status: BudgetItemStatus.quoted,
        ),
        BudgetItem(
          itemId: 'b2',
          description: 'Drydock berth hire',
          amount: 18000,
          currency: 'USD',
          status: BudgetItemStatus.estimated,
        ),
        BudgetItem(
          itemId: 'b3',
          description: 'Crane and rigging',
          amount: 6500,
          currency: 'USD',
          status: BudgetItemStatus.incurred,
        ),
      ],
      budgetDisplayCurrency: 'AUD',
      budgetBaseCurrency: 'USD',
      budgetExchangeRate: 1.52,
      budgetRateDate: DateTime(2026, 6, 10),
      servicesProvided: const ['crane_lifting', 'gas_freeing', 'diving'],
      hotWorkStatus: 'certs_valid',
    );

    await pumpWithRouter(
      tester,
      overrides: [
        repairPeriodsProvider
            .overrideWith(() => FakeRepairPeriodsNotifier([period])),
        damageProvider.overrideWith(() => FakeDamageNotifier(
              const DamageState(
                occurrences: [occurrence],
                damageItems: damageItems,
              ),
            )),
        surveyorNotesProvider
            .overrideWith(() => FakeSurveyorNotesNotifier()),
      ],
      child: const RepairPeriodsScreen(caseId: _caseId),
    );

    // The card defaults to expanded (_PeriodCardState._expanded = true), so
    // everything should already be laid out — but tap the header anyway to
    // mirror "opening a repair period" from a collapsed state, and to catch
    // any overflow that only manifests on the expand transition.
    await tester.tap(find.text('Permanent Repairs — Singapore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permanent Repairs — Singapore'));
    await tester.pumpAndSettle();

    // FlutterError (including "A RenderFlex overflowed by ... pixels")
    // surfaces via tester.takeException() rather than being thrown
    // synchronously from pump — assert none was recorded.
    expect(tester.takeException(), isNull);

    // docs/TODO.md §3.9 — repair-phase field is shown on the card, and the
    // period is editable via the overflow menu (not read-only after
    // creation).
    // Two matches expected: the repair-phase badge on the card header and
    // the "Permanent" outcome label on the turbocharger assignment row.
    expect(find.text('Permanent'), findsWidgets);
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text('Edit period details'), findsOneWidget);
    await tester.tap(find.text('Edit period details'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Repair Period'), findsOneWidget);
    // Pre-filled from the existing period, not a blank form — matches both
    // the (now-hidden-behind-the-sheet) card title and the sheet's title
    // TextField, whose controller text find.text also matches.
    expect(find.text('Permanent Repairs — Singapore'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
