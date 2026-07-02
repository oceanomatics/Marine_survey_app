// lib/shared/widgets/tri_state_row.dart
//
// Not set / Yes / No selector for a nullable bool field. Extracted from
// vessel_particulars_screen.dart so every screen editing the same nullable
// flag (e.g. ISM/Class incident-reported) shares one null-preserving
// widget instead of each screen inventing its own coercion behaviour.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TriStateRow extends StatelessWidget {
  const TriStateRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: AppColors.textSecondary)),
      if (hint != null)
        Text(hint!,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textTertiary,
                fontStyle: FontStyle.italic)),
      const SizedBox(height: 6),
      Row(children: [
        TriBtn('Not set', value == null,  () => onChanged(null)),
        const SizedBox(width: 6),
        TriBtn('Yes', value == true,  () => onChanged(true),
            activeColor: AppColors.success),
        const SizedBox(width: 6),
        TriBtn('No',  value == false, () => onChanged(false),
            activeColor: AppColors.error),
      ]),
    ]);
  }
}

class TriBtn extends StatelessWidget {
  const TriBtn(this.label, this.active, this.onTap, {super.key, this.activeColor});
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? color : AppColors.border,
              width: active ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? color : AppColors.textSecondary)),
      ),
    );
  }
}
