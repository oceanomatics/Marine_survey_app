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
import '../../surveyor_notes/providers/surveyor_notes_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/context_cues_panel.dart';
import '../../../shared/widgets/back_app_bar.dart';

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

    // §3.10: the Unassigned bucket needs its own active-cue count *before*
    // ContextCuesPanel builds, to decide whether it starts collapsed — an
    // empty bucket eating the same expanded space as a populated one was
    // the "awkward, rarely useful" complaint. Uses the same cueMatchesScope
    // the panel itself uses internally, so there's no drift between "what
    // the panel shows" and "what this screen thinks is in it".
    final notesAsync = ref.watch(surveyorNotesProvider(caseId));
    final unassignedCount = notesAsync.value
            ?.where((n) => cueMatchesScope(n, section,
                periodScope: const RepairPeriodScope.unassigned()))
            .where((n) => n.priority != CuePriority.ignored)
            .length ??
        0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(title: Text(title)),
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
                // Recreates the panel's State (and re-evaluates
                // initiallyExpanded) when crossing the empty/non-empty
                // boundary — a `late` field only initialises once per
                // State instance, so this can't just be a rebuild.
                key: ValueKey('unassigned-${unassignedCount > 0}'),
                caseId: caseId,
                section: section,
                periodScope: const RepairPeriodScope.unassigned(),
                initiallyExpanded: unassignedCount > 0,
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
            // TODO.md §3.10: the inline quick-create isn't warranted on
            // General Services & Access specifically — repair periods
            // should be created from the Repair Periods screen itself, not
            // from within a cue-basket screen. WNCA keeps it (no surveyor
            // complaint raised about it there).
            if (section != CaseSection.generalExpenses)
              _AddPeriodPrompt(
                caseId: caseId,
                periods: periods,
                hint: periods.isEmpty ? noPeriodsHint : null,
              )
            else if (periods.isEmpty && noPeriodsHint != null)
              Text(noPeriodsHint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textTertiary)),
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
