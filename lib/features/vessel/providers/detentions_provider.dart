// lib/features/vessel/providers/detentions_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/detention_model.dart';
import '../../../core/api/supabase_client.dart';

final detentionsProvider = AsyncNotifierProviderFamily<DetentionsNotifier,
    List<DetentionModel>, String>(
  DetentionsNotifier.new,
);

class DetentionsNotifier
    extends FamilyAsyncNotifier<List<DetentionModel>, String> {
  // arg = vesselId
  @override
  Future<List<DetentionModel>> build(String vesselId) => _fetch(vesselId);

  Future<List<DetentionModel>> _fetch(String vesselId) async {
    final data = await SupabaseService.client
        .from('detentions')
        .select()
        .eq('vessel_id', vesselId)
        .order('detained_date', ascending: false);
    return (data as List)
        .map((j) => DetentionModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> add({
    required String vesselId,
    DateTime? detainedDate,
    DateTime? releasedDate,
    String? port,
    String? authority,
    String? reason,
    bool resolved = false,
  }) async {
    await SupabaseService.client.from('detentions').insert({
      'vessel_id': vesselId,
      if (detainedDate != null)
        'detained_date': detainedDate.toIso8601String().split('T').first,
      if (releasedDate != null)
        'released_date': releasedDate.toIso8601String().split('T').first,
      if (port != null)      'port':      port,
      if (authority != null) 'authority': authority,
      if (reason != null)    'reason':    reason,
      'resolved': resolved,
    });
    state = await AsyncValue.guard(() => _fetch(arg));
  }

  Future<void> updateDetention(
    String detentionId, {
    DateTime? detainedDate,
    DateTime? releasedDate,
    String? port,
    String? authority,
    String? reason,
    bool? resolved,
    bool clearReleasedDate = false,
  }) async {
    final updates = <String, dynamic>{};
    if (detainedDate != null) {
      updates['detained_date'] =
          detainedDate.toIso8601String().split('T').first;
    }
    if (clearReleasedDate) {
      updates['released_date'] = null;
    } else if (releasedDate != null) {
      updates['released_date'] =
          releasedDate.toIso8601String().split('T').first;
    }
    if (port != null)      updates['port']      = port;
    if (authority != null) updates['authority'] = authority;
    if (reason != null)    updates['reason']    = reason;
    if (resolved != null)  updates['resolved']  = resolved;
    if (updates.isEmpty) return;
    await SupabaseService.client
        .from('detentions')
        .update(updates)
        .eq('detention_id', detentionId);
    state = await AsyncValue.guard(() => _fetch(arg));
  }

  Future<void> delete(String detentionId) async {
    await SupabaseService.client
        .from('detentions')
        .delete()
        .eq('detention_id', detentionId);
    state = await AsyncValue.guard(() => _fetch(arg));
  }
}
