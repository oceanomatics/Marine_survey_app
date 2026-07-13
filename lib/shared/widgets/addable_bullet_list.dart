// lib/shared/widgets/addable_bullet_list.dart
//
// Generic "label header + add button + bullet list with per-item remove"
// widget — currently used by Nature of the Repairs (anticipated repair
// sequence, §3.11). WNCA's per-repair-period items are a different
// mechanism (context cues via ContextCuesPanel), despite an earlier version
// of this comment claiming otherwise — corrected 13 July 2026, this widget
// was never actually wired into that screen.

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
    this.onReorder,
  });

  final String label;
  final List<BulletListItem> items;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final String emptyText;

  /// §3.11: when set, items get a drag handle and can be reordered — list
  /// position order is the report order (no separate index field to
  /// maintain; the caller re-persists the whole reordered array). Omitted
  /// (null) means static order — no current caller needs that, but a
  /// future one might not want reordering.
  ///
  /// Wired to ReorderableListView's `onReorderItem` (not the deprecated
  /// `onReorder`), so `newIndex` here is already adjusted for the
  /// removed-then-reinserted item — callers should NOT apply the classic
  /// `if (newIndex > oldIndex) newIndex -= 1` correction themselves.
  final void Function(int oldIndex, int newIndex)? onReorder;

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
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.textSecondary)),
              ),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color:
                            AppColors.textSecondary.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: AppColors.textSecondary),
                      SizedBox(width: 4),
                      Text('Add',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (items.isEmpty) ...[
            const SizedBox(height: 10),
            Text(emptyText,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic)),
          ] else if (onReorder != null) ...[
            const SizedBox(height: 8),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorderItem: onReorder!,
              itemBuilder: (context, i) => _BulletRow(
                key: ValueKey(items[i].id),
                item: items[i],
                onRemove: onRemove,
                dragIndex: i,
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            for (final item in items)
              _BulletRow(key: ValueKey(item.id), item: item, onRemove: onRemove),
          ],
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({
    super.key,
    required this.item,
    required this.onRemove,
    this.dragIndex,
  });

  final BulletListItem item;
  final ValueChanged<String> onRemove;
  /// Non-null only inside a ReorderableListView — this row's index, needed
  /// to wire up a manual drag handle (buildDefaultDragHandles: false, so
  /// the whole row isn't a drag target and the trailing remove button still
  /// works without starting a drag).
  final int? dragIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (dragIndex != null)
            ReorderableDragStartListener(
              index: dragIndex!,
              child: const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.drag_indicator,
                    size: 18, color: AppColors.textTertiary),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 4, right: 8),
              child: Icon(Icons.circle, size: 6, color: AppColors.textSecondary),
            ),
          Expanded(
            child: Text(item.text,
                style: const TextStyle(
                    fontSize: 13.5, color: AppColors.textPrimary, height: 1.3)),
          ),
          GestureDetector(
            onTap: () => onRemove(item.id),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, size: 17, color: AppColors.textTertiary),
            ),
          ),
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
