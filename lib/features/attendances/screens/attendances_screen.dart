// lib/features/attendances/screens/attendances_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/attendance_model.dart';
import '../providers/attendances_provider.dart';
import '../widgets/add_attendance_sheet.dart';
import '../widgets/edit_attendees_sheet.dart';
import '../../survey/providers/attendees_provider.dart';
import '../../cases/providers/cases_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/back_app_bar.dart';

const _kVisitsColor = Color(0xFFBF7E3A);

/// Case-level "is a follow-up attendance required" flag — relocated here
/// from the report builder's Advice Summary card per surveyor direction
/// (4 July 2026): this is a fact about the case, not something that
/// legitimately varies by which report is currently open, and it's
/// inherently about attendance, so it lives at the top of this screen.
class _FollowUpAttendanceCard extends ConsumerStatefulWidget {
  const _FollowUpAttendanceCard({required this.caseId});
  final String caseId;

  @override
  ConsumerState<_FollowUpAttendanceCard> createState() =>
      _FollowUpAttendanceCardState();
}

class _FollowUpAttendanceCardState
    extends ConsumerState<_FollowUpAttendanceCard> {
  final _detailCtrl = TextEditingController();
  bool _initialised = false;

  @override
  void dispose() {
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateRequired(bool value) async {
    await ref
        .read(caseProvider(widget.caseId).notifier)
        .updateCaseRefs(followUpRequired: value);
  }

  Future<void> _updateDetail(String text) async {
    await ref
        .read(caseProvider(widget.caseId).notifier)
        .updateCaseRefs(followUpDetail: text);
  }

  @override
  Widget build(BuildContext context) {
    final caseModel = ref.watch(caseProvider(widget.caseId)).value;
    if (caseModel == null) return const SizedBox.shrink();

    if (!_initialised) {
      _initialised = true;
      _detailCtrl.text = caseModel.followUpDetail ?? '';
    }

    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Follow-Up Attendance Required?',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final opt in const [(true, 'Yes'), (false, 'No')])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _updateRequired(opt.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: caseModel.followUpRequired == opt.$1
                            ? _kVisitsColor.withValues(alpha: 0.12)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: caseModel.followUpRequired == opt.$1
                                ? _kVisitsColor
                                : AppColors.border,
                            width: caseModel.followUpRequired == opt.$1 ? 1.5 : 1),
                      ),
                      child: Text(opt.$2,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: caseModel.followUpRequired == opt.$1
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: caseModel.followUpRequired == opt.$1
                                  ? _kVisitsColor
                                  : AppColors.textSecondary)),
                    ),
                  ),
                ),
            ],
          ),
          if (caseModel.followUpRequired == true) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _detailCtrl,
              maxLines: 2,
              minLines: 1,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Nature and expected timeline of follow-up',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: _updateDetail,
              onEditingComplete: () => _updateDetail(_detailCtrl.text),
            ),
          ],
        ],
      ),
    );
  }
}

class AttendancesScreen extends ConsumerWidget {
  const AttendancesScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendancesAsync = ref.watch(attendancesProvider(caseId));
    final allAttendees = ref.watch(attendeesProvider(caseId)).value ?? [];

    // Deduplicate previous attendees by name so suggestions are unique
    final seen = <String>{};
    final uniquePrevious = allAttendees
        .where((a) => seen.add(a.fullName.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(title: const Text('Attendance')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref, uniquePrevious),
        backgroundColor: _kVisitsColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Attendance',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          _FollowUpAttendanceCard(caseId: caseId),
          Expanded(
            child: attendancesAsync.when(
        loading: () =>
            const AppLoadingWidget(message: 'Loading attendance...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (attendances) => attendances.isEmpty
            ? _EmptyState(
                onAdd: () => _showAddSheet(context, ref, uniquePrevious))
            : _AttendanceList(
                caseId: caseId,
                attendances: attendances,
                allAttendees: allAttendees,
                onDelete: (id) async {
                  await ref
                      .read(attendancesProvider(caseId).notifier)
                      .delete(id);
                  // Cascade deletes attendees in DB; invalidate so in-memory
                  // state reflects the removal.
                  ref.invalidate(attendeesProvider(caseId));
                },
                onEditAttendees: (attendance, attendees) =>
                    _showEditAttendeesSheet(
                        context, ref, attendance, attendees),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditAttendeesSheet(
    BuildContext context,
    WidgetRef ref,
    SurveyAttendanceModel attendance,
    List<AttendeeModel> currentAttendees,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditAttendeesSheet(
        caseId: caseId,
        attendanceId: attendance.attendanceId,
        initialAttendees: currentAttendees,
        onAdd: (a) =>
            ref.read(attendeesProvider(caseId).notifier).addAttendee(a),
        onDelete: (id) =>
            ref.read(attendeesProvider(caseId).notifier).deleteAttendee(id),
        onReorder: (orderedIds) => ref
            .read(attendeesProvider(caseId).notifier)
            .reorderAttendees(orderedIds),
      ),
    );
  }

  void _showAddSheet(
    BuildContext context,
    WidgetRef ref,
    List<AttendeeModel> previousAttendees,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddAttendanceSheet(
        previousAttendees: previousAttendees,
        onSave: (type, date, location, surveyor, vesselStatus, summary,
            enabledPrevious, newAttendees) async {
          // 1. Create the attendance record
          final created =
              await ref.read(attendancesProvider(caseId).notifier).add(
                    caseId: caseId,
                    type: type,
                    date: date,
                    location: location.text,
                    latitude: location.latitude,
                    longitude: location.longitude,
                    locationType: location.locationType,
                    locationDetail: location.locationDetail,
                    nearestPort: location.nearestPort,
                    distanceOffshoreNm: location.distanceOffshoreNm,
                    surveyorName: surveyor,
                    vesselStatus: vesselStatus,
                    summary: summary,
                  );

          // 2. Carry forward enabled previous attendees (new records per attendance)
          for (final prev in enabledPrevious) {
            await ref.read(attendeesProvider(caseId).notifier).addAttendee(
                  AttendeeModel(
                    attendeeId:   '',
                    caseId:       caseId,
                    fullName:     prev.fullName,
                    attendanceId: created.attendanceId,
                    title:        prev.title,
                    rankPosition: prev.rankPosition,
                    company:      prev.company,
                    representing: prev.representing,
                    roleType:     prev.roleType,
                    contactEmail: prev.contactEmail,
                    contactPhone: prev.contactPhone,
                  ),
                );
          }

          // 3. Create new attendees entered inline
          for (final entry in newAttendees) {
            await ref.read(attendeesProvider(caseId).notifier).addAttendee(
                  AttendeeModel(
                    attendeeId:   '',
                    caseId:       caseId,
                    fullName:     entry.name,
                    attendanceId: created.attendanceId,
                    title:        entry.title,
                    roleType:     entry.role,
                    company:      entry.company,
                  ),
                );
          }
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
    required this.allAttendees,
    required this.onDelete,
    required this.onEditAttendees,
  });

  final String caseId;
  final List<SurveyAttendanceModel> attendances;
  final List<AttendeeModel> allAttendees;
  final Future<void> Function(String attendanceId) onDelete;
  final void Function(SurveyAttendanceModel, List<AttendeeModel>) onEditAttendees;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: attendances.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final attendance = attendances[i];
        // Include attendees linked to this attendance OR case-level
        // attendees (attendance_id == null) from the pre-attendance-linking era.
        final attendees = allAttendees
            .where((a) =>
                a.attendanceId == attendance.attendanceId ||
                a.attendanceId == null)
            .toList()
          ..sort((a, b) =>
              (a.roleType?.sortOrder ?? 99)
                  .compareTo(b.roleType?.sortOrder ?? 99));
        return _AttendanceCard(
          attendance: attendance,
          attendees: attendees,
          onDelete: () => onDelete(attendance.attendanceId),
          onEditAttendees: () => onEditAttendees(attendance, attendees),
        );
      },
    );
  }
}

// ── Attendance card ────────────────────────────────────────────────────────

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({
    required this.attendance,
    required this.attendees,
    required this.onDelete,
    required this.onEditAttendees,
  });

  final SurveyAttendanceModel attendance;
  final List<AttendeeModel> attendees;
  final VoidCallback onDelete;
  final VoidCallback onEditAttendees;

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
                                  style: TextStyle(
                                      color: Colors.red)),
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
          Divider(height: 1, color: tc.withValues(alpha: 0.2)),

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
                    if (attendance.latitude != null &&
                        attendance.longitude != null)
                      _InfoChip(
                        icon: Icons.map_outlined,
                        label:
                            '${attendance.latitude!.toStringAsFixed(4)}, ${attendance.longitude!.toStringAsFixed(4)}',
                        color: _kVisitsColor,
                        onTap: () => launchUrl(
                          Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=${attendance.latitude},${attendance.longitude}'),
                          mode: LaunchMode.externalApplication,
                        ),
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

                // ── Attendees list ─────────────────────────────────
                const SizedBox(height: 10),
                Row(children: [
                  const Text('ATTENDEES',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                          letterSpacing: 0.5)),
                  const Spacer(),
                  GestureDetector(
                    onTap: onEditAttendees,
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.edit_outlined,
                          size: 12, color: _kVisitsColor),
                      SizedBox(width: 3),
                      Text('Edit',
                          style: TextStyle(
                              fontSize: 11,
                              color: _kVisitsColor,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 6),
                if (attendees.isEmpty)
                  Text('No attendees recorded — tap Edit to add',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary.withValues(alpha: 0.8),
                          fontStyle: FontStyle.italic))
                else
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(3),
                    },
                    border: const TableBorder(
                      horizontalInside: BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 0.5,
                      ),
                    ),
                    children: [
                      const TableRow(
                        children: [
                          _TableHeader('Name'),
                          _TableHeader('Title / Function'),
                          _TableHeader('Company'),
                        ],
                      ),
                      ...attendees.map((a) => TableRow(
                            children: [
                              _TableCell(a.fullName, bold: true),
                              _TableCell(
                                  a.roleType?.label ?? a.rankPosition ?? '—'),
                              _TableCell(a.company ?? a.representing ?? '—'),
                            ],
                          )),
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

// ── Attendee table widgets ─────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 0.3,
          ),
        ),
      );
}

class _TableCell extends StatelessWidget {
  const _TableCell(this.text, {this.bold = false});
  final String text;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: bold ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: bold ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      );
}

// ── Info chip ──────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: color,
                decoration:
                    onTap != null ? TextDecoration.underline : null)),
      ],
    );
    return onTap == null
        ? chip
        : GestureDetector(onTap: onTap, child: chip);
  }
}
