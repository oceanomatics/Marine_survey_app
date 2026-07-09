// lib/features/survey/screens/attendees_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/attendees_provider.dart';
import '../widgets/add_attendee_sheet.dart';
import '../../surveyor_notes/models/surveyor_note_model.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/context_cues_panel.dart';
import '../../../shared/widgets/back_app_bar.dart';

class AttendeesScreen extends ConsumerWidget {
  const AttendeesScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendeesAsync = ref.watch(attendeesProvider(caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BackAppBar(
        title: Text('Attendees'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEdit(context, ref),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Person',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: attendeesAsync.when(
        loading: () =>
            const AppLoadingWidget(message: 'Loading attendees...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (attendees) => Column(
          children: [
            Expanded(
              child: attendees.isEmpty
                  ? _EmptyState(onAdd: () => _showAddEdit(context, ref))
                  : _AttendeeBody(
                      attendees: attendees,
                      caseId: caseId,
                      onEdit: (a) => _showAddEdit(context, ref, existing: a),
                      onDelete: (id) => _confirmDelete(context, ref, id),
                    ),
            ),
            ContextCuesPanel(caseId: caseId, section: CaseSection.attendance),
          ],
        ),
      ),
    );
  }

  void _showAddEdit(BuildContext context, WidgetRef ref,
      {AttendeeModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddAttendeeSheet(
        caseId: caseId,
        existing: existing,
        onSave: (attendee) async {
          if (existing != null) {
            await ref
                .read(attendeesProvider(caseId).notifier)
                .updateAttendee(attendee);
          } else {
            await ref
                .read(attendeesProvider(caseId).notifier)
                .addAttendee(attendee);
          }
        },
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, String attendeeId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove attendee?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(attendeesProvider(caseId).notifier)
                  .deleteAttendee(attendeeId);
            },
            child: const Text('Remove',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Body ───────────────────────────────────────────────────────────────────

class _AttendeeBody extends StatelessWidget {
  const _AttendeeBody({
    required this.attendees,
    required this.caseId,
    required this.onEdit,
    required this.onDelete,
  });

  final List<AttendeeModel> attendees;
  final String caseId;
  final ValueChanged<AttendeeModel> onEdit;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Report preview banner ─────────────────────────────────
        _ReportPreview(attendees: attendees),

        // ── List ─────────────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: attendees.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _AttendeeCard(
              attendee: attendees[i],
              onEdit: () => onEdit(attendees[i]),
              onDelete: () => onDelete(attendees[i].attendeeId),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Report preview — how attendees table looks in the report ───────────────

class _ReportPreview extends StatelessWidget {
  const _ReportPreview({required this.attendees});
  final List<AttendeeModel> attendees;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.navy,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(children: [
              const Icon(Icons.table_chart_outlined,
                  color: Colors.white, size: 14),
              const SizedBox(width: 8),
              const Text('ATTENDING THE SURVEY',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
              const Spacer(),
              Text('${attendees.length} person${attendees.length == 1 ? '' : 's'}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10)),
            ]),
          ),
          // Table rows
          if (attendees.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('No attendees recorded yet',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic)),
            )
          else
            ...attendees.map((a) => _PreviewRow(attendee: a)),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.attendee});
  final AttendeeModel attendee;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(children: [
        Expanded(
          child: Text(
            '${attendee.prefix}  ${attendee.fullName}'
            '${attendee.rankPosition != null ? ',  ${attendee.rankPosition}' : ''}',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          attendee.representing ?? attendee.company ?? '',
          style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary),
          textAlign: TextAlign.right,
        ),
      ]),
    );
  }
}

// ── Attendee card ─────────────────────────────────────────────────────────

class _AttendeeCard extends StatelessWidget {
  const _AttendeeCard({
    required this.attendee,
    required this.onEdit,
    required this.onDelete,
  });

  final AttendeeModel attendee;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _roleColor(attendee.roleType)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  _initials(attendee.fullName),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _roleColor(attendee.roleType),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${attendee.prefix} ${attendee.fullName}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  if (attendee.rankPosition != null)
                    Text(attendee.rankPosition!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  if (attendee.company != null)
                    Text(attendee.company!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  if (attendee.representing != null)
                    Text(
                      'Representing: ${attendee.representing}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary),
                    ),
                ],
              ),
            ),

            // Role badge + actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (attendee.roleType != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _roleColor(attendee.roleType)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      attendee.roleType!.label,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _roleColor(attendee.roleType)),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 16, color: AppColors.textSecondary),
                      onPressed: onEdit,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 16, color: AppColors.error),
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  Color _roleColor(AttendeeRole? role) => switch (role) {
        AttendeeRole.master         => AppColors.navy,
        AttendeeRole.chiefEngineer  => AppColors.teal,
        AttendeeRole.firstEngineer  => AppColors.teal,
        AttendeeRole.superintendent => AppColors.midBlue,
        AttendeeRole.classSurveyor  => AppColors.purple,
        AttendeeRole.ownerRep       => AppColors.amber,
        AttendeeRole.serviceEngineer => AppColors.coral,
        AttendeeRole.adjuster       => AppColors.green,
        AttendeeRole.broker         => AppColors.amber,
        AttendeeRole.surveyor       => AppColors.navy,
        _                           => AppColors.textSecondary,
      };
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
          const Icon(Icons.people_outline,
              size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          const Text('No attendees recorded',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text(
            'Record everyone present — master,\nchief engineer, class surveyor,\nservice engineers and owner\'s reps',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Add first person'),
          ),
        ]),
      ),
    );
  }
}
