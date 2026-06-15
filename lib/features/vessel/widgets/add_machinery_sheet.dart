// lib/features/vessel/widgets/add_machinery_sheet.dart

import 'package:flutter/material.dart';
import '../providers/vessel_provider.dart';
import '../widgets/survey_field.dart';
import '../../../shared/theme/app_theme.dart';

class AddMachinerySheet extends StatefulWidget {
  const AddMachinerySheet({
    super.key,
    required this.vesselId,
    required this.onSave,
    this.existing,
  });

  final String vesselId;
  final MachineryModel? existing;
  final Future<void> Function(MachineryModel) onSave;

  @override
  State<AddMachinerySheet> createState() => _AddMachinerySheetState();
}

class _AddMachinerySheetState extends State<AddMachinerySheet> {
  final _typeCtrl    = TextEditingController();
  final _makeCtrl    = TextEditingController();
  final _modelCtrl   = TextEditingController();
  final _serialCtrl  = TextEditingController();
  final _kWCtrl      = TextEditingController();
  final _rpmCtrl     = TextEditingController();
  final _fuelCtrl    = TextEditingController();
  final _cylCtrl     = TextEditingController();
  final _configCtrl  = TextEditingController();
  final _unitCtrl    = TextEditingController();
  final _hrsNewCtrl  = TextEditingController();
  final _hrsOhCtrl   = TextEditingController();
  final _qtyCtrl     = TextEditingController(text: '1');

  String _role = 'main_engine';
  bool _saving = false;

  static const _roles = [
    ('main_engine',       'Main Engine'),
    ('diesel_generator',  'Diesel Generator'),
    ('thruster',          'Thruster'),
    ('turbocharger',      'Turbocharger'),
    ('gearbox',           'Gearbox'),
    ('pump',              'Pump'),
    ('compressor',        'Compressor'),
    ('crane',             'Crane'),
    ('other',             'Other'),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _role = e.role ?? 'main_engine';
      _typeCtrl.text   = e.machineryType;
      _makeCtrl.text   = e.make        ?? '';
      _modelCtrl.text  = e.model       ?? '';
      _serialCtrl.text = e.serialNumber ?? '';
      _kWCtrl.text     = e.mcrKw?.toString()         ?? '';
      _rpmCtrl.text    = e.mcrRpm?.toString()        ?? '';
      _fuelCtrl.text   = e.fuelType    ?? '';
      _cylCtrl.text    = e.cylinderCount?.toString() ?? '';
      _configCtrl.text = e.configuration ?? '';
      _unitCtrl.text   = e.unitNumber  ?? '';
      _hrsNewCtrl.text = e.runHrsNew?.toString()     ?? '';
      _hrsOhCtrl.text  = e.runHrsOverhaul?.toString() ?? '';
      _qtyCtrl.text    = e.quantity.toString();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _typeCtrl, _makeCtrl, _modelCtrl, _serialCtrl, _kWCtrl,
      _rpmCtrl, _fuelCtrl, _cylCtrl, _configCtrl, _unitCtrl,
      _hrsNewCtrl, _hrsOhCtrl, _qtyCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (_makeCtrl.text.trim().isEmpty && _typeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter make or type')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final m = MachineryModel(
        machineryId:    widget.existing?.machineryId ?? '',
        vesselId:       widget.vesselId,
        machineryType:  _typeCtrl.text.trim().isEmpty
            ? _roleLabel(_role)
            : _typeCtrl.text.trim(),
        role:           _role,
        make:           _makeCtrl.text.trim().isEmpty  ? null : _makeCtrl.text.trim(),
        model:          _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
        serialNumber:   _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
        mcrKw:          double.tryParse(_kWCtrl.text.trim()),
        mcrRpm:         double.tryParse(_rpmCtrl.text.trim()),
        fuelType:       _fuelCtrl.text.trim().isEmpty  ? null : _fuelCtrl.text.trim(),
        cylinderCount:  int.tryParse(_cylCtrl.text.trim()),
        configuration:  _configCtrl.text.trim().isEmpty ? null : _configCtrl.text.trim(),
        quantity:       int.tryParse(_qtyCtrl.text.trim()) ?? 1,
        unitNumber:     _unitCtrl.text.trim().isEmpty  ? null : _unitCtrl.text.trim(),
        runHrsNew:      double.tryParse(_hrsNewCtrl.text.trim()),
        runHrsOverhaul: double.tryParse(_hrsOhCtrl.text.trim()),
      );
      await widget.onSave(m);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _roleLabel(String role) =>
      _roles.firstWhere((r) => r.$1 == role, orElse: () => (role, role)).$2;

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
            // Handle
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
            Text(
              isEdit ? 'Edit Machinery' : 'Add Machinery',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),

            // Role selector
            const Text('Role',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              items: _roles
                  .map((r) => DropdownMenuItem(value: r.$1, child: Text(r.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            const SizedBox(height: 14),

            Row(children: [
              Expanded(
                flex: 2,
                child: SurveyField(
                  label: 'Make',
                  controller: _makeCtrl,
                  hint: 'e.g. Caterpillar',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SurveyField(
                  label: 'Model',
                  controller: _modelCtrl,
                  hint: 'e.g. 3516',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SurveyField(
                  label: 'Qty',
                  controller: _qtyCtrl,
                  keyboard: TextInputType.number,
                  hint: '1',
                ),
              ),
            ]),

            Row(children: [
              Expanded(child: SurveyField(
                label: 'MCR (kW)',
                controller: _kWCtrl,
                keyboard: TextInputType.number,
                hint: 'e.g. 2481',
              )),
              const SizedBox(width: 10),
              Expanded(child: SurveyField(
                label: 'RPM',
                controller: _rpmCtrl,
                keyboard: TextInputType.number,
                hint: 'e.g. 1800',
              )),
            ]),

            Row(children: [
              Expanded(child: SurveyField(
                label: 'Fuel Type',
                controller: _fuelCtrl,
                hint: 'e.g. Marine Diesel',
              )),
              const SizedBox(width: 10),
              Expanded(child: SurveyField(
                label: 'Cylinders',
                controller: _cylCtrl,
                keyboard: TextInputType.number,
                hint: 'e.g. 16',
              )),
            ]),

            SurveyField(
              label: 'Configuration',
              controller: _configCtrl,
              hint: 'e.g. 16 cyl Vee type, diesel electric',
            ),
            SurveyField(
              label: 'Serial Number',
              controller: _serialCtrl,
              hint: 'e.g. CAT-3516-00123',
            ),

            Row(children: [
              Expanded(child: SurveyField(
                label: 'Unit No.',
                controller: _unitCtrl,
                hint: 'e.g. 3',
              )),
              const SizedBox(width: 10),
              Expanded(child: SurveyField(
                label: 'Run Hrs (since new)',
                controller: _hrsNewCtrl,
                keyboard: TextInputType.number,
                hint: 'e.g. 28400',
              )),
              const SizedBox(width: 10),
              Expanded(child: SurveyField(
                label: 'Run Hrs (O/H)',
                controller: _hrsOhCtrl,
                keyboard: TextInputType.number,
                hint: 'e.g. 4200',
              )),
            ]),

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(isEdit ? 'Update' : 'Add Machinery'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
