// lib/features/reports/utils/advice_summary_rows.dart
//
// Shared between report_preview.dart and docx_export_service.dart so the
// two independent renderers of the Advice Summary table agree on content —
// same convention as section_text.dart (see gap #5 in
// docs/report_builder_editor_notes.md re: renderer drift).

import '../providers/report_provider.dart';
import '../../survey/models/repair_period_model.dart';

const _allegationLabels = {
  'formal_allegation': 'Allegation made (refer Cause Consideration)',
  'informal_allegation':
      'Informal allegation made (refer Cause Consideration)',
  'no_formal_allegation': 'No formal allegation made',
};

const _towingLabels = {'yes': 'Yes', 'no': 'No', 'n_a': 'N/A'};

String _fmtAmt(num v) {
  final s = v.toStringAsFixed(2);
  final parts = s.split('.');
  final intPart = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '$intPart.${parts[1]}';
}

/// Builds the label/value rows for the Advice Summary table (spec:
/// "Section: Executive Summary (Advice Summary Table)" in
/// docs/report_builder_editor_notes.md).
///
/// As of 4 July 2026, most of these fields are sourced from the *case*
/// (`assembled.caseData`, `assembled.occurrences`, `assembled.
/// repairPeriods`) rather than the per-report-output `advice_*` columns —
/// per surveyor direction: "generally speaking... I would like to have all
/// the data input in the case page. The report builder is only for
/// drafting the paragraphs." Only genuinely per-report prose (Description
/// of Damage, Nature of Repairs, Remarks) and the Confirmed flag still live
/// on `report_outputs`; see `AdviceSummaryCard` for the corresponding
/// editor. The old `advice_cost_amount`/`advice_status_of_repairs`/
/// `advice_follow_up_required` etc. columns are left in place in the
/// schema (unused going forward) rather than dropped, since already-issued
/// reports may still reference them.
///
/// Always returns the full fixed 8-row spec layout — rows are never
/// omitted for missing data, matching the spec's own suggested layout
/// (which shows bracketed placeholders like "[auto or TBD]" for every
/// field).
List<List<String>> buildAdviceSummaryRows(
    ReportOutput output, AssembledReportData assembled) {
  final occ =
      assembled.occurrences.isNotEmpty ? assembled.occurrences.first : null;
  final caseData = assembled.caseData;

  final derivedStatus = deriveRepairStatus(
      assembled.repairPeriods.map(RepairPeriodModel.fromJson).toList());
  final costApproved = derivedStatus == DerivedRepairStatus.complete ||
      derivedStatus == DerivedRepairStatus.ongoing;

  final occDate =
      occ != null ? _formatOccDate(occ['date_time'] as String? ?? '') : '';
  final occTitle = (occ?['title'] as String?) ?? '';
  final dateAndNature = [
    occDate.isNotEmpty ? occDate : '[DOL date not yet recorded]',
    occTitle.isNotEmpty ? occTitle : '[nature of casualty not yet recorded]',
  ].join(' — ');

  final currency = caseData['base_currency'] as String? ?? '';
  final estimatedCost = (caseData['estimated_repair_cost'] as num?);
  final costAmountLine = estimatedCost != null
      ? '$currency ${_fmtAmt(estimatedCost)}'
      : '[not yet estimated]';
  final costIncludesGeneralExpenses =
      caseData['cost_includes_general_expenses'] as bool?;
  final generalExpensesLine = 'Including general expenses: '
      '${costIncludesGeneralExpenses == null ? '[TBD]' : (costIncludesGeneralExpenses ? 'Yes' : 'No')}';
  final towingLine = 'Including towing costs: '
      '${_towingLabels[caseData['cost_includes_towing'] as String?] ?? '[TBD]'}';
  final costLines = [costAmountLine, generalExpensesLine, towingLine];

  final feeHours = caseData['survey_fee_reserve_hours'] as num?;
  final feeExpenses = caseData['survey_fee_reserve_expenses'] as num?;
  final feeHoursLine = 'Hours: ${feeHours ?? '[not yet set]'}';
  final feeExpensesLine = 'Expenses: '
      '${feeExpenses != null ? '$currency ${_fmtAmt(feeExpenses)}' : '[not yet set]'}';
  final feeLines = [feeHoursLine, feeExpensesLine];

  final allegationType = occ?['allegation_type'] as String?;
  final followUpRequired = caseData['follow_up_required'] as bool?;
  final followUpDetail = caseData['follow_up_detail'] as String?;
  final remarksLines = <String>[
    _allegationLabels[allegationType] ?? '[allegation status not yet recorded]',
    if (followUpRequired == true)
      'Follow-up attendance required'
          '${(followUpDetail ?? '').isNotEmpty ? ': $followUpDetail' : ''}'
    else if (followUpRequired == false)
      'No follow-up attendance required'
    else
      'Follow-up required: [not yet recorded]',
    if ((output.adviceRemarks ?? '').isNotEmpty) output.adviceRemarks!,
  ];

  // UCR / Reference reuses the case-level Claim Reference field (Edit Case
  // Details) rather than duplicating it per report-output.
  final claimReference = caseData['claim_reference'] as String?;

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
    ['Status of Repairs', derivedStatus.label],
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
