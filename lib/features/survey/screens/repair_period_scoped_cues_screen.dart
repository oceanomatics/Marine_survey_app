// lib/features/survey/screens/repair_period_scoped_cues_screen.dart
//
// Shared standalone screen for case sections whose cues are scoped to a
// specific repair period (docs/context_cue_system_review.md §3.1/§3.2) —
// Work Not Concerning Average and General Services & Access. Shows an
// "Unassigned" register (cues not yet linked to a period) plus one register
// per existing repair period, and a quick-create shortcut so a period can
// be added inline without leaving this screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/repair_period_model.dart';
import '../providers/repair_period_provider.dart';
import '../widgets/quick_create_repair_period.dart';
import '../../surveyor_notes/models/surveyor_note_model.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/context_cues_panel.dart';

class RepairPeriodScopedCuesScreen extends ConsumerWidget {
  const RepairPeriodScopedCuesScreen({
    super.key,
    required this.caseId,
    required this.section,
    required this.title,
    this.noPeriodsHint,
  });

  final String caseId;
  final CaseSection section;
  final String title;
  /// Shown above the "+ New Repair Period" prompt when no periods exist yet.
  final String? noPeriodsHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodsAsync = ref.watch(repairPeriodsProvider(caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(title)),
      body: periodsAsync.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (periods) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CueSectionCard(
              title: 'Not Allocated to a Period',
              hint: 'Cues not yet tied to a specific repair period.',
              child: ContextCuesPanel(
                caseId: caseId,
                section: section,
                periodScope: const RepairPeriodScope.unassigned(),
              ),
            ),
            const SizedBox(height: 16),
            for (final p in periods) ...[
              CueSectionCard(
                title: p.displayTitle,
                hint: _periodSubtitle(p),
                child: ContextCuesPanel(
                  caseId: caseId,
                  section: section,
                  periodScope: RepairPeriodScope.forPeriod(p.periodId),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _AddPeriodPrompt(
              caseId: caseId,
              periods: periods,
              hint: periods.isEmpty ? noPeriodsHint : null,
            ),
          ],
        ),
      ),
    );
  }

  String? _periodSubtitle(RepairPeriodModel p) {
    final df = DateFormat('d MMM yyyy');
    final dateRange = p.startDate != null
        ? [
            df.format(p.startDate!),
            if (p.endDate != null) df.format(p.endDate!),
          ].join(' – ')
        : null;
    final parts = [
      if (dateRange != null) dateRange,
      if (p.location != null) p.location!,
    ];
    return parts.isEmpty ? null : parts.join('  ·  ');
  }
}

class _AddPeriodPrompt extends ConsumerWidget {
  const _AddPeriodPrompt({
    required this.caseId,
    required this.periods,
    this.hint,
  });

  final String caseId;
  final List<RepairPeriodModel> periods;
  final String? hint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hint != null) ...[
          Text(hint!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textTertiary)),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: () async {
            final nextNo = periods.isEmpty
                ? 1
                : periods.map((p) => p.periodNo).reduce((a, b) => a > b ? a : b) + 1;
            await showQuickCreateRepairPeriodDialog(
              context,
              ref,
              caseId: caseId,
              nextPeriodNo: nextNo,
            );
          },
          icon: const Icon(Icons.add, size: 16),
          label: const Text('New Repair Period'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.midBlue,
            side: const BorderSide(color: AppColors.midBlue),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}
