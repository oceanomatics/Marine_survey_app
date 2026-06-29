// lib/features/vessel/providers/psc_deficiencies_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/psc_deficiency_model.dart';
import '../../../core/api/supabase_client.dart';

final pscDeficienciesProvider = AsyncNotifierProviderFamily<
    PscDeficienciesNotifier, List<PscDeficiencyModel>, String>(
  PscDeficienciesNotifier.new,
);

class PscDeficienciesNotifier
    extends FamilyAsyncNotifier<List<PscDeficiencyModel>, String> {
  // arg = vesselId
  @override
  Future<List<PscDeficiencyModel>> build(String vesselId) => _fetch(vesselId);

  Future<List<PscDeficiencyModel>> _fetch(String vesselId) async {
    final data = await SupabaseService.client
        .from('psc_deficiencies')
        .select()
        .eq('vessel_id', vesselId)
        .order('created_at');
    return (data as List)
        .map((j) => PscDeficiencyModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> add({
    required String vesselId,
    String? code,
    String? description,
    String? actionRequired,
    bool rectified = false,
  }) async {
    await SupabaseService.client.from('psc_deficiencies').insert({
      'vessel_id':         vesselId,
      if (code != null)           'code':            code,
      if (description != null)    'description':     description,
      if (actionRequired != null) 'action_required': actionRequired,
      'rectified':         rectified,
    });
    state = await AsyncValue.guard(() => _fetch(arg));
  }

  Future<void> updateDeficiency(String deficiencyId, {
    String? code,
    String? description,
    String? actionRequired,
    bool? rectified,
  }) async {
    final updates = <String, dynamic>{};
    if (code != null)           updates['code']            = code;
    if (description != null)    updates['description']     = description;
    if (actionRequired != null) updates['action_required'] = actionRequired;
    if (rectified != null)      updates['rectified']       = rectified;
    if (updates.isEmpty) return;
    await SupabaseService.client
        .from('psc_deficiencies')
        .update(updates)
        .eq('deficiency_id', deficiencyId);
    state = await AsyncValue.guard(() => _fetch(arg));
  }

  Future<void> delete(String deficiencyId) async {
    await SupabaseService.client
        .from('psc_deficiencies')
        .delete()
        .eq('deficiency_id', deficiencyId);
    state = await AsyncValue.guard(() => _fetch(arg));
  }
}
