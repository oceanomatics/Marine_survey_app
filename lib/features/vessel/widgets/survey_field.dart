// lib/features/vessel/widgets/survey_field.dart
// Reusable labelled text field for all survey forms

import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';

class SurveyField extends StatelessWidget {
  const SurveyField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboard = TextInputType.text,
    this.onChanged,
    this.maxLines = 1,
    this.capitalization = TextCapitalization.none,
    this.suffix,
    this.suffixIcon,
    this.enabled = true,
    this.important = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType keyboard;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final TextCapitalization capitalization;
  final String? suffix;
  final Widget? suffixIcon;
  final bool enabled;
  final bool important; // shows a blue left border

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: important
            ? const BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.midBlue, width: 3),
                ),
              )
            : null,
        padding: important
            ? const EdgeInsets.only(left: 10)
            : EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 5),
            TextField(
              controller: controller,
              keyboardType: keyboard,
              textCapitalization: capitalization,
              maxLines: maxLines,
              enabled: enabled,
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w400,
                ),
                suffixText: suffix,
                suffixIcon: suffixIcon,
                suffixStyle: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 11),
                filled: true,
                fillColor: enabled ? Colors.white : AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.midBlue, width: 2),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: AppColors.border, width: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
