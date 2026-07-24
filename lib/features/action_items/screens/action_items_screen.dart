// lib/features/action_items/screens/action_items_screen.dart
//
// TODO.md §4.7 — case-level Action Items view. Extracted action items land as
// live tasks straight away (no track/pending-review dance — 24 July 2026), so
// this is just:
//   • "Pending Review" — LEGACY candidates from before the change, still
//     confirmable/dismissable; nothing new lands here.
//   • The task list, filtered by status (Open / Done / Dismissed).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/action_items_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/back_app_bar.dart';
import '../../../shared/widgets/app_feedback.dart';

const _kColor = Color(0xFF7B5EA7);

class ActionItemsScreen extends ConsumerStatefulWidget {
  const ActionItemsScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<ActionItemsScreen> createState() => _ActionItemsScreenState();
}

class _ActionItemsScreenState extends ConsumerState<ActionItemsScreen> {
  ActionItemStatus _filter = ActionItemStatus.open;

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(actionItemsProvider(widget.caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BackAppBar(title: Text('Action Items')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        backgroundColor: _kColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: itemsAsync.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          // Legacy pending-review items (from before extracted items became
          // active on import) can still be confirmed/dismissed here; nothing
          // new lands in this state anymore.
          final pendingReview =
              items.where((i) => i.pendingReview).toList();
          final tracked = items
              .where((i) => !i.pendingReview && i.status == _filter)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            children: [
              if (pendingReview.isNotEmpty) ...[
                const _SectionHeader(
                  label: 'Pending Review',
                  color: AppColors.amber,
                  icon: Icons.rule_outlined,
                ),
                const SizedBox(height: 8),
                ...pendingReview.map((i) => _PendingReviewCard(
                      item: i,
                      onConfirm: () => ref
                          .read(actionItemsProvider(widget.caseId).notifier)
                          .confirm(i.id),
                      onDismiss: () => ref
                          .read(actionItemsProvider(widget.caseId).notifier)
                          .setStatus(i.id, ActionItemStatus.dismissed),
                    )),
                const SizedBox(height: 18),
              ],
              const _SectionHeader(
                label: 'Tasks',
                color: _kColor,
                icon: Icons.checklist_outlined,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: ActionItemStatus.values
                    .map((s) => ChoiceChip(
                          label: Text(s.label,
                              style: const TextStyle(fontSize: 12)),
                          selected: _filter == s,
                          onSelected: (_) => setState(() => _filter = s),
                          selectedColor: _kColor.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                              color: _filter == s
                                  ? _kColor
                                  : AppColors.textSecondary),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              if (tracked.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text('No ${_filter.label.toLowerCase()} tasks.',
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textTertiary,
                          fontStyle: FontStyle.italic)),
                )
              else
                ...tracked.map((i) => _TaskCard(
                      item: i,
                      onToggleDone: () => ref
                          .read(actionItemsProvider(widget.caseId).notifier)
                          .setStatus(
                              i.id,
                              i.status == ActionItemStatus.done
                                  ? ActionItemStatus.open
                                  : ActionItemStatus.done),
                      onDismiss: i.status == ActionItemStatus.dismissed
                          ? null
                          : () => ref
                              .read(
                                  actionItemsProvider(widget.caseId).notifier)
                              .setStatus(i.id, ActionItemStatus.dismissed),
                      onDelete: () => ref
                          .read(actionItemsProvider(widget.caseId).notifier)
                          .delete(i.id),
                    )),
            ],
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Task',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'e.g. Book flights for next attendance',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _kColor, foregroundColor: Colors.white),
                  onPressed: () async {
                    final text = ctrl.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(ctx);
                    await ref
                        .read(actionItemsProvider(widget.caseId).notifier)
                        .addManual(widget.caseId, text);
                    if (context.mounted) showSavedToast(context);
                  },
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.label, required this.color, required this.icon});
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.4)),
      ]);
}

class _PendingReviewCard extends StatelessWidget {
  const _PendingReviewCard({
    required this.item,
    required this.onConfirm,
    required this.onDismiss,
  });
  final ActionItemModel item;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Expanded(
          child: Text(item.text,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(Icons.check_circle_outline,
              size: 18, color: AppColors.success),
          tooltip: 'Confirm — track as a real task',
          onPressed: onConfirm,
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18, color: AppColors.textTertiary),
          tooltip: 'Not relevant',
          onPressed: onDismiss,
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.item,
    required this.onToggleDone,
    required this.onDelete,
    this.onDismiss,
  });
  final ActionItemModel item;
  final VoidCallback onToggleDone;
  final VoidCallback? onDismiss;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final done = item.status == ActionItemStatus.done;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: done ? AppColors.lightGreen.withValues(alpha: 0.4) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        GestureDetector(
          key: Key('task-checkbox-${item.id}'),
          onTap: onToggleDone,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: done ? AppColors.green : Colors.transparent,
              border: Border.all(
                  color: done ? AppColors.green : AppColors.textTertiary,
                  width: done ? 0 : 1.5),
              borderRadius: BorderRadius.circular(5),
            ),
            child: done
                ? const Icon(Icons.check, color: Colors.white, size: 13)
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.text,
                  style: TextStyle(
                      fontSize: 13,
                      color: done
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      decoration: done ? TextDecoration.lineThrough : null)),
              if (item.sourceType == 'correspondence')
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text('From correspondence',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.textTertiary)),
                ),
              if (item.dueDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                      'Due ${DateFormat('dd MMM yyyy').format(item.dueDate!)}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textTertiary)),
                ),
            ],
          ),
        ),
        if (onDismiss != null)
          IconButton(
            icon: const Icon(Icons.visibility_off_outlined,
                size: 16, color: AppColors.textTertiary),
            tooltip: 'Dismiss',
            onPressed: onDismiss,
            visualDensity: VisualDensity.compact,
          ),
        IconButton(
          icon: const Icon(Icons.delete_outline,
              size: 16, color: AppColors.error),
          tooltip: 'Delete',
          onPressed: onDelete,
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }
}
