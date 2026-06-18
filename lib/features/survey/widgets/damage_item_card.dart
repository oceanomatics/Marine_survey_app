// lib/features/survey/widgets/damage_item_card.dart

import 'package:flutter/material.dart';
import '../providers/damage_provider.dart';
import '../../../shared/theme/app_theme.dart';

class DamageItemCard extends StatelessWidget {
  const DamageItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final DamageItemModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────
            Row(
              children: [
                // Sequence number
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: item.isConcerningAverage
                        ? AppColors.lightCoral
                        : AppColors.lightAmber,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      item.sequenceNo.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: item.isConcerningAverage
                            ? AppColors.coral
                            : AppColors.amber,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.componentName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                // Average / owner badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.isConcerningAverage
                        ? AppColors.lightBlue
                        : AppColors.lightAmber,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    item.isConcerningAverage ? 'Average' : "Owner's",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: item.isConcerningAverage
                          ? AppColors.midBlue
                          : AppColors.amber,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      size: 18, color: AppColors.textTertiary),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 15),
                        SizedBox(width: 8),
                        Text('Edit', style: TextStyle(fontSize: 13)),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            color: AppColors.error, size: 15),
                        SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(
                                color: AppColors.error, fontSize: 13)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),

            // ── Location ─────────────────────────────────────────────
            if (item.locationOnVessel != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.location_on_outlined,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(item.locationOnVessel!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ),
              ]),
            ],

            // ── Damage description ────────────────────────────────────
            if (item.damageDescription != null) ...[
              const SizedBox(height: 8),
              Text(
                item.damageDescription!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textPrimary, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // ── Condition found ───────────────────────────────────────
            if (item.conditionFound != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Condition: ',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    Expanded(
                      child: Text(item.conditionFound!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.3)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // ── Status row ────────────────────────────────────────────
            Row(
              children: [
                if (item.repairType != null)
                  _StatusChip(
                    label: item.repairType!.label,
                    color: _repairTypeColor(item.repairType!),
                  ),
                const SizedBox(width: 6),
                _StatusChip(
                  label: item.repairStatus.label,
                  color: _repairStatusColor(item.repairStatus),
                ),
                const Spacer(),
                // Photo count
                if (item.photoCount > 0)
                  Row(children: [
                    const Icon(Icons.photo_outlined,
                        size: 13, color: AppColors.textTertiary),
                    const SizedBox(width: 3),
                    Text('${item.photoCount}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary)),
                  ]),
              ],
            ),

            // ── Exclusion reason (owner's items) ──────────────────────
            if (!item.isConcerningAverage &&
                item.exclusionReason != null) ...[
              const SizedBox(height: 6),
              Text(
                'Not concerning average: ${item.exclusionReason}',
                style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.amber,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _repairTypeColor(RepairType t) => switch (t) {
        RepairType.temporary => AppColors.warning,
        RepairType.permanent => AppColors.success,
        RepairType.deferred  => AppColors.textSecondary,
      };

  Color _repairStatusColor(RepairStatus s) => switch (s) {
        RepairStatus.notStarted => AppColors.textTertiary,
        RepairStatus.inProgress => AppColors.warning,
        RepairStatus.completed  => AppColors.success,
        RepairStatus.deferred   => AppColors.textSecondary,
      };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }
}
