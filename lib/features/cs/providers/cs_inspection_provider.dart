// lib/features/cs/providers/cs_inspection_provider.dart
//
// The C&S inspection register — the F1 register instance. Case-scoped,
// direct-Supabase CRUD, optimistic local patching. Templated on
// action_items_provider.dart.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../models/cs_models.dart';

final csInspectionProvider = AsyncNotifierProviderFamily<CsInspectionNotifier,
    List<CsInspectionItemModel>, String>(
  CsInspectionNotifier.new,
);

class CsInspectionNotifier
    extends FamilyAsyncNotifier<List<CsInspectionItemModel>, String> {
  @override
  Future<List<CsInspectionItemModel>> build(String caseId) => _fetch(caseId);

  Future<List<CsInspectionItemModel>> _fetch(String caseId) async {
    final data = await SupabaseService.client
        .from('cs_inspection_item')
        .select()
        .eq('case_id', caseId)
        .order('sort_order');
    return (data as List)
        .map((e) => CsInspectionItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Adds an inspection item, optionally bound to a template row + section.
  Future<CsInspectionItemModel> addItem({
    String? templateItemId,
    String? sectionId,
    CsGrade? grade,
    String? remark,
    int sortOrder = 0,
  }) async {
    final data = await SupabaseService.client
        .from('cs_inspection_item')
        .insert({
          'case_id': arg,
          if (templateItemId != null) 'template_item_id': templateItemId,
          if (sectionId != null) 'section_id': sectionId,
          if (grade != null) 'grade': grade.value,
          if (remark != null) 'remark': remark,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    final item = CsInspectionItemModel.fromJson(data);
    state = AsyncData([...(state.value ?? []), item]);
    return item;
  }

  /// Sets an item's grade. NB: this does NOT auto-create a recommendation —
  /// the UI offers that step when the grade is UNSATISFACTORY (see
  /// CsRecommendationNotifier.addFromItem), keeping the two registers
  /// decoupled and the gating list surveyor-confirmed.
  Future<void> setGrade(String id, CsGrade? grade) async {
    await SupabaseService.client.from('cs_inspection_item').update({
      'grade': grade?.value,
      'is_na': grade == CsGrade.na,
    }).eq('id', id);
    _patch(id, (i) => i.copyWith(grade: grade, isNa: grade == CsGrade.na));
  }

  Future<void> setRemark(String id, String remark) async {
    await SupabaseService.client
        .from('cs_inspection_item')
        .update({'remark': remark}).eq('id', id);
    _patch(id, (i) => i.copyWith(remark: remark));
  }

  Future<void> setNa(String id, bool isNa) async {
    await SupabaseService.client.from('cs_inspection_item').update({
      'is_na': isNa,
      if (isNa) 'grade': CsGrade.na.value,
    }).eq('id', id);
    _patch(id,
        (i) => i.copyWith(isNa: isNa, grade: isNa ? CsGrade.na : i.grade));
  }

  Future<void> delete(String id) async {
    await SupabaseService.client
        .from('cs_inspection_item')
        .delete()
        .eq('id', id);
    state =
        AsyncData((state.value ?? []).where((i) => i.id != id).toList());
  }

  void _patch(
      String id, CsInspectionItemModel Function(CsInspectionItemModel) update) {
    final current = state.value ?? [];
    state = AsyncData(
        current.map((i) => i.id == id ? update(i) : i).toList());
  }
}
