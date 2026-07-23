// lib/features/cs/providers/cs_sections_provider.dart
//
// Per-case C&S section rows (the existing cs_sections table, extended by
// migration 064). Holds the section header + its rolled-up rating. The rating
// is auto-derived from child inspection-item grades (deriveSectionRating in
// cs_models.dart) unless a surveyor overrides it.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../models/cs_models.dart';

final csSectionsProvider = AsyncNotifierProviderFamily<CsSectionsNotifier,
    List<CsSectionModel>, String>(
  CsSectionsNotifier.new,
);

class CsSectionsNotifier
    extends FamilyAsyncNotifier<List<CsSectionModel>, String> {
  @override
  Future<List<CsSectionModel>> build(String caseId) => _fetch(caseId);

  Future<List<CsSectionModel>> _fetch(String caseId) async {
    final data = await SupabaseService.client
        .from('cs_sections')
        .select()
        .eq('case_id', caseId)
        .order('section_type');
    return (data as List)
        .map((e) => CsSectionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateNarrative(String sectionId, String narrative) async {
    await SupabaseService.client
        .from('cs_sections')
        .update({'narrative': narrative}).eq('section_id', sectionId);
    _patch(sectionId, (s) => s.copyWith(narrative: narrative));
  }

  /// Writes the auto-derived rating. No-op if the section's rating was
  /// manually overridden — a surveyor's explicit call must not be clobbered
  /// when item grades change.
  Future<void> applyDerivedRating(
      String sectionId, CsSectionRating rating) async {
    final section =
        (state.value ?? []).where((s) => s.sectionId == sectionId).firstOrNull;
    if (section != null && section.ratingOverridden) return;
    await SupabaseService.client.from('cs_sections').update({
      'rating': rating.value,
      'rating_overridden': false,
    }).eq('section_id', sectionId);
    _patch(sectionId,
        (s) => s.copyWith(rating: rating, ratingOverridden: false));
  }

  /// Sets the rating by hand and marks it overridden.
  Future<void> overrideRating(
      String sectionId, CsSectionRating rating) async {
    await SupabaseService.client.from('cs_sections').update({
      'rating': rating.value,
      'rating_overridden': true,
    }).eq('section_id', sectionId);
    _patch(sectionId,
        (s) => s.copyWith(rating: rating, ratingOverridden: true));
  }

  /// Drops a manual override so the section returns to auto-derivation.
  Future<void> clearOverride(String sectionId) async {
    await SupabaseService.client
        .from('cs_sections')
        .update({'rating_overridden': false}).eq('section_id', sectionId);
    _patch(sectionId, (s) => s.copyWith(ratingOverridden: false));
  }

  void _patch(String sectionId, CsSectionModel Function(CsSectionModel) update) {
    final current = state.value ?? [];
    state = AsyncData(current
        .map((s) => s.sectionId == sectionId ? update(s) : s)
        .toList());
  }
}
