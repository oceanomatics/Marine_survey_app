// lib/features/reports/utils/section_text.dart
//
// Shared between report_preview.dart and docx_export_service.dart so the
// two independent renderers of the same ReportSection.content agree on
// what counts as a paragraph. Previously each duplicated this logic and
// had drifted before (see gap #5 in docs/report_builder_editor_notes.md).

/// Splits section content into paragraphs on blank lines, trimming and
/// dropping any that are empty.
List<String> splitSectionParagraphs(String content) => content
    .split('\n\n')
    .map((p) => p.trim())
    .where((p) => p.isNotEmpty)
    .toList();

/// Detects a Markdown/pipe-delimited table block and parses it to rows of
/// cells, or returns null when [paragraph] is ordinary prose.
///
/// This is what lets a Case-Analyst-inserted table (the analyst emits a
/// Markdown table into a section's content) export as a REAL Word table
/// rather than flattened text (report_builder_house_style_mods.md item 20 —
/// "any Analyst-inserted table must export as a real Word table"). A block
/// qualifies when it has at least two lines, every non-blank line contains a
/// '|', and (GitHub-flavoured) a separator row of dashes is present — the
/// separator is dropped from the returned rows. The header row (row 0) is
/// preserved so the caller can render it with `boldFirstRow: true`.
List<List<String>>? tryParseMarkdownTable(String paragraph) {
  final lines = paragraph
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.length < 2) return null;
  if (!lines.every((l) => l.contains('|'))) return null;

  // A GFM separator row is all dashes/pipes/colons/spaces, with a dash.
  bool isSeparator(String l) {
    final core = l.replaceAll(RegExp(r'^\||\|$'), '');
    return RegExp(r'^[\s:\-|]+$').hasMatch(core) && core.contains('-');
  }

  if (!lines.any(isSeparator)) return null;

  List<String> cells(String line) {
    var l = line.trim();
    if (l.startsWith('|')) l = l.substring(1);
    if (l.endsWith('|')) l = l.substring(0, l.length - 1);
    return l.split('|').map((c) => c.trim()).toList();
  }

  final rows = <List<String>>[];
  for (final line in lines) {
    if (isSeparator(line)) continue;
    rows.add(cells(line));
  }
  if (rows.length < 2) return null;

  // Normalise ragged rows to the widest column count so the docx grid is
  // well-formed.
  final width = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
  for (final r in rows) {
    while (r.length < width) {
      r.add('');
    }
  }
  return rows;
}
