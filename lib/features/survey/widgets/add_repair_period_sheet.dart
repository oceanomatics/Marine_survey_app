// lib/features/survey/widgets/add_repair_period_sheet.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/repair_period_model.dart';
import '../../../shared/theme/app_theme.dart';

const _kColor = Color(0xFF1A6B9E);

const _kServicesOptions = {
  'crane_lifting':        'Crane / Lifting',
  'scaffolding':          'Scaffolding',
  'gas_freeing':          'Gas Freeing',
  'diving':               'Diving',
  'class_attendance':     'Class Attendance',
  'ndt_xray':             'NDT / X-Ray',
  'hydraulic_testing':    'Hydraulic Testing',
  'air_pressure_testing': 'Air Pressure Testing',
  'hose_testing':         'Hose Testing',
};

const _kHotWorkOptions = {
  'certs_valid':       'Conducted — Certs Valid',
  'certs_not_sighted': 'Conducted — Certs Not Sighted',
};

class AddRepairPeriodSheet extends StatefulWidget {
  const AddRepairPeriodSheet({
    super.key,
    required this.caseId,
    required this.nextPeriodNo,
    required this.onSave,
  });

  final String caseId;
  final int nextPeriodNo;
  final Future<void> Function(RepairPeriodModel) onSave;

  @override
  State<AddRepairPeriodSheet> createState() => _AddRepairPeriodSheetState();
}

class _AddRepairPeriodSheetState extends State<AddRepairPeriodSheet> {
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _servicesNotesCtrl = TextEditingController();
  final _hotWorkNotesCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  PortContext _portContext = PortContext.planned;
  final Set<String> _servicesProvided = {};
  String? _hotWorkStatus;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    _servicesNotesCtrl.dispose();
    _hotWorkNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
      locale: const Locale('en', 'AU'),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked;
          }
        } else {
          _endDate = picked;
          if (_startDate != null && _startDate!.isAfter(picked)) {
            _startDate = picked;
          }
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() { _error = null; _saving = true; });
    try {
      final period = RepairPeriodModel(
        periodId:    '',
        caseId:      widget.caseId,
        periodNo:    widget.nextPeriodNo,
        title:       _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        startDate:   _startDate,
        endDate:     _endDate,
        location:    _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        portContext: _portContext,
        notes:       _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        servicesProvided: _servicesProvided.toList(),
        servicesProvidedNotes: _servicesNotesCtrl.text.trim().isEmpty
            ? null
            : _servicesNotesCtrl.text.trim(),
        hotWorkStatus: _hotWorkStatus,
        hotWorkNotes: _hotWorkNotesCtrl.text.trim().isEmpty
            ? null
            : _hotWorkNotesCtrl.text.trim(),
      );
      await widget.onSave(period);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _kColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.nextPeriodNo}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('New Repair Period',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const Spacer(),
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
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.error)),
              ),

            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // Title
                  _label('Title (optional)'),
                  TextField(
                    controller: _titleCtrl,
                    decoration: _dec(
                        hint: 'e.g. "Temporary Repairs" or leave blank'),
                  ),
                  const SizedBox(height: 16),

                  // Date range
                  _label('Repair Period Dates'),
                  Row(children: [
                    Expanded(
                      child: _DateTile(
                        label: 'Start',
                        date: _startDate,
                        formatted: _startDate != null ? df.format(_startDate!) : null,
                        onTap: () => _pickDate(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateTile(
                        label: 'End',
                        date: _endDate,
                        formatted: _endDate != null ? df.format(_endDate!) : null,
                        onTap: () => _pickDate(isStart: false),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Location
                  _label('Location / Yard'),
                  TextField(
                    controller: _locationCtrl,
                    decoration: _dec(hint: 'e.g. Brisbane Dry Dock, Port of Brisbane'),
                  ),
                  const SizedBox(height: 16),

                  // Port context
                  _label('Port Call Context'),
                  const SizedBox(height: 6),
                  Row(children: PortContext.values.map((ctx) {
                    final selected = _portContext == ctx;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _portContext = ctx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? _contextColor(ctx).withValues(alpha: 0.12)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? _contextColor(ctx)
                                    : AppColors.border,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  _contextIcon(ctx),
                                  color: selected
                                      ? _contextColor(ctx)
                                      : AppColors.textTertiary,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ctx.label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: selected
                                        ? _contextColor(ctx)
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList()),
                  const SizedBox(height: 16),

                  // Notes
                  _label('Notes (optional)'),
                  TextField(
                    controller: _notesCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: _dec(hint: 'Any additional notes about this repair period'),
                  ),
                  const SizedBox(height: 16),

                  // Services provided
                  _label('Services Provided'),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: _kServicesOptions.entries.map((e) {
                        final checked = _servicesProvided.contains(e.key);
                        return CheckboxListTile(
                          value: checked,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: _kColor,
                          title: Text(e.value,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textPrimary)),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _servicesProvided.add(e.key);
                            } else {
                              _servicesProvided.remove(e.key);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _servicesNotesCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: _dec(
                        hint: 'Context on services provided (from invoices '
                            'or observed on site)'),
                  ),
                  const SizedBox(height: 16),

                  // Hot work / gas freeing
                  _label('Hot Work / Gas Freeing'),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: _ChipOption(
                        label: 'Not Conducted',
                        selected: _hotWorkStatus == null,
                        color: AppColors.textTertiary,
                        onTap: () => setState(() => _hotWorkStatus = null),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ..._kHotWorkOptions.entries.map((e) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _ChipOption(
                              label: e.value,
                              selected: _hotWorkStatus == e.key,
                              color: _kColor,
                              onTap: () =>
                                  setState(() => _hotWorkStatus = e.key),
                            ),
                          ),
                        )),
                  ]),
                  if (_hotWorkStatus != null) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _hotWorkNotesCtrl,
                      minLines: 2,
                      maxLines: 4,
                      decoration: _dec(hint: 'Hot work context / notes'),
                    ),
                  ],
                  const SizedBox(height: 24),

                  SizedBox(
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
                          : const Text('Save Repair Period',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      );

  InputDecoration _dec({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      );

  Color _contextColor(PortContext ctx) => switch (ctx) {
        PortContext.planned   => AppColors.success,
        PortContext.diversion => AppColors.warning,
      };

  IconData _contextIcon(PortContext ctx) => switch (ctx) {
        PortContext.planned   => Icons.anchor_outlined,
        PortContext.diversion => Icons.alt_route_outlined,
      };
}

class _ChipOption extends StatelessWidget {
  const _ChipOption({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.5 : 1),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.date,
    required this.formatted,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final String? formatted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: date != null
              ? _kColor.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: date != null ? _kColor.withValues(alpha: 0.4) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 14,
                color: date != null ? _kColor : AppColors.textTertiary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                formatted ?? label,
                style: TextStyle(
                  fontSize: 13,
                  color: date != null
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
