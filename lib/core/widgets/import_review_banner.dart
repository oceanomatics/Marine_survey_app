// lib/core/widgets/import_review_banner.dart
//
// Floating amber card that persists above all navigation while an AI import
// is pending review. Tapping "Keep changes" clears the review state;
// tapping "Revert all" undoes every DB insert from the import.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/import_review.dart';
import '../../shared/theme/app_theme.dart';

class ImportReviewBanner extends ConsumerStatefulWidget {
  const ImportReviewBanner({super.key});

  @override
  ConsumerState<ImportReviewBanner> createState() => _ImportReviewBannerState();
}

class _ImportReviewBannerState extends ConsumerState<ImportReviewBanner> {
  bool _reverting = false;

  Future<void> _revert(ImportReview review) async {
    setState(() => _reverting = true);
    try {
      await revertImport(review, ref);
    } catch (_) {
      // If revert fails partially, clear the review so the banner goes away.
      ref.read(importReviewProvider.notifier).state = null;
    } finally {
      if (mounted) setState(() => _reverting = false);
    }
  }

  void _keep() => ref.read(importReviewProvider.notifier).state = null;

  @override
  Widget build(BuildContext context) {
    final review = ref.watch(importReviewProvider);
    if (review == null) return const SizedBox.shrink();

    final topPadding = MediaQuery.of(context).viewPadding.top;

    return Positioned(
      top: topPadding + 8,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title row
              Row(
                children: [
                  const Icon(Icons.auto_fix_high_outlined,
                      size: 14, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Review import — ${review.docTitle}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: _reverting ? null : _keep,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.close,
                          size: 16, color: AppColors.textTertiary),
                    ),
                  ),
                ],
              ),
              // Summary
              if (review.summaryText.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  review.summaryText,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 8),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _reverting ? null : () => _revert(review),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    child: _reverting
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.error))
                        : const Text('Revert all'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _reverting ? null : _keep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                      elevation: 0,
                    ),
                    child: const Text('Keep changes ✓'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
