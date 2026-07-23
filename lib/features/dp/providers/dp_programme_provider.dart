// lib/features/dp/providers/dp_programme_provider.dart
//
// The single per-case DP trial-programme record (trial_programmes, one row per
// case via a UNIQUE case_id). Upserts on case_id so edits work whether or not
// the row exists yet.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../models/dp_models.dart';

final dpProgrammeProvider = AsyncNotifierProviderFamily<DpProgrammeNotifier,
    DpProgrammeModel?, String>(
  DpProgrammeNotifier.new,
);

class DpProgrammeNotifier
    extends FamilyAsyncNotifier<DpProgrammeModel?, String> {
  @override
  Future<DpProgrammeModel?> build(String caseId) async {
    final data = await SupabaseService.client
        .from('trial_programmes')
        .select()
        .eq('case_id', caseId)
        .maybeSingle();
    return data == null ? null : DpProgrammeModel.fromJson(data);
  }

  Future<void> _upsert(Map<String, dynamic> patch) async {
    final data = await SupabaseService.client
        .from('trial_programmes')
        .upsert({'case_id': arg, ...patch}, onConflict: 'case_id')
        .select()
        .single();
    state = AsyncData(DpProgrammeModel.fromJson(data));
  }

  Future<void> setOverallResult(DpOverallResult? result) =>
      _upsert({'overall_result': result?.value});

  Future<void> setOperatingModes(String modes) =>
      _upsert({'operating_modes': modes});

  Future<void> setApplicableRules(String rules) =>
      _upsert({'applicable_rules': rules});

  Future<void> setRevision(int revision) => _upsert({'revision': revision});
}
