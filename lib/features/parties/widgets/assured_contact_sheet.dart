// lib/features/parties/widgets/assured_contact_sheet.dart

import 'package:flutter/material.dart';
import '../models/party_model.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/error_handler.dart';

const _kColor = AppColors.coral;

class AssuredContactSheet extends StatefulWidget {
  const AssuredContactSheet({
    super.key,
    required this.onSave,
    this.initialGroup,
    this.initialContact,
  });

  final Future<void> Function(
    String name,
    String? company,
    String? roleTitle,
    StakeholderGroup? group,
    String? phone,
    String? email,
    String? notes,
  ) onSave;

  final StakeholderGroup? initialGroup;

  /// When set, the sheet opens in edit mode with all fields pre-filled.
  final AssuredContactModel? initialContact;

  bool get isEditing => initialContact != null;

  @override
  State<AssuredContactSheet> createState() => _AssuredContactSheetState();
}

class _AssuredContactSheetState extends State<AssuredContactSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _companyCtrl;
  late final TextEditingController _roleCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _notesCtrl;

  StakeholderGroup? _group;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initialContact;
    _nameCtrl    = TextEditingController(text: c?.fullName ?? '');
    _companyCtrl = TextEditingController(text: c?.company ?? '');
    _roleCtrl    = TextEditingController(text: c?.roleTitle ?? '');
    _phoneCtrl   = TextEditingController(text: c?.phone ?? '');
    _emailCtrl   = TextEditingController(text: c?.email ?? '');
    _notesCtrl   = TextEditingController(text: c?.notes ?? '');
    _group       = c?.stakeholderGroup ?? widget.initialGroup;
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _companyCtrl, _roleCtrl, _phoneCtrl, _emailCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _val(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    final name = _val(_nameCtrl);
    if (name == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(
        name,
        _val(_companyCtrl),
        _val(_roleCtrl),
        _group,
        _val(_phoneCtrl),
        _val(_emailCtrl),
        _val(_notesCtrl),
      );
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      if (mounted) showError(context, 'Save failed: $e', error: e, stack: st, tag: 'App');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _kColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.isEditing
                        ? Icons.edit_outlined
                        : Icons.person_add_outlined,
                    color: _kColor, size: 17),
                ),
                const SizedBox(width: 10),
                Text(widget.isEditing ? 'Edit Stakeholder' : 'Add Stakeholder',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20,
                      color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Group selector
            DropdownButtonFormField<StakeholderGroup>(
              initialValue: _group,
              decoration: _inputDeco('Group'),
              hint: const Text('Select group',
                  style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
              items: StakeholderGroup.values
                  .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text(g.label,
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (g) => setState(() => _group = g),
            ),
            const SizedBox(height: 10),

            _field('Full Name *', _nameCtrl),
            const SizedBox(height: 10),
            _field('Company / Organisation', _companyCtrl),
            const SizedBox(height: 10),
            _field('Role / Title', _roleCtrl,
                hint: 'e.g. Master, Underwriter, Loss Adjuster'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _field('Phone', _phoneCtrl,
                      keyboardType: TextInputType.phone),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field('Email', _emailCtrl,
                      keyboardType: TextInputType.emailAddress),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _field('Notes', _notesCtrl, maxLines: 2),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(widget.isEditing ? 'Save Changes' : 'Add Stakeholder',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      );

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: _inputDeco(label, hint: hint),
      );
}
