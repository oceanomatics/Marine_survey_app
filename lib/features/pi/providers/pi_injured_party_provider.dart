// lib/features/pi/providers/pi_injured_party_provider.dart
//
// The P&I Medical / Injured Parties register (spec §4.6). Case-scoped,
// direct-Supabase CRUD, optimistic patching.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../models/pi_models.dart';

final piInjuredPartyProvider = AsyncNotifierProviderFamily<
    PiInjuredPartyNotifier, List<PiInjuredPartyModel>, String>(
  PiInjuredPartyNotifier.new,
);

class PiInjuredPartyNotifier
    extends FamilyAsyncNotifier<List<PiInjuredPartyModel>, String> {
  @override
  Future<List<PiInjuredPartyModel>> build(String caseId) => _fetch(caseId);

  Future<List<PiInjuredPartyModel>> _fetch(String caseId) async {
    final data = await SupabaseService.client
        .from('pi_injured_party')
        .select()
        .eq('case_id', caseId)
        .order('sort_order');
    return (data as List)
        .map((e) => PiInjuredPartyModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PiInjuredPartyModel> add({
    String? personRole,
    String? personName,
    String? condition,
    String? infoSource,
  }) async {
    final data = await SupabaseService.client
        .from('pi_injured_party')
        .insert({
          'case_id': arg,
          if (personRole != null) 'person_role': personRole,
          if (personName != null) 'person_name': personName,
          if (condition != null) 'condition': condition,
          if (infoSource != null) 'info_source': infoSource,
        })
        .select()
        .single();
    final party = PiInjuredPartyModel.fromJson(data);
    state = AsyncData([...(state.value ?? []), party]);
    return party;
  }

  Future<void> updateFields(
    String id, {
    String? personRole,
    String? personName,
    String? condition,
    String? infoSource,
  }) async {
    final patch = <String, dynamic>{
      if (personRole != null) 'person_role': personRole,
      if (personName != null) 'person_name': personName,
      if (condition != null) 'condition': condition,
      if (infoSource != null) 'info_source': infoSource,
    };
    if (patch.isEmpty) return;
    await SupabaseService.client
        .from('pi_injured_party')
        .update(patch)
        .eq('id', id);
    _patch(
        id,
        (p) => p.copyWith(
              personRole: personRole,
              personName: personName,
              condition: condition,
              infoSource: infoSource,
            ));
  }

  Future<void> delete(String id) async {
    await SupabaseService.client
        .from('pi_injured_party')
        .delete()
        .eq('id', id);
    state = AsyncData((state.value ?? []).where((p) => p.id != id).toList());
  }

  void _patch(
      String id, PiInjuredPartyModel Function(PiInjuredPartyModel) update) {
    final current = state.value ?? [];
    state =
        AsyncData(current.map((p) => p.id == id ? update(p) : p).toList());
  }
}
