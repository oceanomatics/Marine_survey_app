import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/survey/models/repair_period_model.dart';
import 'package:marine_survey_app/features/survey/providers/damage_provider.dart';
import 'package:marine_survey_app/features/survey/providers/repair_period_provider.dart';

class FakeRepairPeriodsNotifier extends RepairPeriodsNotifier {
  FakeRepairPeriodsNotifier(this._seed);
  final List<RepairPeriodModel> _seed;
  int _counter = 0;

  @override
  Future<List<RepairPeriodModel>> build(String caseId) async => _seed;

  @override
  Future<RepairPeriodModel> addPeriod(RepairPeriodModel period) async {
    final created = RepairPeriodModel(
      periodId: 'fake-period-${++_counter}',
      caseId: period.caseId,
      periodNo: period.periodNo,
      title: period.title,
      startDate: period.startDate,
      endDate: period.endDate,
      location: period.location,
      portContext: period.portContext,
      repairPhase: period.repairPhase,
      notes: period.notes,
      servicesProvided: period.servicesProvided,
      servicesProvidedNotes: period.servicesProvidedNotes,
      hotWorkStatus: period.hotWorkStatus,
      hotWorkNotes: period.hotWorkNotes,
    );
    state = AsyncData([...state.value ?? [], created]);
    return created;
  }

  // repair_period_provider.dart:75 — persists edits to a period's own header
  // fields (title/dates/location/port context/phase/notes/services/hot-work),
  // distinct from the assignment/repair-time/budget mutations below. Without
  // this override the fake fell through to the real Supabase-backed
  // implementation during a widget test.
  @override
  Future<void> updatePeriod(RepairPeriodModel period) async {
    final current = state.value ?? [];
    state = AsyncData(current
        .map((p) => p.periodId == period.periodId ? period : p)
        .toList());
  }

  @override
  Future<void> deletePeriod(String periodId) async {
    final current = state.value ?? [];
    state = AsyncData(current.where((p) => p.periodId != periodId).toList());
  }

  @override
  Future<void> saveAssignments(
    String periodId,
    Map<String, RepairType> outcomes,
    Map<String, bool> concerning,
    Map<String, String?> notes,
  ) async {
    final assignments = outcomes.entries
        .map((e) => RepairAssignmentModel(
              assignmentId: 'fake-assign-${e.key}',
              periodId: periodId,
              damageId: e.key,
              outcome: e.value,
              isConcerningAverage: concerning[e.key] ?? true,
              notes: notes[e.key],
            ))
        .toList();
    final current = state.value ?? [];
    state = AsyncData(current
        .map((p) => p.periodId == periodId
            ? RepairPeriodModel(
                periodId: p.periodId,
                caseId: p.caseId,
                periodNo: p.periodNo,
                title: p.title,
                startDate: p.startDate,
                endDate: p.endDate,
                location: p.location,
                portContext: p.portContext,
                notes: p.notes,
                assignments: assignments,
                repairTimes: p.repairTimes,
                budgetItems: p.budgetItems,
                budgetDisplayCurrency: p.budgetDisplayCurrency,
                budgetBaseCurrency: p.budgetBaseCurrency,
                budgetExchangeRate: p.budgetExchangeRate,
                budgetRateDate: p.budgetRateDate,
                servicesProvided: p.servicesProvided,
                servicesProvidedNotes: p.servicesProvidedNotes,
                hotWorkStatus: p.hotWorkStatus,
                hotWorkNotes: p.hotWorkNotes,
              )
            : p)
        .toList());
  }

  @override
  Future<void> saveRepairTimes(
      String periodId, Map<String, RepairTimeEntry> times) async {
    final current = state.value ?? [];
    state = AsyncData(current
        .map((p) =>
            p.periodId == periodId ? p.copyWith(repairTimes: times) : p)
        .toList());
  }

  @override
  Future<void> addBudgetItem(String periodId, BudgetItem item) async {
    final periods = state.value ?? [];
    final period = periods.firstWhere((p) => p.periodId == periodId);
    final newItem = BudgetItem(
      itemId: item.itemId.isEmpty ? 'fake-budget-${++_counter}' : item.itemId,
      description: item.description,
      amount: item.amount,
      currency: item.currency,
      status: item.status,
    );
    final updated = [...period.budgetItems, newItem];
    state = AsyncData(periods
        .map((p) =>
            p.periodId == periodId ? p.copyWith(budgetItems: updated) : p)
        .toList());
  }

  @override
  Future<void> updateBudgetItem(String periodId, BudgetItem item) async {
    final periods = state.value ?? [];
    final period = periods.firstWhere((p) => p.periodId == periodId);
    final updated = period.budgetItems
        .map((b) => b.itemId == item.itemId ? item : b)
        .toList();
    state = AsyncData(periods
        .map((p) =>
            p.periodId == periodId ? p.copyWith(budgetItems: updated) : p)
        .toList());
  }

  @override
  Future<void> removeBudgetItem(String periodId, String itemId) async {
    final periods = state.value ?? [];
    final period = periods.firstWhere((p) => p.periodId == periodId);
    final updated =
        period.budgetItems.where((b) => b.itemId != itemId).toList();
    state = AsyncData(periods
        .map((p) =>
            p.periodId == periodId ? p.copyWith(budgetItems: updated) : p)
        .toList());
  }

  @override
  Future<void> saveBudgetDisplay({
    required String periodId,
    required String displayCurrency,
    required String baseCurrency,
    double? exchangeRate,
    DateTime? rateDate,
  }) async {
    final periods = state.value ?? [];
    state = AsyncData(periods
        .map((p) => p.periodId == periodId
            ? p.copyWith(
                budgetDisplayCurrency: displayCurrency,
                budgetBaseCurrency: baseCurrency,
                budgetExchangeRate: exchangeRate,
                budgetRateDate: rateDate,
              )
            : p)
        .toList());
  }
}
