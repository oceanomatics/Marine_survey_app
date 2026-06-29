// lib/features/survey/providers/repair_period_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/repair_period_model.dart';
import '../providers/damage_provider.dart';
import '../../../core/api/supabase_client.dart';

const _uuid = Uuid();

final repairPeriodsProvider = AsyncNotifierProviderFamily<
    RepairPeriodsNotifier, List<RepairPeriodModel>, String>(
  RepairPeriodsNotifier.new,
);

class RepairPeriodsNotifier
    extends FamilyAsyncNotifier<List<RepairPeriodModel>, String> {
  @override
  Future<List<RepairPeriodModel>> build(String caseId) => _fetch();

  Future<List<RepairPeriodModel>> _fetch() async {
    final periodsRaw = await SupabaseService.client
        .from('repair_periods')
        .select()
        .eq('case_id', arg)
        .order('period_no');

    final periods = periodsRaw as List;
    if (periods.isEmpty) return [];

    final periodIds = periods
        .map((p) => (p as Map<String, dynamic>)['period_id'] as String)
        .toList();

    final assignmentsRaw = await SupabaseService.client
        .from('repair_assignments')
        .select()
        .inFilter('period_id', periodIds);

    final assignmentMap = <String, List<RepairAssignmentModel>>{};
    for (final a in assignmentsRaw as List) {
      final m = a as Map<String, dynamic>;
      final pid = m['period_id'] as String;
      assignmentMap
          .putIfAbsent(pid, () => [])
          .add(RepairAssignmentModel.fromJson(m));
    }

    return periods.map((p) {
      final m = p as Map<String, dynamic>;
      final pid = m['period_id'] as String;
      return RepairPeriodModel.fromJson(m,
          assignments: assignmentMap[pid] ?? []);
    }).toList();
  }

  Future<void> addPeriod(RepairPeriodModel period) async {
    final inserted = await SupabaseService.client
        .from('repair_periods')
        .insert(period.toInsertJson())
        .select()
        .single();
    final created = RepairPeriodModel.fromJson(inserted);
    final next = <RepairPeriodModel>[...(state.value ?? []), created];
    state = AsyncData(next);
  }

  Future<void> deletePeriod(String periodId) async {
    await SupabaseService.client
        .from('repair_periods')
        .delete()
        .eq('period_id', periodId);
    state = AsyncData(
        (state.value ?? []).where((p) => p.periodId != periodId).toList());
  }

  // ── Assignments ──────────────────────────────────────────────────────────

  Future<void> saveAssignments(
    String periodId,
    Map<String, RepairType> outcomes,
    Map<String, bool> concerning,
    Map<String, String?> notes,
  ) async {
    await SupabaseService.client
        .from('repair_assignments')
        .delete()
        .eq('period_id', periodId);

    if (outcomes.isNotEmpty) {
      final rows = outcomes.entries
          .map((e) {
            final note = notes[e.key];
            return {
              'period_id': periodId,
              'damage_id': e.key,
              'outcome': e.value.value,
              'is_concerning_average': concerning[e.key] ?? true,
              if (note != null && note.isNotEmpty) 'notes': note,
            };
          })
          .toList();
      await SupabaseService.client.from('repair_assignments').insert(rows);

      for (final entry in outcomes.entries) {
        final repairType = entry.value != RepairType.deferred
            ? entry.value.value
            : null;
        final repairStatus = entry.value == RepairType.deferred
            ? RepairStatus.deferred.value
            : RepairStatus.completed.value;
        final update = <String, dynamic>{'repair_status': repairStatus};
        if (repairType != null) update['repair_type'] = repairType;
        await SupabaseService.client
            .from('damage_items')
            .update(update)
            .eq('damage_id', entry.key);
      }
    }

    final fresh = await _fetch();
    state = AsyncData(fresh);
  }

  // ── Repair times ─────────────────────────────────────────────────────────

  Future<void> saveRepairTimes(
      String periodId, Map<String, RepairTimeEntry> times) async {
    final timesJson = times.map((k, v) => MapEntry(k, v.toJson()));
    await SupabaseService.client
        .from('repair_periods')
        .update({'repair_times': timesJson})
        .eq('period_id', periodId);
    state = AsyncData(
      (state.value ?? [])
          .map((p) =>
              p.periodId == periodId ? p.copyWith(repairTimes: times) : p)
          .toList(),
    );
  }

  // ── Not-average items ─────────────────────────────────────────────────────

  Future<void> addNotAverageItem(String periodId, String text) async {
    final periods = state.value ?? [];
    final period = periods.firstWhere((p) => p.periodId == periodId);
    final updated = [
      ...period.notAverageItems,
      NotAverageItem(itemId: _uuid.v4(), text: text),
    ];
    await _persistNotAverage(periodId, updated);
    state = AsyncData(
      periods
          .map((p) =>
              p.periodId == periodId ? p.copyWith(notAverageItems: updated) : p)
          .toList(),
    );
  }

  Future<void> removeNotAverageItem(String periodId, String itemId) async {
    final periods = state.value ?? [];
    final period = periods.firstWhere((p) => p.periodId == periodId);
    final updated =
        period.notAverageItems.where((i) => i.itemId != itemId).toList();
    await _persistNotAverage(periodId, updated);
    state = AsyncData(
      periods
          .map((p) =>
              p.periodId == periodId ? p.copyWith(notAverageItems: updated) : p)
          .toList(),
    );
  }

  Future<void> _persistNotAverage(
      String periodId, List<NotAverageItem> items) async {
    await SupabaseService.client
        .from('repair_periods')
        .update({'not_average_items': items.map((e) => e.toJson()).toList()})
        .eq('period_id', periodId);
  }

  // ── Budget estimate ───────────────────────────────────────────────────────

  Future<void> addBudgetItem(String periodId, BudgetItem item) async {
    final periods = state.value ?? [];
    final period = periods.firstWhere((p) => p.periodId == periodId);
    final newItem = item.itemId.isEmpty
        ? BudgetItem(
            itemId: _uuid.v4(),
            description: item.description,
            amount: item.amount,
            currency: item.currency,
            status: item.status,
          )
        : item;
    final updated = [...period.budgetItems, newItem];
    await _persistBudget(period.copyWith(budgetItems: updated));
    state = AsyncData(
      periods
          .map((p) =>
              p.periodId == periodId ? p.copyWith(budgetItems: updated) : p)
          .toList(),
    );
  }

  Future<void> updateBudgetItem(String periodId, BudgetItem item) async {
    final periods = state.value ?? [];
    final period = periods.firstWhere((p) => p.periodId == periodId);
    final updated = period.budgetItems
        .map((b) => b.itemId == item.itemId ? item : b)
        .toList();
    await _persistBudget(period.copyWith(budgetItems: updated));
    state = AsyncData(
      periods
          .map((p) =>
              p.periodId == periodId ? p.copyWith(budgetItems: updated) : p)
          .toList(),
    );
  }

  Future<void> removeBudgetItem(String periodId, String itemId) async {
    final periods = state.value ?? [];
    final period = periods.firstWhere((p) => p.periodId == periodId);
    final updated =
        period.budgetItems.where((b) => b.itemId != itemId).toList();
    await _persistBudget(period.copyWith(budgetItems: updated));
    state = AsyncData(
      periods
          .map((p) =>
              p.periodId == periodId ? p.copyWith(budgetItems: updated) : p)
          .toList(),
    );
  }

  Future<void> saveBudgetDisplay({
    required String periodId,
    required String displayCurrency,
    required String baseCurrency,
    double? exchangeRate,
    DateTime? rateDate,
  }) async {
    final periods = state.value ?? [];
    final period = periods.firstWhere((p) => p.periodId == periodId);
    final updated = period.copyWith(
      budgetDisplayCurrency: displayCurrency,
      budgetBaseCurrency: baseCurrency,
      budgetExchangeRate: exchangeRate,
      budgetRateDate: rateDate,
    );
    await _persistBudget(updated);
    state = AsyncData(
      periods.map((p) => p.periodId == periodId ? updated : p).toList(),
    );
  }

  Future<void> _persistBudget(RepairPeriodModel period) async {
    final metaJson = {
      'display_currency': period.budgetDisplayCurrency,
      'base_currency': period.budgetBaseCurrency,
      if (period.budgetExchangeRate != null)
        'exchange_rate': period.budgetExchangeRate,
      if (period.budgetRateDate != null)
        'rate_date':
            period.budgetRateDate!.toIso8601String().substring(0, 10),
    };
    await SupabaseService.client.from('repair_periods').update({
      'budget_items': period.budgetItems.map((e) => e.toJson()).toList(),
      'budget_meta': metaJson,
    }).eq('period_id', period.periodId);
  }
}
