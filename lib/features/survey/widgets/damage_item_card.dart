// lib/features/survey/widgets/damage_item_card.dart

import 'package:flutter/material.dart';
import '../providers/damage_provider.dart';
import '../../photos/models/photo_model.dart';
import '../../photos/widgets/photo_strip.dart';
import '../../../shared/theme/app_theme.dart';

class DamageItemCard extends StatelessWidget {
  const DamageItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.photos,
    required this.onAddPhoto,
    required this.onDeletePhoto,
  });

  final DamageItemModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final List<PhotoModel> photos;
  final VoidCallback onAddPhoto;
  final void Function(String photoId) onDeletePhoto;

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
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 15),
                        SizedBox(width: 8),
                        Text('Edit', style: TextStyle(fontSize: 13)),
                      ]),
                    ),
                    PopupMenuItem(
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
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    height: 1.4),
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

            // ── Photo strip ───────────────────────────────────────────
            const SizedBox(height: 10),
            PhotoStrip(
              photos: photos,
              onAddPhoto: onAddPhoto,
              onDeletePhoto: onDeletePhoto,
            ),

            // ── Exclusion reason ──────────────────────────────────────
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

}
