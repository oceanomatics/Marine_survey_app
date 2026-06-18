// lib/features/survey/providers/repair_period_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/repair_period_model.dart';
import '../providers/damage_provider.dart';
import '../../../core/api/supabase_client.dart';

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

  // Replaces all assignments for a period.
  // outcomes: damageId → RepairType
  // concerning: damageId → isConcerningAverage (defaults true if absent)
  // Also updates damage_items repair_type / repair_status in Supabase so
  // the Damage tab reflects the outcome immediately after invalidation.
  Future<void> saveAssignments(
    String periodId,
    Map<String, RepairType> outcomes,
    Map<String, bool> concerning,
  ) async {
    await SupabaseService.client
        .from('repair_assignments')
        .delete()
        .eq('period_id', periodId);

    if (outcomes.isNotEmpty) {
      final rows = outcomes.entries
          .map((e) => {
                'period_id':            periodId,
                'damage_id':            e.key,
                'outcome':              e.value.value,
                'is_concerning_average': concerning[e.key] ?? true,
              })
          .toList();
      await SupabaseService.client.from('repair_assignments').insert(rows);

      // Reflect the outcome on each damage item so status labels update
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

    // Refresh in-memory state
    final fresh = await _fetch();
    state = AsyncData(fresh);
  }
}
