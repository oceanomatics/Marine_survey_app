// lib/features/capture/widgets/capture_item_card.dart

import 'package:flutter/material.dart';
import '../providers/quick_capture_provider.dart';
import '../../../shared/theme/app_theme.dart';

class CaptureItemCard extends StatelessWidget {
  const CaptureItemCard({
    super.key,
    required this.item,
    required this.showActions,
    required this.onRoute,
    required this.onDiscard,
  });

  final QuickCaptureModel item;
  final bool showActions;
  final VoidCallback onRoute;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final isRouted = item.status == CaptureStatus.routed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(children: [
              // Type icon
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: isRouted
                      ? AppColors.lightGreen
                      : AppColors.lightCoral,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.captureType == 'voice'
                      ? Icons.mic_outlined
                      : Icons.bolt_outlined,
                  color: isRouted ? AppColors.green : AppColors.coral,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.captureType == 'voice'
                          ? 'Voice note'
                          : 'Quick capture',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                    if (item.capturedAt != null)
                      Text(
                        _formatTime(item.capturedAt!),
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textTertiary),
                      ),
                  ],
                ),
              ),
              // Routed destination badge
              if (isRouted && item.routedTo != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(item.routedTo!.emoji,
                        style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 4),
                    Text(
                      item.routedTo!.label,
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.green,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
            ]),

            // ── Content ──────────────────────────────────────────────
            const SizedBox(height: 10),
            Text(
              item.content,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.4),
            ),

            // ── Actions (pending only) ────────────────────────────────
            if (showActions) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDiscard,
                    icon: const Icon(Icons.delete_outline,
                        size: 15, color: AppColors.textSecondary),
                    label: const Text('Discard',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onRoute,
                    icon: const Icon(Icons.arrow_forward, size: 15),
                    label: const Text('Route to...',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final d   = dt.day.toString().padLeft(2, '0');
    final m   = dt.month.toString().padLeft(2, '0');
    final h   = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} $h:$min';
  }
}
