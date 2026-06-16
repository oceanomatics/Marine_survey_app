// lib/features/survey/screens/damage_register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/damage_provider.dart';
import '../widgets/damage_item_card.dart';
import '../widgets/add_damage_item_sheet.dart';
import '../widgets/add_occurrence_sheet.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';

class DamageRegisterScreen extends ConsumerWidget {
  const DamageRegisterScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final damageAsync = ref.watch(damageProvider(caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Damage Register'),
      ),
      floatingActionButton: damageAsync.when(
        data: (ds) => FloatingActionButton.extended(
          onPressed: () => ds.occurrences.isEmpty
              ? _showAddOccurrence(context, ref)
              : _showAddDamageItem(context, ref,
                  ds.occurrences.first.occurrenceId),
          backgroundColor: AppColors.coral,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: Text(
            ds.occurrences.isEmpty ? 'Add Occurrence' : 'Add Damage Item',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        loading: () => null,
        error: (_, __) => null,
      ),
      body: damageAsync.when(
        loading: () =>
            const AppLoadingWidget(message: 'Loading damage register...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (ds) => ds.occurrences.isEmpty
            ? _EmptyState(
                onAdd: () => _showAddOccurrence(context, ref),
              )
            : _DamageBody(
                caseId: caseId,
                ds: ds,
                onAddItem: (occId) =>
                    _showAddDamageItem(context, ref, occId),
                onEditItem: (item) =>
                    _showEditDamageItem(context, ref, item),
                onDeleteItem: (damageId) => ref
                    .read(damageProvider(caseId).notifier)
                    .deleteDamageItem(damageId),
                onAddOccurrence: () => _showAddOccurrence(context, ref),
              ),
      ),
    );
  }

  void _showAddOccurrence(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddOccurrenceSheet(
        onSave: (title, dateTime, location, description) async {
          await ref.read(damageProvider(caseId).notifier).createOccurrence(
                caseId: caseId,
                title: title,
                dateTime: dateTime,
                location: location,
                briefDescription: description,
              );
        },
      ),
    );
  }

  void _showAddDamageItem(
      BuildContext context, WidgetRef ref, String occurrenceId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddDamageItemSheet(
        caseId: caseId,
        occurrenceId: occurrenceId,
        onSave: (item) async {
          await ref.read(damageProvider(caseId).notifier).addDamageItem(item);
        },
      ),
    );
  }

  void _showEditDamageItem(
      BuildContext context, WidgetRef ref, DamageItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddDamageItemSheet(
        caseId: caseId,
        occurrenceId: item.occurrenceId,
        existing: item,
        onSave: (updated) async {
          await ref
              .read(damageProvider(caseId).notifier)
              .updateDamageItem(updated);
        },
      ),
    );
  }
}

// ── Body with occurrence sections ──────────────────────────────────────────

class _DamageBody extends StatelessWidget {
  const _DamageBody({
    required this.caseId,
    required this.ds,
    required this.onAddItem,
    required this.onEditItem,
    required this.onDeleteItem,
    required this.onAddOccurrence,
  });

  final String caseId;
  final DamageState ds;
  final ValueChanged<String> onAddItem;
  final ValueChanged<DamageItemModel> onEditItem;
  final ValueChanged<String> onDeleteItem;
  final VoidCallback onAddOccurrence;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Summary banner ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: _SummaryBanner(ds: ds),
        ),

        // ── Occurrences and their damage items ───────────────────────
        for (final occ in ds.occurrences) ...[
          SliverToBoxAdapter(
            child: _OccurrenceHeader(
              occurrence: occ,
              itemCount: ds.itemsForOccurrence(occ.occurrenceId).length,
              onAddItem: () => onAddItem(occ.occurrenceId),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final items = ds.itemsForOccurrence(occ.occurrenceId);
                final item = items[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: DamageItemCard(
                    item: item,
                    onEdit: () => onEditItem(item),
                    onDelete: () => _confirmDelete(context, item.damageId),
                  ),
                );
              },
              childCount:
                  ds.itemsForOccurrence(occ.occurrenceId).length,
            ),
          ),
          // Empty occurrence
          if (ds.itemsForOccurrence(occ.occurrenceId).isEmpty)
            SliverToBoxAdapter(
              child: _EmptyOccurrence(
                  onAdd: () => onAddItem(occ.occurrenceId)),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],

        // ── Add another occurrence ───────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
            child: OutlinedButton.icon(
              onPressed: onAddOccurrence,
              icon: const Icon(Icons.add),
              label: const Text('Add Another Occurrence'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.coral,
                side: const BorderSide(color: AppColors.coral),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, String damageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete damage item?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDeleteItem(damageId);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Summary banner ─────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.ds});
  final DamageState ds;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _Stat('Occurrences', ds.occurrences.length.toString(),
              AppColors.navy),
          _Divider(),
          _Stat('Total Items', ds.totalDamageItems.toString(),
              AppColors.coral),
          _Divider(),
          _Stat('Avg. Items', ds.averageItems.toString(),
              AppColors.midBlue),
          _Divider(),
          _Stat("Owner's", ds.ownerItems.toString(),
              AppColors.amber),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 36, color: AppColors.border);
  }
}

// ── Occurrence header ──────────────────────────────────────────────────────

class _OccurrenceHeader extends StatelessWidget {
  const _OccurrenceHeader({
    required this.occurrence,
    required this.itemCount,
    required this.onAddItem,
  });

  final OccurrenceModel occurrence;
  final int itemCount;
  final VoidCallback onAddItem;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightCoral,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppColors.coral.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.coral,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text(
                occurrence.occurrenceNo.toString(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  occurrence.title ?? 'Occurrence ${occurrence.occurrenceNo}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.coral),
                ),
                if (occurrence.dateTime != null)
                  Text(
                    _formatDate(occurrence.dateTime!),
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.coral.withValues(alpha: 0.7)),
                  ),
              ],
            ),
          ),
          Text(
            '$itemCount item${itemCount == 1 ? '' : 's'}',
            style: TextStyle(
                fontSize: 11,
                color: AppColors.coral.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add_circle_outline,
                color: AppColors.coral, size: 20),
            onPressed: onAddItem,
            tooltip: 'Add damage item',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Empty states ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warning_amber_outlined,
              size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          const Text('No occurrences recorded',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text(
            'Add an occurrence to start recording\ndamage items',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Occurrence'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white),
          ),
        ]),
      ),
    );
  }
}

class _EmptyOccurrence extends StatelessWidget {
  const _EmptyOccurrence({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: OutlinedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add first damage item',
            style: TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
