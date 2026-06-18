// lib/features/attendances/screens/attendances_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/attendance_model.dart';
import '../providers/attendances_provider.dart';
import '../widgets/add_attendance_sheet.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';

const _kVisitsColor = Color(0xFFBF7E3A);

class AttendancesScreen extends ConsumerWidget {
  const AttendancesScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendancesAsync = ref.watch(attendancesProvider(caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Attendance')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        backgroundColor: _kVisitsColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Attendance',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: attendancesAsync.when(
        loading: () =>
            const AppLoadingWidget(message: 'Loading attendance...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (attendances) => attendances.isEmpty
            ? _EmptyState(onAdd: () => _showAddSheet(context, ref))
            : _AttendanceList(
                caseId: caseId,
                attendances: attendances,
                onDelete: (id) => ref
                    .read(attendancesProvider(caseId).notifier)
                    .delete(id),
              ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddAttendanceSheet(
        onSave: (type, date, location, surveyor, vesselStatus, summary) async {
          await ref.read(attendancesProvider(caseId).notifier).add(
                caseId:       caseId,
                type:         type,
                date:         date,
                location:     location,
                surveyorName: surveyor,
                vesselStatus: vesselStatus,
                summary:      summary,
              );
        },
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _kVisitsColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_today_outlined,
                color: _kVisitsColor, size: 30),
          ),
          const SizedBox(height: 16),
          const Text('No attendance recorded',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Tap Add Attendance to log your first visit',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Visit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kVisitsColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── List of attendances ────────────────────────────────────────────────────

class _AttendanceList extends StatelessWidget {
  const _AttendanceList({
    required this.caseId,
    required this.attendances,
    required this.onDelete,
  });

  final String caseId;
  final List<SurveyAttendanceModel> attendances;
  final Future<void> Function(String attendanceId) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: attendances.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _AttendanceCard(
        attendance: attendances[i],
        isFirst: i == 0,
        onDelete: () => onDelete(attendances[i].attendanceId),
      ),
    );
  }
}

// ── Attendance card ────────────────────────────────────────────────────────

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({
    required this.attendance,
    required this.isFirst,
    required this.onDelete,
  });

  final SurveyAttendanceModel attendance;
  final bool isFirst;
  final VoidCallback onDelete;

  Color _typeColor(AttendanceType t) => switch (t) {
        AttendanceType.initial         => _kVisitsColor,
        AttendanceType.followUp        => AppColors.midBlue,
        AttendanceType.finalInspection => AppColors.teal,
        AttendanceType.remoteReview    => AppColors.purple,
      };

  Color _statusColor(VesselStatus? s) => switch (s) {
        VesselStatus.dryDocked    => AppColors.coral,
        VesselStatus.atAnchor     => AppColors.teal,
        VesselStatus.alongside    => AppColors.midBlue,
        VesselStatus.inTransit    => AppColors.purple,
        VesselStatus.afloatOther  => AppColors.info,
        _                         => AppColors.textTertiary,
      };

  @override
  Widget build(BuildContext context) {
    final tc = _typeColor(attendance.attendanceType);
    final dateStr = attendance.attendanceDate != null
        ? DateFormat('dd/MM/yyyy').format(attendance.attendanceDate!)
        : 'Date TBC';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: tc.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: tc.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    attendance.attendanceType.label,
                    style: TextStyle(
                        color: tc,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(dateStr,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: AppColors.textTertiary, size: 18),
                  onSelected: (v) async {
                    if (v == 'delete') {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Remove attendance?'),
                          content: Text(
                              'Remove the $dateStr attendance?'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, false),
                                child: const Text('Cancel')),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(ctx, true),
                              child: const Text('Remove',
                                  style:
                                      TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) onDelete();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text('Remove',
                            style: TextStyle(
                                color: Colors.red, fontSize: 13)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: tc.withValues(alpha: 0.2)),
          // ── Body ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    if (attendance.location != null)
                      _InfoChip(
                        icon: Icons.location_on_outlined,
                        label: attendance.location!,
                        color: AppColors.textSecondary,
                      ),
                    if (attendance.vesselStatus != null)
                      _InfoChip(
                        icon: Icons.anchor_outlined,
                        label: attendance.vesselStatus!.label,
                        color: _statusColor(attendance.vesselStatus),
                      ),
                    if (attendance.surveyorName != null)
                      _InfoChip(
                        icon: Icons.person_outlined,
                        label: attendance.surveyorName!,
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
                if (attendance.summary != null &&
                    attendance.summary!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    attendance.summary!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info chip ──────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
