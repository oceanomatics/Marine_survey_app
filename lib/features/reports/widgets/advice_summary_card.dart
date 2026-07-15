// lib/features/reports/widgets/advice_summary_card.dart
//
// Structured "Advice Summary" table — Page 2 of the report, immediately
// below the AI Usage Disclosure and above the free-text Executive Summary
// narrative. See docs/report_builder_editor_notes.md
// "Section: Executive Summary (Advice Summary Table)" and TODO.md §2.6.
//
// As of 4 July 2026, most Advice Summary fields have been relocated to the
// case screen (per surveyor direction: "the report builder is only for
// drafting the paragraphs") — see AccountsScreen (cost estimate, cost
// inclusions, survey fee reserve), AttendancesScreen (follow-up attendance),
// and deriveRepairStatus() in repair_period_model.dart (status of repairs,
// now computed from repair periods rather than typed).
//
// 14 July 2026: Description of Damage and Nature of Repairs were the last
// two fields still typed here as free text, duplicating the real
// SectionType.damageDescription/natureOfRepairs sections in the report body
// — surveyor flagged this live as inconsistent with everything else on this
// card. Converted to read-only, sourced from `sectionDraftProvider` (the
// same computed state the body sections render, kept in sync by
// construction rather than re-derived). Also added Assured/Instructing
// Party (previously missing from the 12-field spec, docs/AUDIT_delta.md)
// and a real "Edit in X →" deep-link on every read-only group, matching the
// pattern already used in section_editor.dart — this card predated that
// convention (built 4 July, deep-link landed 10 July) and was never
// retrofitted. `advice_remarks` is now the only free-text field left.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/report_provider.dart';
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
      _ => 'Not yet determined',
    };

const _towingLabels = {'yes': 'Yes', 'no': 'No', 'n_a': 'N/A'};

class _AdviceSummaryCardState extends ConsumerState<AdviceSummaryCard> {
  bool _expanded = true;
  late final Map<String, TextEditingController> _ctrls;
  Timer? _saveTimer;
  final Map<String, dynamic> _pending = {};

  @override
  void initState() {
    super.initState();
    final o = widget.output;
    _ctrls = {
      'advice_remarks': TextEditingController(text: o.adviceRemarks ?? ''),
    };
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_pending.isNotEmpty) _persist();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

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
    // Discrete controls (checkbox) — write immediately, no debounce.
    ref
        .read(reportOutputsProvider(widget.output.caseId).notifier)
        .updateAdviceSummary(widget.output.outputId, {key: value});
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.output;
    final caseId = o.caseId;
    final v = widget.assembled.vessel ?? {};
    final caseData = widget.assembled.caseData;
    final occ = widget.assembled.occurrences.isNotEmpty
        ? widget.assembled.occurrences.first
        : null;
    final locked = widget.isLocked;

    // Same computed section state the report body renders — kept in sync
    // by construction rather than re-derived here.
    final sections = ref.watch(
        sectionDraftProvider((caseId: caseId, outputId: o.outputId)));
    final damageContent =
        sections[SectionType.damageDescription]?.fullContent ?? '';
    final natureContent =
        sections[SectionType.natureOfRepairs]?.fullContent ?? '';

    final derivedStatus = deriveRepairStatus(widget.assembled.repairPeriods
        .map(RepairPeriodModel.fromJson)
        .toList());
    final currency = caseData['base_currency'] as String? ?? '';
    final estimatedCost = caseData['estimated_repair_cost'] as num?;
    final costIncludesGeneralExpenses =
        caseData['cost_includes_general_expenses'] as bool?;
    final costIncludesTowing = caseData['cost_includes_towing'] as String?;
    final feeHours = caseData['survey_fee_reserve_hours'] as num?;
    final feeExpenses = caseData['survey_fee_reserve_expenses'] as num?;
    final followUpRequired = caseData['follow_up_required'] as bool?;
    final followUpDetail = caseData['follow_up_detail'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: o.adviceConfirmed ? AppColors.success.withValues(alpha: 0.4) : AppColors.border,
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
                  o.adviceConfirmed ? Icons.check_circle : Icons.summarize_outlined,
                  size: 18,
                  color: o.adviceConfirmed ? AppColors.success : AppColors.navy,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Advice Summary  ·  Page 2',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ),
                if (!locked)
                  Row(children: [
                    Checkbox(
                      value: o.adviceConfirmed,
                      onChanged: (val) => _setNow('advice_confirmed', val ?? false),
                      visualDensity: VisualDensity.compact,
                    ),
                    const Text('Confirmed', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more, color: AppColors.textTertiary, size: 18),
                ),
              ]),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _autoRow('Vessel', v['name'] as String?),
                  _autoRow('IMO / Flag', [v['imo_number'], v['flag']].where((e) => e != null && '$e'.isNotEmpty).join(' / ')),
                  _autoRow('Report Type / No.', [o.outputType.label, o.reportNumber ?? o.versionCode].join(' / ')),
                  _autoRow('Technical File No.', caseData['technical_file_no'] as String?),
                  _autoRow('UCR / Reference', caseData['claim_reference'] as String?),
                  _autoRow('Assured', caseData['assured'] as String?),
                  _autoRow('Instructing Party', caseData['instructing_party'] as String?),
                  _autoRow('Date and Nature of Casualty', occ?['title'] as String?),
                  const SizedBox(height: 10),

                  _autoProseSection(
                    'Description of Damage',
                    damageContent,
                    caseId: caseId,
                    route: autoPopulatedEditRoute[SectionType.damageDescription],
                  ),
                  const SizedBox(height: 10),
                  _autoProseSection(
                    'Nature of Repairs',
                    natureContent,
                    caseId: caseId,
                    route: autoPopulatedEditRoute[SectionType.natureOfRepairs],
                  ),

                  const SizedBox(height: 10),
                  _readOnlySection('Data now entered in the case screen', [
                    ('Status of Repairs', derivedStatus.label),
                    (
                      'Estimated Cost of Repairs',
                      estimatedCost != null ? '$currency ${estimatedCost.toStringAsFixed(0)}' : 'Not yet set',
                    ),
                    (
                      'Cost Inclusions',
                      'General expenses: ${costIncludesGeneralExpenses == null ? 'TBD' : (costIncludesGeneralExpenses ? 'Yes' : 'No')}  ·  '
                          'Towing: ${_towingLabels[costIncludesTowing] ?? 'TBD'}',
                    ),
                    (
                      'Survey Fee Reserve',
                      'Hours: ${feeHours ?? '—'}   Expenses: ${feeExpenses != null ? '$currency ${feeExpenses.toStringAsFixed(0)}' : '—'}',
                    ),
                  ], caseId: caseId, route: ('accounts', 'Accounts')),

                  const SizedBox(height: 10),
                  _readOnlySection('Data now entered in the case screen', [
                    (
                      'Follow-up Attendance',
                      followUpRequired == true
                          ? 'Required${(followUpDetail ?? '').isNotEmpty ? ' — $followUpDetail' : ''}'
                          : followUpRequired == false
                              ? 'Not required'
                              : 'Not yet recorded',
                    ),
                  ], caseId: caseId, route: ('attendances', 'Attendances')),

                  const SizedBox(height: 10),
                  _autoRow('Allegation Status', _allegationLabel(occ?['allegation_type'] as String?)),

                  const SizedBox(height: 10),
                  _field('Remarks', 'advice_remarks', locked, maxLines: 3),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _autoRow(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 130,
              child: Text(label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w600))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
        ],
      ),
    );
  }

  Widget _readOnlySection(String heading, List<(String, String)> rows,
      {required String caseId, required (String, String) route}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.lock_clock_outlined, size: 11, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(heading,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary)),
          ]),
          const SizedBox(height: 6),
          for (final r in rows) _autoRow(r.$1, r.$2),
          const SizedBox(height: 4),
          _editLink(caseId, route),
        ],
      ),
    );
  }

  /// Deep-link button matching the pattern already used for auto-populated
  /// body sections (section_editor.dart) — this card predated that
  /// convention and only ever showed static hint text until 14 July 2026.
  Widget _editLink(String caseId, (String, String) route) {
    return TextButton.icon(
      onPressed: () => context.go('/cases/$caseId/${route.$1}'),
      icon: const Icon(Icons.open_in_new, size: 13),
      label: Text('Edit in ${route.$2} →',
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.midBlue,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: const Size(0, 24),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  /// Read-only auto-populated prose (Description of Damage / Nature of
  /// Repairs) — sourced from the same computed section content the report
  /// body renders, replacing what used to be a free-text box duplicating
  /// that content. Only Remarks stays manually editable on this card.
  Widget _autoProseSection(String label, String content,
      {required String caseId, (String, String)? route}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            content.isNotEmpty ? content : 'No data on file yet.',
            style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, height: 1.5),
          ),
        ),
        if (route != null) _editLink(caseId, route),
      ],
    );
  }

  Widget _field(String label, String key, bool locked,
      {String? hint, int maxLines = 1, TextInputType? keyboardType}) {
    final ctrl = _ctrls[key]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
        TextField(
          controller: ctrl,
          enabled: !locked,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          onChanged: (val) => _stage(key,
              keyboardType == TextInputType.number ? num.tryParse(val) : val),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.midBlue, width: 1.5)),
          ),
        ),
      ],
    );
  }
}
