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
/// new period's id, or null if the user cancelled.
Future<String?> showQuickCreateRepairPeriodDialog(
  BuildContext context,
  WidgetRef ref, {
  required String caseId,
  required int nextPeriodNo,
}) async {
  final ctrl = TextEditingController(text: 'Repair Period $nextPeriodNo');
  final title = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('New Repair Period'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()),
        decoration: const InputDecoration(
          labelText: 'Title',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: AppColors.midBlue),
          child: const Text('Create'),
        ),
      ],
    ),
  );
  if (title == null || title.isEmpty) return null;

  final created = await ref.read(repairPeriodsProvider(caseId).notifier).addPeriod(
        RepairPeriodModel(
          periodId: '',
          caseId:   caseId,
          periodNo: nextPeriodNo,
          title:    title,
        ),
      );
  return created.periodId;
}
