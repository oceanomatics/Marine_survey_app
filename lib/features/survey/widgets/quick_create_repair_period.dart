// lib/features/survey/widgets/quick_create_repair_period.dart
//
// Minimal inline repair-period creation, reachable from a cue's repair-
// period picker rather than requiring a trip to the Repairs screen
// (docs/context_cue_system_review.md §3.1) — "the surveyor should be able
// to create a new repair period inline from the cue editor itself." Only
// asks for a title; dates/location/services are filled in later from the
// Repair Periods screen. `RepairPeriodModel` only strictly requires
// periodId/caseId/periodNo, so this is a safe minimal insert.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/repair_period_model.dart';
import '../providers/repair_period_provider.dart';
import '../../../shared/theme/app_theme.dart';

/// Shows a minimal "New Repair Period" dialog and creates it. Returns the
/// new period's id, or null if the user cancelled. Asks for a title and the
/// repair phase (preliminary / temporary / permanent) up front so a period
/// is routed to the right kind the moment it's created (23 July 2026 —
/// "when I create a new period I should be given the choice"), rather than
/// having to open the full editor afterwards to set it.
Future<String?> showQuickCreateRepairPeriodDialog(
  BuildContext context,
  WidgetRef ref, {
  required String caseId,
  required int nextPeriodNo,
}) async {
  final ctrl = TextEditingController(text: 'Repair Period $nextPeriodNo');
  RepairPhase? phase;
  final result = await showDialog<(String, RepairPhase?)>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('New Repair Period'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) =>
                  Navigator.pop(ctx, (ctrl.text.trim(), phase)),
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Repair phase',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: _PhaseChip(
                  label: 'Not set',
                  color: AppColors.textTertiary,
                  selected: phase == null,
                  onTap: () => setState(() => phase = null),
                ),
              ),
              ...RepairPhase.values.map((p) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _PhaseChip(
                        label: p.label,
                        color: AppColors.midBlue,
                        selected: phase == p,
                        onTap: () => setState(() => phase = p),
                      ),
                    ),
                  )),
            ]),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, (ctrl.text.trim(), phase)),
            style: FilledButton.styleFrom(backgroundColor: AppColors.midBlue),
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
  if (result == null || result.$1.isEmpty) return null;

  final created = await ref.read(repairPeriodsProvider(caseId).notifier).addPeriod(
        RepairPeriodModel(
          periodId:    '',
          caseId:      caseId,
          periodNo:    nextPeriodNo,
          title:       result.$1,
          repairPhase: result.$2,
        ),
      );
  return created.periodId;
}

/// Compact selectable phase chip used in the quick-create dialog.
class _PhaseChip extends StatelessWidget {
  const _PhaseChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
