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
      await SupabaseService.client.from('token_usage').insert({
        if (caseId != null) 'case_id': caseId,
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
