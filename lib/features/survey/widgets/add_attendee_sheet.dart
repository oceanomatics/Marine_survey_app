// lib/features/survey/widgets/add_attendee_sheet.dart

import 'package:flutter/material.dart';
import '../providers/attendees_provider.dart';
import '../../vessel/widgets/survey_field.dart';
import '../../../shared/theme/app_theme.dart';

class AddAttendeeSheet extends StatefulWidget {
  const AddAttendeeSheet({
    super.key,
    required this.caseId,
    required this.onSave,
    this.existing,
  });

  final String caseId;
  final AttendeeModel? existing;
  final Future<void> Function(AttendeeModel) onSave;

  @override
  State<AddAttendeeSheet> createState() => _AddAttendeeSheetState();
}

class _AddAttendeeSheetState extends State<AddAttendeeSheet> {
  final _nameCtrl          = TextEditingController();
  final _rankCtrl          = TextEditingController();
  final _companyCtrl       = TextEditingController();
  final _representingCtrl  = TextEditingController();
  final _emailCtrl         = TextEditingController();
  final _phoneCtrl         = TextEditingController();

  AttendeeRole _role = AttendeeRole.other;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text         = e.fullName;
      _rankCtrl.text         = e.rankPosition     ?? '';
      _companyCtrl.text      = e.company           ?? '';
      _representingCtrl.text = e.representing      ?? '';
      _emailCtrl.text        = e.contactEmail      ?? '';
      _phoneCtrl.text        = e.contactPhone      ?? '';
      _role                  = e.roleType          ?? AttendeeRole.other;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rankCtrl.dispose();
    _companyCtrl.dispose();
    _representingCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // Auto-fill rank when role changes
  void _onRoleChanged(AttendeeRole role) {
    setState(() => _role = role);
    if (_rankCtrl.text.isEmpty) {
      _rankCtrl.text = switch (role) {
        AttendeeRole.master         => 'Master',
        AttendeeRole.chiefEngineer  => 'Chief Engineer',
        AttendeeRole.firstEngineer  => 'First Engineer',
        AttendeeRole.superintendent => 'Superintendent',
        AttendeeRole.classSurveyor  => 'Class Surveyor',
        AttendeeRole.serviceEngineer => 'Field Service Engineer',
        AttendeeRole.surveyor       => 'Marine Surveyor',
        _ => '',
      };
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final attendee = AttendeeModel(
        attendeeId:   widget.existing?.attendeeId ?? '',
        caseId:       widget.caseId,
        fullName:     _nameCtrl.text.trim(),
        rankPosition: _rankCtrl.text.trim().isEmpty
            ? null : _rankCtrl.text.trim(),
        company:      _companyCtrl.text.trim().isEmpty
            ? null : _companyCtrl.text.trim(),
        representing: _representingCtrl.text.trim().isEmpty
            ? null : _representingCtrl.text.trim(),
        roleType:     _role,
        contactEmail: _emailCtrl.text.trim().isEmpty
            ? null : _emailCtrl.text.trim(),
        contactPhone: _phoneCtrl.text.trim().isEmpty
            ? null : _phoneCtrl.text.trim(),
      );
      await widget.onSave(attendee);
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
              isEdit ? 'Edit Attendee' : 'Add Person',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),

            // Role selector — first, drives rank autofill
            const Text('Role',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 5),
            DropdownButtonFormField<AttendeeRole>(
              initialValue: _role,
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
              items: AttendeeRole.values
                  .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r.label,
                          style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) {
                if (v != null) _onRoleChanged(v);
              },
            ),
            const SizedBox(height: 14),

            // Name + rank side by side
            Row(children: [
              Expanded(
                flex: 3,
                child: SurveyField(
                  label: 'Full Name *',
                  controller: _nameCtrl,
                  hint: 'e.g. John Samuel',
                  important: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SurveyField(
                  label: 'Rank / Position',
                  controller: _rankCtrl,
                  hint: 'e.g. Master',
                ),
              ),
            ]),

            SurveyField(
              label: 'Company',
              controller: _companyCtrl,
              hint: 'e.g. MinRes Marine Pty Ltd',
            ),

            SurveyField(
              label: 'Representing',
              controller: _representingCtrl,
              hint: 'e.g. Vessel Owners / ABL / Westrac',
            ),

            // Contact details — collapsible section
            const _ContactDivider(),

            Row(children: [
              Expanded(
                child: SurveyField(
                  label: 'Email',
                  controller: _emailCtrl,
                  hint: 'Optional',
                  keyboard: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SurveyField(
                  label: 'Phone',
                  controller: _phoneCtrl,
                  hint: 'Optional',
                  keyboard: TextInputType.phone,
                ),
              ),
            ]),

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        isEdit ? 'Update' : 'Add to Attendees',
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
}

class _ContactDivider extends StatelessWidget {
  const _ContactDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('Contact details (optional)',
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Divider()),
      ]),
    );
  }
}
