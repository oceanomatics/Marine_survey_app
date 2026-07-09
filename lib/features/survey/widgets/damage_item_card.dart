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
      child: InkWell(
        // TODO.md §3.8 row 22: clicking a damage item opens the editor
        // directly — no longer requires finding Edit in the overflow menu.
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
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
                    if (v == 'delete') onDelete();
                  },
                  // 'Edit' removed from the menu (row 22) — the whole card
                  // now opens the editor directly on tap.
                  itemBuilder: (_) => const [
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

            // ── Auto-composed summary (§3.8 rows 21+23) ────────────────
            // Replaces the old separate Damage Description / Condition
            // Found blocks with one semi-automatic two-line summary woven
            // from those same fields plus confirmation provenance —
            // Condition Found is still captured in the editor, just no
            // longer shown as an isolated field here.
            if (item.damageDescription != null || item.conditionFound != null) ...[
              const SizedBox(height: 8),
              Text(
                composeDamageRowDescription(item),
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

}
