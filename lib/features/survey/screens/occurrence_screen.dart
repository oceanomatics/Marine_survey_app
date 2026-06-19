// lib/features/survey/screens/occurrence_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/damage_provider.dart';
import '../widgets/add_occurrence_sheet.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';

class OccurrenceScreen extends ConsumerWidget {
  const OccurrenceScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final damageAsync = ref.watch(damageProvider(caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Occurrences')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        backgroundColor: AppColors.coral,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Occurrence',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: damageAsync.when(
        loading: () =>
            const AppLoadingWidget(message: 'Loading occurrences...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (ds) {
          // Sort by date ascending; null dates go to the end
          final sorted = [...ds.occurrences]..sort((a, b) {
              if (a.dateTime == null && b.dateTime == null) return 0;
              if (a.dateTime == null) return 1;
              if (b.dateTime == null) return -1;
              return a.dateTime!.compareTo(b.dateTime!);
            });

          if (sorted.isEmpty) {
            return _EmptyState(onAdd: () => _showAddSheet(context, ref));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _OccurrenceCard(
              occurrence: sorted[i],
              onEdit: () => _showEditSheet(context, ref, sorted[i]),
            ),
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
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

  void _showEditSheet(
      BuildContext context, WidgetRef ref, OccurrenceModel occ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddOccurrenceSheet(
        existing: occ,
        onSave: (title, dateTime, location, description) async {
          final updated = OccurrenceModel(
            occurrenceId:        occ.occurrenceId,
            caseId:              occ.caseId,
            occurrenceNo:        occ.occurrenceNo,
            title:               title,
            dateTime:            dateTime,
            location:            (location == null || location.isEmpty) ? null : location,
            briefDescription:    description?.isEmpty == true ? null : description,
            backgroundNarrative: occ.backgroundNarrative,
            chronology:          occ.chronology,
            allegationType:      occ.allegationType,
            causeNarrative:      occ.causeNarrative,
            ismReported:         occ.ismReported,
            createdAt:           occ.createdAt,
          );
          await ref
              .read(damageProvider(caseId).notifier)
              .updateOccurrence(updated);
        },
      ),
    );
  }
}

// ── Occurrence card ────────────────────────────────────────────────────────

class _OccurrenceCard extends StatelessWidget {
  const _OccurrenceCard({
    required this.occurrence,
    required this.onEdit,
  });

  final OccurrenceModel occurrence;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: AppColors.coral,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Text(
                      '${occurrence.occurrenceNo}',
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
                      if (occurrence.dateTime != null) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 11,
                              color: AppColors.coral.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Text(
                            _fmtDate(occurrence.dateTime!),
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.coral.withValues(alpha: 0.8)),
                          ),
                        ]),
                      ],
                      if (occurrence.location != null &&
                          occurrence.location!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(Icons.location_on_outlined,
                              size: 11,
                              color: AppColors.coral.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              occurrence.location!,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.coral.withValues(alpha: 0.8),
                                  fontStyle: FontStyle.italic),
                            ),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: AppColors.coral, size: 18),
                  onPressed: onEdit,
                  tooltip: 'Edit occurrence',
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // ── Narrative ───────────────────────────────────────────────
          if (occurrence.briefDescription != null &&
              occurrence.briefDescription!.isNotEmpty) ...[
            Divider(
                height: 1,
                color: AppColors.coral.withValues(alpha: 0.15)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Text(
                occurrence.briefDescription!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    final timeStr = (d.hour != 0 || d.minute != 0) ? '  $h:$min LT' : '';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}$timeStr';
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.event_note_outlined,
              size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          const Text('No occurrences recorded',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text(
            'An occurrence is the casualty event at the\n'
            'root of the survey — dates, location and\n'
            'background narrative.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add first occurrence'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white),
          ),
        ]),
      ),
    );
  }
}
