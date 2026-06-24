// lib/features/survey/widgets/add_repair_sheet.dart

import 'package:flutter/material.dart';
import '../providers/damage_provider.dart';
import '../../../shared/theme/app_theme.dart';

class AddRepairSheet extends StatefulWidget {
  const AddRepairSheet({
    super.key,
    required this.caseId,
    required this.occurrenceId,
    required this.availableDamageItems,
    required this.onSave,
    this.existing,
  });

  final String caseId;
  final String occurrenceId;
  final List<DamageItemModel> availableDamageItems;
  final Future<void> Function(RepairModel) onSave;
  final RepairModel? existing;

  @override
  State<AddRepairSheet> createState() => _AddRepairSheetState();
}

class _AddRepairSheetState extends State<AddRepairSheet> {
  final _descriptionCtrl = TextEditingController();
  final _estCostCtrl     = TextEditingController();
  final _actCostCtrl     = TextEditingController();
  final _notesCtrl       = TextEditingController();

  RepairType _repairType     = RepairType.temporary;
  RepairStatus _repairStatus = RepairStatus.notStarted;
  DateTime? _completionDate;
  final Set<String> _linkedIds = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _repairType       = e.repairType;
      _repairStatus     = e.repairStatus;
      _descriptionCtrl.text = e.description ?? '';
      _estCostCtrl.text = e.estimatedCost != null
          ? e.estimatedCost!.toStringAsFixed(0)
          : '';
      _actCostCtrl.text = e.actualCost != null
          ? e.actualCost!.toStringAsFixed(0)
          : '';
      _notesCtrl.text   = e.notes ?? '';
      _completionDate   = e.completionDate;
      _linkedIds.addAll(e.linkedDamageIds);
    }
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _estCostCtrl.dispose();
    _actCostCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repair = RepairModel(
        repairId:        widget.existing?.repairId ?? '',
        occurrenceId:    widget.occurrenceId,
        caseId:          widget.caseId,
        repairType:      _repairType,
        repairStatus:    _repairStatus,
        description:     _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        estimatedCost:   double.tryParse(
            _estCostCtrl.text.replaceAll(',', '')),
        actualCost:      double.tryParse(
            _actCostCtrl.text.replaceAll(',', '')),
        completionDate:  _completionDate,
        notes:           _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
        linkedDamageIds: _linkedIds.toList(),
        sequenceNo:      widget.existing?.sequenceNo ?? 1,
      );
      await widget.onSave(repair);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _completionDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('en', 'AU'),
    );
    if (picked != null && mounted) setState(() => _completionDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.build_outlined,
                    color: AppColors.midBlue, size: 17),
              ),
              const SizedBox(width: 10),
              Text(
                isEdit ? 'Edit Repair' : 'Add Repair',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Repair Type chips ────────────────────────────────────
            const _Label('Repair Type'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: RepairType.values.map((t) {
                final sel = _repairType == t;
                final color = _typeColor(t);
                return GestureDetector(
                  onTap: () => setState(() => _repairType = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? color.withValues(alpha: 0.12)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? color : AppColors.border,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      t.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            sel ? FontWeight.w600 : FontWeight.normal,
                        color: sel ? color : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── Status ───────────────────────────────────────────────
            const _Label('Status'),
            const SizedBox(height: 6),
            DropdownButtonFormField<RepairStatus>(
              initialValue: _repairStatus,
              decoration: _fieldDeco(),
              items: RepairStatus.values
                  .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.label,
                          style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _repairStatus = v ?? _repairStatus),
            ),
            const SizedBox(height: 16),

            // ── Description ──────────────────────────────────────────
            const _Label('Description'),
            const SizedBox(height: 6),
            TextField(
              controller: _descriptionCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: _fieldDeco(
                  hint: 'What repair work was / will be done...'),
            ),
            const SizedBox(height: 16),

            // ── Linked damage items ──────────────────────────────────
            if (widget.availableDamageItems.isNotEmpty) ...[
              const _Label('Addresses Damage Items'),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: widget.availableDamageItems.map((item) {
                    final checked = _linkedIds.contains(item.damageId);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _linkedIds.add(item.damageId);
                        } else {
                          _linkedIds.remove(item.damageId);
                        }
                      }),
                      tileColor: Colors.transparent,
                      title: Text(item.componentName,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: item.damageCategory != DamageCategory.other
                          ? Text(item.damageCategory.label,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary))
                          : null,
                      dense: true,
                      activeColor: AppColors.midBlue,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Costs ────────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Estimated Cost'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _estCostCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: const TextStyle(fontSize: 13),
                      decoration: _fieldDeco(hint: '0', prefix: 'AUD '),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Actual Cost'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _actCostCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: const TextStyle(fontSize: 13),
                      decoration: _fieldDeco(hint: '0', prefix: 'AUD '),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Completion date ──────────────────────────────────────
            const _Label('Completion Date'),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: AppColors.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _completionDate != null
                          ? _fmtDate(_completionDate!)
                          : 'Select date',
                      style: TextStyle(
                        fontSize: 13,
                        color: _completionDate != null
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                  if (_completionDate != null)
                    GestureDetector(
                      onTap: () =>
                          setState(() => _completionDate = null),
                      child: const Icon(Icons.clear,
                          size: 16, color: AppColors.textTertiary),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // ── Notes ────────────────────────────────────────────────
            const _Label('Notes'),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration:
                  _fieldDeco(hint: 'Any additional notes or remarks...'),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.midBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(isEdit ? 'Update Repair' : 'Add Repair',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Color _typeColor(RepairType t) => switch (t) {
        RepairType.temporary => AppColors.warning,
        RepairType.permanent => AppColors.success,
        RepairType.deferred  => AppColors.textSecondary,
      };

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  InputDecoration _fieldDeco({String? hint, String? prefix}) =>
      InputDecoration(
        hintText: hint,
        prefixText: prefix,
        hintStyle:
            const TextStyle(color: AppColors.textTertiary, fontSize: 13),
        prefixStyle:
            const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary),
      );
}
