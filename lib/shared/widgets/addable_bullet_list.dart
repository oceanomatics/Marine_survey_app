// lib/shared/widgets/addable_bullet_list.dart
//
// Generic "label header + add button + bullet list with per-item remove"
// widget — shared by Work Not Concerning Average (per repair period items)
// and Nature of the Repairs (anticipated repair sequence), which both need
// the same free-addable text-item list presentation.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

const kBulletListAccent = Color(0xFF1A6B9E);

class BulletListItem {
  const BulletListItem({required this.id, required this.text});
  final String id;
  final String text;
}

class AddableBulletList extends StatelessWidget {
  const AddableBulletList({
    super.key,
    required this.label,
    required this.items,
    required this.onAdd,
    required this.onRemove,
    this.emptyText = 'No items added yet.',
  });

  final String label;
  final List<BulletListItem> items;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_list_bulleted,
                  size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.textSecondary)),
              ),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color:
                            AppColors.textSecondary.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 11, color: AppColors.textSecondary),
                      SizedBox(width: 3),
                      Text('Add',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (items.isEmpty) ...[
            const SizedBox(height: 8),
            Text(emptyText,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic)),
          ] else ...[
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3, right: 6),
                      child: Icon(Icons.circle,
                          size: 5, color: AppColors.textSecondary),
                    ),
                    Expanded(
                      child: Text(item.text,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textPrimary)),
                    ),
                    GestureDetector(
                      onTap: () => onRemove(item.id),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.close,
                            size: 14, color: AppColors.textTertiary),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

Future<void> showAddBulletItemDialog(
  BuildContext context, {
  required String title,
  required String hintText,
  required ValueChanged<String> onAdd,
}) {
  final ctrl = TextEditingController();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title:
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: 2,
        decoration: InputDecoration(
          hintText: hintText,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        style: const TextStyle(fontSize: 13),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final text = ctrl.text.trim();
            if (text.isEmpty) return;
            Navigator.pop(ctx);
            onAdd(text);
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: kBulletListAccent, foregroundColor: Colors.white),
          child: const Text('Add'),
        ),
      ],
    ),
  );
}
