// lib/features/survey/widgets/add_occurrence_sheet.dart

import 'package:flutter/material.dart';
import '../../vessel/widgets/survey_field.dart';
import '../providers/damage_provider.dart';
import '../../../shared/theme/app_theme.dart';

const _kVesselStatusOptions = {
  'at_sea':            'At Sea',
  'in_port_at_anchor': 'In Port / At Anchor',
  'maintenance':       'Undergoing Maintenance',
  'manoeuvring':       'Manoeuvring',
};

const _kAftermathOptions = {
  'own_power':                 'Own Power',
  'tug_only':                  'Tug Only',
  'tug_and_pilot':             'Tug and Pilot',
  'tug_pilot_lines_gangway':   'Tug, Pilot, Lines & Gangway',
  'towed':                     'Towed',
  'proceeded_with_operations': 'Proceeded with Operations',
};

class AddOccurrenceSheet extends StatefulWidget {
  const AddOccurrenceSheet({
    super.key,
    required this.onSave,
    this.existing,
  });

  final OccurrenceModel? existing;

  final Future<void> Function(
    String title,
    DateTime? dateTime,
    String? location,
    String? description,
    String? vesselStatusAtCasualty,
    String? aftermathStatus,
    String? aftermathPort,
  ) onSave;

  @override
  State<AddOccurrenceSheet> createState() => _AddOccurrenceSheetState();
}

class _AddOccurrenceSheetState extends State<AddOccurrenceSheet> {
  final _titleCtrl        = TextEditingController();
  final _locationCtrl     = TextEditingController();
  final _descriptionCtrl  = TextEditingController();
  final _aftermathPortCtrl = TextEditingController();
  DateTime? _dateTime;
  String? _vesselStatusAtCasualty;
  String? _aftermathStatus;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text       = e.title        ?? '';
      _locationCtrl.text    = e.location     ?? '';
      _descriptionCtrl.text = e.briefDescription ?? '';
      _dateTime             = e.dateTime;
      _vesselStatusAtCasualty = e.vesselStatusAtCasualty;
      _aftermathStatus        = e.aftermathStatus;
      _aftermathPortCtrl.text = e.aftermathPort ?? '';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _descriptionCtrl.dispose();
    _aftermathPortCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('en', 'AU'),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime ?? DateTime.now()),
    );
    if (!mounted) return;
    setState(() {
      _dateTime = DateTime(
        date.year, date.month, date.day,
        time?.hour ?? 0, time?.minute ?? 0,
      );
    });
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Occurrence title is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(
        _titleCtrl.text.trim(),
        _dateTime,
        _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        _vesselStatusAtCasualty,
        _aftermathStatus,
        _aftermathPortCtrl.text.trim().isEmpty
            ? null
            : _aftermathPortCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text(
                widget.existing != null ? 'Edit Occurrence' : 'Add Occurrence',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text(
              'An occurrence is a specific casualty event.\n'
              'Most H&M cases have one occurrence.',
              style:
                  TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            SurveyField(
              label: 'Occurrence Title *',
              controller: _titleCtrl,
              hint:
                  'e.g. Main diesel generator No.3 — connecting rod cap failure',
              important: true,
            ),

            // Date/time picker
            const Text('Date & Time of Occurrence',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 5),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: AppColors.textTertiary),
                  const SizedBox(width: 10),
                  Text(
                    _dateTime != null
                        ? _formatDateTime(_dateTime!)
                        : 'Select date and time',
                    style: TextStyle(
                      fontSize: 14,
                      color: _dateTime != null
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                      fontWeight: _dateTime != null
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                  const Spacer(),
                  if (_dateTime != null)
                    GestureDetector(
                      onTap: () => setState(() => _dateTime = null),
                      child: const Icon(Icons.clear,
                          size: 16, color: AppColors.textTertiary),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            SurveyField(
              label: 'Location',
              controller: _locationCtrl,
              hint: 'e.g. 12 NM off Onslow, Western Australia',
            ),

            _DropdownField(
              label: 'Vessel Status at Casualty',
              value: _vesselStatusAtCasualty,
              options: _kVesselStatusOptions,
              onChanged: (v) => setState(() => _vesselStatusAtCasualty = v),
            ),
            const SizedBox(height: 14),

            SurveyField(
              label: 'Narrative',
              controller: _descriptionCtrl,
              hint:
                  'Background, sequence of events, owner\'s account…',
              maxLines: 12,
            ),

            const Text('Aftermath',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.3)),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DropdownField(
                    label: 'What happened after the casualty?',
                    value: _aftermathStatus,
                    options: _kAftermathOptions,
                    onChanged: (v) => setState(() => _aftermathStatus = v),
                  ),
                  const SizedBox(height: 10),
                  SurveyField(
                    label: 'Port (if applicable)',
                    controller: _aftermathPortCtrl,
                    hint: 'e.g. Fremantle',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
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
                    : Text(
                        widget.existing != null
                            ? 'Update Occurrence'
                            : 'Add Occurrence',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}  $h:$min';
  }
}

// ── Reusable labelled dropdown (string key/value options) ──────────────────

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.3)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String?>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            hint: const Text('— Not specified —',
                style: TextStyle(fontSize: 14, color: AppColors.textTertiary)),
            items: [
              const DropdownMenuItem(
                  value: null,
                  child: Text('— Not specified —',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textTertiary))),
              ...options.entries.map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textPrimary)),
                  )),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
