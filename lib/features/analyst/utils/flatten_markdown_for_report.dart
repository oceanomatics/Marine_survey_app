// lib/features/analyst/utils/flatten_markdown_for_report.dart
//
// A Case Analyst chat reply can contain markdown (headings, bold, bullets,
// and — per the "insert a table of defects" walkthrough ask, 14 July 2026
// §21 — tables). This normalises that reply for insertion into a report
// section's `content`:
//   - headings become a capitalised line,
//   - bold/italic/code markers are stripped,
//   - bullets are normalised to "• ",
//   - a MARKDOWN TABLE IS PRESERVED as a clean, blank-line-isolated table
//     block so it round-trips to a REAL Word table on export
//     (report_builder_house_style_mods.md item 20 — "any Analyst-inserted
//     table must export as a real Word table"). Both the docx export
//     (renderTextSection -> tryParseMarkdownTable) and the in-app preview
//     detect that block and render an actual table.
//
// Previously a table was flattened to one "Header: value — Header: value"
// line per row, which read acceptably but could never export as a table.
String flattenMarkdownForReport(String markdown) {
  final lines = markdown.split('\n');
  final out = <String>[];

  // Buffer of raw pipe-table lines (excluding the separator) for the table
  // block currently being accumulated.
  final tableBuf = <List<String>>[];

  bool isTableRow(String line) =>
      line.trim().startsWith('|') && line.trim().endsWith('|');
  bool isTableSeparator(String line) =>
      RegExp(r'^\|?[\s:|-]+\|?$').hasMatch(line.trim()) &&
      line.contains('-');

  List<String> splitRow(String line) => line
      .trim()
      .replaceAll(RegExp(r'^\||\|$'), '')
      .split('|')
      .map((c) => c.trim())
      .toList();

  String stripGroup1(String s, RegExp pattern) =>
      s.replaceAllMapped(pattern, (m) => m.group(1)!);

  String stripInline(String s) {
    s = stripGroup1(s, RegExp(r'\*\*(.*?)\*\*'));
    s = stripGroup1(s, RegExp(r'__(.*?)__'));
    s = stripGroup1(s, RegExp(r'\*(.*?)\*'));
    s = stripGroup1(s, RegExp(r'`(.*?)`'));
    return s;
  }

  // Emit the accumulated table (if any) as a clean, blank-line-isolated
  // markdown block: header row, dash separator, then body rows.
  void flushTable() {
    if (tableBuf.isEmpty) return;
    final width =
        tableBuf.map((r) => r.length).fold<int>(0, (a, b) => a > b ? a : b);
    List<String> pad(List<String> r) =>
        [...r, ...List.filled(width - r.length, '')];
    String rowLine(List<String> r) =>
        '| ${pad(r).map(stripInline).join(' | ')} |';

    if (out.isNotEmpty && out.last.trim().isNotEmpty) out.add('');
    out.add(rowLine(tableBuf.first));
    out.add('| ${List.filled(width, '---').join(' | ')} |');
    for (final r in tableBuf.skip(1)) {
      out.add(rowLine(r));
    }
    out.add('');
    tableBuf.clear();
  }

  for (final raw in lines) {
    final line = raw.trimRight();

    if (isTableRow(line)) {
      if (!isTableSeparator(line)) tableBuf.add(splitRow(line));
      continue;
    }
    flushTable();

    final heading = RegExp(r'^#{1,6}\s+(.*)$').firstMatch(line);
    if (heading != null) {
      out.add(stripInline(heading.group(1)!).toUpperCase());
      continue;
    }

    final bullet = RegExp(r'^\s*[-*]\s+(.*)$').firstMatch(line);
    if (bullet != null) {
      out.add('• ${stripInline(bullet.group(1)!)}');
      continue;
    }

    out.add(stripInline(line));
  }
  flushTable();

  // Collapse runs of 3+ blank lines down to a single paragraph break.
  final text = out.join('\n');
  return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
