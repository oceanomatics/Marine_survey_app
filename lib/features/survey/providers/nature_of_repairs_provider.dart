// lib/features/survey/providers/nature_of_repairs_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/supabase_client.dart';
import '../models/nature_of_repairs_model.dart';

const _uuid = Uuid();

final natureOfRepairsProvider = AsyncNotifierProviderFamily<
    NatureOfRepairsNotifier, NatureOfRepairs, String>(
  NatureOfRepairsNotifier.new,
);

class NatureOfRepairsNotifier
    extends FamilyAsyncNotifier<NatureOfRepairs, String> {
  @override
  Future<NatureOfRepairs> build(String caseId) => _fetch(caseId);

  Future<NatureOfRepairs> _fetch(String caseId) async {
    final rows = await SupabaseService.client
        .from('case_nature_of_repairs')
        .select()
        .eq('case_id', caseId)
        .limit(1);
    if (rows.isEmpty) return NatureOfRepairs.empty(caseId);
    return NatureOfRepairs.fromMap(rows.first);
  }

  Future<void> _patch(Map<String, dynamic> fields) async {
    final caseId = arg;
    await SupabaseService.client.from('case_nature_of_repairs').upsert({
      'case_id': caseId,
      ...fields,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'case_id');
    state = await AsyncValue.guard(() => _fetch(caseId));
  }

  Future<void> setDrydocking(bool required, String? comment) => _patch({
        'drydocking_required': required,
        'drydocking_comment': comment,
      });

  Future<void> setAssuredPlan(bool value, String? comment) => _patch({
        'assured_plan_formulated': value,
        'assured_plan_comment': comment,
      });

  Future<void> setFurtherInspections(bool value, String? comment) => _patch({
        'further_inspections_planned': value,
        'further_inspections_comment': comment,
      });

  Future<void> setPartsLeadTime(bool value, String? comment) => _patch({
        'parts_long_lead_time': value,
        'parts_lead_time_comment': comment,
      });

  Future<void> setForeseeableDifficulties(bool value, String? comment) =>
      _patch({
        'foreseeable_difficulties': value,
        'foreseeable_difficulties_comment': comment,
      });

  Future<void> addSequenceItem(String text) async {
    final current = state.value ?? NatureOfRepairs.empty(arg);
    final updated = [
      ...current.sequenceItems,
      RepairSequenceItem(itemId: _uuid.v4(), text: text),
    ];
    await _patch({'sequence_items': updated.map((e) => e.toJson()).toList()});
  }

  Future<void> removeSequenceItem(String itemId) async {
    final current = state.value ?? NatureOfRepairs.empty(arg);
    final updated =
        current.sequenceItems.where((i) => i.itemId != itemId).toList();
    await _patch({'sequence_items': updated.map((e) => e.toJson()).toList()});
  }
}
