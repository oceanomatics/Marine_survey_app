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
/// `report_outputs.advice_*` fields. Rows with no data are omitted.
List<List<String>> buildAdviceSummaryRows(
    ReportOutput output, AssembledReportData assembled) {
  final occ =
      assembled.occurrences.isNotEmpty ? assembled.occurrences.first : null;
  final costApproved = output.adviceStatusOfRepairs == 'complete' ||
      output.adviceStatusOfRepairs == 'ongoing';

  final dateAndNature = [
    if (occ != null) _formatOccDate(occ['date_time'] as String? ?? ''),
    output.adviceNatureOfCasualty,
  ].where((e) => e != null && e.isNotEmpty).join(' — ');

  var statusLine = _statusLabels[output.adviceStatusOfRepairs];
  if (statusLine != null &&
      (output.adviceStatusOfRepairsDetail ?? '').isNotEmpty) {
    statusLine = '$statusLine ${output.adviceStatusOfRepairsDetail}';
  }

  final costLines = <String>[];
  if (output.adviceCostAmount != null) {
    final ccy = output.adviceCostCurrency ?? '';
    costLines.add('$ccy ${_fmtAmt(output.adviceCostAmount!)}');
  }
  if (output.adviceCostIncludesGeneralExpenses != null) {
    costLines.add('Incl. general expenses: '
        '${output.adviceCostIncludesGeneralExpenses! ? 'Yes' : 'No'}');
  }
  if (output.adviceCostIncludesTowing != null) {
    costLines.add('Incl. towing costs: '
        '${{'yes': 'Yes', 'no': 'No', 'n_a': 'N/A'}[output.adviceCostIncludesTowing] ?? '—'}');
  }

  final feeLines = <String>[];
  if (output.adviceFeeReserveHours != null) {
    feeLines.add('Hours: ${output.adviceFeeReserveHours}');
  }
  if (output.adviceFeeReserveExpenses != null) {
    feeLines.add('Expenses: ${output.adviceCostCurrency ?? ''} '
        '${_fmtAmt(output.adviceFeeReserveExpenses!)}');
  }

  final allegationType = occ?['allegation_type'] as String?;
  final remarksLines = <String>[
    if (allegationType != null && _allegationLabels.containsKey(allegationType))
      _allegationLabels[allegationType]!,
    if (output.adviceFollowUpRequired == true)
      'Follow-up attendance required'
          '${(output.adviceFollowUpDetail ?? '').isNotEmpty ? ': ${output.adviceFollowUpDetail}' : ''}'
    else if (output.adviceFollowUpRequired == false)
      'No follow-up attendance required',
    if ((output.adviceRemarks ?? '').isNotEmpty) output.adviceRemarks!,
  ];

  // UCR / Reference reuses the case-level Claim Reference field (Edit Case
  // Details) rather than duplicating it per report-output.
  final claimReference = assembled.caseData['claim_reference'] as String?;

  return [
    if ((claimReference ?? '').isNotEmpty)
      ['UCR / Reference', claimReference!],
    if (dateAndNature.isNotEmpty)
      ['Date and Nature of Casualty', dateAndNature],
    if ((output.adviceDescriptionOfDamage ?? '').isNotEmpty)
      ['Description of Damage', output.adviceDescriptionOfDamage!],
    if ((output.adviceNatureOfRepairs ?? '').isNotEmpty)
      ['Nature of Repairs', output.adviceNatureOfRepairs!],
    if (statusLine != null) ['Status of Repairs', statusLine],
    if (costLines.isNotEmpty)
      [
        costApproved ? 'Sum Approved Without Prejudice' : 'Estimated Cost of Repairs',
        costLines.join('\n'),
      ],
    if (feeLines.isNotEmpty) ['Survey Fee Reserve', feeLines.join('\n')],
    if (remarksLines.isNotEmpty) ['Remarks', remarksLines.join('\n')],
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
