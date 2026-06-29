// lib/features/vessel/providers/class_conditions_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/class_condition_model.dart';
import '../../../core/api/supabase_client.dart';

final classConditionsProvider = AsyncNotifierProviderFamily<
    ClassConditionsNotifier, List<ClassConditionModel>, String>(
  ClassConditionsNotifier.new,
);

class ClassConditionsNotifier
    extends FamilyAsyncNotifier<List<ClassConditionModel>, String> {
  // arg = vesselId
  @override
  Future<List<ClassConditionModel>> build(String vesselId) => _fetch(vesselId);

  Future<List<ClassConditionModel>> _fetch(String vesselId) async {
    final data = await SupabaseService.client
        .from('class_conditions')
        .select()
        .eq('vessel_id', vesselId)
        .order('created_at');
    return (data as List)
        .map((j) => ClassConditionModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> add({
    required String vesselId,
    String? reference,
    String? description,
    DateTime? expiryDate,
    bool occurrenceRelated = false,
    String? occurrenceId,
  }) async {
    await SupabaseService.client.from('class_conditions').insert({
      'vessel_id':          vesselId,
      if (reference != null)    'reference':    reference,
      if (description != null)  'description':  description,
      if (expiryDate != null)
        'expiry_date': expiryDate.toIso8601String().split('T').first,
      'occurrence_related': occurrenceRelated,
      if (occurrenceId != null) 'occurrence_id': occurrenceId,
    });
    state = await AsyncValue.guard(() => _fetch(arg));
  }

  Future<void> updateCondition(String conditionId, {
    String? reference,
    String? description,
    DateTime? expiryDate,
    bool? occurrenceRelated,
    String? occurrenceId,
  }) async {
    final updates = <String, dynamic>{};
    if (reference != null)         updates['reference']          = reference;
    if (description != null)       updates['description']        = description;
    if (expiryDate != null) {
      updates['expiry_date'] = expiryDate.toIso8601String().split('T').first;
    }
    if (occurrenceRelated != null) updates['occurrence_related'] = occurrenceRelated;
    if (occurrenceId != null)      updates['occurrence_id']      = occurrenceId;
    if (updates.isEmpty) return;
    await SupabaseService.client
        .from('class_conditions')
        .update(updates)
        .eq('condition_id', conditionId);
    state = await AsyncValue.guard(() => _fetch(arg));
  }

  Future<void> delete(String conditionId) async {
    await SupabaseService.client
        .from('class_conditions')
        .delete()
        .eq('condition_id', conditionId);
    state = await AsyncValue.guard(() => _fetch(arg));
  }
}
