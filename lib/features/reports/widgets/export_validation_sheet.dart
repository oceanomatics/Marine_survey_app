// lib/features/reports/widgets/export_validation_sheet.dart
//
// Single consolidated pre-export checklist dialog (TODO.md §1.7), replacing
// what used to be two separate sequential dialogs in export_button.dart.
// Returns true if the surveyor chooses to export anyway, false/null to
// cancel. Only ever shown for soft warnings — the hard blocks (sign-off,
// AI review) are enforced by disabling the Export button itself and never
// reach this sheet.

import 'package:flutter/material.dart';

import '../utils/export_validation.dart';
import '../../../shared/theme/app_theme.dart';

Future<bool> showExportValidationSheet(
    BuildContext context, List<ExportWarning> warnings) async {
  if (warnings.isEmpty) return true;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.fact_check_outlined, color: Color(0xFFD97706), size: 20),
        const SizedBox(width: 8),
        Text('Pre-export check (${warnings.length})',
            style: const TextStyle(fontSize: 16)),
      ]),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'These items may be worth reviewing before issuing this report:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ...warnings.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.circle, size: 5, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(w.message,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textPrimary)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: Colors.white),
            child: const Text('Export anyway')),
      ],
    ),
  );
  return result ?? false;
}
