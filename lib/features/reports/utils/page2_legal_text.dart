// lib/features/reports/utils/page2_legal_text.dart
//
// Page 2 Legal Designations + AI Usage Declaration — spec: "Page 2 Legal
// Designations — Architecture" in docs/report_builder_editor_notes.md.
// These precede the Advice Summary table, in a fixed order, on every
// report: (a) Legal Designations, (b) AI Usage Declaration (only if AI was
// actually used), (c) Advice Summary. Shared between report_preview.dart
// and docx_export_service.dart so both renderers agree — same convention
// as advice_summary_rows.dart / section_table_rows.dart.

import '../providers/report_provider.dart';
import '../../../core/models/ai_generation_log_model.dart';

class LegalDesignationLines {
  const LegalDesignationLines({
    required this.withoutPrejudice,
    required this.confidentiality,
    required this.copyright,
  });
  final String withoutPrejudice;
  final String confidentiality;
  final String copyright;
}

/// (a) Legal Designations — verbatim locked clauses. Sourced from
/// `clause_library` (`page2_without_prejudice` / `page2_confidentiality` /
/// `page2_copyright`) with the spec's own wording as the fallback when no
/// clause_library row has been seeded yet — same fallback convention as
/// `wp_header_text`/`wp_cover_text` elsewhere in docx_export_service.dart.
LegalDesignationLines buildLegalDesignationLines(AssembledReportData assembled) {
  final org = assembled.organisation;
  final firmName = (org?['name'] as String?)?.isNotEmpty == true
      ? org!['name'] as String
      : '[Survey Firm]';
  final year = DateTime.now().year;

  String fill(String clauseType, String fallback) =>
      (assembled.clauseByType(clauseType)?.clauseText ?? fallback)
          .replaceAll('{FIRM_NAME}', firmName)
          .replaceAll('{YEAR}', '$year');

  return LegalDesignationLines(
    withoutPrejudice: fill(
      'page2_without_prejudice',
      'This report and all approvals of expenditure contained herein are '
          'given without prejudice to the rights of Underwriters.',
    ),
    confidentiality: fill(
      'page2_confidentiality',
      'This report is confidential and is supplied without prejudice to '
          'any or all parties involved. It shall not be copied or passed '
          'on to third parties without the express permission of $firmName.',
    ),
    copyright: fill('page2_copyright', '© $year $firmName. All rights reserved.'),
  );
}

const _aiPurposeLabels = {
  'extraction': 'extraction of technical data from source documents',
  'invoice_extraction': 'extraction of technical data from source documents',
  'report_section':
      'drafting support for narrative sections as identified in Annexure I',
};

/// (b) AI Usage Declaration — spec verbatim paragraph (Oceanoservices
/// analysis §6.4), with the bracketed purposes list populated from the
/// distinct call types actually present in the AI generation log. Returns
/// null when no AI calls are on record — the block must be suppressed
/// entirely in that case, with no surveyor toggle (per spec).
String? buildAiUsageDeclaration(List<AiGenerationLogModel> log) {
  if (log.isEmpty) return null;
  final purposes = <String>{
    for (final entry in log)
      if (_aiPurposeLabels[entry.callType] != null) _aiPurposeLabels[entry.callType]!,
  };
  final purposesText = purposes.isNotEmpty
      ? purposes.join('; ')
      : 'assisting with the preparation of this report';
  return 'This report was compiled with the assistance of Claude '
      '(Anthropic Inc.), a generative AI language model deployed via '
      'private API under a zero-data-retention agreement. AI assistance '
      'was used for the following purposes: $purposesText. All '
      'AI-generated content was reviewed and where necessary amended by '
      'the signing surveyor. The opinions expressed in this report are '
      'those of the signing surveyor alone. Full details of the AI tools, '
      'model versions, source documents processed, and review records are '
      'set out in Annexure I.';
}
