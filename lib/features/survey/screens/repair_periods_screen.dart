// lib/features/survey/screens/repair_periods_screen.dart

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/damage_provider.dart';
import '../providers/repair_period_provider.dart';
import '../models/repair_period_model.dart';
import '../widgets/add_repair_period_sheet.dart';
import '../widgets/assign_repair_items_sheet.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/context_cues_panel.dart';
import '../../surveyor_notes/models/surveyor_note_model.dart';
import '../../surveyor_notes/providers/surveyor_notes_provider.dart';
import '../../../shared/widgets/back_app_bar.dart';
import '../../../shared/widgets/app_feedback.dart';

const _kRepairColor = Color(0xFF1A6B9E);
const _kTimesColor  = Color(0xFF0F766E);
const _kBudgetColor = Color(0xFF7B5EA7);
const _kSeaTrialColor = Color(0xFF0369A1);

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
    final damageAsync  = ref.watch(damageProvider(caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BackAppBar(
        title: Text('Repair Periods'),
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
            onEditPeriod: (period) => _showEditRepairPeriod(context, period),
            onDeletePeriod: (periodId) => ref
                .read(repairPeriodsProvider(caseId).notifier)
                .deletePeriod(periodId),
            onAssignItems: (period) =>
                _showAssignItems(context, period, ds),
            onPromoteCue: (note) => _promoteCue(context, note, periods),
          ),
        ),
      ),
    );
  }

  void _showAddRepairPeriod(BuildContext context, int existingCount,
      {SurveyorNote? sourceCue}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddRepairPeriodSheet(
        caseId: caseId,
        nextPeriodNo: existingCount + 1,
        sourceCue: sourceCue,
        onSave: (period) async {
          final saved = await ref
              .read(repairPeriodsProvider(caseId).notifier)
              .addPeriod(period);
          if (sourceCue != null) await _linkCueToPeriod(sourceCue, saved.periodId);
          if (context.mounted) showSavedToast(context);
          return saved;
        },
      ),
    );
  }

  void _showEditRepairPeriod(BuildContext context, RepairPeriodModel period,
      {SurveyorNote? sourceCue}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddRepairPeriodSheet(
        caseId: caseId,
        nextPeriodNo: period.periodNo,
        existing: period,
        sourceCue: sourceCue,
        onSave: (updated) async {
          await ref
              .read(repairPeriodsProvider(caseId).notifier)
              .updatePeriod(updated);
          if (sourceCue != null) {
            await _linkCueToPeriod(sourceCue, updated.periodId);
          }
          if (context.mounted) showSavedToast(context);
          return updated;
        },
      ),
    );
  }

  /// Re-tags [note] onto [periodId] via the same polymorphic
  /// linked_to_type/linked_to_id mechanism used for damage items/
  /// occurrences/machinery nameplates — no schema change. Unlike Damage
  /// Register's cue promotion, there's no single narrative field to
  /// append to here: a repair period's cues are just organised by period
  /// (the same scoping `ContextCuesPanel.periodScope` already provides),
  /// so "merge into existing" is just re-linking, not a text merge.
  Future<void> _linkCueToPeriod(SurveyorNote note, String periodId) =>
      ref.read(surveyorNotesProvider(caseId).notifier).editNote(
            note.id,
            content: note.content,
            natureOfContent: note.natureOfContent,
            evidentiaryWeight: note.evidentiaryWeight,
            origin: note.origin,
            caseSection: note.caseSection,
            priority: note.priority,
            linkedToType: repairPeriodLinkType,
            linkedToId: periodId,
          );

  // Row 17/§3.9: cue -> repair period promotion (create new, or merge into
  // an existing period), the same standing cue-action principle already
  // applied to Damage Register (§3.8), docs/context_cue_system_review.md.
  void _promoteCue(BuildContext context, SurveyorNote note,
      List<RepairPeriodModel> periods) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Promote Context Cue',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('"${note.content}"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.add_box_outlined, color: _kRepairColor),
              title: const Text('Create new repair period'),
              subtitle: const Text('Prefills notes from this cue',
                  style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showAddRepairPeriod(context, periods.length, sourceCue: note);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.merge_type_outlined, color: _kRepairColor),
              title: const Text('Merge into existing period'),
              subtitle: const Text('Links this cue to a chosen period',
                  style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickExistingPeriod(context, periods).then((picked) {
                  if (picked != null) {
                    _linkCueToPeriod(note, picked.periodId);
                    if (context.mounted) showSavedToast(context);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<RepairPeriodModel?> _pickExistingPeriod(
      BuildContext context, List<RepairPeriodModel> periods) {
    return showModalBottomSheet<RepairPeriodModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * 0.6),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Repair Period',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            if (periods.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No repair periods yet — create one instead.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: periods.length,
                  itemBuilder: (_, i) {
                    final p = periods[i];
                    return ListTile(
                      title: Text(p.displayTitle),
                      onTap: () => Navigator.pop(sheetCtx, p),
                    );
                  },
                ),
              ),
          ],
        ),
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
    required this.onEditPeriod,
    required this.onDeletePeriod,
    required this.onAssignItems,
    required this.onPromoteCue,
  });

  final String caseId;
  final List<RepairPeriodModel> periods;
  final DamageState ds;
  final VoidCallback onAddPeriod;
  final ValueChanged<RepairPeriodModel> onEditPeriod;
  final ValueChanged<String> onDeletePeriod;
  final ValueChanged<RepairPeriodModel> onAssignItems;
  final ValueChanged<SurveyorNote> onPromoteCue;

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) {
      // No periods exist yet, so every 'repairs'/'repairTimes' cue is
      // necessarily unallocated — same "not allocated to a period" bucket
      // semantics as WNCA/General Services & Access
      // (docs/context_cue_system_review.md §3.1/§3.2), now extended here
      // (docs/TODO.md §3.9).
      return Column(
        children: [
          Expanded(child: _EmptyRepairs(onAdd: onAddPeriod)),
          ContextCuesPanel(
              caseId: caseId,
              section: CaseSection.repairs,
              title: 'Repairs — Context Cues',
              periodScope: const RepairPeriodScope.unassigned(),
              onPromote: onPromoteCue),
          ContextCuesPanel(
              caseId: caseId,
              section: CaseSection.repairTimes,
              title: 'Repair Times — Context Cues',
              periodScope: const RepairPeriodScope.unassigned(),
              initiallyExpanded: false,
              onPromote: onPromoteCue),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: periods.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PeriodCard(
                caseId: caseId,
                period: periods[i],
                ds: ds,
                onDelete: () => _confirmDelete(context, periods[i]),
                onEdit: () => onEditPeriod(periods[i]),
                onAssign: () => onAssignItems(periods[i]),
              ),
            ),
          ),
        ),
        // Bucket for 'repairs'/'repairTimes' cues not tied to any specific
        // period — collapsed by default now that each period card carries
        // its own scoped panel below (the primary entry point once at
        // least one period exists).
        ContextCuesPanel(
            caseId: caseId,
            section: CaseSection.repairs,
            title: 'Repairs — Context Cues',
            periodScope: const RepairPeriodScope.unassigned(),
            initiallyExpanded: false,
            onPromote: onPromoteCue),
        ContextCuesPanel(
            caseId: caseId,
            section: CaseSection.repairTimes,
            title: 'Repair Times — Context Cues',
            periodScope: const RepairPeriodScope.unassigned(),
            initiallyExpanded: false,
            onPromote: onPromoteCue),
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

// ── Period card ────────────────────────────────────────────────────────────

class _PeriodCard extends ConsumerStatefulWidget {
  const _PeriodCard({
    required this.caseId,
    required this.period,
    required this.ds,
    required this.onDelete,
    required this.onEdit,
    required this.onAssign,
  });

  final String caseId;
  final RepairPeriodModel period;
  final DamageState ds;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onAssign;

  @override
  ConsumerState<_PeriodCard> createState() => _PeriodCardState();
}

class _PeriodCardState extends ConsumerState<_PeriodCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final period = widget.period;
    final df = DateFormat('dd/MM/yyyy');
    final dateStr = [
      if (period.startDate != null) df.format(period.startDate!),
      if (period.endDate   != null) df.format(period.endDate!),
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
          // ── Card header ──────────────────────────────────────────────
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
                      child: Text('${period.periodNo}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(period.displayTitle,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: contextColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                  color: contextColor.withValues(alpha: 0.3)),
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
                        if (period.repairPhase != null) ...[
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _kRepairColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                    color:
                                        _kRepairColor.withValues(alpha: 0.25)),
                              ),
                              child: Text(
                                period.repairPhase!.label,
                                style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: _kRepairColor,
                                    letterSpacing: 0.3),
                              ),
                            ),
                          ),
                        ],
                        if (dateStr.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.date_range_outlined,
                                size: 12, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(dateStr,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                            ),
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
                          if (v == 'edit') widget.onEdit();
                          if (v == 'delete') widget.onDelete();
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit_outlined,
                                    color: _kRepairColor, size: 16),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text('Edit period details',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13)),
                                ),
                              ])),
                          const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_outline,
                                    color: AppColors.error, size: 16),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text('Delete period',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: AppColors.error, fontSize: 13)),
                                ),
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

          // ── Expandable body ──────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, thickness: 0.5),

            // ── Assignments ──────────────────────────────────────────
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
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
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

            // ── Repair Times ─────────────────────────────────────────
            const Divider(height: 1, thickness: 0.5),
            _RepairTimesSection(
              period: period,
              occurrences: widget.ds.occurrences,
              onEditRow: (key, current) => _editRepairTimeRow(key, current),
            ),

            // ── Budget Estimate ──────────────────────────────────────
            const Divider(height: 1, thickness: 0.5),
            _BudgetSection(
              caseId: widget.caseId,
              period: period,
            ),

            // ── Post-repair sea trial ────────────────────────────────
            const Divider(height: 1, thickness: 0.5),
            _SeaTrialSection(
              caseId: widget.caseId,
              period: period,
            ),

            // ── Context cues, scoped to this specific period ──────────
            // Same two-level allocation mechanism already proven for
            // WNCA/General Services & Access (docs/context_cue_system_
            // review.md §3.1/§3.2), now extended to the Repair Periods
            // screen itself (docs/TODO.md §3.9) instead of the flat
            // case-wide panel this screen used to show only once at the
            // bottom, with no way to tell which period a cue related to.
            const Divider(height: 1, thickness: 0.5),
            ContextCuesPanel(
              caseId: widget.caseId,
              section: CaseSection.repairs,
              periodScope: RepairPeriodScope.forPeriod(period.periodId),
              initiallyExpanded: false,
            ),
            ContextCuesPanel(
              caseId: widget.caseId,
              section: CaseSection.repairTimes,
              periodScope: RepairPeriodScope.forPeriod(period.periodId),
              initiallyExpanded: false,
            ),
          ],
        ],
      ),
    );
  }

  // ── Repair time edit ────────────────────────────────────────────────────

  void _editRepairTimeRow(String key, RepairTimeEntry current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditRepairTimeSheet(
        rowLabel: _repairTimeLabel(key, widget.ds.occurrences),
        current: current,
        onSave: (entry) async {
          final updated = Map<String, RepairTimeEntry>.from(
              widget.period.repairTimes);
          if (entry.isEmpty) {
            updated.remove(key);
          } else {
            updated[key] = entry;
          }
          await ref
              .read(repairPeriodsProvider(widget.caseId).notifier)
              .saveRepairTimes(widget.period.periodId, updated);
        },
      ),
    );
  }

  String _repairTimeLabel(String key, List<OccurrenceModel> occs) {
    if (key == 'owners') return "Owner's Work";
    final no = int.tryParse(key.replaceFirst('occ_', ''));
    if (no == null) return key;
    final occ = occs.where((o) => o.occurrenceNo == no).firstOrNull;
    return occ?.title != null && occ!.title!.isNotEmpty
        ? 'Occ. $no — ${occ.title}'
        : 'Occurrence $no';
  }

}

// ── Repair Times section ──────────────────────────────────────────────────

class _RepairTimesSection extends StatelessWidget {
  const _RepairTimesSection({
    required this.period,
    required this.occurrences,
    required this.onEditRow,
  });

  final RepairPeriodModel period;
  final List<OccurrenceModel> occurrences;
  final void Function(String key, RepairTimeEntry current) onEditRow;

  @override
  Widget build(BuildContext context) {
    final sortedOccs = [...occurrences]
      ..sort((a, b) => a.occurrenceNo.compareTo(b.occurrenceNo));

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          const Row(children: [
            Icon(Icons.schedule_outlined,
                size: 13, color: _kTimesColor),
            SizedBox(width: 5),
            Text('REPAIR TIMES',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: _kTimesColor)),
          ]),
          const SizedBox(height: 8),

          // Table header
          Container(
            decoration: BoxDecoration(
              color: _kTimesColor.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            child: const Row(
              children: [
                Expanded(child: SizedBox()),
                _TableHeader('DRY-DOCK'),
                _TableHeader('ALONGSIDE'),
                SizedBox(width: 28),
              ],
            ),
          ),

          // Occurrence rows
          for (int i = 0; i < sortedOccs.length; i++) ...[
            _RepairTimeRow(
              label: _rowLabel(sortedOccs[i]),
              entry: period.repairTimes['occ_${sortedOccs[i].occurrenceNo}'] ??
                  const RepairTimeEntry(),
              isLast: false,
              isAlt: i.isOdd,
              onTap: () => onEditRow(
                'occ_${sortedOccs[i].occurrenceNo}',
                period.repairTimes['occ_${sortedOccs[i].occurrenceNo}'] ??
                    const RepairTimeEntry(),
              ),
            ),
          ],

          // Owner's Work row
          _RepairTimeRow(
            label: "Owner's Work",
            entry: period.repairTimes['owners'] ?? const RepairTimeEntry(),
            isLast: true,
            isAlt: sortedOccs.length.isOdd,
            onTap: () => onEditRow(
              'owners',
              period.repairTimes['owners'] ?? const RepairTimeEntry(),
            ),
          ),
        ],
      ),
    );
  }

  String _rowLabel(OccurrenceModel occ) {
    if (occ.title != null && occ.title!.isNotEmpty) {
      return 'Occ. ${occ.occurrenceNo} — ${occ.title}';
    }
    return 'Occurrence ${occ.occurrenceNo}';
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: _kTimesColor,
            letterSpacing: 0.5),
      ),
    );
  }
}

class _RepairTimeRow extends StatelessWidget {
  const _RepairTimeRow({
    required this.label,
    required this.entry,
    required this.isLast,
    required this.isAlt,
    required this.onTap,
  });

  final String label;
  final RepairTimeEntry entry;
  final bool isLast;
  final bool isAlt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isAlt
        ? _kTimesColor.withValues(alpha: 0.03)
        : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(6))
              : null,
          border: Border(
            left: BorderSide(
                color: _kTimesColor.withValues(alpha: 0.2), width: 0.5),
            right: BorderSide(
                color: _kTimesColor.withValues(alpha: 0.2), width: 0.5),
            bottom: BorderSide(
                color: _kTimesColor.withValues(alpha: 0.2), width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textPrimary)),
            ),
            _DayCell(entry.drydockDays),
            _DayCell(entry.alongsideDays),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.edit_outlined,
                  size: 13, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell(this.days);
  final double? days;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Text(
        days != null ? '${_fmt(days!)} d' : '—',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 12,
            fontWeight: days != null ? FontWeight.w600 : FontWeight.w400,
            color: days != null ? AppColors.textPrimary : AppColors.textTertiary),
      ),
    );
  }

  String _fmt(double d) =>
      d == d.truncateToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);
}

// ── Edit repair time sheet ─────────────────────────────────────────────────

class _EditRepairTimeSheet extends StatefulWidget {
  const _EditRepairTimeSheet({
    required this.rowLabel,
    required this.current,
    required this.onSave,
  });

  final String rowLabel;
  final RepairTimeEntry current;
  final Future<void> Function(RepairTimeEntry) onSave;

  @override
  State<_EditRepairTimeSheet> createState() => _EditRepairTimeSheetState();
}

class _EditRepairTimeSheetState extends State<_EditRepairTimeSheet> {
  late final TextEditingController _drydock;
  late final TextEditingController _alongside;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _drydock = TextEditingController(
        text: widget.current.drydockDays?.toString() ?? '');
    _alongside = TextEditingController(
        text: widget.current.alongsideDays?.toString() ?? '');
  }

  @override
  void dispose() {
    _drydock.dispose();
    _alongside.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text('Repair Times — ${widget.rowLabel}',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Enter number of days (decimals allowed)',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: _DaysField(
                    label: 'Dry-Dock Days',
                    controller: _drydock,
                    color: _kTimesColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DaysField(
                    label: 'Alongside Days',
                    controller: _alongside,
                    color: _kTimesColor),
              ),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _kTimesColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final entry = RepairTimeEntry(
        drydockDays: double.tryParse(_drydock.text.trim()),
        alongsideDays: double.tryParse(_alongside.text.trim()),
      );
      await widget.onSave(entry);
      if (mounted) {
        showSavedToast(context);
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _DaysField extends StatelessWidget {
  const _DaysField(
      {required this.label, required this.controller, required this.color});
  final String label;
  final TextEditingController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          decoration: InputDecoration(
            hintText: '0',
            hintStyle:
                const TextStyle(color: AppColors.textTertiary),
            suffixText: 'd',
            suffixStyle: TextStyle(
                color: color, fontWeight: FontWeight.w600),
            filled: true,
            fillColor: color.withValues(alpha: 0.05),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color.withValues(alpha: 0.3))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color.withValues(alpha: 0.3))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color, width: 1.5)),
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ── Budget Estimate section ────────────────────────────────────────────────

class _BudgetSection extends ConsumerStatefulWidget {
  const _BudgetSection({required this.caseId, required this.period});
  final String caseId;
  final RepairPeriodModel period;

  @override
  ConsumerState<_BudgetSection> createState() => _BudgetSectionState();
}

class _BudgetSectionState extends ConsumerState<_BudgetSection> {
  bool _fetchingRate = false;

  @override
  Widget build(BuildContext context) {
    final period = widget.period;
    final items  = period.budgetItems;
    final fmt    = NumberFormat('#,##0.00');

    // Sum per item currency — never blindly add mixed currencies into one
    // base-labelled total (that silently mislabels e.g. AUD items as USD).
    final byCcy = <String, double>{};
    for (final i in items) {
      byCcy[i.currency] = (byCcy[i.currency] ?? 0) + i.amount;
    }
    final baseCcy = period.budgetBaseCurrency;
    final totalBase = byCcy[baseCcy] ?? 0;
    final foreignTotals = byCcy.entries
        .where((e) => e.key != baseCcy)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final hasForeign = foreignTotals.isNotEmpty;
    // Only convert the base-currency portion to the display currency, and only
    // when there are no un-convertible foreign items muddying the total.
    final converted =
        (period.budgetExchangeRate != null && !_sameCurrency(period) && !hasForeign)
            ? totalBase * period.budgetExchangeRate!
            : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              const Icon(Icons.calculate_outlined,
                  size: 13, color: _kBudgetColor),
              const SizedBox(width: 5),
              const Expanded(
                child: Text('BUDGET ESTIMATE',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: _kBudgetColor)),
              ),
              GestureDetector(
                onTap: () => _showDisplaySettings(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kBudgetColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: _kBudgetColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.currency_exchange,
                          size: 11, color: _kBudgetColor),
                      const SizedBox(width: 3),
                      Text(
                        _sameCurrency(period)
                            ? period.budgetBaseCurrency
                            : '${period.budgetBaseCurrency} → ${period.budgetDisplayCurrency}',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _kBudgetColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (items.isEmpty)
            const Text(
              'No budget items yet. Tap + to add cost estimates for the underwriter.',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic),
            )
          else ...[
            // Table header
            Container(
              decoration: BoxDecoration(
                color: _kBudgetColor.withValues(alpha: 0.06),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
              ),
              padding:
                  const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
              child: const Row(
                children: [
                  Expanded(
                    child: Text('DESCRIPTION',
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: _kBudgetColor,
                            letterSpacing: 0.5)),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text('AMOUNT',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: _kBudgetColor,
                            letterSpacing: 0.5)),
                  ),
                  SizedBox(width: 26),
                ],
              ),
            ),

            // Item rows
            for (int i = 0; i < items.length; i++)
              _BudgetItemRow(
                item: items[i],
                isAlt: i.isOdd,
                isLast: i == items.length - 1,
                onTap: () => _editItem(items[i]),
                onDelete: () => ref
                    .read(repairPeriodsProvider(widget.caseId).notifier)
                    .removeBudgetItem(period.periodId, items[i].itemId),
              ),

            // Total row
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: _kBudgetColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border:
                    Border.all(color: _kBudgetColor.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(hasForeign ? 'TOTAL ($baseCcy)' : 'TOTAL',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _kBudgetColor)),
                      const Spacer(),
                      Text(
                        '$baseCcy ${fmt.format(totalBase)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kBudgetColor),
                      ),
                    ],
                  ),
                  // Foreign-currency items shown as their own subtotals — never
                  // folded into the base total without an FX rate.
                  for (final e in foreignTotals) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text('TOTAL (${e.key})',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange)),
                        const Spacer(),
                        Text('${e.key} ${fmt.format(e.value)}',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange)),
                      ],
                    ),
                  ],
                  if (hasForeign) ...[
                    const SizedBox(height: 3),
                    const Text(
                      'Mixed currencies — foreign items not converted. '
                      'Set an FX rate per currency to combine.',
                      style: TextStyle(
                          fontSize: 9,
                          fontStyle: FontStyle.italic,
                          color: Colors.orange),
                    ),
                  ],
                  if (!_sameCurrency(period)) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            period.budgetExchangeRate != null
                                ? '@ ${period.budgetExchangeRate!.toStringAsFixed(4)}'
                                    '${period.budgetRateDate != null ? ' — ${DateFormat('dd MMM yyyy').format(period.budgetRateDate!)}' : ''}'
                                : 'Exchange rate not set',
                            style: TextStyle(
                                fontSize: 10,
                                color: period.budgetExchangeRate != null
                                    ? AppColors.textSecondary
                                    : AppColors.textTertiary,
                                fontStyle: period.budgetExchangeRate == null
                                    ? FontStyle.italic
                                    : FontStyle.normal),
                          ),
                        ),
                        GestureDetector(
                          onTap: _fetchingRate ? null : () => _fetchRate(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _fetchingRate
                                  ? AppColors.border
                                  : _kBudgetColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: _fetchingRate
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: _kBudgetColor))
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.refresh,
                                          size: 11, color: _kBudgetColor),
                                      SizedBox(width: 3),
                                      Text('Fetch Rate',
                                          style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: _kBudgetColor)),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                    if (converted != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '≈ ${period.budgetDisplayCurrency} ${fmt.format(converted)}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _addItem(),
              icon: const Icon(Icons.add, size: 15),
              label: const Text('Add Budget Item'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kBudgetColor,
                side: const BorderSide(color: _kBudgetColor),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _sameCurrency(RepairPeriodModel p) =>
      p.budgetBaseCurrency == p.budgetDisplayCurrency;

  void _addItem() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BudgetItemSheet(
        defaultCurrency: widget.period.budgetBaseCurrency,
        onSave: (item) async {
          await ref
              .read(repairPeriodsProvider(widget.caseId).notifier)
              .addBudgetItem(widget.period.periodId, item);
        },
      ),
    );
  }

  void _editItem(BudgetItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BudgetItemSheet(
        existing: item,
        defaultCurrency: widget.period.budgetBaseCurrency,
        onSave: (updated) async {
          await ref
              .read(repairPeriodsProvider(widget.caseId).notifier)
              .updateBudgetItem(widget.period.periodId, updated);
        },
      ),
    );
  }

  void _showDisplaySettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BudgetDisplaySheet(
        period: widget.period,
        onSave: (base, display, rate, date) async {
          await ref
              .read(repairPeriodsProvider(widget.caseId).notifier)
              .saveBudgetDisplay(
                periodId: widget.period.periodId,
                displayCurrency: display,
                baseCurrency: base,
                exchangeRate: rate,
                rateDate: date,
              );
        },
      ),
    );
  }

  Future<void> _fetchRate() async {
    final base    = widget.period.budgetBaseCurrency;
    final display = widget.period.budgetDisplayCurrency;
    if (base == display) return;

    setState(() => _fetchingRate = true);
    try {
      final rate = await _fetchExchangeRate(base, display);
      if (rate != null && mounted) {
        await ref
            .read(repairPeriodsProvider(widget.caseId).notifier)
            .saveBudgetDisplay(
              periodId: widget.period.periodId,
              displayCurrency: display,
              baseCurrency: base,
              exchangeRate: rate,
              rateDate: DateTime.now(),
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Rate updated: 1 $base = ${rate.toStringAsFixed(4)} $display'),
            duration: const Duration(seconds: 3),
          ));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not fetch rate — check your connection.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _fetchingRate = false);
    }
  }
}

Future<double?> _fetchExchangeRate(String base, String display) async {
  try {
    final response = await Dio().get(
      'https://open.er-api.com/v6/latest/$base',
      options: Options(receiveTimeout: const Duration(seconds: 10)),
    );
    if (response.statusCode == 200) {
      final rates = (response.data as Map<String, dynamic>)['rates']
          as Map<String, dynamic>?;
      return (rates?[display] as num?)?.toDouble();
    }
  } catch (_) {}
  return null;
}

// ── Budget item row ────────────────────────────────────────────────────────

class _BudgetItemRow extends StatelessWidget {
  const _BudgetItemRow({
    required this.item,
    required this.isAlt,
    required this.isLast,
    required this.onTap,
    required this.onDelete,
  });

  final BudgetItem item;
  final bool isAlt;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(item.status);
    final fmt = NumberFormat('#,##0.00');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isAlt
              ? _kBudgetColor.withValues(alpha: 0.03)
              : Colors.white,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(6))
              : null,
          border: Border(
            left: BorderSide(
                color: _kBudgetColor.withValues(alpha: 0.2), width: 0.5),
            right: BorderSide(
                color: _kBudgetColor.withValues(alpha: 0.2), width: 0.5),
            bottom: BorderSide(
                color: _kBudgetColor.withValues(alpha: 0.2), width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.description,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(item.status.label,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ),
                  if (item.hasBreakdown) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${fmt.format(item.quantity)} ${item.unit ?? ''}'
                      ' @ ${fmt.format(item.unitRate)}'.trim(),
                      style: const TextStyle(
                          fontSize: 9.5,
                          color: AppColors.textTertiary,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmt.format(item.amount),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                Text(item.currency,
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textSecondary)),
              ],
            ),
            GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.close,
                    size: 14, color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(BudgetItemStatus s) => switch (s) {
        BudgetItemStatus.estimated => AppColors.warning,
        BudgetItemStatus.quoted    => AppColors.info,
        BudgetItemStatus.incurred  => AppColors.success,
      };
}

// ── Budget item add/edit sheet ─────────────────────────────────────────────

const _kCurrencies = [
  'USD', 'EUR', 'GBP', 'AUD', 'CAD', 'JPY', 'CHF',
  'NOK', 'DKK', 'SEK', 'SGD', 'HKD', 'NZD', 'CNY',
];

class _BudgetItemSheet extends StatefulWidget {
  const _BudgetItemSheet({
    this.existing,
    required this.defaultCurrency,
    required this.onSave,
  });

  final BudgetItem? existing;
  final String defaultCurrency;
  final Future<void> Function(BudgetItem) onSave;

  @override
  State<_BudgetItemSheet> createState() => _BudgetItemSheetState();
}

class _BudgetItemSheetState extends State<_BudgetItemSheet> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _rateCtrl;
  late String _currency;
  late BudgetItemStatus _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _amountCtrl = TextEditingController(
        text: e != null ? e.amount.toStringAsFixed(2) : '');
    _qtyCtrl = TextEditingController(text: _fmtNum(e?.quantity));
    _unitCtrl = TextEditingController(text: e?.unit ?? '');
    _rateCtrl = TextEditingController(text: _fmtNum(e?.unitRate));
    _currency = e?.currency ?? widget.defaultCurrency;
    _status   = e?.status ?? BudgetItemStatus.estimated;
    // Keep the amount in sync with qty × rate whenever either changes.
    _qtyCtrl.addListener(_recomputeAmount);
    _rateCtrl.addListener(_recomputeAmount);
  }

  static String _fmtNum(double? v) {
    if (v == null) return '';
    // Drop trailing .0 for whole numbers so "5" not "5.0".
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  }

  void _recomputeAmount() {
    final qty = double.tryParse(_qtyCtrl.text.trim());
    final rate = double.tryParse(_rateCtrl.text.trim());
    if (qty != null && rate != null) {
      final computed = qty * rate;
      final text = computed.toStringAsFixed(2);
      if (_amountCtrl.text != text) _amountCtrl.text = text;
    }
  }

  @override
  void dispose() {
    _qtyCtrl.removeListener(_recomputeAmount);
    _rateCtrl.removeListener(_recomputeAmount);
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(RepairCostPreset preset) {
    setState(() {
      _descCtrl.text = preset.description;
      _unitCtrl.text = preset.unit;
      _qtyCtrl.text = _fmtNum(preset.defaultQuantity);
      _rateCtrl.text = _fmtNum(preset.typicalRate);
    });
    _recomputeAmount();
  }

  Future<void> _pickPreset() async {
    final preset = await showModalBottomSheet<RepairCostPreset>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CostPresetPickerSheet(),
    );
    if (preset != null) _applyPreset(preset);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Text(isNew ? 'Add Budget Item' : 'Edit Budget Item',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.5),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    // Cost preset shortcut — pre-fills description, unit and a
                    // typical rate; everything stays editable afterward.
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickPreset,
                        icon: const Icon(Icons.list_alt_outlined, size: 16),
                        label: const Text('Choose from cost presets'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kBudgetColor,
                          side: const BorderSide(color: _kBudgetColor),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _sheetLabel('Description'),
                    TextField(
                      controller: _descCtrl,
                      minLines: 1,
                      maxLines: 3,
                      decoration: _sheetDec(hint: 'e.g. Hull plating repairs'),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 14),

                    // Quantity × unit rate — optional breakdown. When both are
                    // filled, Amount auto-computes but stays editable.
                    _sheetLabel('Quantity × rate (optional)'),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*')),
                          ],
                          decoration: _sheetDec(hint: 'Qty'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _unitCtrl,
                          decoration: _sheetDec(hint: 'unit'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('@',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textTertiary)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _rateCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*')),
                          ],
                          decoration: _sheetDec(hint: 'rate'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    _sheetLabel('Amount'),
                    Row(children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*')),
                          ],
                          decoration:
                              _sheetDec(hint: '0.00'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _kCurrencies.contains(_currency)
                              ? _currency
                              : _kCurrencies.first,
                          decoration: _sheetDec(),
                          items: _kCurrencies
                              .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c,
                                      style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _currency = v ?? _currency),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    _sheetLabel('Status'),
                    Wrap(
                      spacing: 8,
                      children: BudgetItemStatus.values.map((s) {
                        final selected = _status == s;
                        final color = _statusColor(s);
                        return GestureDetector(
                          onTap: () => setState(() => _status = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? color
                                  : color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: color.withValues(
                                      alpha: selected ? 1.0 : 0.3)),
                            ),
                            child: Text(s.label,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: selected ? Colors.white : color)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kBudgetColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(isNew ? 'Add Item' : 'Save Changes',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(BudgetItemStatus s) => switch (s) {
        BudgetItemStatus.estimated => AppColors.warning,
        BudgetItemStatus.quoted    => AppColors.info,
        BudgetItemStatus.incurred  => AppColors.success,
      };

  Widget _sheetLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      );

  InputDecoration _sheetDec({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
      );

  Future<void> _save() async {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) return;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final qty = double.tryParse(_qtyCtrl.text.trim());
    final rate = double.tryParse(_rateCtrl.text.trim());
    final unit = _unitCtrl.text.trim();
    setState(() => _saving = true);
    try {
      final item = BudgetItem(
        itemId: widget.existing?.itemId ?? '',
        description: desc,
        amount: amount,
        currency: _currency,
        status: _status,
        quantity: qty,
        unit: unit.isEmpty ? null : unit,
        unitRate: rate,
      );
      await widget.onSave(item);
      if (mounted) {
        showSavedToast(context);
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Cost preset picker ──────────────────────────────────────────────────────
//
// Starter catalogue so the surveyor can pick a common cost line rather than
// typing every one from scratch (16 July 2026 sweep). Returns the chosen
// [RepairCostPreset]; the caller pre-fills the item sheet, all fields editable.

class _CostPresetPickerSheet extends StatelessWidget {
  const _CostPresetPickerSheet();

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.##');
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Cost Presets',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Pick a line to add — rates are indicative (USD) and every '
                'field stays editable once added.',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic),
              ),
            ),
            const Divider(height: 1, thickness: 0.5),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  for (final group in CostPresetGroup.values) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                      child: Text(group.label.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: _kBudgetColor)),
                    ),
                    for (final p in kRepairCostPresets
                        .where((e) => e.group == group))
                      InkWell(
                        onTap: () => Navigator.pop(context, p),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _kBudgetColor.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    _kBudgetColor.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(p.description,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text(
                                      p.typicalRate != null
                                          ? 'per ${p.unit} · ~USD ${fmt.format(p.typicalRate)}'
                                          : 'per ${p.unit} · quote',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.add_circle_outline,
                                  size: 18, color: _kBudgetColor),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Budget display / currency settings sheet ───────────────────────────────

class _BudgetDisplaySheet extends StatefulWidget {
  const _BudgetDisplaySheet({required this.period, required this.onSave});

  final RepairPeriodModel period;
  final Future<void> Function(
      String base, String display, double? rate, DateTime? date) onSave;

  @override
  State<_BudgetDisplaySheet> createState() => _BudgetDisplaySheetState();
}

class _BudgetDisplaySheetState extends State<_BudgetDisplaySheet> {
  late String _base;
  late String _display;
  late final TextEditingController _rateCtrl;
  DateTime? _rateDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _base    = widget.period.budgetBaseCurrency;
    _display = widget.period.budgetDisplayCurrency;
    _rateCtrl = TextEditingController(
        text: widget.period.budgetExchangeRate?.toStringAsFixed(4) ?? '');
    _rateDate = widget.period.budgetRateDate;
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Currency & Exchange Rate',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            // Base currency
            Row(children: [
              Expanded(
                child: _currencyDropdown(
                    label: 'Input Currency', value: _base,
                    onChanged: (v) => setState(() => _base = v!)),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward,
                      size: 18, color: AppColors.textTertiary),
                ),
              ),
              Expanded(
                child: _currencyDropdown(
                    label: 'Display Currency', value: _display,
                    onChanged: (v) => setState(() => _display = v!)),
              ),
            ]),
            const SizedBox(height: 14),

            if (_base != _display) ...[
              // Rate field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Exchange Rate (1 $_base = ? $_display)',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _rateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: InputDecoration(
                      hintText: '1.0000',
                      hintStyle: const TextStyle(
                          color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Rate date
              GestureDetector(
                onTap: () => _pickDate(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _rateDate != null
                        ? _kBudgetColor.withValues(alpha: 0.05)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _rateDate != null
                          ? _kBudgetColor.withValues(alpha: 0.4)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 14,
                          color: _rateDate != null
                              ? _kBudgetColor
                              : AppColors.textTertiary),
                      const SizedBox(width: 8),
                      Text(
                        _rateDate != null
                            ? 'Rate Date: ${DateFormat('dd MMM yyyy').format(_rateDate!)}'
                            : 'Select Rate Date',
                        style: TextStyle(
                            fontSize: 13,
                            color: _rateDate != null
                                ? AppColors.textPrimary
                                : AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ] else
              const SizedBox(height: 6),

            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _kBudgetColor,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 12)),
                  child: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _currencyDropdown({
    required String label,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _kCurrencies.contains(value) ? value : _kCurrencies.first,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border)),
          ),
          items: _kCurrencies
              .map((c) => DropdownMenuItem(
                  value: c,
                  child:
                      Text(c, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _rateDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
    );
    if (picked != null) setState(() => _rateDate = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final rate = double.tryParse(_rateCtrl.text.trim());
      await widget.onSave(_base, _display, rate, _rateDate);
      if (mounted) {
        showSavedToast(context);
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Assignment sub-widgets ─────────────────────────────────────────────────

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
    final color  = _outcomeColor(assignment.outcome);
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isOwners ? 0.05 : 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color:
                        color.withValues(alpha: isOwners ? 0.15 : 0.3)),
              ),
              child: Text(
                assignment.outcome.label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color:
                        color.withValues(alpha: isOwners ? 0.5 : 1.0)),
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

// ── Post-repair sea trial section ────────────────────────────────────────────
//
// Records the confirmation that repairs performed as intended (16 July 2026
// sweep — surveyor: "we have not managed a post repair seatrial entry").
// One optional record per repair period.

class _SeaTrialSection extends ConsumerWidget {
  const _SeaTrialSection({required this.caseId, required this.period});
  final String caseId;
  final RepairPeriodModel period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trial = period.seaTrial;
    final hasTrial = trial != null && !trial.isEmpty;
    final df = DateFormat('dd MMM yyyy');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sailing_outlined,
                  size: 13, color: _kSeaTrialColor),
              const SizedBox(width: 5),
              const Expanded(
                child: Text('POST-REPAIR SEA TRIAL',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: _kSeaTrialColor)),
              ),
              if (hasTrial)
                _SeaTrialOutcomeBadge(satisfactory: trial.satisfactory),
            ],
          ),
          const SizedBox(height: 10),
          if (!hasTrial)
            const Text(
              'No sea trial recorded yet. Add one to log the post-repair '
              'trial: date, duration, parameters observed and outcome.',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kSeaTrialColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: _kSeaTrialColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      if (trial.date != null)
                        _SeaTrialFact(
                            icon: Icons.event_outlined,
                            text: df.format(trial.date!)),
                      if (trial.durationHours != null)
                        _SeaTrialFact(
                            icon: Icons.schedule_outlined,
                            text:
                                '${_fmtHours(trial.durationHours!)} h'),
                      if (trial.location != null &&
                          trial.location!.isNotEmpty)
                        _SeaTrialFact(
                            icon: Icons.location_on_outlined,
                            text: trial.location!),
                    ],
                  ),
                  if (trial.parameters.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in trial.parameters)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: _kSeaTrialColor
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Text.rich(TextSpan(children: [
                              TextSpan(
                                  text: '${p.label}: ',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                              TextSpan(
                                  text: p.value,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)),
                            ])),
                          ),
                      ],
                    ),
                  ],
                  if (trial.notes != null && trial.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(trial.notes!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4)),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _edit(context, ref),
              icon: Icon(hasTrial ? Icons.edit_outlined : Icons.add, size: 15),
              label: Text(hasTrial ? 'Edit Sea Trial' : 'Add Sea Trial'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kSeaTrialColor,
                side: const BorderSide(color: _kSeaTrialColor),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _edit(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SeaTrialSheet(
        existing: period.seaTrial,
        onSave: (trial) => ref
            .read(repairPeriodsProvider(caseId).notifier)
            .saveSeaTrial(period.periodId, trial),
      ),
    );
  }

  static String _fmtHours(double h) =>
      h == h.roundToDouble() ? h.toStringAsFixed(0) : h.toString();
}

class _SeaTrialOutcomeBadge extends StatelessWidget {
  const _SeaTrialOutcomeBadge({required this.satisfactory});
  final bool? satisfactory;

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (satisfactory) {
      true => (AppColors.success, 'Satisfactory', Icons.check_circle_outline),
      false => (AppColors.error, 'Not satisfactory', Icons.cancel_outlined),
      null => (AppColors.textTertiary, 'Not assessed', Icons.help_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _SeaTrialFact extends StatelessWidget {
  const _SeaTrialFact({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _kSeaTrialColor),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textPrimary)),
        ],
      );
}

// ── Sea trial add/edit sheet ─────────────────────────────────────────────────

class _SeaTrialSheet extends StatefulWidget {
  const _SeaTrialSheet({required this.existing, required this.onSave});
  final SeaTrial? existing;
  final Future<void> Function(SeaTrial?) onSave;

  @override
  State<_SeaTrialSheet> createState() => _SeaTrialSheetState();
}

class _ParamRow {
  _ParamRow({String label = '', String value = ''})
      : labelCtrl = TextEditingController(text: label),
        valueCtrl = TextEditingController(text: value);
  final TextEditingController labelCtrl;
  final TextEditingController valueCtrl;
  void dispose() {
    labelCtrl.dispose();
    valueCtrl.dispose();
  }
}

class _SeaTrialSheetState extends State<_SeaTrialSheet> {
  DateTime? _date;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _notesCtrl;
  final List<_ParamRow> _params = [];
  bool? _satisfactory;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.date;
    _durationCtrl = TextEditingController(
        text: e?.durationHours != null
            ? _SeaTrialSection._fmtHours(e!.durationHours!)
            : '');
    _locationCtrl = TextEditingController(text: e?.location ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _satisfactory = e?.satisfactory;
    for (final p in e?.parameters ?? const <SeaTrialParameter>[]) {
      _params.add(_ParamRow(label: p.label, value: p.value));
    }
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    for (final p in _params) {
      p.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null || widget.existing!.isEmpty;
    final df = DateFormat('dd MMM yyyy');
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Text(isNew ? 'Add Sea Trial' : 'Edit Sea Trial',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.5),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    _label('Date'),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(children: [
                          const Icon(Icons.event_outlined,
                              size: 16, color: _kSeaTrialColor),
                          const SizedBox(width: 8),
                          Text(
                            _date != null ? df.format(_date!) : 'Select date',
                            style: TextStyle(
                                fontSize: 13,
                                color: _date != null
                                    ? AppColors.textPrimary
                                    : AppColors.textTertiary),
                          ),
                          const Spacer(),
                          if (_date != null)
                            GestureDetector(
                              onTap: () => setState(() => _date = null),
                              child: const Icon(Icons.close,
                                  size: 15, color: AppColors.textTertiary),
                            ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Duration (hours)'),
                            TextField(
                              controller: _durationCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*')),
                              ],
                              decoration: _dec(hint: 'e.g. 3.5'),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Location'),
                            TextField(
                              controller: _locationCtrl,
                              decoration:
                                  _dec(hint: 'e.g. Off Fremantle'),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    _label('Parameters observed'),
                    for (int i = 0; i < _params.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _params[i].labelCtrl,
                              decoration: _dec(hint: 'Parameter'),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _params[i].valueCtrl,
                              decoration: _dec(hint: 'Value'),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() {
                              _params.removeAt(i).dispose();
                            }),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.close,
                                  size: 16, color: AppColors.textTertiary),
                            ),
                          ),
                        ]),
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final preset in kSeaTrialParameterPresets)
                          GestureDetector(
                            onTap: () => setState(
                                () => _params.add(_ParamRow(label: preset))),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color:
                                    _kSeaTrialColor.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: _kSeaTrialColor
                                        .withValues(alpha: 0.25)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.add,
                                    size: 12, color: _kSeaTrialColor),
                                const SizedBox(width: 3),
                                Text(preset,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: _kSeaTrialColor,
                                        fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _params.add(_ParamRow())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add,
                                      size: 12,
                                      color: AppColors.textSecondary),
                                  SizedBox(width: 3),
                                  Text('Custom',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600)),
                                ]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _label('Outcome'),
                    Row(
                      children: [
                        _outcomeChip(true, 'Satisfactory',
                            Icons.check_circle_outline, AppColors.success),
                        const SizedBox(width: 8),
                        _outcomeChip(false, 'Not satisfactory',
                            Icons.cancel_outlined, AppColors.error),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _label('Notes'),
                    TextField(
                      controller: _notesCtrl,
                      minLines: 2,
                      maxLines: 5,
                      decoration: _dec(
                          hint:
                              'Observations, machinery behaviour, defects found…'),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    Row(children: [
                      if (!isNew)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : _clear,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side:
                                  const BorderSide(color: AppColors.error),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: const Text('Delete'),
                          ),
                        ),
                      if (!isNew) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kSeaTrialColor,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(isNew ? 'Add Sea Trial' : 'Save Changes',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _outcomeChip(bool value, String label, IconData icon, Color color) {
    final selected = _satisfactory == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(
            () => _satisfactory = selected ? null : value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: color.withValues(alpha: selected ? 1.0 : 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15, color: selected ? Colors.white : color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      );

  InputDecoration _dec({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
      );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _date = picked);
  }

  SeaTrial _collect() {
    final params = <SeaTrialParameter>[];
    for (final p in _params) {
      final label = p.labelCtrl.text.trim();
      final value = p.valueCtrl.text.trim();
      if (label.isEmpty && value.isEmpty) continue;
      params.add(SeaTrialParameter(label: label, value: value));
    }
    final loc = _locationCtrl.text.trim();
    final notes = _notesCtrl.text.trim();
    return SeaTrial(
      date: _date,
      durationHours: double.tryParse(_durationCtrl.text.trim()),
      location: loc.isEmpty ? null : loc,
      parameters: params,
      satisfactory: _satisfactory,
      notes: notes.isEmpty ? null : notes,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final trial = _collect();
      await widget.onSave(trial.isEmpty ? null : trial);
      if (mounted) {
        showSavedToast(context);
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(null);
      if (mounted) {
        showSavedToast(context);
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
