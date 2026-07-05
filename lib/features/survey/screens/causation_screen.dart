// lib/features/survey/screens/causation_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/damage_provider.dart';
import '../widgets/causation_sheet.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/context_cues_panel.dart';
import '../../surveyor_notes/models/surveyor_note_model.dart';

class CausationScreen extends ConsumerWidget {
  const CausationScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final damageAsync = ref.watch(damageProvider(caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Allegation / Causation')),
      body: damageAsync.when(
        loading: () =>
            const AppLoadingWidget(message: 'Loading occurrences...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (ds) {
          final occs = [...ds.occurrences]..sort((a, b) {
              if (a.dateTime == null && b.dateTime == null) return 0;
              if (a.dateTime == null) return 1;
              if (b.dateTime == null) return -1;
              return a.dateTime!.compareTo(b.dateTime!);
            });

          return Column(
            children: [
              Expanded(
                child: occs.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.gavel_outlined,
                                  size: 64,
                                  color: AppColors.textTertiary),
                              SizedBox(height: 16),
                              Text(
                                'No occurrences recorded',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Add an occurrence first before recording\ncausation details.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        itemCount: occs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) => _CausationCard(
                          occurrence: occs[i],
                          onEdit: () =>
                              _showSheet(context, ref, occs[i]),
                        ),
                      ),
              ),
              ContextCuesPanel(
                caseId: caseId,
                section: CaseSection.causation,
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSheet(
      BuildContext context, WidgetRef ref, OccurrenceModel occ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CausationSheet(
        occurrence: occ,
        onSave: (updated) =>
            ref.read(damageProvider(caseId).notifier).updateOccurrence(updated),
      ),
    );
  }
}

// ── Causation card ─────────────────────────────────────────────────────────

class _CausationCard extends StatelessWidget {
  const _CausationCard({
    required this.occurrence,
    required this.onEdit,
  });

  final OccurrenceModel occurrence;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final causeType = HMCauseType.fromValue(occurrence.causeType);
    final allegationType = occurrence.allegationType;
    final agreement = occurrence.causeAgreement;
    final formulation = buildAllegationFormulation(
        causeType, allegationType, agreement);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28, height: 28,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Text(
                      '${occurrence.occurrenceNo}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
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
                          color: AppColors.amber,
                        ),
                      ),
                      if (occurrence.dateTime != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _fmtDate(occurrence.dateTime!),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.amber.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: AppColors.amber, size: 18),
                  onPressed: onEdit,
                  tooltip: 'Edit causation',
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          Divider(
              height: 1,
              color: AppColors.amber.withValues(alpha: 0.15)),

          // ── Body ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    _InfoStack(
                      label: 'Cause Type',
                      child: causeType != null
                          ? _Badge(
                              label: causeType.label,
                              bg: AppColors.lightAmber,
                              fg: AppColors.amber,
                            )
                          : const _Unset('Not set'),
                    ),
                    _InfoStack(
                      label: 'Formal Statement',
                      child: _allegationBadge(allegationType),
                    ),
                    if (allegationType == 'formal_allegation')
                      _InfoStack(
                        label: 'Our Position',
                        child: _agreementBadge(agreement),
                      ),
                  ],
                ),

                // Sub-causation comment preview
                if (occurrence.causeNarrative != null &&
                    occurrence.causeNarrative!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'SUB-CAUSATION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    occurrence.causeNarrative!.length > 200
                        ? '${occurrence.causeNarrative!.substring(0, 200)}…'
                        : occurrence.causeNarrative!,
                    style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary,
                    ),
                  ),
                ],

                // Standard formulation preview
                if (formulation != null) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'STANDARD FORMULATION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.lightAmber,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.amber.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      formulation,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _allegationBadge(String? type) {
    switch (type) {
      case 'formal_allegation':
        return const _Badge(
          label: 'Formal Allegation',
          bg: AppColors.lightCoral,
          fg: AppColors.coral,
        );
      case 'no_formal_allegation':
        return const _Badge(
          label: 'No Allegation',
          bg: AppColors.lightGreen,
          fg: AppColors.green,
        );
      case 'tbc':
        return const _Badge(
          label: 'TBC',
          bg: AppColors.surface,
          fg: AppColors.textSecondary,
        );
      default:
        return const _Unset('Not set');
    }
  }

  Widget _agreementBadge(String? agreement) {
    switch (agreement) {
      case 'agree':
        return const _Badge(
          label: 'We Agree',
          bg: AppColors.lightGreen,
          fg: AppColors.green,
        );
      case 'disagree':
        return const _Badge(
          label: 'We Disagree',
          bg: AppColors.lightCoral,
          fg: AppColors.coral,
        );
      case 'tbc':
        return const _Badge(
          label: 'TBC',
          bg: AppColors.surface,
          fg: AppColors.textSecondary,
        );
      default:
        return const _Unset('Not stated');
    }
  }

  String _fmtDate(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    final time =
        (d.hour != 0 || d.minute != 0) ? '  $h:$min LT' : '';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}$time';
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────

class _InfoStack extends StatelessWidget {
  const _InfoStack({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: fg,
        ),
      ),
    );
  }
}

class _Unset extends StatelessWidget {
  const _Unset(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textTertiary,
          fontStyle: FontStyle.italic,
        ),
      );
}
