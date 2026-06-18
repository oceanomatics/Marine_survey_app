// lib/features/survey/widgets/assign_repair_items_sheet.dart

import 'package:flutter/material.dart';
import '../models/repair_period_model.dart';
import '../providers/damage_provider.dart';
import '../../../shared/theme/app_theme.dart';

const _kColor = Color(0xFF1A6B9E);

class AssignRepairItemsSheet extends StatefulWidget {
  const AssignRepairItemsSheet({
    super.key,
    required this.period,
    required this.ds,
    required this.onSave,
  });

  final RepairPeriodModel period;
  final DamageState ds;
  final Future<void> Function(
    Map<String, RepairType> outcomes,
    Map<String, bool> concerning,
    Map<String, String?> notes,
  ) onSave;

  @override
  State<AssignRepairItemsSheet> createState() => _AssignRepairItemsSheetState();
}

class _AssignRepairItemsSheetState extends State<AssignRepairItemsSheet> {
  late final Map<String, RepairType?> _selections;
  late final Map<String, bool> _concerning;
  late final Map<String, TextEditingController> _noteCtrlMap;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selections = {};
    _concerning = {};
    _noteCtrlMap = {};
    for (final item in widget.ds.damageItems) {
      _selections[item.damageId] = null;
      _concerning[item.damageId] = item.isConcerningAverage;
      _noteCtrlMap[item.damageId] = TextEditingController();
    }
    for (final a in widget.period.assignments) {
      if (_selections.containsKey(a.damageId)) {
        _selections[a.damageId] = a.outcome;
        _concerning[a.damageId] = a.isConcerningAverage;
        _noteCtrlMap[a.damageId]?.text = a.notes ?? '';
      }
    }
  }

  @override
  void dispose() {
    for (final ctrl in _noteCtrlMap.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _error = null; _saving = true; });
    try {
      final outcomes = Map.fromEntries(
        _selections.entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value!)),
      );
      final concerning = Map.fromEntries(
        outcomes.keys.map((id) => MapEntry(id, _concerning[id] ?? true)),
      );
      final notes = Map.fromEntries(
        outcomes.keys.map((id) {
          final text = _noteCtrlMap[id]?.text.trim();
          return MapEntry(id, text?.isEmpty == true ? null : text);
        }),
      );
      await widget.onSave(outcomes, concerning, notes);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.checklist, color: _kColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assign Items — ${widget.period.displayTitle}',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                          ),
                          const Text(
                            'Select damage items and set their repair outcome',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.5),

              if (_error != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(fontSize: 12, color: AppColors.error)),
                ),

              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  children: [
                    for (final occ in widget.ds.occurrences) ...[
                      _OccurrenceHeader(occ: occ),
                      for (final cat in DamageCategory.values) ...[
                        ...() {
                          final items = widget.ds
                              .itemsForOccurrenceAndCategory(occ.occurrenceId, cat);
                          if (items.isEmpty) return <Widget>[];
                          return [
                            _CategoryLabel(cat: cat),
                            ...items.map((item) => _ItemRow(
                                  item: item,
                                  selected: _selections[item.damageId] != null,
                                  outcome: _selections[item.damageId],
                                  isConcerningAverage:
                                      _concerning[item.damageId] ?? true,
                                  notesCtrl: _noteCtrlMap[item.damageId]!,
                                  onToggle: (v) => setState(() {
                                    _selections[item.damageId] =
                                        v ? RepairType.temporary : null;
                                  }),
                                  onOutcome: (o) => setState(
                                      () => _selections[item.damageId] = o),
                                  onConcerningChanged: (v) => setState(
                                      () => _concerning[item.damageId] = v),
                                )),
                          ];
                        }(),
                      ],
                    ],
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(
                      top: BorderSide(color: AppColors.border, width: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8, offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            'Save Assignments (${_selections.values.where((v) => v != null).length} selected)',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OccurrenceHeader extends StatelessWidget {
  const _OccurrenceHeader({required this.occ});
  final OccurrenceModel occ;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: AppColors.coral,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(
              child: Text(
                '${occ.occurrenceNo}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            occ.title ?? 'Occurrence ${occ.occurrenceNo}',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.coral),
          ),
        ],
      ),
    );
  }
}

class _CategoryLabel extends StatelessWidget {
  const _CategoryLabel({required this.cat});
  final DamageCategory cat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 0, 2),
      child: Text(
        cat.label.toUpperCase(),
        style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textTertiary),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.selected,
    required this.outcome,
    required this.isConcerningAverage,
    required this.notesCtrl,
    required this.onToggle,
    required this.onOutcome,
    required this.onConcerningChanged,
  });

  final DamageItemModel item;
  final bool selected;
  final RepairType? outcome;
  final bool isConcerningAverage;
  final TextEditingController notesCtrl;
  final ValueChanged<bool> onToggle;
  final ValueChanged<RepairType> onOutcome;
  final ValueChanged<bool> onConcerningChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: selected
            ? _kColor.withValues(alpha: 0.04)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? _kColor.withValues(alpha: 0.3) : AppColors.border,
          width: selected ? 1.2 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => onToggle(!selected),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 20, height: 20,
                    child: Checkbox(
                      value: selected,
                      onChanged: (v) => onToggle(v ?? false),
                      activeColor: _kColor,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.componentName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (item.damageDescription != null &&
                            item.damageDescription!.isNotEmpty)
                          Text(
                            item.damageDescription!.length > 80
                                ? '${item.damageDescription!.substring(0, 80)}…'
                                : item.damageDescription!,
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textTertiary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (selected) ...[
            const Divider(height: 1, thickness: 0.5, indent: 12, endIndent: 12),
            // Outcome chips
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Row(
                children: [
                  const Text('Outcome:',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: RepairType.values.map((rt) {
                        final isSelected = outcome == rt;
                        final color = _outcomeColor(rt);
                        return GestureDetector(
                          onTap: () => onOutcome(rt),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected ? color : AppColors.border,
                                width: isSelected ? 1.3 : 1,
                              ),
                            ),
                            child: Text(
                              rt.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? color
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            // Concerning average toggle
            InkWell(
              onTap: () => onConcerningChanged(!isConcerningAverage),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20, height: 20,
                      child: Checkbox(
                        value: isConcerningAverage,
                        onChanged: (v) => onConcerningChanged(v ?? true),
                        activeColor: AppColors.success,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Concerning the average',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 6),
                    if (!isConcerningAverage)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("Owner's A/c",
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                      ),
                  ],
                ),
              ),
            ),
            // Notes field
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: TextField(
                controller: notesCtrl,
                decoration: InputDecoration(
                  hintText: 'Notes about what was done (optional)',
                  hintStyle: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.surface,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                minLines: 1,
                maxLines: 3,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _outcomeColor(RepairType rt) => switch (rt) {
        RepairType.temporary => AppColors.warning,
        RepairType.permanent => AppColors.success,
        RepairType.deferred  => AppColors.textSecondary,
      };
}
