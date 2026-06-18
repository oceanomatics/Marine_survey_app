// lib/features/survey/screens/repair_periods_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/damage_provider.dart';
import '../providers/repair_period_provider.dart';
import '../models/repair_period_model.dart';
import '../widgets/add_repair_period_sheet.dart';
import '../widgets/assign_repair_items_sheet.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';

const _kRepairColor = Color(0xFF1A6B9E);

// ── Screen ─────────────────────────────────────────────────────────────────

class RepairPeriodsScreen extends ConsumerStatefulWidget {
  const RepairPeriodsScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<RepairPeriodsScreen> createState() =>
      _RepairPeriodsScreenState();
}

class _RepairPeriodsScreenState extends ConsumerState<RepairPeriodsScreen> {
  String get caseId => widget.caseId;

  @override
  Widget build(BuildContext context) {
    final repairsAsync = ref.watch(repairPeriodsProvider(caseId));
    final damageAsync = ref.watch(damageProvider(caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Repair Periods'),
        backgroundColor: _kRepairColor,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _showAddRepairPeriod(context, repairsAsync.value?.length ?? 0),
        backgroundColor: _kRepairColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Repair Period',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: repairsAsync.when(
        loading: () =>
            const AppLoadingWidget(message: 'Loading repair periods...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (periods) => damageAsync.when(
          loading: () =>
              const AppLoadingWidget(message: 'Loading damage items...'),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (ds) => _RepairPeriodsBody(
            caseId: caseId,
            periods: periods,
            ds: ds,
            onAddPeriod: () =>
                _showAddRepairPeriod(context, periods.length),
            onDeletePeriod: (periodId) => ref
                .read(repairPeriodsProvider(caseId).notifier)
                .deletePeriod(periodId),
            onAssignItems: (period) =>
                _showAssignItems(context, period, ds),
          ),
        ),
      ),
    );
  }

  void _showAddRepairPeriod(BuildContext context, int existingCount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddRepairPeriodSheet(
        caseId: caseId,
        nextPeriodNo: existingCount + 1,
        onSave: (period) async {
          await ref
              .read(repairPeriodsProvider(caseId).notifier)
              .addPeriod(period);
        },
      ),
    );
  }

  void _showAssignItems(
      BuildContext context, RepairPeriodModel period, DamageState ds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssignRepairItemsSheet(
        period: period,
        ds: ds,
        onSave: (outcomes, concerning, notes) async {
          await ref
              .read(repairPeriodsProvider(caseId).notifier)
              .saveAssignments(period.periodId, outcomes, concerning, notes);
          ref.invalidate(damageProvider(caseId));
        },
      ),
    );
  }
}

// ── Body ───────────────────────────────────────────────────────────────────

class _RepairPeriodsBody extends StatelessWidget {
  const _RepairPeriodsBody({
    required this.caseId,
    required this.periods,
    required this.ds,
    required this.onAddPeriod,
    required this.onDeletePeriod,
    required this.onAssignItems,
  });

  final String caseId;
  final List<RepairPeriodModel> periods;
  final DamageState ds;
  final VoidCallback onAddPeriod;
  final ValueChanged<String> onDeletePeriod;
  final ValueChanged<RepairPeriodModel> onAssignItems;

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) {
      return _EmptyRepairs(onAdd: onAddPeriod);
    }

    final totalAssigned = periods
        .expand((p) => p.assignments)
        .map((a) => a.damageId)
        .toSet()
        .length;
    final totalItems = ds.totalDamageItems;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _RepairSummaryBanner(
            periods: periods.length,
            assignedItems: totalAssigned,
            totalItems: totalItems,
          ),
        ),
        for (final period in periods)
          SliverToBoxAdapter(
            child: _PeriodCard(
              period: period,
              ds: ds,
              onDelete: () => _confirmDelete(context, period),
              onAssign: () => onAssignItems(period),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  void _confirmDelete(BuildContext context, RepairPeriodModel period) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${period.displayTitle}"?'),
        content: const Text(
            'All item assignments within this period will be removed. '
            'Damage item status labels will not be reset automatically.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDeletePeriod(period.periodId);
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

class _RepairSummaryBanner extends StatelessWidget {
  const _RepairSummaryBanner({
    required this.periods,
    required this.assignedItems,
    required this.totalItems,
  });

  final int periods;
  final int assignedItems;
  final int totalItems;

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
          _RStat('Periods', '$periods', _kRepairColor),
          _RDivider(),
          _RStat('Items Assigned', '$assignedItems', AppColors.success),
          _RDivider(),
          _RStat('Total Items', '$totalItems', AppColors.coral),
        ],
      ),
    );
  }
}

class _RStat extends StatelessWidget {
  const _RStat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _RDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: AppColors.border);
}

// ── Period card ────────────────────────────────────────────────────────────

class _PeriodCard extends StatefulWidget {
  const _PeriodCard({
    required this.period,
    required this.ds,
    required this.onDelete,
    required this.onAssign,
  });

  final RepairPeriodModel period;
  final DamageState ds;
  final VoidCallback onDelete;
  final VoidCallback onAssign;

  @override
  State<_PeriodCard> createState() => _PeriodCardState();
}

class _PeriodCardState extends State<_PeriodCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final period = widget.period;
    final df = DateFormat('dd/MM/yyyy');
    final dateStr = [
      if (period.startDate != null) df.format(period.startDate!),
      if (period.endDate != null) df.format(period.endDate!),
    ].join(' → ');

    final contextColor = period.portContext == PortContext.planned
        ? AppColors.success
        : AppColors.warning;
    final contextIcon = period.portContext == PortContext.planned
        ? Icons.anchor_outlined
        : Icons.alt_route_outlined;

    final grouped = <DamageCategory, List<RepairAssignmentModel>>{};
    for (final a in period.assignments) {
      final item = widget.ds.damageItems
          .where((d) => d.damageId == a.damageId)
          .firstOrNull;
      if (item != null) {
        grouped.putIfAbsent(item.damageCategory, () => []).add(a);
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // ── Card header ────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: _kRepairColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${period.periodNo}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              period.displayTitle,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: contextColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                  color:
                                      contextColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(contextIcon,
                                    size: 11, color: contextColor),
                                const SizedBox(width: 3),
                                Text(
                                  period.portContext == PortContext.planned
                                      ? 'Planned'
                                      : 'Diversion',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: contextColor),
                                ),
                              ],
                            ),
                          ),
                        ]),
                        if (dateStr.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.date_range_outlined,
                                size: 12, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Text(dateStr,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ]),
                        ],
                        if (period.location != null &&
                            period.location!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.location_on_outlined,
                                size: 12, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(period.location!,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontStyle: FontStyle.italic)),
                            ),
                          ]),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert,
                            size: 18, color: AppColors.textTertiary),
                        onSelected: (v) {
                          if (v == 'delete') widget.onDelete();
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_outline,
                                    color: AppColors.error, size: 16),
                                SizedBox(width: 8),
                                Text('Delete period',
                                    style: TextStyle(
                                        color: AppColors.error,
                                        fontSize: 13)),
                              ])),
                        ],
                      ),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Assignments (expandable) ──────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, thickness: 0.5, indent: 12),
            if (period.assignments.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Row(children: [
                  Icon(Icons.info_outline,
                      size: 14, color: AppColors.textTertiary),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'No damage items assigned yet. '
                      'Tap "Assign Items" to link items to this period.',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                ]),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final cat in DamageCategory.values) ...[
                      if ((grouped[cat] ?? []).isNotEmpty) ...[
                        _AssignmentCategoryHeader(cat: cat),
                        for (final a in grouped[cat]!)
                          _AssignmentRow(
                            assignment: a,
                            item: widget.ds.damageItems
                                .where((d) => d.damageId == a.damageId)
                                .firstOrNull,
                          ),
                      ],
                    ],
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onAssign,
                  icon: const Icon(Icons.checklist, size: 16),
                  label: Text(period.assignments.isEmpty
                      ? 'Assign Damage Items'
                      : 'Edit Assignments (${period.assignments.length})'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kRepairColor,
                    side: const BorderSide(color: _kRepairColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AssignmentCategoryHeader extends StatelessWidget {
  const _AssignmentCategoryHeader({required this.cat});
  final DamageCategory cat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Text(
        cat.label.toUpperCase(),
        style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textTertiary),
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({required this.assignment, required this.item});
  final RepairAssignmentModel assignment;
  final DamageItemModel? item;

  @override
  Widget build(BuildContext context) {
    final color = _outcomeColor(assignment.outcome);
    final isOwners = !assignment.isConcerningAverage;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 6, height: 6,
              margin: const EdgeInsets.only(right: 8, top: 1),
              decoration: BoxDecoration(
                color: isOwners ? AppColors.textTertiary : color,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                item?.componentName ?? assignment.damageId.substring(0, 8),
                style: TextStyle(
                    fontSize: 12,
                    color: isOwners
                        ? AppColors.textSecondary
                        : AppColors.textPrimary),
              ),
            ),
            if (isOwners) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text("Owner's A/c",
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
              ),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isOwners ? 0.05 : 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: color.withValues(alpha: isOwners ? 0.15 : 0.3)),
              ),
              child: Text(
                assignment.outcome.label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: isOwners ? 0.5 : 1.0)),
              ),
            ),
          ]),
          if (assignment.notes != null && assignment.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 2, bottom: 1),
              child: Text(
                assignment.notes!,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Color _outcomeColor(RepairType rt) => switch (rt) {
        RepairType.temporary => AppColors.warning,
        RepairType.permanent => AppColors.success,
        RepairType.deferred  => AppColors.textSecondary,
      };
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyRepairs extends StatelessWidget {
  const _EmptyRepairs({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _kRepairColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.build_circle_outlined,
                color: _kRepairColor, size: 36),
          ),
          const SizedBox(height: 18),
          const Text('No repair periods yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Repair periods group together the work done during a '
            'single repair episode — whether a planned port call or '
            'an emergency diversion.\n\n'
            'Tap + to add your first repair period.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Repair Period'),
            style: ElevatedButton.styleFrom(
                backgroundColor: _kRepairColor,
                foregroundColor: Colors.white),
          ),
        ]),
      ),
    );
  }
}
