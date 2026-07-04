// lib/features/reports/utils/advice_summary_rows.dart
//
// Shared between report_preview.dart and docx_export_service.dart so the
// two independent renderers of the Advice Summary table agree on content —
// same convention as section_text.dart (see gap #5 in
// docs/report_builder_editor_notes.md re: renderer drift).

import '../providers/report_provider.dart';

const _statusLabels = {
  'complete': 'Complete',
  'ongoing': 'Ongoing',
  'awaiting': 'Awaiting',
  'deferred': 'Deferred to',
  'not_commenced': 'Not yet commenced',
};

const _allegationLabels = {
  'formal_allegation': 'Allegation made (refer Cause Consideration)',
  'informal_allegation':
      'Informal allegation made (refer Cause Consideration)',
  'no_formal_allegation': 'No formal allegation made',
};

String _fmtAmt(num v) {
  final s = v.toStringAsFixed(2);
  final parts = s.split('.');
  final intPart = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '$intPart.${parts[1]}';
}

/// Builds the label/value rows for the Advice Summary table (spec:
/// "Section: Executive Summary (Advice Summary Table)" in
/// docs/report_builder_editor_notes.md), populated from
/// `report_outputs.advice_*` fields.
///
/// Always returns the full fixed 8-row spec layout — rows are never
/// omitted for missing data, matching the spec's own suggested layout
/// (which shows bracketed placeholders like "[auto or TBD]" for every
/// field) and the explicit instruction that this table must render with
/// placeholders rather than disappear before the surveyor has filled in
/// AdviceSummaryCard. Previously every row (and the whole table, since the
/// Preview/docx callers both gated on `rows.isNotEmpty`) was silently
/// dropped whenever a report had not yet had its Advice Summary fields
/// entered — which is the normal state for a freshly-built report.
List<List<String>> buildAdviceSummaryRows(
    ReportOutput output, AssembledReportData assembled) {
  final occ =
      assembled.occurrences.isNotEmpty ? assembled.occurrences.first : null;
  final costApproved = output.adviceStatusOfRepairs == 'complete' ||
      output.adviceStatusOfRepairs == 'ongoing';

  final occDate =
      occ != null ? _formatOccDate(occ['date_time'] as String? ?? '') : '';
  final dateAndNature = [
    occDate.isNotEmpty ? occDate : '[DOL date not yet recorded]',
    (output.adviceNatureOfCasualty ?? '').isNotEmpty
        ? output.adviceNatureOfCasualty!
        : '[nature of casualty not yet recorded]',
  ].join(' — ');

  var statusLine =
      _statusLabels[output.adviceStatusOfRepairs] ?? '[not yet recorded]';
  if (_statusLabels.containsKey(output.adviceStatusOfRepairs) &&
      (output.adviceStatusOfRepairsDetail ?? '').isNotEmpty) {
    statusLine = '$statusLine ${output.adviceStatusOfRepairsDetail}';
  }

  final costAmountLine = output.adviceCostAmount != null
      ? '${output.adviceCostCurrency ?? ''} ${_fmtAmt(output.adviceCostAmount!)}'
      : '[not yet estimated]';
  final generalExpensesLine = 'Including general expenses: '
      '${output.adviceCostIncludesGeneralExpenses == null ? '[TBD]' : (output.adviceCostIncludesGeneralExpenses! ? 'Yes' : 'No')}';
  final towingLine = 'Including towing costs: '
      '${{'yes': 'Yes', 'no': 'No', 'n_a': 'N/A'}[output.adviceCostIncludesTowing] ?? '[TBD]'}';
  final costLines = [costAmountLine, generalExpensesLine, towingLine];

  final feeHoursLine = 'Hours: '
      '${output.adviceFeeReserveHours ?? '[not yet set]'}';
  final feeExpensesLine = 'Expenses: '
      '${output.adviceFeeReserveExpenses != null ? '${output.adviceCostCurrency ?? ''} ${_fmtAmt(output.adviceFeeReserveExpenses!)}' : '[not yet set]'}';
  final feeLines = [feeHoursLine, feeExpensesLine];

  final allegationType = occ?['allegation_type'] as String?;
  final remarksLines = <String>[
    _allegationLabels[allegationType] ?? '[allegation status not yet recorded]',
    if (output.adviceFollowUpRequired == true)
      'Follow-up attendance required'
          '${(output.adviceFollowUpDetail ?? '').isNotEmpty ? ': ${output.adviceFollowUpDetail}' : ''}'
    else if (output.adviceFollowUpRequired == false)
      'No follow-up attendance required'
    else
      'Follow-up required: [not yet recorded]',
    if ((output.adviceRemarks ?? '').isNotEmpty) output.adviceRemarks!,
  ];

  // UCR / Reference reuses the case-level Claim Reference field (Edit Case
  // Details) rather than duplicating it per report-output.
  final claimReference = assembled.caseData['claim_reference'] as String?;

  return [
    ['UCR / Reference',
     (claimReference ?? '').isNotEmpty ? claimReference! : '[TBD]'],
    ['Date and Nature of Casualty', dateAndNature],
    ['Description of Damage',
     (output.adviceDescriptionOfDamage ?? '').isNotEmpty
         ? output.adviceDescriptionOfDamage!
         : '[description of damage — pending]'],
    ['Nature of Repairs',
     (output.adviceNatureOfRepairs ?? '').isNotEmpty
         ? output.adviceNatureOfRepairs!
         : '[nature of repairs — pending]'],
    ['Status of Repairs', statusLine],
    [
      costApproved ? 'Sum Approved Without Prejudice' : 'Estimated Cost of Repairs',
      costLines.join('\n'),
    ],
    ['Survey Fee Reserve', feeLines.join('\n')],
    ['Remarks', remarksLines.join('\n')],
  ];
}

String _formatOccDate(String iso) {
  if (iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  const months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${dt.day} ${months[dt.month]} ${dt.year}';
}
