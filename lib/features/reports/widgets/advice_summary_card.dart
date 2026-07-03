// lib/features/reports/widgets/advice_summary_card.dart
//
// Structured "Advice Summary" table — Page 2 of the report, immediately
// below the AI Usage Disclosure and above the free-text Executive Summary
// narrative. See docs/report_builder_editor_notes.md
// "Section: Executive Summary (Advice Summary Table)" and TODO.md §2.6.
//
// Values are stored per report_output (docs/migrations/014_advice_summary.sql)
// since several fields legitimately change across successive reports on the
// same case (status of repairs, cost figures).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/report_provider.dart';
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

const _statusOptions = [
  ('complete', 'Complete'),
  ('ongoing', 'Ongoing'),
  ('awaiting', 'Awaiting'),
  ('deferred', 'Deferred to'),
  ('not_commenced', 'Not yet commenced'),
];

const _towingOptions = [
  ('yes', 'Yes'),
  ('no', 'No'),
  ('n_a', 'N/A'),
];

String _allegationLabel(String? type) => switch (type) {
      'formal_allegation' => 'Allegation made (refer Cause Consideration)',
      'informal_allegation' => 'Informal allegation made (refer Cause Consideration)',
      'no_formal_allegation' => 'No formal allegation made',
      _ => 'Not yet determined',
    };

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
      'advice_nature_of_casualty': TextEditingController(text: o.adviceNatureOfCasualty ?? ''),
      'advice_description_of_damage': TextEditingController(text: o.adviceDescriptionOfDamage ?? ''),
      'advice_nature_of_repairs': TextEditingController(text: o.adviceNatureOfRepairs ?? ''),
      'advice_status_of_repairs_detail': TextEditingController(text: o.adviceStatusOfRepairsDetail ?? ''),
      'advice_cost_amount': TextEditingController(text: o.adviceCostAmount?.toString() ?? ''),
      'advice_cost_currency': TextEditingController(
          text: o.adviceCostCurrency ?? (widget.assembled.caseData['base_currency'] as String? ?? 'AUD')),
      'advice_fee_reserve_hours': TextEditingController(text: o.adviceFeeReserveHours?.toString() ?? ''),
      'advice_fee_reserve_expenses': TextEditingController(text: o.adviceFeeReserveExpenses?.toString() ?? ''),
      'advice_follow_up_detail': TextEditingController(text: o.adviceFollowUpDetail ?? ''),
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
    // Discrete controls (dropdown/checkbox) — write immediately, no debounce.
    ref
        .read(reportOutputsProvider(widget.output.caseId).notifier)
        .updateAdviceSummary(widget.output.outputId, {key: value});
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.output;
    final v = widget.assembled.vessel ?? {};
    final caseData = widget.assembled.caseData;
    final occ = widget.assembled.occurrences.isNotEmpty
        ? widget.assembled.occurrences.first
        : null;
    final locked = widget.isLocked;

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
                  const SizedBox(height: 10),

                  _field('Nature of Casualty (owners\' description)', 'advice_nature_of_casualty', locked,
                      hint: 'e.g. Reported grounding'),
                  _field('Description of Damage', 'advice_description_of_damage', locked, maxLines: 4),
                  _field('Nature of Repairs', 'advice_nature_of_repairs', locked, maxLines: 4),

                  const SizedBox(height: 8),
                  const Text('Status of Repairs',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  _statusDropdown(locked),
                  if (o.adviceStatusOfRepairs == 'awaiting' || o.adviceStatusOfRepairs == 'deferred')
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _field('', 'advice_status_of_repairs_detail', locked, hint: 'Awaiting / deferred to...'),
                    ),

                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        flex: 2,
                        child: _field(
                            o.adviceStatusOfRepairs == 'complete' || o.adviceStatusOfRepairs == 'ongoing'
                                ? 'Sum Approved Without Prejudice'
                                : 'Estimated Cost of Repairs',
                            'advice_cost_amount', locked,
                            keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('Currency', 'advice_cost_currency', locked)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: InkWell(
                        onTap: locked
                            ? null
                            : () => _setNow('advice_cost_includes_general_expenses',
                                !(o.adviceCostIncludesGeneralExpenses ?? false)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: o.adviceCostIncludesGeneralExpenses ?? false,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onChanged: locked
                                  ? null
                                  : (val) => _setNow(
                                      'advice_cost_includes_general_expenses', val ?? false),
                            ),
                            const SizedBox(width: 4),
                            const Flexible(
                              child: Text('Incl. general expenses',
                                  style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: _towingDropdown(locked),
                    ),
                  ]),

                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field('Survey Fee Reserve — Hours', 'advice_fee_reserve_hours', locked, keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('Survey Fee Reserve — Expenses', 'advice_fee_reserve_expenses', locked, keyboardType: TextInputType.number)),
                  ]),

                  const SizedBox(height: 10),
                  _autoRow('Allegation Status', _allegationLabel(occ?['allegation_type'] as String?)),

                  const SizedBox(height: 10),
                  Row(children: [
                    const Text('Follow-up attendance required?',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('Yes', style: TextStyle(fontSize: 11)),
                      selected: o.adviceFollowUpRequired == true,
                      onSelected: locked ? null : (_) => _setNow('advice_follow_up_required', true),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('No', style: TextStyle(fontSize: 11)),
                      selected: o.adviceFollowUpRequired == false,
                      onSelected: locked ? null : (_) => _setNow('advice_follow_up_required', false),
                    ),
                  ]),
                  if (o.adviceFollowUpRequired == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _field('', 'advice_follow_up_detail', locked, hint: 'Nature and expected timeline...'),
                    ),

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

  Widget _statusDropdown(bool locked) {
    return DropdownButtonFormField<String>(
      initialValue: widget.output.adviceStatusOfRepairs,
      isDense: true,
      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
      ),
      hint: const Text('Select...', style: TextStyle(fontSize: 12)),
      items: _statusOptions
          .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2, style: const TextStyle(fontSize: 12))))
          .toList(),
      onChanged: locked ? null : (val) => _setNow('advice_status_of_repairs', val),
    );
  }

  Widget _towingDropdown(bool locked) {
    return DropdownButtonFormField<String>(
      initialValue: widget.output.adviceCostIncludesTowing,
      isDense: true,
      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        labelText: 'Towing costs',
        labelStyle: const TextStyle(fontSize: 11),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
      ),
      items: _towingOptions
          .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2, style: const TextStyle(fontSize: 12))))
          .toList(),
      onChanged: locked ? null : (val) => _setNow('advice_cost_includes_towing', val),
    );
  }
}
