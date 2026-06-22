// lib/features/parties/widgets/assured_contact_sheet.dart

import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/error_handler.dart';

const _kColor = AppColors.coral;

class AssuredContactSheet extends StatefulWidget {
  const AssuredContactSheet({super.key, required this.onSave});

  final Future<void> Function(
    String name,
    String? roleTitle,
    String? phone,
    String? email,
    String? notes,
  ) onSave;

  @override
  State<AssuredContactSheet> createState() => _AssuredContactSheetState();
}

class _AssuredContactSheetState extends State<AssuredContactSheet> {
  final _nameCtrl     = TextEditingController();
  final _roleCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _notesCtrl    = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _roleCtrl, _phoneCtrl, _emailCtrl, _notesCtrl]) {
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
        _val(_roleCtrl),
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
                child: const Icon(Icons.person_add_outlined,
                    color: _kColor, size: 17),
              ),
              const SizedBox(width: 10),
              const Text('Add Assured Contact',
                  style: TextStyle(
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
          const SizedBox(height: 18),
          _field('Full Name *', _nameCtrl),
          const SizedBox(height: 10),
          _field('Role / Title', _roleCtrl,
              hint: 'e.g. Master, Owner Rep, Chief Engineer'),
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
                : const Text('Add Contact',
                    style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
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
      ),
    );
  }
}
