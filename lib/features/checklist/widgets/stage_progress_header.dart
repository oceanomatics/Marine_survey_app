// lib/features/checklist/widgets/stage_progress_header.dart

import 'package:flutter/material.dart';
import '../providers/checklist_provider.dart';
import '../../../shared/theme/app_theme.dart';

class StageProgressHeader extends StatelessWidget {
  const StageProgressHeader({
    super.key,
    required this.stage,
    required this.completed,
    required this.total,
    required this.progress,
    this.onMarkAllDone,
  });

  final ChecklistStage stage;
  final int completed;
  final int total;
  final double progress;
  final VoidCallback? onMarkAllDone;

  @override
  Widget build(BuildContext context) {
    final isComplete = progress >= 1.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isComplete
            ? AppColors.lightGreen
            : AppColors.lightBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComplete
              ? AppColors.green.withValues(alpha: 0.3)
              : AppColors.midBlue.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isComplete ? AppColors.green : AppColors.midBlue,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isComplete
                            ? AppColors.green
                            : AppColors.midBlue,
                      ),
                    ),
                    Text(
                      stage.subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Mark all done button
              if (!isComplete && onMarkAllDone != null)
                TextButton(
                  onPressed: onMarkAllDone,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    backgroundColor:
                        AppColors.midBlue.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Mark all done',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.midBlue,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              if (isComplete)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Complete ✓',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.green,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.6),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isComplete ? AppColors.green : AppColors.midBlue,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$completed / $total',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      isComplete ? AppColors.green : AppColors.midBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
