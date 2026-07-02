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
