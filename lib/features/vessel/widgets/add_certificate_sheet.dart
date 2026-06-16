// lib/features/vessel/widgets/add_certificate_sheet.dart

import 'package:flutter/material.dart';
import '../providers/certificates_provider.dart';
import './survey_field.dart';
import '../../../shared/theme/app_theme.dart';

class AddCertificateSheet extends StatefulWidget {
  const AddCertificateSheet({
    super.key,
    required this.caseId,
    required this.onSave,
    this.existing,
  });

  final String caseId;
  final CertificateModel? existing;
  final Future<void> Function(CertificateModel) onSave;

  @override
  State<AddCertificateSheet> createState() => _AddCertificateSheetState();
}

class _AddCertificateSheetState extends State<AddCertificateSheet> {
  final _nameCtrl      = TextEditingController();
  final _authorityCtrl = TextEditingController();
  final _numberCtrl    = TextEditingController();
  final _notesCtrl     = TextEditingController();

  CertType   _certType = CertType.classCertificate;
  CertStatus _status   = CertStatus.valid;
  DateTime?  _issueDate;
  DateTime?  _expiryDate;
  DateTime?  _annualDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _certType     = e.certType;
      _status       = e.status;
      _issueDate    = e.issueDate;
      _expiryDate   = e.expiryDate;
      _annualDate   = e.annualSurveyDate;
      _nameCtrl.text      = e.certName         ?? '';
      _authorityCtrl.text = e.issuingAuthority  ?? '';
      _numberCtrl.text    = e.certNumber        ?? '';
      _notesCtrl.text     = e.notes             ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _authorityCtrl.dispose();
    _numberCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // Auto-fill name and authority from cert type
  void _onTypeChanged(CertType type) {
    setState(() => _certType = type);
    if (_nameCtrl.text.isEmpty) {
      _nameCtrl.text = type.label;
    }
  }

  Future<void> _pickDate(String field) async {
    final initial = switch (field) {
      'issue'  => _issueDate  ?? DateTime.now(),
      'expiry' => _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      _        => _annualDate ?? DateTime.now(),
    };

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      switch (field) {
        case 'issue':  _issueDate  = picked;
        case 'expiry': _expiryDate = picked;
        case 'annual': _annualDate = picked;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final cert = CertificateModel(
        certId:          widget.existing?.certId ?? '',
        caseId:          widget.caseId,
        certType:        _certType,
        certName:        _nameCtrl.text.trim().isEmpty
            ? _certType.label : _nameCtrl.text.trim(),
        issuingAuthority: _authorityCtrl.text.trim().isEmpty
            ? null : _authorityCtrl.text.trim(),
        issueDate:       _issueDate,
        expiryDate:      _expiryDate,
        annualSurveyDate: _annualDate,
        certNumber:      _numberCtrl.text.trim().isEmpty
            ? null : _numberCtrl.text.trim(),
        status:          _status,
        notes:           _notesCtrl.text.trim().isEmpty
            ? null : _notesCtrl.text.trim(),
        extractedAuto:   widget.existing?.extractedAuto ?? false,
        sourceDocId:     widget.existing?.sourceDocId,
      );
      await widget.onSave(cert);
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
            Text(isEdit ? 'Edit Certificate' : 'Add Certificate',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            // Certificate type
            const Text('Certificate Type',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 5),
            DropdownButtonFormField<CertType>(
              initialValue: _certType,
              decoration: _ddDeco(),
              isExpanded: true,
              items: CertType.values
                  .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.label,
                          style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) { if (v != null) _onTypeChanged(v); },
            ),
            const SizedBox(height: 14),

            SurveyField(
              label: 'Certificate Name',
              controller: _nameCtrl,
              hint: 'e.g. Class Certificate',
            ),
            SurveyField(
              label: 'Issuing Authority',
              controller: _authorityCtrl,
              hint: 'e.g. A.B.S., Lloyd\'s Register, AMSA',
            ),
            SurveyField(
              label: 'Certificate Number',
              controller: _numberCtrl,
              hint: 'Optional',
            ),

            // Dates section
            const Text('Dates',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _DatePicker(
                label: 'Issue Date',
                date: _issueDate,
                onTap: () => _pickDate('issue'),
                onClear: () => setState(() => _issueDate = null),
              )),
              const SizedBox(width: 10),
              Expanded(child: _DatePicker(
                label: 'Expiry Date',
                date: _expiryDate,
                onTap: () => _pickDate('expiry'),
                onClear: () => setState(() => _expiryDate = null),
                highlight: _expiryDate != null &&
                    _expiryDate!.isBefore(DateTime.now()),
              )),
            ]),
            const SizedBox(height: 10),
            _DatePicker(
              label: 'Annual Survey Date',
              date: _annualDate,
              onTap: () => _pickDate('annual'),
              onClear: () => setState(() => _annualDate = null),
            ),
            const SizedBox(height: 14),

            // Status
            const Text('Status',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 5),
            DropdownButtonFormField<CertStatus>(
              initialValue: _status,
              decoration: _ddDeco(),
              items: CertStatus.values
                  .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.label,
                          style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _status = v);
              },
            ),
            const SizedBox(height: 14),

            SurveyField(
              label: 'Notes',
              controller: _notesCtrl,
              hint: 'Any remarks about this certificate...',
              maxLines: 2,
            ),

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(isEdit ? 'Update' : 'Add Certificate',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _ddDeco() => InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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

class _DatePicker extends StatelessWidget {
  const _DatePicker({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
    this.highlight = false,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: highlight
                  ? AppColors.lightCoral
                  : Colors.white,
              border: Border.all(
                color: highlight
                    ? AppColors.error.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: highlight
                    ? AppColors.error
                    : AppColors.textTertiary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  date != null ? _fmt(date!) : 'Select date',
                  style: TextStyle(
                    fontSize: 13,
                    color: date != null
                        ? (highlight
                            ? AppColors.error
                            : AppColors.textPrimary)
                        : AppColors.textTertiary,
                    fontWeight: date != null
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                ),
              ),
              if (date != null)
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.clear,
                      size: 14,
                      color: highlight
                          ? AppColors.error
                          : AppColors.textTertiary),
                ),
            ]),
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
