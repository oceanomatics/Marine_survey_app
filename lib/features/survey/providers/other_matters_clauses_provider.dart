// lib/features/survey/providers/other_matters_clauses_provider.dart
//
// Candidate "Other Matters of Relevance" legal clauses (docs/migrations/
// 018_other_matters_clauses.sql) — a small, fixed set of standing legal
// statements (e.g. retention of damaged parts, prudent uninsured notice)
// the surveyor ticks to include in the report. `clause_type` is a real
// Postgres enum, so the candidate set is a hardcoded list of known values
// here (same convention as e.g. `_kCostStatusOptions` in
// accounts_screen.dart) rather than a dynamic prefix query — enum values
// require their own migration to add anyway, so there's no meaningful
// "dynamic discovery" being given up.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../../reports/providers/report_provider.dart' show ClauseModel;

const otherMattersClauseTypes = [
  'other_matters_retain_damaged_parts',
  'other_matters_prudent_uninsured',
];

/// Keyed by `format_type` (the case's `outputFormat`, default 'abl').
final otherMattersClausesProvider =
    FutureProvider.family<List<ClauseModel>, String>((ref, formatType) async {
  final rows = await SupabaseService.client
      .from('clause_library')
      .select()
      .eq('format_type', formatType)
      .inFilter('clause_type', otherMattersClauseTypes);
  return (rows as List)
      .map((r) => ClauseModel.fromJson(r as Map<String, dynamic>))
      .toList();
});
