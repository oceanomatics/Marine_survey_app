// lib/features/survey/widgets/add_occurrence_sheet.dart

import 'package:flutter/material.dart';
import '../../vessel/widgets/survey_field.dart';
import '../../../shared/theme/app_theme.dart';

class AddOccurrenceSheet extends StatefulWidget {
  const AddOccurrenceSheet({super.key, required this.onSave});

  final Future<void> Function(
    String title,
    DateTime? dateTime,
    String? location,
    String? description,
  ) onSave;

  @override
  State<AddOccurrenceSheet> createState() => _AddOccurrenceSheetState();
}

class _AddOccurrenceSheetState extends State<AddOccurrenceSheet> {
  final _titleCtrl       = TextEditingController();
  final _locationCtrl    = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  DateTime? _dateTime;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _descriptionCtrl.dispose();
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
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const Text('Add Occurrence',
                style: TextStyle(
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

            SurveyField(
              label: "Owner's Description (brief)",
              controller: _descriptionCtrl,
              hint:
                  'Brief background — the owner\'s account of what happened. '
                  'Full narrative can be added in the report builder.',
              maxLines: 4,
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
                    : const Text('Add Occurrence',
                        style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
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
