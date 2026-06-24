// lib/shared/widgets/save_bar.dart
// Animated bottom save bar — appears when a form has unsaved changes.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SaveBar extends StatelessWidget {
  const SaveBar({
    super.key,
    required this.visible,
    required this.saving,
    required this.onSave,
    this.label = 'Save changes',
  });

  final bool visible;
  final bool saving;
  final VoidCallback onSave;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.bottomCenter,
      child: visible
          ? Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 12,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
              child: FilledButton(
                onPressed: saving ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.midBlue,
                  disabledBackgroundColor: AppColors.midBlue.withValues(alpha: 0.6),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        label,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}
