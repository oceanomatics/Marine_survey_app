// lib/features/cs/providers/cs_template_provider.dart
//
// Reads the SHARED C&S template skeleton (cs_template / cs_template_item).
// Not case-scoped — this is reference data, so it's a simple keyed fetch by
// vessel type. Seeded by migration 065.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../models/cs_models.dart';

/// The active template's items for a given vessel type (e.g. 'ahts'),
/// ordered as they appear in the report.
final csTemplateItemsProvider =
    FutureProvider.family<List<CsTemplateItemModel>, String>((ref, vesselType) async {
  final template = await SupabaseService.client
      .from('cs_template')
      .select('id')
      .eq('vessel_type', vesselType)
      .eq('is_active', true)
      .order('version', ascending: false)
      .limit(1)
      .maybeSingle();

  if (template == null) return <CsTemplateItemModel>[];

  final data = await SupabaseService.client
      .from('cs_template_item')
      .select()
      .eq('template_id', template['id'] as String)
      .order('sort_order');

  return (data as List)
      .map((e) => CsTemplateItemModel.fromJson(e as Map<String, dynamic>))
      .toList();
});
