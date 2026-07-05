// lib/features/timeline/screens/timeline_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/timeline_event_model.dart';
import '../providers/timeline_provider.dart';
import '../widgets/add_timeline_event_sheet.dart';
import '../../survey/providers/damage_provider.dart';
import '../../attendances/providers/attendances_provider.dart';
import '../../attendances/models/attendance_model.dart';
import '../../surveyor_notes/models/surveyor_note_model.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/context_cues_panel.dart';

const _kColor = Color(0xFF2E7CB7);

// ── Unified entry (in-memory only, never stored directly) ─────────────────

enum _Source { occurrence, attendance, repair, manual }

class _TEntry {
  const _TEntry({
    required this.date,
    required this.title,
    required this.source,
    required this.color,
    required this.icon,
    this.subtitle,
    this.badge,
    this.description,
    this.manualId,
  });

  final DateTime? date;
  final String title;
  final String? subtitle;
  final String? badge;
  final String? description;
  final _Source source;
  final Color color;
  final IconData icon;
  final String? manualId; // non-null → can be deleted
}

// ── Screen ────────────────────────────────────────────────────────────────

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manual     = ref.watch(timelineProvider(caseId)).value ?? [];
    final attendances = ref.watch(attendancesProvider(caseId)).value ?? [];
    final damage     = ref.watch(damageProvider(caseId)).value;

    final entries = _merge(manual, attendances, damage);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: _kColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Case Timeline',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 24),
            tooltip: 'Add event',
            onPressed: () => _showAddSheet(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: entries.isEmpty
                ? _emptyState()
                : _buildList(context, ref, entries),
          ),
          ContextCuesPanel(caseId: caseId, section: CaseSection.timeline),
        ],
      ),
    );
  }

  // ── Merge all sources ────────────────────────────────────────────────────

  List<_TEntry> _merge(
    List<TimelineEventModel> manual,
    List<SurveyAttendanceModel> attendances,
    DamageState? damage,
  ) {
    final list = <_TEntry>[];

    // Occurrences
    for (final occ in damage?.occurrences ?? []) {
      list.add(_TEntry(
        date:        occ.dateTime,
        title:       occ.title ?? 'Incident / Occurrence',
        subtitle:    occ.location,
        description: occ.briefDescription,
        source:      _Source.occurrence,
        color:       AppColors.coral,
        icon:        Icons.warning_amber_outlined,
        badge:       'Occurrence',
      ));
    }

    // Attendances
    for (final att in attendances) {
      final parts = <String>[];
      if (att.surveyorName != null) parts.add(att.surveyorName!);
      if (att.vesselStatus != null) parts.add(att.vesselStatus!.label);
      list.add(_TEntry(
        date:        att.attendanceDate,
        title:       att.attendanceType.label,
        subtitle:    att.location,
        badge:       'Attendance',
        description: [
            if (parts.isNotEmpty) parts.join(' · '),
            if (att.summary != null && att.summary!.isNotEmpty) att.summary!,
          ].join('\n').nullIfEmpty,
        source:      _Source.attendance,
        color:       const Color(0xFFBF7E3A),
        icon:        Icons.calendar_today_outlined,
      ));
    }

    // Completed repairs (auto-sourced from repair completionDate)
    for (final r in damage?.repairs ?? []) {
      if (r.completionDate != null) {
        list.add(_TEntry(
          date:        r.completionDate,
          title:       r.description ?? '${r.repairType.label} repairs completed',
          badge:       '${r.repairType.label} · Completed',
          description: r.notes,
          source:      _Source.repair,
          color:       AppColors.success,
          icon:        Icons.verified_outlined,
        ));
      }
    }

    // Manual events
    for (final ev in manual) {
      list.add(_TEntry(
        date:        ev.eventDate,
        title:       ev.title ?? ev.eventType.label,
        subtitle:    ev.location,
        description: ev.description,
        source:      _Source.manual,
        color:       _colorForType(ev.eventType),
        icon:        _iconForType(ev.eventType),
        manualId:    ev.eventId,
      ));
    }

    // Sort chronologically (undated entries last)
    list.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return a.date!.compareTo(b.date!);
    });

    return list;
  }

  // ── List view ────────────────────────────────────────────────────────────

  Widget _buildList(
      BuildContext context, WidgetRef ref, List<_TEntry> entries) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: entries.length,
      itemBuilder: (ctx, i) => _TimelineItem(
        entry:    entries[i],
        isFirst:  i == 0,
        isLast:   i == entries.length - 1,
        onDelete: entries[i].manualId != null
            ? () => _confirmDelete(context, ref, entries[i].manualId!)
            : null,
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: _kColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timeline, color: _kColor, size: 36),
            ),
            const SizedBox(height: 18),
            const Text('No timeline events yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'Events are added automatically from occurrences, '
              'attendances and completed repairs.\n\n'
              'Tap + to add vessel movements, drydock entries, '
              'repair milestones and custom notes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTimelineEventSheet(
        onSave: (model) async {
          final m = TimelineEventModel(
            eventId:     '',
            caseId:      caseId,
            eventType:   model.eventType,
            eventDate:   model.eventDate,
            title:       model.title,
            location:    model.location,
            description: model.description,
          );
          await ref.read(timelineProvider(caseId).notifier).add(m);
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String eventId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove event?'),
        content: const Text('This timeline entry will be permanently deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(timelineProvider(caseId).notifier).delete(eventId);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static Color _colorForType(TimelineEventType t) => switch (t) {
        TimelineEventType.tempRepairStart    => AppColors.warning,
        TimelineEventType.tempRepairComplete => AppColors.warning,
        TimelineEventType.permRepairStart    => AppColors.midBlue,
        TimelineEventType.permRepairComplete => AppColors.success,
        TimelineEventType.surveyorRemark     => AppColors.purple,
        _                                    => _kColor,
      };

  static IconData _iconForType(TimelineEventType t) => switch (t) {
        TimelineEventType.vesselDeparture    => Icons.directions_boat_outlined,
        TimelineEventType.vesselArrival      => Icons.anchor_outlined,
        TimelineEventType.drydockEntry       => Icons.water_outlined,
        TimelineEventType.drydockExit        => Icons.launch_outlined,
        TimelineEventType.tempRepairStart    => Icons.handyman_outlined,
        TimelineEventType.tempRepairComplete => Icons.check_circle_outline,
        TimelineEventType.permRepairStart    => Icons.build_outlined,
        TimelineEventType.permRepairComplete => Icons.verified_outlined,
        TimelineEventType.surveyorRemark     => Icons.note_outlined,
        _                                    => Icons.event_note_outlined,
      };
}

// ── Timeline item widget ──────────────────────────────────────────────────

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.entry,
    required this.isFirst,
    required this.isLast,
    this.onDelete,
  });

  final _TEntry entry;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final dateStr = entry.date != null
        ? DateFormat('dd/MM/yyyy').format(entry.date!)
        : 'Date TBC';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Vertical rail ──────────────────────────────────────────────
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Line above dot
                Expanded(
                  child: isFirst
                      ? const SizedBox.shrink()
                      : Center(
                          child: Container(
                            width: 2,
                            color: AppColors.border,
                          ),
                        ),
                ),
                // Dot
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: entry.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: entry.color.withValues(alpha: 0.3),
                          blurRadius: 4),
                    ],
                  ),
                ),
                // Line below dot
                Expanded(
                  child: isLast
                      ? const SizedBox.shrink()
                      : Center(
                          child: Container(
                            width: 2,
                            color: AppColors.border,
                          ),
                        ),
                ),
              ],
            ),
          ),

          // ── Content card ───────────────────────────────────────────────
          Expanded(
            child: Container(
              margin: EdgeInsets.only(
                left: 10,
                bottom: isLast ? 4 : 14,
                top: isFirst ? 0 : 0,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date + badge row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          dateStr,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _kColor),
                        ),
                      ),
                      if (entry.badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: entry.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            entry.badge!,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: entry.color),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (onDelete != null)
                        GestureDetector(
                          onTap: onDelete,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(Icons.delete_outline,
                                size: 16,
                                color: AppColors.textTertiary
                                    .withValues(alpha: 0.6)),
                          ),
                        ),
                      // Source indicator
                      Icon(entry.icon,
                          size: 14,
                          color: entry.color.withValues(alpha: 0.7)),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Title
                  Text(
                    entry.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),

                  // Subtitle (location etc.)
                  if (entry.subtitle != null &&
                      entry.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 11,
                            color: AppColors.textTertiary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            entry.subtitle!,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Description
                  if (entry.description != null &&
                      entry.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.description!.length > 160
                          ? '${entry.description!.substring(0, 160)}…'
                          : entry.description!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.45),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

extension _StringX on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
