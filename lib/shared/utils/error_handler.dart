// lib/shared/utils/error_handler.dart
//
// Single entry point for user-visible errors. Always logs to DebugLogger
// AND shows the red snackbar — so nothing gets lost silently.
//
// Usage:
//   showError(context, 'Save failed', error: e, stack: st, tag: 'Vessel');

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../core/services/debug_logger.dart';

void showError(
  BuildContext context,
  String message, {
  Object? error,
  StackTrace? stack,
  String tag = 'App',
}) {
  // Always log — fire and forget.
  DebugLogger.log(message, tag: tag, error: error, stack: stack);

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
