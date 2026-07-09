// lib/shared/widgets/app_feedback.dart
//
// Unified save-confirmation feedback. Surveyor flagged (8 July 2026) that
// save affordances/feedback were inconsistent screen to screen (Parties'
// save button didn't match anywhere else) — this is the one place every
// screen should call after a successful save, instead of each screen
// rolling its own SnackBar/toast.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shows a green, visible confirmation toast. Call after any successful
/// save — case fields, attendees, documents, report sections, everything.
void showSavedToast(BuildContext context, {String label = 'Saved'}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
}
