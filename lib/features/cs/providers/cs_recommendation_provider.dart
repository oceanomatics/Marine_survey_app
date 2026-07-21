// lib/features/cs/providers/cs_recommendation_provider.dart
//
// The §1.13 gating recommendations register (the F4 findings instance).
// Case-scoped, direct-Supabase CRUD, optimistic patching.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../models/cs_models.dart';

final csRecommendationProvider = AsyncNotifierProviderFamily<
    CsRecommendationNotifier, List<CsRecommendationModel>, String>(
  CsRecommendationNotifier.new,
);

class CsRecommendationNotifier
    extends FamilyAsyncNotifier<List<CsRecommendationModel>, String> {
  @override
  Future<List<CsRecommendationModel>> build(String caseId) => _fetch(caseId);

  Future<List<CsRecommendationModel>> _fetch(String caseId) async {
    final data = await SupabaseService.client
        .from('cs_recommendation')
        .select()
        .eq('case_id', caseId)
        .order('sort_order');
    return (data as List)
        .map((e) => CsRecommendationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CsRecommendationModel> add(String text,
      {String? refNo, String? sourceItemId}) async {
    final data = await SupabaseService.client
        .from('cs_recommendation')
        .insert({
          'case_id': arg,
          'text': text,
          if (refNo != null) 'ref_no': refNo,
          if (sourceItemId != null) 'source_item_id': sourceItemId,
        })
        .select()
        .single();
    final rec = CsRecommendationModel.fromJson(data);
    state = AsyncData([...(state.value ?? []), rec]);
    return rec;
  }

  /// Creates a recommendation linked to an inspection item — the
  /// "UNSATISFACTORY → gating recommendation" flow, carrying the item's
  /// remark as the starting text.
  Future<CsRecommendationModel> addFromItem(
    CsInspectionItemModel item, {
    String? text,
  }) =>
      add(
        text ?? item.remark ?? '',
        sourceItemId: item.id,
      );

  Future<void> updateText(String id, String text) async {
    await SupabaseService.client
        .from('cs_recommendation')
        .update({'text': text}).eq('id', id);
    _patch(id, (r) => r.copyWith(text: text));
  }

  Future<void> setStatus(String id, CsRecommendationStatus status) async {
    await SupabaseService.client.from('cs_recommendation').update({
      'status': status.value,
      'close_date': status == CsRecommendationStatus.closed
          ? DateTime.now().toIso8601String().split('T').first
          : null,
    }).eq('id', id);
    _patch(
        id,
        (r) => r.copyWith(
            status: status,
            closeDate:
                status == CsRecommendationStatus.closed ? DateTime.now() : null));
  }

  Future<void> delete(String id) async {
    await SupabaseService.client
        .from('cs_recommendation')
        .delete()
        .eq('id', id);
    state =
        AsyncData((state.value ?? []).where((r) => r.id != id).toList());
  }

  void _patch(
      String id, CsRecommendationModel Function(CsRecommendationModel) update) {
    final current = state.value ?? [];
    state = AsyncData(
        current.map((r) => r.id == id ? update(r) : r).toList());
  }
}
