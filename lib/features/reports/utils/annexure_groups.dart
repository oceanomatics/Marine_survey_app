// lib/features/reports/utils/annexure_groups.dart
//
// Shared between report_preview.dart and docx_export_service.dart so the
// two independent renderers of the annexures agree on grouping/order — same
// convention as section_text.dart / advice_summary_rows.dart (see gap #5 in
// docs/report_builder_editor_notes.md re: renderer drift).
//
// NOTE: this is the CURRENT fixed-letter model (`documents.annexure_assignment`
// set per-document by the surveyor) — not the "dynamic category-driven
// allocation" target architecture described in docs/report_builder_editor_notes.md
// ("Annexure Allocation Model"), which is still unbuilt. Letter 'I' is
// reserved for the AI Generation Record and is excluded from this grouping.

/// Groups case documents by `annexure_assignment` letter, sorted A→Z,
/// excluding 'I' (reserved for the AI Generation Record).
List<MapEntry<String, List<Map<String, dynamic>>>> buildAnnexureGroups(
    List<Map<String, dynamic>> caseDocuments) {
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final d in caseDocuments) {
    final a = d['annexure_assignment'] as String?;
    if (a == null || a.isEmpty) continue;
    final letter = a.toUpperCase().trim();
    if (letter == 'I') continue;
    grouped.putIfAbsent(letter, () => []).add(d);
  }
  final letters = grouped.keys.toList()..sort();
  return [for (final l in letters) MapEntry(l, grouped[l]!)];
}
