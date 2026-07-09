// lib/features/survey/screens/occurrence_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/damage_provider.dart';
import '../widgets/add_occurrence_sheet.dart';
import 'occurrence_editor_screen.dart';
import '../../cases/providers/cases_provider.dart';
import '../../surveyor_notes/models/surveyor_note_model.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/context_cues_panel.dart';
import '../../../shared/widgets/back_app_bar.dart';

class OccurrenceScreen extends ConsumerWidget {
  const OccurrenceScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final damageAsync = ref.watch(damageProvider(caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(title: const Text('Occurrences')),
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

          return Column(
            children: [
              Expanded(
                child: sorted.isEmpty
                    ? _EmptyState(onAdd: () => _showAddSheet(context, ref))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: sorted.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _OccurrenceCard(
                          occurrence: sorted[i],
                          occurrenceCount: sorted.length,
                          onEdit: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => OccurrenceEditorScreen(
                                      caseId: caseId, occurrence: sorted[i]))),
                          onDelete: () => _confirmDelete(context, ref, sorted[i]),
                          onSetPrimary: () => ref
                              .read(damageProvider(caseId).notifier)
                              .setPrimaryOccurrence(sorted[i].occurrenceId)
                              .then((_) => ref.invalidate(caseProvider(caseId))),
                        ),
                      ),
              ),
              ContextCuesPanel(caseId: caseId, section: CaseSection.occurrence),
            ],
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
        onSave: (title, dateTime, location, description,
            vesselStatusAtCasualty, aftermathStatus, aftermathPort) async {
          await ref.read(damageProvider(caseId).notifier).createOccurrence(
                caseId: caseId,
                title: title,
                dateTime: dateTime,
                location: location,
                briefDescription: description,
                vesselStatusAtCasualty: vesselStatusAtCasualty,
                aftermathStatus: aftermathStatus,
                aftermathPort: aftermathPort,
              );
        },
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, OccurrenceModel occ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete occurrence?'),
        content: Text(
          'Delete "${occ.title ?? 'Occurrence ${occ.occurrenceNo}'}"? '
          'All linked damage items and repairs will also be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(damageProvider(caseId).notifier)
                  .deleteOccurrence(occ.occurrenceId);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

}

// ── Occurrence card ────────────────────────────────────────────────────────

class _OccurrenceCard extends StatelessWidget {
  const _OccurrenceCard({
    required this.occurrence,
    required this.occurrenceCount,
    required this.onEdit,
    required this.onDelete,
    required this.onSetPrimary,
  });

  final OccurrenceModel occurrence;
  final int occurrenceCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetPrimary;

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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              occurrence.title ??
                                  'Occurrence ${occurrence.occurrenceNo}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.coral),
                            ),
                          ),
                          if (occurrenceCount > 1 && occurrence.isPrimary) ...[
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.teal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                    color: AppColors.teal.withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'PRIMARY',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.teal,
                                    letterSpacing: 0.5),
                              ),
                            ),
                          ],
                        ],
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
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: AppColors.coral, size: 20),
                  padding: EdgeInsets.zero,
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                    if (v == 'primary') onSetPrimary();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (occurrenceCount > 1 && !occurrence.isPrimary)
                      const PopupMenuItem(
                        value: 'primary',
                        child: Row(children: [
                          Icon(Icons.star_outline,
                              size: 15, color: AppColors.teal),
                          SizedBox(width: 8),
                          Text('Set as primary',
                              style: TextStyle(color: AppColors.teal)),
                        ]),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
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
