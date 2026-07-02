// lib/features/survey/widgets/add_damage_item_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/damage_provider.dart';
import '../../vessel/providers/vessel_provider.dart';
import '../../vessel/widgets/survey_field.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/chip_row.dart';

// Quick-pick condition labels for mechanical/electrical damage
const _conditionSuggestions = [
  'In situ',
  'Running at time of survey',
  'Stopped for survey',
  'Removed for inspection',
  'Removed for repair',
  'Dismantled — laid out',
  'As found — not disturbed',
  'Presented for survey',
];

class AddDamageItemSheet extends ConsumerStatefulWidget {
  const AddDamageItemSheet({
    super.key,
    required this.caseId,
    required this.occurrenceId,
    required this.onSave,
    this.vesselId,
    this.existing,
    this.occurrences = const [],
  });

  final String caseId;
  final String? vesselId;
  final String occurrenceId;
  final DamageItemModel? existing;
  final Future<void> Function(DamageItemModel) onSave;
  final List<OccurrenceModel> occurrences;

  @override
  ConsumerState<AddDamageItemSheet> createState() =>
      _AddDamageItemSheetState();
}

class _AddDamageItemSheetState extends ConsumerState<AddDamageItemSheet> {
  final _componentCtrl   = TextEditingController();
  final _locationCtrl    = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _conditionCtrl   = TextEditingController();
  final _exclusionCtrl   = TextEditingController();
  final _newComponentCtrl = TextEditingController();
  final _confirmationMethodCtrl = TextEditingController();
  final _averagePartialCtrl     = TextEditingController();

  DamageCategory _category            = DamageCategory.other;
  bool _saving                        = false;
  late String _selectedOccurrenceId;

  ConditionStatus? _conditionStatus;
  final Set<ConfirmedByRole> _confirmedBy = {};
  DateTime? _confirmationDate;
  AverageStatus _averageStatus = AverageStatus.yes;

  // Machinery / component selection
  String? _selectedMachineryId;
  String? _selectedComponentId;
  bool _addingNewComponent            = false;

  @override
  void initState() {
    super.initState();
    _selectedOccurrenceId = widget.occurrenceId;
    final e = widget.existing;
    if (e != null) {
      _componentCtrl.text   = e.componentName;
      _locationCtrl.text    = e.locationOnVessel   ?? '';
      _descriptionCtrl.text = e.damageDescription  ?? '';
      _conditionCtrl.text   = e.conditionFound      ?? '';
      _exclusionCtrl.text   = e.exclusionReason     ?? '';
      _category             = e.damageCategory;
      _selectedMachineryId  = e.machineryId;
      _selectedComponentId  = e.componentId;
      _conditionStatus      = e.conditionStatus;
      _confirmedBy.addAll(e.confirmedBy);
      _confirmationDate     = e.confirmationDate;
      _confirmationMethodCtrl.text = e.confirmationMethod ?? '';
      _averageStatus = e.averageStatus ??
          (e.isConcerningAverage ? AverageStatus.yes : AverageStatus.no);
      _averagePartialCtrl.text = e.averagePartialDetail ?? '';
    }
  }

  @override
  void dispose() {
    _componentCtrl.dispose();
    _locationCtrl.dispose();
    _descriptionCtrl.dispose();
    _conditionCtrl.dispose();
    _exclusionCtrl.dispose();
    _newComponentCtrl.dispose();
    _confirmationMethodCtrl.dispose();
    _averagePartialCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_componentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Component / equipment name is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      // If user typed a new component name, create it in vessel_components first
      String? resolvedComponentId = _selectedComponentId;
      if (_addingNewComponent &&
          _newComponentCtrl.text.trim().isNotEmpty &&
          _selectedMachineryId != null &&
          widget.vesselId != null) {
        final created = await ref
            .read(vesselComponentsProvider(_selectedMachineryId!).notifier)
            .addComponent(VesselComponentModel(
              componentId:  '',
              machineryId:  _selectedMachineryId!,
              vesselId:     widget.vesselId!,
              name:         _newComponentCtrl.text.trim(),
            ));
        resolvedComponentId = created.componentId;
        // Also use it as the component name in the damage item
        if (_componentCtrl.text.trim().isEmpty) {
          _componentCtrl.text = created.name;
        }
      }

      final item = DamageItemModel(
        damageId:          widget.existing?.damageId ?? '',
        occurrenceId:      _selectedOccurrenceId,
        caseId:            widget.caseId,
        componentName:     _componentCtrl.text.trim(),
        damageCategory:    _category,
        machineryId:       _selectedMachineryId,
        componentId:       resolvedComponentId,
        locationOnVessel:  _locationCtrl.text.trim().isEmpty
            ? null : _locationCtrl.text.trim(),
        damageDescription: _descriptionCtrl.text.trim().isEmpty
            ? null : _descriptionCtrl.text.trim(),
        conditionFound:    _conditionCtrl.text.trim().isEmpty
            ? null : _conditionCtrl.text.trim(),
        isConcerningAverage: _averageStatus != AverageStatus.no,
        exclusionReason:   _averageStatus == AverageStatus.no &&
                _exclusionCtrl.text.trim().isNotEmpty
            ? _exclusionCtrl.text.trim()
            : null,
        sequenceNo: widget.existing?.sequenceNo ?? 1,
        conditionStatus: _conditionStatus,
        confirmedBy: _confirmedBy.toList(),
        confirmationDate: _confirmedBy.isNotEmpty ? _confirmationDate : null,
        confirmationMethod: _confirmedBy.isNotEmpty &&
                _confirmationMethodCtrl.text.trim().isNotEmpty
            ? _confirmationMethodCtrl.text.trim()
            : null,
        averageStatus: _averageStatus,
        averagePartialDetail: _averageStatus == AverageStatus.partial &&
                _averagePartialCtrl.text.trim().isNotEmpty
            ? _averagePartialCtrl.text.trim()
            : null,
      );
      await widget.onSave(item);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit     = widget.existing != null;
    final vesselId   = widget.vesselId;
    final machinery  = vesselId != null
        ? ref.watch(machineryProvider(vesselId)).value ?? []
        : <MachineryModel>[];
    final components = _selectedMachineryId != null
        ? ref.watch(vesselComponentsProvider(_selectedMachineryId!)).value ?? []
        : <VesselComponentModel>[];

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
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
              // ── Handle ────────────────────────────────────────────
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

              // ── Occurrence selector ────────────────────────────────
              if (widget.occurrences.length > 1) ...[
                const _FieldLabel('Occurrence'),
                const SizedBox(height: 6),
                _StyledDropdown<String>(
                  value: _selectedOccurrenceId,
                  accentColor: AppColors.coral,
                  items: widget.occurrences
                      .map((occ) => DropdownMenuItem(
                            value: occ.occurrenceId,
                            child: Text(
                              occ.title ?? 'Occurrence ${occ.occurrenceNo}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedOccurrenceId = v);
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],

              // ── Machinery / System picker (claim object — primary axis) ─
              if (vesselId != null) ...[
                const _FieldLabel('Machinery / System'),
                const SizedBox(height: 6),
                if (machinery.isEmpty)
                  const Text(
                    'No machinery on file — add systems in the Vessel page.',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontStyle: FontStyle.italic),
                  )
                else
                  _StyledDropdown<String?>(
                    value: _selectedMachineryId,
                    accentColor: AppColors.amber,
                    hint: '— None / not applicable —',
                    items: [
                      const DropdownMenuItem(
                          value: null,
                          child: Text('— None / not applicable —')),
                      ...machinery.map((m) => DropdownMenuItem(
                            value: m.machineryId,
                            child: Text(
                              '${m.roleLabel}: ${m.displayName}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                    ],
                    onChanged: (v) => setState(() {
                      _selectedMachineryId  = v;
                      _selectedComponentId  = null;
                      _addingNewComponent   = false;
                      _newComponentCtrl.clear();
                    }),
                  ),
                const SizedBox(height: 14),
              ],

              // ── Component picker (when machinery selected) ─────────
              if (_selectedMachineryId != null && vesselId != null) ...[
                const _FieldLabel('Sub-component / Part'),
                const SizedBox(height: 6),
                if (components.isNotEmpty && !_addingNewComponent)
                  _StyledDropdown<String?>(
                    value: _selectedComponentId,
                    accentColor: AppColors.coral,
                    hint: '— Select or add component —',
                    items: [
                      const DropdownMenuItem(
                          value: null,
                          child: Text('— Not listed —')),
                      ...components.map((c) => DropdownMenuItem(
                            value: c.componentId,
                            child: Text(c.name,
                                overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setState(() {
                      _selectedComponentId = v;
                      if (v != null) {
                        final comp = components
                            .firstWhere((c) => c.componentId == v);
                        // Pre-fill component name field
                        _componentCtrl.text = comp.name;
                      }
                    }),
                  ),
                if (!_addingNewComponent)
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Add new component',
                        style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.coral,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    onPressed: () => setState(() {
                      _addingNewComponent  = true;
                      _selectedComponentId = null;
                    }),
                  ),
                if (_addingNewComponent) ...[
                  SurveyField(
                    label: 'New component name',
                    controller: _newComponentCtrl,
                    hint: 'e.g. Turbocharger, Fuel injection pump',
                    important: true,
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _addingNewComponent = false;
                      _newComponentCtrl.clear();
                    }),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.textTertiary,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Cancel',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
                const SizedBox(height: 6),
              ],

              // ── Specific part / affected component ────────────────
              SurveyField(
                label: 'Affected Part / Component *',
                controller: _componentCtrl,
                hint: 'e.g. Connecting rod cap, Fuel injector No.3',
                important: true,
              ),

              SurveyField(
                label: 'Location on Vessel',
                controller: _locationCtrl,
                hint: 'e.g. Engine room — port side',
              ),

              SurveyField(
                label: 'Damage Description',
                controller: _descriptionCtrl,
                hint: 'Describe the nature and extent of damage...',
                maxLines: 3,
              ),

              // ── Damage Type (tag, not the primary organiser) ───────
              const _FieldLabel('Damage Type'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DamageCategory.values.map((cat) {
                  final selected = _category == cat;
                  final color    = _categoryColor(cat);
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
              const SizedBox(height: 16),

              // ── Condition / Status ─────────────────────────────────
              const _FieldLabel('Condition / Status'),
              const SizedBox(height: 8),
              ChipRow<ConditionStatus>(
                values: ConditionStatus.values,
                selected: _conditionStatus,
                label: (s) => s.label,
                onChanged: (v) => setState(() => _conditionStatus = v),
              ),
              const SizedBox(height: 16),

              // ── Confirmed by (third-party confirmation) ────────────
              const _FieldLabel('Confirmed By'),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: ConfirmedByRole.values.map((role) {
                    final checked = _confirmedBy.contains(role);
                    return CheckboxListTile(
                      value: checked,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.coral,
                      title: Text(role.label,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textPrimary)),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _confirmedBy.add(role);
                        } else {
                          _confirmedBy.remove(role);
                        }
                      }),
                    );
                  }).toList(),
                ),
              ),
              if (_confirmedBy.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _confirmationDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _confirmationDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Confirmation Date',
                          labelStyle: TextStyle(fontSize: 12),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                        ),
                        child: Text(
                          _confirmationDate != null
                              ? '${_confirmationDate!.day.toString().padLeft(2, '0')}/'
                                '${_confirmationDate!.month.toString().padLeft(2, '0')}/'
                                '${_confirmationDate!.year}'
                              : 'Select date',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                SurveyField(
                  label: 'Confirmation Method',
                  controller: _confirmationMethodCtrl,
                  hint: 'e.g. Visual inspection, Disassembly and measurement',
                ),
              ],
              const SizedBox(height: 4),

              // ── Condition Found ────────────────────────────────────
              const _FieldLabel('Condition Found'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _conditionSuggestions.map((label) {
                  final active = _conditionCtrl.text == label;
                  return GestureDetector(
                    onTap: () => setState(
                        () => _conditionCtrl.text =
                            active ? '' : label),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.midBlue.withValues(alpha: 0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: active
                              ? AppColors.midBlue
                              : AppColors.border,
                          width: active ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          color: active
                              ? AppColors.midBlue
                              : AppColors.textSecondary,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              SurveyField(
                label: '',
                controller: _conditionCtrl,
                hint: 'Add detail or type a custom condition…',
                maxLines: 2,
              ),

              const SizedBox(height: 4),

              // ── Average status (Yes / No / Partial) ────────────────
              const _FieldLabel('Concerning Average'),
              const SizedBox(height: 8),
              ChipRow<AverageStatus>(
                values: AverageStatus.values,
                selected: _averageStatus,
                label: (s) => s.label,
                onChanged: (v) =>
                    setState(() => _averageStatus = v ?? AverageStatus.yes),
              ),

              if (_averageStatus == AverageStatus.no) ...[
                const SizedBox(height: 10),
                SurveyField(
                  label: "Reason (owner's account)",
                  controller: _exclusionCtrl,
                  hint: 'e.g. Pre-existing condition unrelated to casualty',
                ),
              ],
              if (_averageStatus == AverageStatus.partial) ...[
                const SizedBox(height: 10),
                SurveyField(
                  label: 'Partial average detail',
                  controller: _averagePartialCtrl,
                  hint: 'What part is/isn\'t concerning average, and why',
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
                          width: 18, height: 18,
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
      ),
    );
  }

  Color _categoryColor(DamageCategory cat) => switch (cat) {
        DamageCategory.structuralExternal    => AppColors.coral,
        DamageCategory.structuralInternal    => AppColors.navy,
        DamageCategory.mechanical            => AppColors.amber,
        DamageCategory.electricalElectronics => AppColors.purple,
        DamageCategory.coating               => AppColors.teal,
        DamageCategory.other                 => AppColors.textSecondary,
      };

  IconData _categoryIcon(DamageCategory cat) => switch (cat) {
        DamageCategory.structuralExternal    => Icons.shield_outlined,
        DamageCategory.structuralInternal    => Icons.home_outlined,
        DamageCategory.mechanical            => Icons.settings_outlined,
        DamageCategory.electricalElectronics => Icons.bolt_outlined,
        DamageCategory.coating               => Icons.format_paint_outlined,
        DamageCategory.other                 => Icons.help_outline,
      };
}

// ── Shared widgets ─────────────────────────────────────────────────────────

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

class _StyledDropdown<T> extends StatelessWidget {
  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.accentColor,
    this.hint,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final Color accentColor;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.05),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: Colors.white,
        hint: hint != null
            ? Text(hint!,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textTertiary))
            : null,
        style: const TextStyle(
            fontSize: 13, color: AppColors.textPrimary),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}
