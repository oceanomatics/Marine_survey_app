// lib/features/pi/providers/pi_opinion_provider.dart
//
// The P&I Opinion/Conclusions register. Case-scoped, direct-Supabase CRUD,
// optimistic patching. Templated on action_items / cs_inspection.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../models/pi_models.dart';

final piOpinionProvider = AsyncNotifierProviderFamily<PiOpinionNotifier,
    List<PiOpinionModel>, String>(
  PiOpinionNotifier.new,
);

class PiOpinionNotifier
    extends FamilyAsyncNotifier<List<PiOpinionModel>, String> {
  @override
  Future<List<PiOpinionModel>> build(String caseId) => _fetch(caseId);

  Future<List<PiOpinionModel>> _fetch(String caseId) async {
    final data = await SupabaseService.client
        .from('pi_opinion')
        .select()
        .eq('case_id', caseId)
        .order('sort_order');
    return (data as List)
        .map((e) => PiOpinionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PiOpinionModel> add(String opinionText,
      {String? heading, String? basis, int sortOrder = 0}) async {
    final data = await SupabaseService.client
        .from('pi_opinion')
        .insert({
          'case_id': arg,
          'opinion_text': opinionText,
          if (heading != null) 'heading': heading,
          if (basis != null) 'basis': basis,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    final opinion = PiOpinionModel.fromJson(data);
    state = AsyncData([...(state.value ?? []), opinion]);
    return opinion;
  }

  Future<void> updateFields(
    String id, {
    String? opinionText,
    String? heading,
    String? basis,
    String? qualifierNote,
  }) async {
    final patch = <String, dynamic>{
      if (opinionText != null) 'opinion_text': opinionText,
      if (heading != null) 'heading': heading,
      if (basis != null) 'basis': basis,
      if (qualifierNote != null) 'qualifier_note': qualifierNote,
    };
    if (patch.isEmpty) return;
    await SupabaseService.client.from('pi_opinion').update(patch).eq('id', id);
    _patch(
        id,
        (o) => o.copyWith(
              opinionText: opinionText,
              heading: heading,
              basis: basis,
              qualifierNote: qualifierNote,
            ));
  }

  /// Sets the GPN-EXPT / cl.3 qualifier flags on an opinion.
  Future<void> setQualifiers(String id,
      {bool? outsideExpertise, bool? notConcluded}) async {
    final patch = <String, dynamic>{
      if (outsideExpertise != null) 'outside_expertise': outsideExpertise,
      if (notConcluded != null) 'not_concluded': notConcluded,
    };
    if (patch.isEmpty) return;
    await SupabaseService.client.from('pi_opinion').update(patch).eq('id', id);
    _patch(
        id,
        (o) => o.copyWith(
              outsideExpertise: outsideExpertise,
              notConcluded: notConcluded,
            ));
  }

  Future<void> delete(String id) async {
    await SupabaseService.client.from('pi_opinion').delete().eq('id', id);
    state = AsyncData((state.value ?? []).where((o) => o.id != id).toList());
  }

  void _patch(String id, PiOpinionModel Function(PiOpinionModel) update) {
    final current = state.value ?? [];
    state =
        AsyncData(current.map((o) => o.id == id ? update(o) : o).toList());
  }
}
