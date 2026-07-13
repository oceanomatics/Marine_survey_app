// lib/features/checklist/widgets/checklist_item_tile.dart

import 'package:flutter/material.dart';
import '../providers/checklist_provider.dart';
import '../../../shared/theme/app_theme.dart';

class ChecklistItemTile extends StatefulWidget {
  const ChecklistItemTile({
    super.key,
    required this.item,
    required this.onSetResponse,
    required this.onNotesSaved,
    this.onDelete,
    this.onNavigate,
  });

  final ChecklistItem item;
  final void Function(ChecklistResponse response) onSetResponse;
  final Future<void> Function(String notes) onNotesSaved;
  final VoidCallback? onDelete;
  final VoidCallback? onNavigate;

  @override
  State<ChecklistItemTile> createState() => _ChecklistItemTileState();
}

class _ChecklistItemTileState extends State<ChecklistItemTile> {
  bool _expanded = false;
  late TextEditingController _notesCtrl;
  bool _savingNotes = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.item.notes ?? '');
  }

  @override
  void didUpdateWidget(ChecklistItemTile old) {
    super.didUpdateWidget(old);
    if (old.item.notes != widget.item.notes) {
      _notesCtrl.text = widget.item.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final done = item.completed;
    final flagged = item.response == ChecklistResponse.no;
    final na = item.response == ChecklistResponse.na;

    final Color tint = done
        ? AppColors.green
        : flagged
            ? AppColors.error
            : na
                ? AppColors.textTertiary
                : AppColors.border;
    final Color bg = done
        ? AppColors.lightGreen.withValues(alpha: 0.5)
        : flagged
            ? AppColors.error.withValues(alpha: 0.06)
            : na
                ? AppColors.surface
                : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: done || flagged
              ? tint.withValues(alpha: 0.3)
              : AppColors.border,
          width: done || flagged ? 1 : 0.8,
        ),
      ),
      child: Column(
        children: [
          // ── Main row ─────────────────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Y / N / N-A response selector
                  _ResponseSelector(
                    checklistId: item.checklistId,
                    response: item.response,
                    onChanged: widget.onSetResponse,
                  ),
                  const SizedBox(width: 12),

                  // Item text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.itemText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: done || na
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            decoration: done
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: AppColors.textTertiary,
                          ),
                        ),
                        if (item.notes != null &&
                            item.notes!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.notes!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (item.response != null &&
                            item.answeredAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _formatTime(item.answeredAt!),
                            style: TextStyle(
                              fontSize: 10,
                              color: flagged ? AppColors.error : tint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Right-side actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Navigate to linked section
                      if (widget.onNavigate != null)
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios_rounded,
                              size: 13, color: AppColors.midBlue),
                          onPressed: widget.onNavigate,
                          tooltip: 'Go to section',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      // §4.4: auto-ticked provenance badge
                      if (item.completed && item.autoTickAttempted)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.lightGreen,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('auto',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.green,
                                  fontWeight: FontWeight.w600)),
                        ),
                      // Custom badge + delete
                      if (item.isCustom)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.lightAmber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('custom',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.amber,
                                  fontWeight: FontWeight.w600)),
                        ),
                      // Expand toggle for notes
                      IconButton(
                        icon: AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(Icons.expand_more,
                              size: 18, color: AppColors.textTertiary),
                        ),
                        onPressed: () =>
                            setState(() => _expanded = !_expanded),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded section (notes + delete) ─────────────────────
          if (_expanded) ...[
            const Divider(height: 1, indent: 50),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notes',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText:
                          'Add a note, observation or reference...',
                      hintStyle: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.midBlue, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (widget.onDelete != null)
                        TextButton.icon(
                          onPressed: () {
                            widget.onDelete!();
                            setState(() => _expanded = false);
                          },
                          icon: const Icon(Icons.delete_outline,
                              size: 15, color: AppColors.error),
                          label: const Text('Delete',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.error)),
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            setState(() => _expanded = false),
                        child: const Text('Cancel',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _savingNotes
                            ? null
                            : () async {
                                setState(() => _savingNotes = true);
                                await widget.onNotesSaved(
                                    _notesCtrl.text.trim());
                                if (mounted) {
                                  setState(() {
                                    _savingNotes = false;
                                    _expanded = false;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: _savingNotes
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2))
                            : const Text('Save note'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final mon = dt.month.toString().padLeft(2, '0');
    return '$day/$mon $h:$m';
  }
}

/// Compact 3-way Yes/No/N-A selector, replacing the old single checkbox.
class _ResponseSelector extends StatelessWidget {
  const _ResponseSelector({
    required this.checklistId,
    required this.response,
    required this.onChanged,
  });

  final String checklistId;
  final ChecklistResponse? response;
  final void Function(ChecklistResponse) onChanged;

  Color _colorFor(ChecklistResponse r) => switch (r) {
        ChecklistResponse.yes => AppColors.green,
        ChecklistResponse.no => AppColors.error,
        ChecklistResponse.na => AppColors.textTertiary,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in ChecklistResponse.values) ...[
          _ResponseButton(
            key: Key('response-${r.value}-$checklistId'),
            label: r == ChecklistResponse.na ? 'N/A' : r.label[0],
            selected: response == r,
            color: _colorFor(r),
            onTap: () => onChanged(r),
          ),
          if (r != ChecklistResponse.values.last) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _ResponseButton extends StatelessWidget {
  const _ResponseButton({
    super.key,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 26,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          border: Border.all(
              color: selected ? color : AppColors.textTertiary, width: 1.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
