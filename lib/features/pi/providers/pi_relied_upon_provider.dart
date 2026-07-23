// lib/features/pi/providers/pi_relied_upon_provider.dart
//
// The P&I "Facts & Documents Relied Upon" register (spec §4.3). Case-scoped,
// direct-Supabase CRUD, optimistic patching.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../models/pi_models.dart';

final piReliedUponProvider = AsyncNotifierProviderFamily<PiReliedUponNotifier,
    List<PiReliedUponModel>, String>(
  PiReliedUponNotifier.new,
);

class PiReliedUponNotifier
    extends FamilyAsyncNotifier<List<PiReliedUponModel>, String> {
  @override
  Future<List<PiReliedUponModel>> build(String caseId) => _fetch(caseId);

  Future<List<PiReliedUponModel>> _fetch(String caseId) async {
    final data = await SupabaseService.client
        .from('pi_relied_upon')
        .select()
        .eq('case_id', caseId)
        .order('sort_order');
    return (data as List)
        .map((e) => PiReliedUponModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PiReliedUponModel> add(String description,
      {String? reference, String? documentId, int sortOrder = 0}) async {
    final data = await SupabaseService.client
        .from('pi_relied_upon')
        .insert({
          'case_id': arg,
          'description': description,
          if (reference != null) 'reference': reference,
          if (documentId != null) 'document_id': documentId,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    final item = PiReliedUponModel.fromJson(data);
    state = AsyncData([...(state.value ?? []), item]);
    return item;
  }

  Future<void> updateFields(String id,
      {String? description, String? reference}) async {
    final patch = <String, dynamic>{
      if (description != null) 'description': description,
      if (reference != null) 'reference': reference,
    };
    if (patch.isEmpty) return;
    await SupabaseService.client
        .from('pi_relied_upon')
        .update(patch)
        .eq('id', id);
    _patch(id, (r) => r.copyWith(description: description, reference: reference));
  }

  Future<void> delete(String id) async {
    await SupabaseService.client.from('pi_relied_upon').delete().eq('id', id);
    state = AsyncData((state.value ?? []).where((r) => r.id != id).toList());
  }

  void _patch(String id, PiReliedUponModel Function(PiReliedUponModel) update) {
    final current = state.value ?? [];
    state =
        AsyncData(current.map((r) => r.id == id ? update(r) : r).toList());
  }
}
