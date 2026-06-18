// lib/features/survey/screens/damage_register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/damage_provider.dart';
import '../widgets/damage_item_card.dart';
import '../widgets/add_damage_item_sheet.dart';
import '../widgets/add_occurrence_sheet.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';

// ── Screen ─────────────────────────────────────────────────────────────────

class DamageRegisterScreen extends ConsumerWidget {
  const DamageRegisterScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final damageAsync = ref.watch(damageProvider(caseId));

    void showAddOccurrence() {
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

    void showAddDamageItem(String occurrenceId) {
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

    void showEditDamageItem(DamageItemModel item) {
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

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Damage Register'),
      ),
      floatingActionButton: damageAsync.when(
        data: (ds) => FloatingActionButton.extended(
          onPressed: () => ds.occurrences.isEmpty
              ? showAddOccurrence()
              : showAddDamageItem(ds.occurrences.first.occurrenceId),
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
            ? _EmptyState(onAdd: showAddOccurrence)
            : _DamageBody(
                caseId: caseId,
                ds: ds,
                onAddItem: showAddDamageItem,
                onEditItem: showEditDamageItem,
                onDeleteItem: (damageId) => ref
                    .read(damageProvider(caseId).notifier)
                    .deleteDamageItem(damageId),
                onAddOccurrence: showAddOccurrence,
              ),
      ),
    );
  }
}

// ── Damage body ────────────────────────────────────────────────────────────

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
        SliverToBoxAdapter(child: _SummaryBanner(ds: ds)),

        for (final occ in ds.occurrences) ...[
          SliverToBoxAdapter(
            child: _OccurrenceHeader(
              occurrence: occ,
              itemCount: ds.itemsForOccurrence(occ.occurrenceId).length,
              onAddItem: () => onAddItem(occ.occurrenceId),
            ),
          ),

          for (final cat in DamageCategory.values) ...[
            if (ds
                .itemsForOccurrenceAndCategory(occ.occurrenceId, cat)
                .isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _CategorySubHeader(
                  category: cat,
                  count: ds
                      .itemsForOccurrenceAndCategory(occ.occurrenceId, cat)
                      .length,
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final items = ds.itemsForOccurrenceAndCategory(
                        occ.occurrenceId, cat);
                    final item = items[i];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                      child: DamageItemCard(
                        item: item,
                        onEdit: () => onEditItem(item),
                        onDelete: () => _confirmDelete(ctx, item.damageId),
                      ),
                    );
                  },
                  childCount: ds
                      .itemsForOccurrenceAndCategory(occ.occurrenceId, cat)
                      .length,
                ),
              ),
            ],
          ],

          if (ds.itemsForOccurrence(occ.occurrenceId).isEmpty)
            SliverToBoxAdapter(
              child: _EmptyOccurrence(
                  onAdd: () => onAddItem(occ.occurrenceId)),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],

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
          _Stat("Owner's", ds.ownerItems.toString(), AppColors.amber),
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
      child: Column(children: [
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
      ]),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: AppColors.border);
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
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            margin: const EdgeInsets.only(top: 1),
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
                  occurrence.title ??
                      'Occurrence ${occurrence.occurrenceNo}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.coral),
                ),
                if (occurrence.dateTime != null)
                  Text(
                    _fmtDate(occurrence.dateTime!),
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.coral.withValues(alpha: 0.7)),
                  ),
                if (occurrence.location != null &&
                    occurrence.location!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.location_on_outlined,
                        size: 12,
                        color: AppColors.coral.withValues(alpha: 0.8)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        occurrence.location!,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.coral.withValues(alpha: 0.85),
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$itemCount item${itemCount == 1 ? '' : 's'}',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.coral.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onAddItem,
                child: const Icon(Icons.add_circle_outline,
                    color: AppColors.coral, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Category sub-header ────────────────────────────────────────────────────

class _CategorySubHeader extends StatelessWidget {
  const _CategorySubHeader({
    required this.category,
    required this.count,
  });

  final DamageCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = _color(category);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 3),
      child: Row(children: [
        Icon(_icon(category), size: 13, color: color),
        const SizedBox(width: 6),
        Text(
          category.label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          '($count)',
          style: TextStyle(
              fontSize: 10, color: color.withValues(alpha: 0.6)),
        ),
      ]),
    );
  }

  Color _color(DamageCategory cat) => switch (cat) {
        DamageCategory.structuralExternal    => AppColors.coral,
        DamageCategory.structuralInternal    => AppColors.navy,
        DamageCategory.mechanical            => AppColors.amber,
        DamageCategory.electricalElectronics => AppColors.purple,
        DamageCategory.other                 => AppColors.textSecondary,
      };

  IconData _icon(DamageCategory cat) => switch (cat) {
        DamageCategory.structuralExternal    => Icons.shield_outlined,
        DamageCategory.structuralInternal    => Icons.home_outlined,
        DamageCategory.mechanical            => Icons.settings_outlined,
        DamageCategory.electricalElectronics => Icons.bolt_outlined,
        DamageCategory.other                 => Icons.help_outline,
      };
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
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
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
