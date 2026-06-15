// lib/features/checklist/widgets/add_item_sheet.dart

import 'package:flutter/material.dart';
import '../providers/checklist_provider.dart';
import '../../../shared/theme/app_theme.dart';

class AddChecklistItemSheet extends StatefulWidget {
  const AddChecklistItemSheet({
    super.key,
    required this.stage,
    required this.onAdd,
  });

  final ChecklistStage stage;
  final Future<void> Function(String text) onAdd;

  @override
  State<AddChecklistItemSheet> createState() => _AddChecklistItemSheetState();
}

class _AddChecklistItemSheetState extends State<AddChecklistItemSheet> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onAdd(text);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.stage.label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.green,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Add custom item',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Custom items are specific to this case and will\nappear alongside the standard checklist.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 2,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText:
                  'e.g. "Confirm turbocharger serial number with chief"\n'
                  '"Request oil analysis from last service"',
              hintStyle: const TextStyle(
                  fontSize: 13, color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.green, width: 2),
              ),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Add to Checklist'),
            ),
          ),
        ],
      ),
    );
  }
}
