// lib/features/reports/widgets/advice_summary_card.dart
//
// Structured "Advice Summary" table — Page 2 of the report, immediately
// below the AI Usage Disclosure and above the free-text Executive Summary
// narrative. See docs/report_builder_editor_notes.md
// "Section: Executive Summary (Advice Summary Table)" and TODO.md §2.6.
//
// 21 July 2026 — full tabular rework (surveyor: "I want a completely tabular
// card, similar to the report preview, with all the data fields repeated in
// the report preview"):
//   * EVERY field the Preview's Advice Summary table shows now renders here,
//     as a bordered label/value table, and rows are NEVER hidden when empty —
//     a missing value shows a placeholder (e.g. "[TBD]") instead of vanishing
//     (the old _autoRow collapsed empty fields, so missing Assured /
//     Instructing Party were invisible AND unfillable — e.g. the Astrolabe
//     case).
//   * The case-level identity fields — Technical File No., UCR / Reference,
//     Assured, Instructing Party — are now EDITABLE inline from the editor
//     (persisted via caseProvider.updateCaseRefs, which the accounts /
//     attendances editors also use), then assembledDataProvider is
//     invalidated so the card and the Preview refresh together.
//   * The structured/computed rows (Date & Nature, Damage, Nature of Repairs,
//     Status, Cost, Fee, Allegation, Follow-up) stay read-only with their
//     "Edit in X →" deep-link to the dedicated case-screen editor, but are
//     always visible with a placeholder so nothing is silently missing.
//   * Remarks (report-output level) stays editable via updateAdviceSummary.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/report_provider.dart';
import '../../cases/providers/cases_provider.dart';
import '../../survey/models/repair_period_model.dart';
import '../../../shared/theme/app_theme.dart';

class AdviceSummaryCard extends ConsumerStatefulWidget {
  const AdviceSummaryCard({
    super.key,
    required this.output,
    required this.assembled,
    required this.isLocked,
  });

  final ReportOutput output;
  final AssembledReportData assembled;
  final bool isLocked;

  @override
  ConsumerState<AdviceSummaryCard> createState() => _AdviceSummaryCardState();
}

String _allegationLabel(String? type) => switch (type) {
      'formal_allegation' => 'Allegation made (refer Cause Consideration)',
      'informal_allegation' => 'Informal allegation made (refer Cause Consideration)',
      'no_formal_allegation' => 'No formal allegation made',
      _ => '[allegation status not yet recorded]',
    };

const _towingLabels = {'yes': 'Yes', 'no': 'No', 'n_a': 'N/A'};

class _AdviceSummaryCardState extends ConsumerState<AdviceSummaryCard> {
  bool _expanded = true;
  late final Map<String, TextEditingController> _ctrls;
  Timer? _saveTimer; // report-output (Remarks / Confirmed)
  final Map<String, dynamic> _pending = {};
  Timer? _caseTimer; // case-level identity fields
  final Map<String, String> _pendingCase = {};

  @override
  void initState() {
    super.initState();
    final o = widget.output;
    final cd = widget.assembled.caseData;
    _ctrls = {
      'advice_remarks': TextEditingController(text: o.adviceRemarks ?? ''),
      'technical_file_no':
          TextEditingController(text: cd['technical_file_no'] as String? ?? ''),
      'claim_reference':
          TextEditingController(text: cd['claim_reference'] as String? ?? ''),
      'assured': TextEditingController(text: cd['assured'] as String? ?? ''),
      'instructing_party':
          TextEditingController(text: cd['instructing_party'] as String? ?? ''),
    };
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _caseTimer?.cancel();
    if (_pending.isNotEmpty) _persist();
    if (_pendingCase.isNotEmpty) _persistCase();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Report-output fields (Remarks) ────────────────────────────────────
  void _stage(String key, dynamic value) {
    _pending[key] = value;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _persist);
  }

  void _persist() {
    if (_pending.isEmpty) return;
    final fields = Map<String, dynamic>.from(_pending);
    _pending.clear();
    ref
        .read(reportOutputsProvider(widget.output.caseId).notifier)
        .updateAdviceSummary(widget.output.outputId, fields);
  }

  void _setNow(String key, dynamic value) {
    ref
        .read(reportOutputsProvider(widget.output.caseId).notifier)
        .updateAdviceSummary(widget.output.outputId, {key: value});
  }

  // ── Case-level identity fields (File No / UCR / Assured / Instructing) ──
  void _stageCase(String column, String value) {
    _pendingCase[column] = value.trim();
    _caseTimer?.cancel();
    _caseTimer = Timer(const Duration(milliseconds: 800), _persistCase);
  }

  Future<void> _persistCase() async {
    if (_pendingCase.isEmpty) return;
    final f = Map<String, String>.from(_pendingCase);
    _pendingCase.clear();
    final caseId = widget.output.caseId;
    await ref.read(caseProvider(caseId).notifier).updateCaseRefs(
          technicalFileNo: f['technical_file_no'],
          claimReference: f['claim_reference'],
          assured: f['assured'],
          instructingParty: f['instructing_party'],
        );
    // Refresh the assembled snapshot the card + Preview read from, so the
    // edit is reflected everywhere without leaving the editor.
    ref.invalidate(assembledDataProvider(caseId));
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.output;
    final caseId = o.caseId;
    final v = widget.assembled.vessel ?? {};
    final locked = widget.isLocked;

    final occ = widget.assembled.occurrences.isNotEmpty
        ? widget.assembled.occurrences.first
        : null;

    // Same computed section content the report body renders — kept in sync
    // by construction rather than re-derived here.
    final sections = ref.watch(
        sectionDraftProvider((caseId: caseId, outputId: o.outputId)));
    final damageContent =
        sections[SectionType.damageDescription]?.fullContent ?? '';
    final natureContent =
        sections[SectionType.natureOfRepairs]?.fullContent ?? '';

    final caseData = widget.assembled.caseData;
    final derivedStatus = deriveRepairStatus(widget.assembled.repairPeriods
        .map(RepairPeriodModel.fromJson)
        .toList());
    final costApproved = derivedStatus == DerivedRepairStatus.complete ||
        derivedStatus == DerivedRepairStatus.ongoing;
    final currency = caseData['base_currency'] as String? ?? '';
    final estimatedCost = caseData['estimated_repair_cost'] as num?;
    final costIncludesGeneralExpenses =
        caseData['cost_includes_general_expenses'] as bool?;
    final costIncludesTowing = caseData['cost_includes_towing'] as String?;
    final feeHours = caseData['survey_fee_reserve_hours'] as num?;
    final feeExpenses = caseData['survey_fee_reserve_expenses'] as num?;
    final followUpRequired = caseData['follow_up_required'] as bool?;
    final followUpDetail = caseData['follow_up_detail'] as String?;

    final imoFlag = [v['imo_number'], v['flag']]
        .where((e) => e != null && '$e'.isNotEmpty)
        .join(' / ');
    final reportTypeNo =
        [o.outputType.label, o.reportNumber ?? o.versionCode].join(' / ');
    final dateNature = occ?['title'] as String?;
    final costLine = [
      estimatedCost != null
          ? '$currency ${estimatedCost.toStringAsFixed(0)}'
          : '[not yet estimated]',
      'General expenses: ${costIncludesGeneralExpenses == null ? '[TBD]' : (costIncludesGeneralExpenses ? 'Yes' : 'No')}',
      'Towing: ${_towingLabels[costIncludesTowing] ?? '[TBD]'}',
    ].join('\n');
    final feeLine = 'Hours: ${feeHours ?? '[not set]'}\n'
        'Expenses: ${feeExpenses != null ? '$currency ${feeExpenses.toStringAsFixed(0)}' : '[not set]'}';
    final followUpLine = followUpRequired == true
        ? 'Required${(followUpDetail ?? '').isNotEmpty ? ' — $followUpDetail' : ''}'
        : followUpRequired == false
            ? 'Not required'
            : '[not yet recorded]';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: o.adviceConfirmed
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.border,
          width: o.adviceConfirmed ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Icon(
                  o.adviceConfirmed
                      ? Icons.check_circle
                      : Icons.summarize_outlined,
                  size: 18,
                  color: o.adviceConfirmed ? AppColors.success : AppColors.navy,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Advice Summary  ·  Page 2',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
                if (!locked)
                  Row(children: [
                    Checkbox(
                      value: o.adviceConfirmed,
                      onChanged: (val) =>
                          _setNow('advice_confirmed', val ?? false),
                      visualDensity: VisualDensity.compact,
                    ),
                    const Text('Confirmed',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more,
                      color: AppColors.textTertiary, size: 18),
                ),
              ]),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _table([
                _row('Vessel',
                    _ro(v['name'] as String?, edit: ('vessel', 'Vessel'), caseId: caseId),
                    first: true),
                _row('IMO / Flag', _ro(imoFlag)),
                _row('Report Type / No.', _ro(reportTypeNo)),
                _row('Technical File No.',
                    _edit('technical_file_no', (val) => _stageCase('technical_file_no', val), locked)),
                _row('UCR / Reference',
                    _edit('claim_reference', (val) => _stageCase('claim_reference', val), locked)),
                _row('Assured',
                    _edit('assured', (val) => _stageCase('assured', val), locked)),
                _row('Instructing Party',
                    _edit('instructing_party', (val) => _stageCase('instructing_party', val), locked)),
                _row('Date & Nature of Casualty',
                    _ro(dateNature, edit: ('occurrence', 'Occurrence'), caseId: caseId)),
                _row('Description of Damage',
                    _ro(damageContent,
                        placeholder: '[description of damage — pending]',
                        edit: autoPopulatedEditRoute[SectionType.damageDescription],
                        caseId: caseId)),
                _row('Nature of Repairs',
                    _ro(natureContent,
                        placeholder: '[nature of repairs — pending]',
                        edit: autoPopulatedEditRoute[SectionType.natureOfRepairs],
                        caseId: caseId)),
                _row('Status of Repairs',
                    _ro(derivedStatus.label, edit: ('repairs', 'Repair Periods'), caseId: caseId)),
                _row(costApproved ? 'Sum Approved (WP)' : 'Estimated Cost of Repairs',
                    _ro(costLine, edit: ('accounts', 'Accounts'), caseId: caseId)),
                _row('Survey Fee Reserve',
                    _ro(feeLine, edit: ('accounts', 'Accounts'), caseId: caseId)),
                _row('Allegation Status',
                    _ro(_allegationLabel(occ?['allegation_type'] as String?),
                        edit: ('occurrence', 'Occurrence'), caseId: caseId)),
                _row('Follow-up Attendance',
                    _ro(followUpLine, edit: ('attendances', 'Attendances'), caseId: caseId)),
                _row('Remarks',
                    _edit('advice_remarks', (val) => _stage('advice_remarks', val), locked,
                        maxLines: 3, hint: 'Free-text remarks…'),
                    last: true),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  // ── Table primitives ──────────────────────────────────────────────────
  Widget _table(List<Widget> rows) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: rows),
      );

  Widget _row(String label, Widget value, {bool first = false, bool last = false}) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: first
              ? BorderSide.none
              : const BorderSide(color: AppColors.border),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 150,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Align(
                    alignment: Alignment.centerLeft, child: value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Read-only value cell — always renders (placeholder when empty, italic
  /// grey) plus an optional "Edit in X →" deep-link to the case-screen editor.
  Widget _ro(String? value,
      {String placeholder = '[TBD]', (String, String)? edit, String? caseId}) {
    final trimmed = value?.trim() ?? '';
    final has = trimmed.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          has ? trimmed : placeholder,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.4,
            color: has ? AppColors.textPrimary : AppColors.textTertiary,
            fontStyle: has ? FontStyle.normal : FontStyle.italic,
          ),
        ),
        if (edit != null && caseId != null) _editLink(caseId, edit),
      ],
    );
  }

  /// Inline-editable value cell (borderless, so it reads as a table cell).
  Widget _edit(String key, void Function(String) onChanged, bool locked,
      {String hint = '[TBD]', int maxLines = 1}) {
    return TextField(
      key: ValueKey('advice-edit-$key'),
      controller: _ctrls[key]!,
      enabled: !locked,
      maxLines: maxLines,
      textInputAction: maxLines == 1 ? TextInputAction.done : null,
      style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary),
      onChanged: onChanged,
      onSubmitted:
          maxLines == 1 ? (_) => FocusScope.of(context).unfocus() : null,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 11, color: AppColors.textTertiary),
      ),
    );
  }

  Widget _editLink(String caseId, (String, String) route) {
    return TextButton.icon(
      onPressed: () => context.go('/cases/$caseId/${route.$1}'),
      icon: const Icon(Icons.open_in_new, size: 13),
      label: Text('Edit in ${route.$2} →',
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.midBlue,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 22),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.centerLeft,
      ),
    );
  }
}
