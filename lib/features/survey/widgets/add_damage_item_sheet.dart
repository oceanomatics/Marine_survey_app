// lib/features/survey/widgets/add_damage_item_sheet.dart

import 'package:flutter/material.dart';
import '../providers/damage_provider.dart';
import '../../vessel/widgets/survey_field.dart';
import '../../../shared/theme/app_theme.dart';

class AddDamageItemSheet extends StatefulWidget {
  const AddDamageItemSheet({
    super.key,
    required this.caseId,
    required this.occurrenceId,
    required this.onSave,
    this.existing,
  });

  final String caseId;
  final String occurrenceId;
  final DamageItemModel? existing;
  final Future<void> Function(DamageItemModel) onSave;

  @override
  State<AddDamageItemSheet> createState() => _AddDamageItemSheetState();
}

class _AddDamageItemSheetState extends State<AddDamageItemSheet> {
  final _componentCtrl   = TextEditingController();
  final _locationCtrl    = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _conditionCtrl   = TextEditingController();
  final _exclusionCtrl   = TextEditingController();
  final _machineryCtrl   = TextEditingController();

  DamageCategory _category     = DamageCategory.other;
  RepairType _repairType        = RepairType.permanent;
  RepairStatus _repairStatus    = RepairStatus.notStarted;
  bool _isConcerningAverage     = true;
  bool _saving                  = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _componentCtrl.text   = e.componentName;
      _locationCtrl.text    = e.locationOnVessel   ?? '';
      _descriptionCtrl.text = e.damageDescription  ?? '';
      _conditionCtrl.text   = e.conditionFound      ?? '';
      _exclusionCtrl.text   = e.exclusionReason     ?? '';
      _category             = e.damageCategory;
      _repairType           = e.repairType          ?? RepairType.permanent;
      _repairStatus         = e.repairStatus;
      _isConcerningAverage  = e.isConcerningAverage;
    }
  }

  @override
  void dispose() {
    _componentCtrl.dispose();
    _locationCtrl.dispose();
    _descriptionCtrl.dispose();
    _conditionCtrl.dispose();
    _exclusionCtrl.dispose();
    _machineryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_componentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Component name is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final item = DamageItemModel(
        damageId:          widget.existing?.damageId ?? '',
        occurrenceId:      widget.occurrenceId,
        caseId:            widget.caseId,
        componentName:     _componentCtrl.text.trim(),
        damageCategory:    _category,
        locationOnVessel:  _locationCtrl.text.trim().isEmpty
            ? null : _locationCtrl.text.trim(),
        damageDescription: _descriptionCtrl.text.trim().isEmpty
            ? null : _descriptionCtrl.text.trim(),
        conditionFound:    _conditionCtrl.text.trim().isEmpty
            ? null : _conditionCtrl.text.trim(),
        repairType:        _repairType,
        repairStatus:      _repairStatus,
        isConcerningAverage: _isConcerningAverage,
        exclusionReason:   !_isConcerningAverage &&
                _exclusionCtrl.text.trim().isNotEmpty
            ? _exclusionCtrl.text.trim()
            : null,
        sequenceNo:        widget.existing?.sequenceNo ?? 1,
      );
      await widget.onSave(item);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.lightCoral,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_outlined,
                    color: AppColors.coral, size: 17),
              ),
              const SizedBox(width: 10),
              Text(
                isEdit ? 'Edit Damage Item' : 'Add Damage Item',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Damage Category ──────────────────────────────────────
            const _FieldLabel('Damage Category'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DamageCategory.values.map((cat) {
                final selected = _category == cat;
                final color = _categoryColor(cat);
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: 0.12)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? color : AppColors.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_categoryIcon(cat),
                          size: 13,
                          color: selected
                              ? color
                              : AppColors.textTertiary),
                      const SizedBox(width: 5),
                      Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: selected
                              ? color
                              : AppColors.textSecondary,
                        ),
                      ),
                    ]),
                  ),
                );
              }).toList(),
            ),

            if (_category == DamageCategory.mechanical) ...[
              const SizedBox(height: 10),
              SurveyField(
                label: 'Machinery / System',
                controller: _machineryCtrl,
                hint: 'e.g. Main Engine, Generator No. 2, Steering Gear',
              ),
            ],

            const SizedBox(height: 16),

            SurveyField(
              label: 'Component / Equipment *',
              controller: _componentCtrl,
              hint: 'e.g. Main diesel generator No.3 — connecting rod cap',
              important: true,
            ),

            SurveyField(
              label: 'Location on Vessel',
              controller: _locationCtrl,
              hint: 'e.g. Engine room, port side',
            ),

            SurveyField(
              label: 'Damage Description',
              controller: _descriptionCtrl,
              hint: 'Describe the damage found...',
              maxLines: 3,
            ),

            SurveyField(
              label: 'Condition Found',
              controller: _conditionCtrl,
              hint:
                  'e.g. Complete running units No.15 and No.16, '
                  'connecting rod, bearing shells, piston and pins, '
                  'smashed and twisted.',
              maxLines: 3,
            ),

            const SizedBox(height: 4),

            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Repair Type'),
                    const SizedBox(height: 5),
                    DropdownButtonFormField<RepairType>(
                      initialValue: _repairType,
                      decoration: _dropdownDeco(),
                      items: RepairType.values
                          .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.label,
                                  style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _repairType = v ?? _repairType),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Repair Status'),
                    const SizedBox(height: 5),
                    DropdownButtonFormField<RepairStatus>(
                      initialValue: _repairStatus,
                      decoration: _dropdownDeco(),
                      items: RepairStatus.values
                          .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.label,
                                  style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) =>
                          setState(() =>
                              _repairStatus = v ?? _repairStatus),
                    ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _isConcerningAverage
                    ? AppColors.lightBlue
                    : AppColors.lightAmber,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isConcerningAverage
                      ? AppColors.midBlue.withValues(alpha: 0.3)
                      : AppColors.amber.withValues(alpha: 0.3),
                ),
              ),
              child: Row(children: [
                Icon(
                  _isConcerningAverage
                      ? Icons.check_circle_outline
                      : Icons.person_outline,
                  color: _isConcerningAverage
                      ? AppColors.midBlue
                      : AppColors.amber,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isConcerningAverage
                        ? 'Concerning average (claim-related)'
                        : "Owner's account (not claim-related)",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isConcerningAverage
                          ? AppColors.midBlue
                          : AppColors.amber,
                    ),
                  ),
                ),
                Switch(
                  value: _isConcerningAverage,
                  onChanged: (v) =>
                      setState(() => _isConcerningAverage = v),
                  activeThumbColor: AppColors.midBlue,
                ),
              ]),
            ),

            if (!_isConcerningAverage) ...[
              const SizedBox(height: 10),
              SurveyField(
                label: "Reason (owner's account)",
                controller: _exclusionCtrl,
                hint:
                    'e.g. Pre-existing condition unrelated to casualty under review',
              ),
            ],

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(isEdit ? 'Update Item' : 'Add Damage Item',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(DamageCategory cat) => switch (cat) {
        DamageCategory.structuralExternal    => AppColors.coral,
        DamageCategory.structuralInternal    => AppColors.navy,
        DamageCategory.mechanical            => AppColors.amber,
        DamageCategory.electricalElectronics => AppColors.purple,
        DamageCategory.other                 => AppColors.textSecondary,
      };

  IconData _categoryIcon(DamageCategory cat) => switch (cat) {
        DamageCategory.structuralExternal    => Icons.shield_outlined,
        DamageCategory.structuralInternal    => Icons.home_outlined,
        DamageCategory.mechanical            => Icons.settings_outlined,
        DamageCategory.electricalElectronics => Icons.bolt_outlined,
        DamageCategory.other                 => Icons.help_outline,
      };

  InputDecoration _dropdownDeco() => InputDecoration(
        filled: true,
        fillColor: Colors.white,
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
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
