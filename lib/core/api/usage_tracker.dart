// lib/core/api/usage_tracker.dart
//
// Logs Claude API token consumption to Supabase.
// All methods are fire-and-forget — they never throw.

import 'package:flutter/foundation.dart';
import 'supabase_client.dart';

class UsageTracker {
  // claude-sonnet-4-6 pricing (USD per million tokens)
  static const _inputRateUsd  = 3.0;
  static const _outputRateUsd = 15.0;

  // Phase 2 multi-tenancy (migration 048): token_usage.organisation_id is
  // NOT NULL, and this table has no case_id on most rows (many calls
  // aren't tied to a case) — so there's no join path back to an org the
  // way most other tables have via cases.organisation_id. Cached per
  // process since it never changes mid-session and this is called after
  // every single AI call.
  static String? _cachedOrgId;

  static Future<String?> _orgId() async {
    if (_cachedOrgId != null) return _cachedOrgId;
    try {
      final row = await SupabaseService.client
          .from('surveyor_profiles')
          .select('organisation_id')
          .eq('user_id', SupabaseService.userId)
          .single();
      _cachedOrgId = row['organisation_id'] as String?;
    } catch (_) {
      // No surveyor_profiles row yet — leave null, log() below skips the
      // insert rather than violate the NOT NULL constraint.
    }
    return _cachedOrgId;
  }

  static double costUsd(int inputTokens, int outputTokens) =>
      (inputTokens * _inputRateUsd + outputTokens * _outputRateUsd) / 1000000;

  /// Log a completed Claude API call.
  /// [caseId] is optional — pass it when available so costs map to a case.
  /// [feature] is a short identifier, e.g. 'report_extraction'.
  static Future<void> log({
    String? caseId,
    required String feature,
    required String model,
    required int inputTokens,
    required int outputTokens,
  }) async {
    if (inputTokens == 0 && outputTokens == 0) return;
    try {
      final orgId = await _orgId();
      if (orgId == null) return;
      await SupabaseService.client.from('token_usage').insert({
        if (caseId != null) 'case_id': caseId,
        'organisation_id': orgId,
        'feature':       feature,
        'model':         model,
        'input_tokens':  inputTokens,
        'output_tokens': outputTokens,
        'cost_usd':      costUsd(inputTokens, outputTokens),
      });
    } catch (e) {
      debugPrint('[UsageTracker] log failed (non-fatal): $e');
    }
  }
}
