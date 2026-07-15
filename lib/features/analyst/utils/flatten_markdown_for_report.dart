// lib/features/analyst/utils/flatten_markdown_for_report.dart
//
// Report section `content` is plain prose — docx_export_service.dart has no
// markdown parser, it just writes paragraphs (see buildVesselParticularsRows
// and friends for the app's *only* table mechanism, which is a fixed
// data-driven table, not free markdown). A Case Analyst chat reply can
// contain markdown (headings, bold, and — per the "insert a table of
// defects" walkthrough ask, 14 July 2026 §21 — tables), so inserting it
// verbatim into a section would export literal `| col | col |` pipe syntax.
// This flattens that down to something that reads correctly as plain
// prose: headings become a capitalised line, bold/italic markers are
// stripped, and a markdown table becomes one line per row in
// "Header: value — Header: value" form.
String flattenMarkdownForReport(String markdown) {
  final lines = markdown.split('\n');
  final out = <String>[];
  List<String>? tableHeader;

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

  for (final raw in lines) {
    final line = raw.trimRight();

    if (isTableRow(line)) {
      final cells = splitRow(line);
      if (tableHeader == null) {
        tableHeader = cells;
      } else if (!isTableSeparator(line)) {
        final row = <String>[];
        for (var i = 0; i < cells.length; i++) {
          final header = i < tableHeader.length ? tableHeader[i] : '';
          row.add(header.isEmpty ? cells[i] : '$header: ${cells[i]}');
        }
        out.add(row.join(' — '));
      }
      continue;
    }
    tableHeader = null;

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

  // Collapse runs of 3+ blank lines (table borders often leave two) down to
  // a single paragraph break.
  final text = out.join('\n');
  return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
