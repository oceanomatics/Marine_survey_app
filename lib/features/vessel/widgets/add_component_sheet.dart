// lib/features/vessel/widgets/add_component_sheet.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vessel_provider.dart';
import '../../photos/providers/photo_provider.dart';
import 'survey_field.dart';
import '../../../core/api/claude_api.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/case_photo_picker_sheet.dart';

class AddComponentSheet extends ConsumerStatefulWidget {
  const AddComponentSheet({
    super.key,
    required this.machineryId,
    required this.vesselId,
    required this.caseId,
    required this.onSave,
    this.existing,
    this.nextSeqNo = 1,
  });

  final String machineryId;
  final String vesselId;
  final String caseId;
  final VesselComponentModel? existing;
  final int nextSeqNo;
  final Future<VesselComponentModel> Function(VesselComponentModel) onSave;

  @override
  ConsumerState<AddComponentSheet> createState() => _AddComponentSheetState();
}

class _AddComponentSheetState extends ConsumerState<AddComponentSheet> {
  String? _scannedPhotoId;
  final _nameCtrl         = TextEditingController();
  final _manufacturerCtrl = TextEditingController();
  final _modelCtrl        = TextEditingController();
  final _partCtrl         = TextEditingController();
  final _serialCtrl       = TextEditingController();
  final _dateCtrl         = TextEditingController();
  final _notesCtrl        = TextEditingController();

  bool _saving          = false;
  bool _scanningPlate   = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text         = e.name;
      _manufacturerCtrl.text = e.manufacturer      ?? '';
      _modelCtrl.text        = e.model             ?? '';
      _serialCtrl.text       = e.serialNumber      ?? '';
      _dateCtrl.text         = e.dateOfManufacture ?? '';
      _notesCtrl.text        = e.notes             ?? '';
      // part_number stored in model field with a "P/N:" prefix if present
      if (e.model != null && e.model!.startsWith('P/N: ')) {
        _partCtrl.text  = e.model!.substring(5);
        _modelCtrl.text = '';
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _manufacturerCtrl, _modelCtrl, _partCtrl,
      _serialCtrl, _dateCtrl, _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

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

    setState(() {
      _scanningPlate = true;
      _scannedPhotoId = picked.first.id as String;
    });
    try {
      final photo = picked.first;
      final bytes = await File(photo.localPath as String).readAsBytes();
      final b64   = base64Encode(bytes);
      const mime  = 'image/jpeg';

      final result = await ClaudeApi.extractNameplate(
        base64Image: b64,
        mediaType:   mime,
      );
      if (!mounted) return;

      setState(() {
        if ((result['manufacturer'] as String? ?? '').isNotEmpty) {
          _manufacturerCtrl.text = result['manufacturer'] as String;
        }
        final model = result['model'] as String? ?? '';
        final part  = result['part_number'] as String? ?? '';
        if (model.isNotEmpty) _modelCtrl.text = model;
        if (part.isNotEmpty)  _partCtrl.text  = part;
        if ((result['serial_number'] as String? ?? '').isNotEmpty) {
          _serialCtrl.text = result['serial_number'] as String;
        }
        if ((result['date_of_manufacture'] as String? ?? '').isNotEmpty) {
          _dateCtrl.text = result['date_of_manufacture'] as String;
        }
        // Build extra notes from additional_info + electrical specs
        final parts = <String>[];
        final addl = result['additional_info'] as String? ?? '';
        if (addl.isNotEmpty) parts.add(addl);
        final voltage = result['voltage_v'];
        final freq    = result['frequency_hz'];
        final current = result['current_a'];
        if (voltage != null) parts.add('${voltage}V');
        if (freq != null)    parts.add('${freq}Hz');
        if (current != null) parts.add('${current}A');
        if (parts.isNotEmpty && _notesCtrl.text.isEmpty) {
          _notesCtrl.text = parts.join(' · ');
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nameplate scanned — review and save'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _scanningPlate = false);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Component name is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      // Combine model + part number: store part as "P/N: ..." if no model
      final model = _modelCtrl.text.trim();
      final part  = _partCtrl.text.trim();
      final storedModel = model.isNotEmpty
          ? model
          : part.isNotEmpty
              ? 'P/N: $part'
              : null;

      final comp = VesselComponentModel(
        componentId:       widget.existing?.componentId ?? '',
        machineryId:       widget.machineryId,
        vesselId:          widget.vesselId,
        name:              _nameCtrl.text.trim(),
        manufacturer:      _manufacturerCtrl.text.trim().isEmpty ? null : _manufacturerCtrl.text.trim(),
        model:             storedModel,
        serialNumber:      _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
        dateOfManufacture: _dateCtrl.text.trim().isEmpty ? null : _dateCtrl.text.trim(),
        notes:             _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        sequenceNo:        widget.existing?.sequenceNo ?? widget.nextSeqNo,
      );
      final saved = await widget.onSave(comp);
      if (_scannedPhotoId != null) {
        await ref
            .read(photosProvider(widget.caseId).notifier)
            .attachLink(_scannedPhotoId!, 'component_nameplate', saved.componentId);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
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
                  isEdit ? 'Edit Sub-component' : 'Add Sub-component',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                const Spacer(),
                // Scan nameplate button
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
                            style: TextStyle(
                                fontSize: 12, color: AppColors.teal)),
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

              SurveyField(
                label: 'Component Name *',
                controller: _nameCtrl,
                hint: 'e.g. Turbocharger, Fuel injection pump No.1',
                capitalization: TextCapitalization.words,
                important: true,
              ),

              Row(children: [
                Expanded(child: SurveyField(
                  label: 'Manufacturer',
                  controller: _manufacturerCtrl,
                  hint: 'e.g. ABB, Bosch',
                  capitalization: TextCapitalization.words,
                )),
                const SizedBox(width: 10),
                Expanded(child: SurveyField(
                  label: 'Model / Type',
                  controller: _modelCtrl,
                  hint: 'e.g. TPL77-B',
                )),
              ]),

              Row(children: [
                Expanded(child: SurveyField(
                  label: 'Part Number',
                  controller: _partCtrl,
                  hint: 'e.g. 3BTS-00421',
                )),
                const SizedBox(width: 10),
                Expanded(child: SurveyField(
                  label: 'Serial Number',
                  controller: _serialCtrl,
                  hint: 'e.g. SN-20091234',
                )),
              ]),

              SurveyField(
                label: 'Date of Manufacture',
                controller: _dateCtrl,
                hint: 'e.g. 2009 or 2009-03',
                keyboard: TextInputType.datetime,
              ),

              SurveyField(
                label: 'Additional Info / Notes',
                controller: _notesCtrl,
                hint: 'Ratings, certifications, condition notes…',
                maxLines: 3,
              ),

              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
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
                      : Text(isEdit ? 'Update' : 'Add Component',
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
