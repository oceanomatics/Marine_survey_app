// lib/features/vessel/widgets/add_machinery_sheet.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../providers/vessel_provider.dart';
import 'survey_field.dart';
import '../../../core/api/claude_api.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/case_photo_picker_sheet.dart';

// ── Role catalogue ─────────────────────────────────────────────────────────

const _roles = [
  ('main_engine',         'Main Engine'),
  ('diesel_generator',    'Diesel Generator'),
  ('emergency_generator', 'Emerg. Generator'),
  ('thruster',            'Thruster'),
  ('gearbox',             'Gearbox'),
  ('pump',                'Pump'),
  ('compressor',          'Compressor'),
  ('separator',           'Separator'),
  ('crane',               'Crane / Deck Equip.'),
  ('other',               'Other Equipment'),
];

// ── Role groups ────────────────────────────────────────────────────────────

const _engineRoles  = {'main_engine', 'diesel_generator', 'emergency_generator'};
const _thrusterRole = 'thruster';
const _gearboxRole  = 'gearbox';

// ── Engine option chips ────────────────────────────────────────────────────

const _fuelTypes    = ['MGO', 'MDO', 'HFO', 'Dual fuel', 'Gas'];
const _engineConfig = ['Inline', 'Vee', 'Radial', 'Opposed'];

// ── Thruster option chips ──────────────────────────────────────────────────

const _thrusterTypes = [
  'Tunnel FPP',
  'Tunnel CPP',
  'Azimuthing — retractable',
  'Azimuthing — fixed',
  'Water Jet',
];
const _thrusterDrives = ['Electric', 'Diesel-hydraulic', 'Diesel direct'];

// ── Gearbox option chips ───────────────────────────────────────────────────

const _gearboxTypes = ['Reduction', 'Double reduction', 'Split gearbox'];

// ──────────────────────────────────────────────────────────────────────────

class AddMachinerySheet extends StatefulWidget {
  const AddMachinerySheet({
    super.key,
    required this.vesselId,
    required this.caseId,
    required this.onSave,
    this.existing,
  });

  final String vesselId;
  final String caseId;
  final MachineryModel? existing;
  final Future<void> Function(MachineryModel) onSave;

  @override
  State<AddMachinerySheet> createState() => _AddMachinerySheetState();
}

class _AddMachinerySheetState extends State<AddMachinerySheet> {
  // Text controllers
  final _makeCtrl    = TextEditingController();
  final _modelCtrl   = TextEditingController();
  final _serialCtrl  = TextEditingController();
  final _unitCtrl    = TextEditingController();
  final _kWCtrl      = TextEditingController();
  final _rpmCtrl     = TextEditingController();
  final _cylCtrl     = TextEditingController();
  final _ratioCtrl   = TextEditingController(); // gearbox ratio
  final _descCtrl    = TextEditingController(); // generic sub-type description
  final _hrsNewCtrl  = TextEditingController();
  final _hrsOhCtrl   = TextEditingController();

  // Role + chip selections
  String  _role          = 'main_engine';
  String? _engineFuel;
  String? _engineLayout;
  String? _thrusterType;
  String? _thrusterDrive;
  String? _gearboxType;

  bool _saving        = false;
  bool _scanningPlate = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _role            = e.role ?? 'main_engine';
      _makeCtrl.text   = e.make          ?? '';
      _modelCtrl.text  = e.model         ?? '';
      _serialCtrl.text = e.serialNumber  ?? '';
      _unitCtrl.text   = e.unitNumber    ?? '';
      _kWCtrl.text     = e.mcrKw?.toString()          ?? '';
      _rpmCtrl.text    = e.mcrRpm?.toString()         ?? '';
      _cylCtrl.text    = e.cylinderCount?.toString()  ?? '';
      _hrsNewCtrl.text = e.runHrsNew?.toString()      ?? '';
      _hrsOhCtrl.text  = e.runHrsOverhaul?.toString() ?? '';

      // Restore chip selections from stored fields
      if (_engineRoles.contains(_role)) {
        _engineFuel   = e.fuelType;
        _engineLayout = e.configuration;
      } else if (_role == _thrusterRole) {
        _thrusterType  = e.configuration;
        _thrusterDrive = e.fuelType;
      } else if (_role == _gearboxRole) {
        _gearboxType   = e.configuration;
        _ratioCtrl.text = e.fuelType ?? ''; // ratio stored in fuelType for gearbox
      } else {
        // Generic: description stored in machineryType unless it matches the role label
        final roleLabel = _roles.firstWhere(
            (r) => r.$1 == _role, orElse: () => (_role, _role)).$2;
        _descCtrl.text = e.machineryType == roleLabel ? '' : e.machineryType;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _makeCtrl, _modelCtrl, _serialCtrl, _unitCtrl, _kWCtrl, _rpmCtrl,
      _cylCtrl, _ratioCtrl, _descCtrl, _hrsNewCtrl, _hrsOhCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_makeCtrl.text.trim().isEmpty && _modelCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter make or model')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      // Derive stored field values depending on role
      final String? storedConfig;
      final String? storedFuel;
      final String machineryType;

      if (_engineRoles.contains(_role)) {
        storedConfig  = _engineLayout;
        storedFuel    = _engineFuel;
        machineryType = _roleLabel(_role);
      } else if (_role == _thrusterRole) {
        storedConfig  = _thrusterType;
        storedFuel    = _thrusterDrive;
        machineryType = _thrusterType ?? _roleLabel(_role);
      } else if (_role == _gearboxRole) {
        storedConfig  = _gearboxType;
        storedFuel    = _ratioCtrl.text.trim().isEmpty ? null : _ratioCtrl.text.trim();
        machineryType = _gearboxType ?? _roleLabel(_role);
      } else {
        storedConfig  = null;
        storedFuel    = null;
        final desc    = _descCtrl.text.trim();
        machineryType = desc.isEmpty ? _roleLabel(_role) : desc;
      }

      final m = MachineryModel(
        machineryId:    widget.existing?.machineryId ?? '',
        vesselId:       widget.vesselId,
        machineryType:  machineryType,
        role:           _role,
        make:           _makeCtrl.text.trim().isEmpty  ? null : _makeCtrl.text.trim(),
        model:          _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
        serialNumber:   _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
        unitNumber:     _unitCtrl.text.trim().isEmpty  ? null : _unitCtrl.text.trim(),
        mcrKw:          double.tryParse(_kWCtrl.text.trim()),
        mcrRpm:         double.tryParse(_rpmCtrl.text.trim()),
        fuelType:       storedFuel,
        cylinderCount:  int.tryParse(_cylCtrl.text.trim()),
        configuration:  storedConfig,
        quantity:       1,
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

  bool get _isEngine    => _engineRoles.contains(_role);
  bool get _isThruster  => _role == _thrusterRole;
  bool get _isGearbox   => _role == _gearboxRole;
  bool get _isGeneric   => !_isEngine && !_isThruster && !_isGearbox;

  Future<void> _scanNameplate() async {
    final picked = await showModalBottomSheet<List<dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CasePhotoPickerSheet(
        caseId: widget.caseId,
        title: 'Select Nameplate Photo',
        accentColor: AppColors.teal,
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    setState(() => _scanningPlate = true);
    try {
      final photo  = picked.first;
      final bytes  = await File(photo.localPath as String).readAsBytes();
      final b64    = base64Encode(bytes);
      const mime   = 'image/jpeg';
      final result = await ClaudeApi.extractNameplate(
          base64Image: b64, mediaType: mime);
      if (!mounted) return;
      setState(() {
        final make   = result['manufacturer'] as String? ?? '';
        final model  = result['model'] as String? ?? '';
        final serial = result['serial_number'] as String? ?? '';
        final power  = (result['rated_power_kw'] as num?)?.toDouble();
        final rpm    = (result['rated_rpm'] as num?)?.toDouble();
        if (make.isNotEmpty)   _makeCtrl.text   = make;
        if (model.isNotEmpty)  _modelCtrl.text  = model;
        if (serial.isNotEmpty) _serialCtrl.text = serial;
        if (power != null)     _kWCtrl.text     = power.toStringAsFixed(0);
        if (rpm != null)       _rpmCtrl.text    = rpm.toStringAsFixed(0);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nameplate scanned — review and save'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Scan failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _scanningPlate = false);
    }
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
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Text(
                  isEdit ? 'Edit Machinery / System' : 'Add Machinery / System',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                const Spacer(),
                _scanningPlate
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.teal))
                    : TextButton.icon(
                        onPressed: _scanNameplate,
                        icon: const Icon(Icons.document_scanner_outlined,
                            size: 16, color: AppColors.teal),
                        label: const Text('Scan Nameplate',
                            style: TextStyle(fontSize: 12, color: AppColors.teal)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          backgroundColor: AppColors.lightTeal,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
              ]),
              const SizedBox(height: 18),

              // ── Role chip strip ────────────────────────────────────
              const _Label('System Type'),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _roles.map((r) {
                    final selected = r.$1 == _role;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _role = r.$1;
                          // Reset conditional chip selections on role change
                          _engineFuel = _engineLayout = null;
                          _thrusterType = _thrusterDrive = null;
                          _gearboxType = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.midBlue
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppColors.midBlue
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(r.$2,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textSecondary)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),

              // ── Make / Model / Unit No. (all roles) ───────────────
              Row(children: [
                Expanded(
                  flex: 5,
                  child: SurveyField(
                    label: 'Make',
                    controller: _makeCtrl,
                    hint: _isEngine
                        ? 'e.g. Caterpillar'
                        : _isThruster
                            ? 'e.g. ABB'
                            : 'e.g. Wartsila',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: SurveyField(
                    label: 'Model',
                    controller: _modelCtrl,
                    hint: _isEngine
                        ? 'e.g. 3516'
                        : _isThruster
                            ? 'e.g. Azipod XO'
                            : 'e.g. WLD 2000',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: SurveyField(
                    label: 'Unit No.',
                    controller: _unitCtrl,
                    hint: _isThruster ? 'e.g. Bow 1' : 'e.g. 1',
                  ),
                ),
              ]),

              // ── Generic sub-type description (pump/crane/other) ────
              if (_isGeneric) ...[
                SurveyField(
                  label: 'Sub-type / Description',
                  controller: _descCtrl,
                  hint: switch (_role) {
                    'pump'       => 'e.g. Bilge pump, Fire pump, Ballast pump',
                    'compressor' => 'e.g. Air start compressor, Control air',
                    'separator'  => 'e.g. Fuel oil purifier, Lube oil purifier',
                    'crane'      => 'e.g. Knuckle boom crane, Provision crane',
                    _            => 'Describe this equipment',
                  },
                ),
              ],

              // ── Engine fields ──────────────────────────────────────
              if (_isEngine) ...[
                Row(children: [
                  Expanded(child: SurveyField(
                    label: 'MCR (kW)',
                    controller: _kWCtrl,
                    keyboard: TextInputType.number,
                    hint: 'e.g. 2481',
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: SurveyField(
                    label: 'MCR RPM',
                    controller: _rpmCtrl,
                    keyboard: TextInputType.number,
                    hint: 'e.g. 1800',
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: SurveyField(
                    label: 'Cylinders',
                    controller: _cylCtrl,
                    keyboard: TextInputType.number,
                    hint: 'e.g. 16',
                  )),
                ]),
                const _Label('Fuel Type'),
                const SizedBox(height: 6),
                _ChipRow(
                  options: _fuelTypes,
                  selected: _engineFuel,
                  onSelected: (v) => setState(() => _engineFuel = v),
                ),
                const SizedBox(height: 12),
                const _Label('Engine Layout'),
                const SizedBox(height: 6),
                _ChipRow(
                  options: _engineConfig,
                  selected: _engineLayout,
                  onSelected: (v) => setState(() => _engineLayout = v),
                ),
                const SizedBox(height: 12),
              ],

              // ── Thruster fields ────────────────────────────────────
              if (_isThruster) ...[
                const _Label('Thruster Type'),
                const SizedBox(height: 6),
                _ChipRow(
                  options: _thrusterTypes,
                  selected: _thrusterType,
                  onSelected: (v) => setState(() => _thrusterType = v),
                ),
                const SizedBox(height: 12),
                const _Label('Drive Type'),
                const SizedBox(height: 6),
                _ChipRow(
                  options: _thrusterDrives,
                  selected: _thrusterDrive,
                  onSelected: (v) => setState(() => _thrusterDrive = v),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: SurveyField(
                    label: 'Power (kW)',
                    controller: _kWCtrl,
                    keyboard: TextInputType.number,
                    hint: 'e.g. 1500',
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: SurveyField(
                    label: 'RPM',
                    controller: _rpmCtrl,
                    keyboard: TextInputType.number,
                    hint: 'e.g. 250',
                  )),
                ]),
              ],

              // ── Gearbox fields ─────────────────────────────────────
              if (_isGearbox) ...[
                const _Label('Gearbox Type'),
                const SizedBox(height: 6),
                _ChipRow(
                  options: _gearboxTypes,
                  selected: _gearboxType,
                  onSelected: (v) => setState(() => _gearboxType = v),
                ),
                const SizedBox(height: 12),
                SurveyField(
                  label: 'Reduction Ratio',
                  controller: _ratioCtrl,
                  hint: 'e.g. 5.04:1',
                ),
              ],

              // ── Common bottom fields (all roles) ───────────────────
              SurveyField(
                label: 'Serial Number',
                controller: _serialCtrl,
                hint: 'e.g. CAT-3516-00123',
              ),
              Row(children: [
                Expanded(child: SurveyField(
                  label: 'Run Hrs (since new)',
                  controller: _hrsNewCtrl,
                  keyboard: TextInputType.number,
                  hint: 'e.g. 28400',
                )),
                const SizedBox(width: 10),
                Expanded(child: SurveyField(
                  label: 'Run Hrs (since O/H)',
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.midBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? 'Update' : 'Add System',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Local helper widgets ───────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.3),
      );
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final isSelected = opt == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onSelected(isSelected ? null : opt),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.lightBlue : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.midBlue
                        : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(opt,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? AppColors.midBlue
                            : AppColors.textSecondary)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
