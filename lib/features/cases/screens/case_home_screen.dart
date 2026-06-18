// lib/features/cases/screens/case_home_screen.dart
//
// Main case hub: vertical nav rail (left) + pseudo-report overview (right).
// AppBar carries a checklist progress bar at its base.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/cases_provider.dart';
import '../models/case_model.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/error_widget.dart';
import '../../capture/screens/camera_screen.dart';
import '../../vessel/providers/vessel_provider.dart';
import '../../survey/providers/damage_provider.dart';
import '../../survey/providers/attendees_provider.dart';
import '../../documents/providers/document_provider.dart';
import '../../capture/providers/voice_note_provider.dart';
import '../../parties/providers/parties_provider.dart';
import '../../parties/models/party_model.dart';
import '../../attendances/providers/attendances_provider.dart';
import '../../attendances/models/attendance_model.dart';
import '../../timeline/providers/timeline_provider.dart';
import '../../timeline/models/timeline_event_model.dart';
import '../../survey/providers/repair_period_provider.dart';
import '../../survey/models/repair_period_model.dart';

const _kTimelineColor = Color(0xFF2E7CB7);

// ── Shell ─────────────────────────────────────────────────────────────────

class CaseHomeScreen extends ConsumerWidget {
  const CaseHomeScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caseAsync = ref.watch(caseProvider(caseId));
    final progressAsync = ref.watch(checklistProgressProvider(caseId));
    final pendingAsync = ref.watch(pendingCapturesProvider(caseId));

    return caseAsync.when(
      loading: () => const Scaffold(body: AppLoadingWidget()),
      error: (e, _) => Scaffold(body: AppErrorWidget(error: e.toString())),
      data: (survey) => _CaseHomeView(
        caseId: caseId,
        survey: survey,
        checklistProgress: progressAsync.value ?? 0,
        pendingCaptures: pendingAsync.value ?? 0,
        onDeleteCase: () => _deleteCase(context, ref, survey),
      ),
    );
  }

  Future<void> _deleteCase(
      BuildContext context, WidgetRef ref, CaseModel survey) async {
    final label = survey.title ?? survey.vesselName ?? survey.jobNumber;

    // First confirmation
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete case?'),
        content: Text(
          'Delete "$label"?\n\n'
          'All occurrences, damage items, documents, attendees, '
          'checklists and reports for this case will be removed.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue',
                style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    if (first != true || !context.mounted) return;

    // Second confirmation — explicit destructive button
    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanently delete?',
            style: TextStyle(color: Colors.red)),
        content: const Text(
          'This cannot be undone. The case and every piece of data '
          'linked to it will be permanently erased.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Permanently delete'),
          ),
        ],
      ),
    );
    if (second != true || !context.mounted) return;

    try {
      await ref.read(casesProvider.notifier).deleteCase(caseId);
      if (context.mounted) context.go('/cases');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red));
      }
    }
  }
}

// ── Scaffold ──────────────────────────────────────────────────────────────

class _CaseHomeView extends StatelessWidget {
  const _CaseHomeView({
    required this.caseId,
    required this.survey,
    required this.checklistProgress,
    required this.pendingCaptures,
    required this.onDeleteCase,
  });

  final String caseId;
  final CaseModel survey;
  final double checklistProgress;
  final int pendingCaptures;
  final VoidCallback onDeleteCase;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _SurveyAppBar(
        survey: survey,
        progress: checklistProgress,
        onBack: () => context.go('/cases'),
        onDelete: onDeleteCase,
      ),
      bottomNavigationBar: _CaptureToolbar(caseId: caseId),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SurveyNavRail(caseId: caseId, pendingCaptures: pendingCaptures),
          const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
          Expanded(
            child: _PseudoReport(
              caseId: caseId,
              survey: survey,
              checklistProgress: checklistProgress,
            ),
          ),
        ],
      ),
    );
  }
}

// ── AppBar with progress bar ──────────────────────────────────────────────

class _SurveyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SurveyAppBar({
    required this.survey,
    required this.progress,
    required this.onBack,
    required this.onDelete,
  });

  final CaseModel survey;
  final double progress;
  final VoidCallback onBack;
  final VoidCallback onDelete;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 4);

  Color _statusColor(CaseStatus s) => switch (s) {
        CaseStatus.open => AppColors.info,
        CaseStatus.prelimIssued => AppColors.warning,
        CaseStatus.adviceIssued => AppColors.warning,
        CaseStatus.finalIssued => AppColors.success,
        CaseStatus.closed => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.navy,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: onBack,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            survey.title ?? survey.vesselName ?? 'Vessel TBC',
            style: const TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
          ),
          Text(
            '${survey.caseType.label} · ${survey.jobNumber}',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65), fontSize: 11),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.checklist_outlined, color: Colors.white60, size: 14),
              const SizedBox(width: 3),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor(survey.status).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _statusColor(survey.status).withValues(alpha: 0.5)),
          ),
          child: Text(
            survey.status.label.toUpperCase(),
            style: TextStyle(
              color: _statusColor(survey.status),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
          onSelected: (v) { if (v == 'delete') onDelete(); },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_forever_outlined, color: Colors.red, size: 18),
                SizedBox(width: 10),
                Text('Delete case…',
                    style: TextStyle(color: Colors.red, fontSize: 13)),
              ]),
            ),
          ],
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(4),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white.withValues(alpha: 0.15),
          valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1.0 ? AppColors.success : const Color(0xFF5BC8F5)),
          minHeight: 4,
        ),
      ),
    );
  }
}

// ── Nav Rail ──────────────────────────────────────────────────────────────

class _SurveyNavRail extends StatelessWidget {
  const _SurveyNavRail({required this.caseId, required this.pendingCaptures});

  final String caseId;
  final int pendingCaptures;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      color: const Color(0xFFD5E8F5),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _NavItem(
            icon: Icons.directions_boat_outlined,
            label: 'Vessel',
            accent: AppColors.teal,
            onTap: () => context.go('/cases/$caseId/vessel'),
          ),
          _NavItem(
            icon: Icons.handshake_outlined,
            label: 'Parties',
            accent: AppColors.midBlue,
            onTap: () => context.go('/cases/$caseId/parties'),
          ),
          _NavItem(
            icon: Icons.folder_outlined,
            label: 'Docs',
            accent: AppColors.amber,
            onTap: () => context.go('/cases/$caseId/documents'),
          ),
          _NavItem(
            icon: Icons.mic_outlined,
            label: 'Interview',
            accent: AppColors.purple,
            onTap: () => context.go('/cases/$caseId/voice'),
          ),
          _NavItem(
            icon: Icons.warning_amber_outlined,
            label: 'Damage',
            accent: AppColors.coral,
            onTap: () => context.go('/cases/$caseId/damage'),
          ),
          _NavItem(
            icon: Icons.calendar_today_outlined,
            label: 'Attend.',
            accent: const Color(0xFFBF7E3A),
            onTap: () => context.go('/cases/$caseId/attendances'),
          ),
          _NavItem(
            icon: Icons.timeline,
            label: 'Timeline',
            accent: _kTimelineColor,
            onTap: () => context.go('/cases/$caseId/timeline'),
          ),
          _NavItem(
            icon: Icons.checklist_outlined,
            label: 'Checklist',
            accent: AppColors.green,
            onTap: () => context.go('/cases/$caseId/checklist'),
          ),
          _NavItem(
            icon: Icons.inbox_outlined,
            label: 'Inbox',
            accent: pendingCaptures > 0
                ? AppColors.coral
                : AppColors.navy,
            badge: pendingCaptures > 0 ? '$pendingCaptures' : null,
            onTap: () => context.go('/cases/$caseId/capture'),
          ),
          _NavItem(
            icon: Icons.description_outlined,
            label: 'Report',
            accent: AppColors.navy,
            onTap: () => context.go('/cases/$caseId/reports'),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// ── Bottom capture toolbar ────────────────────────────────────────────────

class _CaptureToolbar extends StatelessWidget {
  const _CaptureToolbar({required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Color(0xFFD5E8F5),
        border: Border(top: BorderSide(color: Color(0xFFB8D5EC), width: 1)),
      ),
      child: Row(
        children: [
          _CaptureToolButton(
            icon: Icons.camera_alt_outlined,
            label: 'Camera',
            accent: AppColors.navy,
            onTap: () => context.go('/cases/$caseId/camera'),
          ),
          _CaptureToolButton(
            icon: Icons.mic_outlined,
            label: 'Voice',
            accent: AppColors.purple,
            onTap: () => context.go('/cases/$caseId/voice'),
          ),
          _CaptureToolButton(
            icon: Icons.edit_outlined,
            label: 'Stylus',
            accent: AppColors.navy,
            onTap: () {},
          ),
          _CaptureToolButton(
            icon: Icons.bolt_outlined,
            label: 'Quick Capture',
            accent: AppColors.coral,
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => QuickCaptureSheet(caseId: caseId),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureToolButton extends StatelessWidget {
  const _CaptureToolButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: accent.withValues(alpha: 0.15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: accent.withValues(alpha: 0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Nav Rail ─────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: accent.withValues(alpha: 0.15),
          child: SizedBox(
            width: 68,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 32,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: accent, size: 22),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.8),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  if (badge != null)
                    Positioned(
                      top: 0,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.coral,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pseudo-Report — template-aware ───────────────────────────────────────

class _PseudoReport extends ConsumerWidget {
  const _PseudoReport({
    required this.caseId,
    required this.survey,
    required this.checklistProgress,
  });

  final String caseId;
  final CaseModel survey;
  final double checklistProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vessel = ref.watch(vesselForCaseProvider(caseId)).value;
    final damage = ref.watch(damageProvider(caseId)).value;
    final attendees = ref.watch(attendeesProvider(caseId)).value ?? [];
    final docs = ref.watch(documentProvider(caseId)).value ?? [];
    final voices = ref.watch(voiceNotesProvider(caseId)).value ?? [];
    final parties = ref.watch(partiesProvider(caseId)).value;
    final assuredContacts =
        ref.watch(assuredContactsProvider(caseId)).value ?? [];
    final visits = ref.watch(attendancesProvider(caseId)).value ?? [];
    final timeline = ref.watch(timelineProvider(caseId)).value ?? [];
    final repairPeriods = ref.watch(repairPeriodsProvider(caseId)).value ?? [];

    final List<Widget> sections = survey.outputFormat == OutputFormat.nordic
        ? _nordicSections(context, vessel, damage, attendees, docs, voices,
            parties, assuredContacts, visits, timeline, repairPeriods)
        : _ablSections(context, vessel, damage, attendees, docs, voices,
            parties, assuredContacts, visits, timeline, repairPeriods);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CaseBanner(survey: survey),
          const SizedBox(height: 10),
          for (final s in sections) ...[s, const SizedBox(height: 8)],
          _SectionCard(
            accentColor: AppColors.green,
            icon: Icons.checklist_outlined,
            title: 'Survey Checklist',
            countLabel: '${(checklistProgress * 100).round()}%',
            onOpen: () => context.go('/cases/$caseId/checklist'),
            child: _checklistContent(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── ABL London sections ───────────────────────────────────────────────────

  List<Widget> _ablSections(
    BuildContext ctx,
    VesselModel? vessel,
    DamageState? damage,
    List<AttendeeModel> attendees,
    List<DocumentModel> docs,
    List<VoiceNoteModel> voices,
    CasePartiesModel? parties,
    List<AssuredContactModel> assuredContacts,
    List<SurveyAttendanceModel> visits,
    List<TimelineEventModel> timeline,
    List<RepairPeriodModel> repairPeriods,
  ) {
    final occ = damage?.occurrences.firstOrNull;
    return [
      _SectionCard(
        accentColor: AppColors.midBlue,
        icon: Icons.handshake_outlined,
        title: 'Parties',
        onOpen: () => ctx.go('/cases/$caseId/parties'),
        child: _partiesContent(parties, assuredContacts),
      ),
      _SectionCard(
        accentColor: AppColors.teal,
        icon: Icons.directions_boat_outlined,
        title: "Vessel's Description",
        initiallyExpanded: vessel != null,
        onOpen: () => ctx.go('/cases/$caseId/vessel'),
        child: _vesselAblTable(vessel),
      ),
      _SectionCard(
        accentColor: AppColors.coral,
        icon: Icons.event_note_outlined,
        title: 'Occurrence',
        countLabel: (damage?.occurrences.length ?? 0) > 0
            ? '${damage!.occurrences.length}'
            : null,
        initiallyExpanded: occ != null,
        onOpen: () => ctx.go('/cases/$caseId/damage'),
        child: _occurrenceContent(damage),
      ),
      _SectionCard(
        accentColor: const Color(0xFFBF7E3A),
        icon: Icons.calendar_today_outlined,
        title: 'Attendance',
        countLabel: visits.isEmpty ? null : '${visits.length}',
        initiallyExpanded: visits.isNotEmpty,
        onOpen: () => ctx.go('/cases/$caseId/attendances'),
        child: _visitsContent(visits),
      ),
      _SectionCard(
        accentColor: AppColors.navy,
        icon: Icons.people_outline,
        title: 'Attending Representatives',
        countLabel: attendees.isEmpty ? null : '${attendees.length}',
        onOpen: () => ctx.go('/cases/$caseId/attendees'),
        child: _attendeesContent(attendees),
      ),
      _SectionCard(
        accentColor: _kTimelineColor,
        icon: Icons.timeline,
        title: 'Case Timeline',
        countLabel: _timelineCount(timeline, visits, damage),
        initiallyExpanded: timeline.isNotEmpty || visits.isNotEmpty,
        onOpen: () => ctx.go('/cases/$caseId/timeline'),
        child: _timelineContent(timeline, visits, damage),
      ),
      _SectionCard(
        accentColor: AppColors.coral,
        icon: Icons.warning_amber_outlined,
        title: 'Extent of Damage',
        countLabel: (damage?.totalDamageItems ?? 0) > 0
            ? '${damage!.totalDamageItems} items'
            : null,
        initiallyExpanded: (damage?.totalDamageItems ?? 0) > 0,
        onOpen: () => ctx.go('/cases/$caseId/damage'),
        child: _extentOfDamageContent(damage),
      ),
      _SectionCard(
        accentColor: AppColors.amber,
        icon: Icons.gavel_outlined,
        title: occ?.allegationType != null
            ? 'Allegation'
            : 'Cause Consideration',
        onOpen: () => ctx.go('/cases/$caseId/damage'),
        child: _causationContent(occ),
      ),
      _SectionCard(
        accentColor: AppColors.midBlue,
        icon: Icons.build_outlined,
        title: 'Repairs',
        countLabel: repairPeriods.isEmpty ? null : '${repairPeriods.length} period${repairPeriods.length == 1 ? '' : 's'}',
        initiallyExpanded: repairPeriods.isNotEmpty,
        onOpen: () => ctx.go('/cases/$caseId/damage'),
        child: _repairsContent(repairPeriods),
      ),
      _SectionCard(
        accentColor: AppColors.green,
        icon: Icons.receipt_outlined,
        title: 'Accounts',
        onOpen: () => ctx.go('/cases/$caseId/damage'),
        child: const _SectionEmpty('Invoices module — Phase 1.1'),
      ),
      _SectionCard(
        accentColor: AppColors.teal,
        icon: Icons.schedule_outlined,
        title: 'Repair Times',
        onOpen: () => ctx.go('/cases/$caseId/damage'),
        child: const _SectionEmpty('Drydock / afloat days — enter in Damage Register'),
      ),
      _SectionCard(
        accentColor: AppColors.purple,
        icon: Icons.mic_outlined,
        title: "Surveyor's Notes",
        countLabel: voices.isEmpty ? null : '${voices.length}',
        onOpen: () => ctx.go('/cases/$caseId/voice'),
        child: _voiceContent(voices),
      ),
      _SectionCard(
        accentColor: AppColors.amber,
        icon: Icons.folder_outlined,
        title: 'Documents',
        countLabel: docs.isEmpty ? null : '${docs.length}',
        onOpen: () => ctx.go('/cases/$caseId/documents'),
        child: _documentsContent(docs),
      ),
      _SectionCard(
        accentColor: AppColors.midBlue,
        icon: Icons.description_outlined,
        title: 'Report Status',
        onOpen: () => ctx.go('/cases/$caseId/reports'),
        child: _reportStatusContent(),
      ),
    ];
  }

  // ── Nordic / Gard sections ────────────────────────────────────────────────

  List<Widget> _nordicSections(
    BuildContext ctx,
    VesselModel? vessel,
    DamageState? damage,
    List<AttendeeModel> attendees,
    List<DocumentModel> docs,
    List<VoiceNoteModel> voices,
    CasePartiesModel? parties,
    List<AssuredContactModel> assuredContacts,
    List<SurveyAttendanceModel> visits,
    List<TimelineEventModel> timeline,
    List<RepairPeriodModel> repairPeriods,
  ) {
    final occ = damage?.occurrences.firstOrNull;
    return [
      _SectionCard(
        accentColor: AppColors.midBlue,
        icon: Icons.handshake_outlined,
        title: 'Parties',
        onOpen: () => ctx.go('/cases/$caseId/parties'),
        child: _partiesContent(parties, assuredContacts),
      ),
      _SectionCard(
        accentColor: AppColors.coral,
        icon: Icons.event_note_outlined,
        title: 'Occurrence',
        countLabel: (damage?.occurrences.length ?? 0) > 0
            ? '${damage!.occurrences.length}'
            : null,
        initiallyExpanded: occ != null,
        onOpen: () => ctx.go('/cases/$caseId/damage'),
        child: _occurrenceContent(damage),
      ),
      _SectionCard(
        accentColor: const Color(0xFFBF7E3A),
        icon: Icons.calendar_today_outlined,
        title: 'Attendance',
        countLabel: visits.isEmpty ? null : '${visits.length}',
        initiallyExpanded: visits.isNotEmpty,
        onOpen: () => ctx.go('/cases/$caseId/attendances'),
        child: _visitsContent(visits),
      ),
      _SectionCard(
        accentColor: AppColors.navy,
        icon: Icons.people_outline,
        title: 'Attending Representatives',
        countLabel: attendees.isEmpty ? null : '${attendees.length}',
        onOpen: () => ctx.go('/cases/$caseId/attendees'),
        child: _attendeesContent(attendees),
      ),
      _SectionCard(
        accentColor: _kTimelineColor,
        icon: Icons.timeline,
        title: 'Case Timeline',
        countLabel: _timelineCount(timeline, visits, damage),
        initiallyExpanded: timeline.isNotEmpty || visits.isNotEmpty,
        onOpen: () => ctx.go('/cases/$caseId/timeline'),
        child: _timelineContent(timeline, visits, damage),
      ),
      _SectionCard(
        accentColor: AppColors.teal,
        icon: Icons.directions_boat_outlined,
        title: 'Vessel Particulars',
        initiallyExpanded: vessel != null,
        onOpen: () => ctx.go('/cases/$caseId/vessel'),
        child: _vesselNordicTable(vessel),
      ),
      _SectionCard(
        accentColor: AppColors.midBlue,
        icon: Icons.route_outlined,
        title: "Vessel's Movements & Events",
        onOpen: () => ctx.go('/cases/$caseId/damage'),
        child: _narrativeContent(
          occ?.chronology,
          'Chronology / movements — enter in Occurrence',
        ),
      ),
      _SectionCard(
        accentColor: AppColors.amber,
        icon: Icons.folder_outlined,
        title: 'Available Information',
        countLabel: docs.isEmpty ? null : '${docs.length}',
        onOpen: () => ctx.go('/cases/$caseId/documents'),
        child: _availableInfoContent(docs),
      ),
      _SectionCard(
        accentColor: AppColors.teal,
        icon: Icons.engineering_outlined,
        title: 'Brief Technical Description',
        onOpen: () => ctx.go('/cases/$caseId/vessel'),
        child: const _SectionEmpty(
            'Technical description — draft in Report Builder'),
      ),
      _SectionCard(
        accentColor: AppColors.midBlue,
        icon: Icons.history_outlined,
        title: 'Background',
        onOpen: () => ctx.go('/cases/$caseId/damage'),
        child: _narrativeContent(
          occ?.backgroundNarrative,
          'Background narrative — enter in Occurrence',
        ),
      ),
      _SectionCard(
        accentColor: AppColors.coral,
        icon: Icons.warning_amber_outlined,
        title: 'Damage Description',
        countLabel: (damage?.totalDamageItems ?? 0) > 0
            ? '${damage!.totalDamageItems} items'
            : null,
        initiallyExpanded: (damage?.totalDamageItems ?? 0) > 0,
        onOpen: () => ctx.go('/cases/$caseId/damage'),
        child: _extentOfDamageContent(damage),
      ),
      _SectionCard(
        accentColor: AppColors.midBlue,
        icon: Icons.build_outlined,
        title: 'Repairs',
        countLabel: repairPeriods.isEmpty ? null : '${repairPeriods.length} period${repairPeriods.length == 1 ? '' : 's'}',
        initiallyExpanded: repairPeriods.isNotEmpty,
        onOpen: () => ctx.go('/cases/$caseId/damage'),
        child: _repairsContent(repairPeriods),
      ),
      _SectionCard(
        accentColor: AppColors.purple,
        icon: Icons.more_horiz_outlined,
        title: 'Other Matters of Relevance',
        onOpen: () => ctx.go('/cases/$caseId/reports'),
        child:
            const _SectionEmpty('Other matters — draft in Report Builder'),
      ),
      _SectionCard(
        accentColor: AppColors.amber,
        icon: Icons.gavel_outlined,
        title: 'Cause Consideration',
        onOpen: () => ctx.go('/cases/$caseId/damage'),
        child: _causationContent(occ),
      ),
      _SectionCard(
        accentColor: AppColors.green,
        icon: Icons.receipt_outlined,
        title: 'Repair Cost',
        onOpen: () => ctx.go('/cases/$caseId/damage'),
        child: const _SectionEmpty('Invoices module — Phase 1.1'),
      ),
      _SectionCard(
        accentColor: AppColors.teal,
        icon: Icons.anchor_outlined,
        title: 'Dry Docking / Temporary Repairs',
        onOpen: () => ctx.go('/cases/$caseId/damage'),
        child: const _SectionEmpty(
            'Drydock details — enter in Damage Register'),
      ),
      _SectionCard(
        accentColor: AppColors.midBlue,
        icon: Icons.attach_money_outlined,
        title: 'Extra Expenses / General Expenses',
        onOpen: () => ctx.go('/cases/$caseId/damage'),
        child: const _SectionEmpty('Extra expenses — Phase 1.1'),
      ),
      _SectionCard(
        accentColor: AppColors.textSecondary,
        icon: Icons.remove_circle_outline,
        title: 'Work Not Concerning Average',
        onOpen: () => ctx.go('/cases/$caseId/damage'),
        child: _notAverageContent(damage),
      ),
      _SectionCard(
        accentColor: AppColors.navy,
        icon: Icons.schedule_outlined,
        title: 'Summary of Time for Repairs',
        onOpen: () => ctx.go('/cases/$caseId/damage'),
        child: const _SectionEmpty(
            'Repair times — enter in Damage Register'),
      ),
      _SectionCard(
        accentColor: AppColors.midBlue,
        icon: Icons.description_outlined,
        title: 'Report Status',
        onOpen: () => ctx.go('/cases/$caseId/reports'),
        child: _reportStatusContent(),
      ),
    ];
  }

  // ── Content builders ──────────────────────────────────────────────────────

  Widget _vesselAblTable(VesselModel? vessel) {
    if (vessel == null) {
      return const _SectionEmpty('No vessel added — tap Open to begin');
    }
    return _fieldWrap([
      ('Name', vessel.name),
      ('Type', vessel.vesselType),
      ('Flag', vessel.flag),
      ('IMO No.', vessel.imoNumber),
      ('GT / NT',
          vessel.grossTonnage != null
              ? '${vessel.grossTonnage!.toStringAsFixed(0)} / ${vessel.netTonnage?.toStringAsFixed(0) ?? '—'}'
              : null),
      ('DWT',
          vessel.deadweight != null
              ? '${vessel.deadweight!.toStringAsFixed(0)} t'
              : null),
      ('Built',
          vessel.yearBuilt != null
              ? [vessel.yearBuilt.toString(), vessel.buildYard]
                  .whereType<String>()
                  .join(', ')
              : null),
      ('Owners', vessel.owners),
      ('Class',
          vessel.classSociety != null
              ? '${vessel.classSociety} ${vessel.classNotation ?? ''}'.trim()
              : null),
      ('LOA / LBP',
          vessel.lengthOa != null
              ? '${vessel.lengthOa!.toStringAsFixed(0)} / ${vessel.lengthBp?.toStringAsFixed(0) ?? '—'} m'
              : null),
      ('B × D',
          vessel.breadth != null
              ? '${vessel.breadth!.toStringAsFixed(0)} × ${vessel.depth?.toStringAsFixed(0) ?? '—'} m'
              : null),
      ('Max Draft',
          vessel.maxDraft != null
              ? '${vessel.maxDraft!.toStringAsFixed(1)} m'
              : null),
      ('Speed',
          vessel.serviceSpeed != null
              ? '${vessel.serviceSpeed!.toStringAsFixed(1)} kn'
              : null),
    ]);
  }

  Widget _vesselNordicTable(VesselModel? vessel) {
    if (vessel == null) {
      return const _SectionEmpty('No vessel added — tap Open to begin');
    }
    return _fieldWrap([
      ('Vessel Type', vessel.vesselType),
      ('IMO No.', vessel.imoNumber),
      ('GT', vessel.grossTonnage?.toStringAsFixed(0)),
      ('Flag', vessel.flag),
      ('Port of Registry', vessel.portOfRegistry),
      ('Year Built', vessel.yearBuilt?.toString()),
      ('Build Yard', vessel.buildYard),
      ('Owners', vessel.owners),
      ('Operators', vessel.operators),
      ('Class Society', vessel.classSociety),
      ('Class Notation', vessel.classNotation),
      ('LOA / LBP',
          vessel.lengthOa != null
              ? '${vessel.lengthOa!.toStringAsFixed(0)} / ${vessel.lengthBp?.toStringAsFixed(0) ?? '—'} m'
              : null),
      ('B × D',
          vessel.breadth != null
              ? '${vessel.breadth!.toStringAsFixed(0)} × ${vessel.depth?.toStringAsFixed(0) ?? '—'} m'
              : null),
      ('DWT',
          vessel.deadweight != null
              ? '${vessel.deadweight!.toStringAsFixed(0)} t'
              : null),
      ('Max Draft',
          vessel.maxDraft != null
              ? '${vessel.maxDraft!.toStringAsFixed(1)} m'
              : null),
      ('Speed',
          vessel.serviceSpeed != null
              ? '${vessel.serviceSpeed!.toStringAsFixed(1)} kn'
              : null),
    ]);
  }

  Widget _fieldWrap(List<(String, String?)> rows) {
    final filled =
        rows.where((r) => r.$2 != null && r.$2!.isNotEmpty).toList();
    if (filled.isEmpty) return const _SectionEmpty('No data saved yet');
    return Wrap(
      spacing: 8,
      runSpacing: 2,
      children: filled
          .map((r) => SizedBox(
                width: 190,
                child: _FieldRow(label: r.$1, value: r.$2!),
              ))
          .toList(),
    );
  }

  Widget _occurrenceContent(DamageState? damage) {
    if (damage == null || damage.occurrences.isEmpty) {
      return const _SectionEmpty(
          'No occurrences recorded — tap Open to add');
    }
    return Column(
      children: damage.occurrences.map((occ) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.lightCoral,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      occ.title ?? 'Occurrence ${occ.occurrenceNo}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.coral),
                    ),
                  ),
                  if (occ.dateTime != null)
                    Text(
                      '${occ.dateTime!.day.toString().padLeft(2, '0')}/${occ.dateTime!.month.toString().padLeft(2, '0')}/${occ.dateTime!.year}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                ],
              ),
              if (occ.location != null) ...[
                const SizedBox(height: 3),
                Text(occ.location!,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
              if (occ.briefDescription != null &&
                  occ.briefDescription!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  occ.briefDescription!.length > 140
                      ? '${occ.briefDescription!.substring(0, 140)}…'
                      : occ.briefDescription!,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _extentOfDamageContent(DamageState? damage) {
    if (damage == null || damage.damageItems.isEmpty) {
      return const _SectionEmpty(
          'No damage items recorded — tap Open to add');
    }
    return Column(
      children: damage.damageItems.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 5, right: 8),
                decoration: BoxDecoration(
                  color: item.isConcerningAverage
                      ? AppColors.coral
                      : AppColors.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.componentName,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary),
                    ),
                    if (item.damageDescription != null &&
                        item.damageDescription!.isNotEmpty)
                      Text(
                        item.damageDescription!.length > 90
                            ? '${item.damageDescription!.substring(0, 90)}…'
                            : item.damageDescription!,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              if (item.repairType != null)
                _StatusChip(
                    label: item.repairType!.label, color: AppColors.midBlue),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _causationContent(OccurrenceModel? occ) {
    if (occ == null) {
      return const _SectionEmpty(
          'No occurrence recorded — tap Open to add');
    }
    if (occ.allegationType != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.lightAmber,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Allegation type: ${occ.allegationType}',
          style: const TextStyle(
              fontSize: 11,
              color: AppColors.amber,
              fontWeight: FontWeight.w500),
        ),
      );
    }
    if (occ.causeNarrative != null && occ.causeNarrative!.isNotEmpty) {
      final text = occ.causeNarrative!;
      return Text(
        text.length > 250 ? '${text.substring(0, 250)}…' : text,
        style: const TextStyle(
            fontSize: 11, color: AppColors.textSecondary),
      );
    }
    return const _SectionEmpty(
        'Cause / allegation — enter in Occurrence or draft in Report Builder');
  }

  Widget _repairsContent(List<RepairPeriodModel> periods) {
    if (periods.isEmpty) {
      return const _SectionEmpty('No repair periods — tap Open to add');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: periods.map((period) {
        final contextColor = period.portContext == PortContext.planned
            ? AppColors.success
            : AppColors.warning;
        final assignedCount = period.assignments.length;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.lightBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A6B9E),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Center(
                  child: Text(
                    '${period.periodNo}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      period.displayTitle,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                    if (assignedCount > 0)
                      Text(
                        '$assignedCount item${assignedCount == 1 ? '' : 's'} assigned',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              _StatusChip(
                  label: period.portContext.label.split(' ').first,
                  color: contextColor),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _narrativeContent(String? text, String emptyHint) {
    if (text == null || text.isEmpty) return _SectionEmpty(emptyHint);
    return Text(
      text.length > 250 ? '${text.substring(0, 250)}…' : text,
      style:
          const TextStyle(fontSize: 11, color: AppColors.textSecondary),
    );
  }

  Widget _availableInfoContent(List<DocumentModel> docs) {
    if (docs.isEmpty) {
      return const _SectionEmpty('No documents imported yet');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(
              child: Text('Document',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary)),
            ),
            Text('Availability',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary)),
          ],
        ),
        const Divider(height: 8, color: AppColors.border),
        ...docs.map((d) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(d.title,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                    d.availability.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: d.availability.value == 'enclosed'
                          ? AppColors.success
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _documentsContent(List<DocumentModel> docs) {
    if (docs.isEmpty) {
      return const _SectionEmpty('No documents imported yet');
    }
    final byCategory = <String, int>{};
    for (final d in docs) {
      final cat = d.docCategory?.label ?? 'Other';
      byCategory[cat] = (byCategory[cat] ?? 0) + 1;
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: byCategory.entries
          .map((e) => _CategoryChip(label: e.key, count: e.value))
          .toList(),
    );
  }

  Widget _voiceContent(List<VoiceNoteModel> voices) {
    if (voices.isEmpty) return const _SectionEmpty('No recordings yet');
    final transcribed = voices
        .where((n) => n.status == 'transcribed' || n.status == 'routed')
        .length;
    final pending = voices.where((n) => n.status == 'pending').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatPill(
                label: 'Transcribed',
                value: transcribed,
                color: AppColors.purple),
            if (pending > 0) ...[
              const SizedBox(width: 6),
              _StatPill(
                  label: 'Pending',
                  value: pending,
                  color: AppColors.warning),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ...voices.take(3).map((n) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.graphic_eq,
                      size: 13,
                      color: AppColors.purple.withValues(alpha: 0.5)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      n.transcript?.isNotEmpty == true
                          ? n.transcript!.length > 100
                              ? '${n.transcript!.substring(0, 100)}…'
                              : n.transcript!
                          : 'No transcript yet',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _attendeesContent(List<AttendeeModel> attendees) {
    if (attendees.isEmpty) {
      return const _SectionEmpty('No attendees recorded yet');
    }
    return Column(
      children: attendees.map((a) => _AttendeeRow(attendee: a)).toList(),
    );
  }

  Widget _partiesContent(
      CasePartiesModel? parties, List<AssuredContactModel> contacts) {
    if (parties == null || parties.isEmpty) {
      return const _SectionEmpty('No parties recorded — tap Open to add');
    }
    final rows = <(String, String)>[];
    if (parties.principalCompany != null || parties.principalName != null) {
      rows.add(('Principal',
          [parties.principalName, parties.principalCompany]
              .whereType<String>()
              .join(' · ')));
    }
    if (parties.reviewerName != null || parties.reviewerCompany != null) {
      rows.add(('Reviewer',
          [parties.reviewerName, parties.reviewerCompany]
              .whereType<String>()
              .join(' · ')));
    }
    if (parties.underwriterCompany != null ||
        parties.underwriterName != null) {
      rows.add(('Underwriter',
          [parties.underwriterName, parties.underwriterCompany]
              .whereType<String>()
              .join(' · ')));
    }
    if (parties.adjusterName != null || parties.adjusterCompany != null) {
      rows.add(('Adjuster',
          [parties.adjusterName, parties.adjusterCompany]
              .whereType<String>()
              .join(' · ')));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...rows.map((r) => _FieldRow(label: r.$1, value: r.$2)),
        if (contacts.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Assured: ${contacts.map((c) => c.fullName).join(', ')}',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _visitsContent(List<SurveyAttendanceModel> visits) {
    if (visits.isEmpty) {
      return const _SectionEmpty('No visits recorded — tap Open to add');
    }
    return Column(
      children: visits.map((v) {
        final dateStr = v.attendanceDate != null
            ? '${v.attendanceDate!.day.toString().padLeft(2, '0')}/'
                '${v.attendanceDate!.month.toString().padLeft(2, '0')}/'
                '${v.attendanceDate!.year}'
            : 'TBC';
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 5, right: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFBF7E3A),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          v.attendanceType.label,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 6),
                        Text(dateStr,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                    if (v.location != null)
                      Text(v.location!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    if (v.vesselStatus != null)
                      Text(v.vesselStatus!.label,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Timeline helpers ──────────────────────────────────────────────────────

  String? _timelineCount(
    List<TimelineEventModel> timeline,
    List<SurveyAttendanceModel> visits,
    DamageState? damage,
  ) {
    int n = timeline.length + visits.length;
    n += damage?.occurrences.where((o) => o.dateTime != null).length ?? 0;
    n += damage?.repairs.where((r) => r.completionDate != null).length ?? 0;
    return n == 0 ? null : '$n events';
  }

  Widget _timelineContent(
    List<TimelineEventModel> manual,
    List<SurveyAttendanceModel> visits,
    DamageState? damage,
  ) {
    // Build a flat merged list of (date, label, color) for preview
    final entries = <(DateTime?, String, Color)>[];

    for (final occ in damage?.occurrences ?? []) {
      if (occ.dateTime != null) {
        entries.add((
          occ.dateTime,
          occ.title ?? 'Incident / Occurrence',
          AppColors.coral,
        ));
      }
    }
    for (final v in visits) {
      entries.add((
        v.attendanceDate,
        v.attendanceType.label,
        const Color(0xFFBF7E3A),
      ));
    }
    for (final r in damage?.repairs ?? []) {
      if (r.completionDate != null) {
        entries.add((
          r.completionDate,
          '${r.repairType.label} repairs completed',
          AppColors.success,
        ));
      }
    }
    for (final ev in manual) {
      entries.add((
        ev.eventDate,
        ev.title ?? ev.eventType.label,
        _kTimelineColor,
      ));
    }

    entries.sort((a, b) {
      if (a.$1 == null && b.$1 == null) return 0;
      if (a.$1 == null) return 1;
      if (b.$1 == null) return -1;
      return a.$1!.compareTo(b.$1!);
    });

    if (entries.isEmpty) {
      return const _SectionEmpty(
          'No events yet — occurrences, attendances and repairs appear automatically');
    }

    final show = entries.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...show.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(top: 3, right: 8),
                    decoration:
                        BoxDecoration(color: e.$3, shape: BoxShape.circle),
                  ),
                  if (e.$1 != null)
                    Text(
                      '${e.$1!.day.toString().padLeft(2, '0')}/'
                      '${e.$1!.month.toString().padLeft(2, '0')}/'
                      '${e.$1!.year}  ',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textTertiary),
                    ),
                  Expanded(
                    child: Text(
                      e.$2,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
        if (entries.length > 6)
          Text(
            '+ ${entries.length - 6} more events',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textTertiary),
          ),
      ],
    );
  }

  Widget _notAverageContent(DamageState? damage) {
    if (damage == null) return const _SectionEmpty('No damage data');
    final ownerItems =
        damage.damageItems.where((d) => !d.isConcerningAverage).toList();
    if (ownerItems.isEmpty) {
      return const _SectionEmpty('No items excluded from average');
    }
    return Column(
      children: ownerItems
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.remove_circle_outline,
                        size: 12, color: AppColors.textTertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(item.componentName,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ),
                    if (item.exclusionReason != null)
                      Text(item.exclusionReason!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _reportStatusContent() {
    final stages = <(String, bool)>[
      ('Preliminary', survey.status != CaseStatus.open),
      (
        'Advice',
        survey.status == CaseStatus.adviceIssued ||
            survey.status == CaseStatus.finalIssued ||
            survey.status == CaseStatus.closed
      ),
      (
        'Final',
        survey.status == CaseStatus.finalIssued ||
            survey.status == CaseStatus.closed
      ),
    ];
    return Row(
      children: stages
          .map((s) => Expanded(
                child: Row(
                  children: [
                    Icon(
                      s.$2
                          ? Icons.check_circle_outline
                          : Icons.radio_button_unchecked,
                      size: 14,
                      color:
                          s.$2 ? AppColors.success : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        s.$1,
                        style: TextStyle(
                          fontSize: 11,
                          color: s.$2
                              ? AppColors.success
                              : AppColors.textTertiary,
                          fontWeight:
                              s.$2 ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _checklistContent() {
    final pct = (checklistProgress * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: checklistProgress,
            minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(
                checklistProgress >= 1.0
                    ? AppColors.success
                    : AppColors.green),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          checklistProgress >= 1.0
              ? 'All checklist items complete'
              : '$pct% complete — ${((1 - checklistProgress) * 100).round()}% remaining',
          style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

}

// ── Case info banner ──────────────────────────────────────────────────────

class _CaseBanner extends StatelessWidget {
  const _CaseBanner({required this.survey});
  final CaseModel survey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.lightPurple,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              survey.caseType.label,
              style: const TextStyle(
                  color: AppColors.purple,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
          if (survey.outputFormat != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                survey.outputFormat!.label,
                style: const TextStyle(
                    color: AppColors.midBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const Spacer(),
          if (survey.clientName != null)
            Text(survey.clientName!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          if (survey.instructionDate != null) ...[
            const SizedBox(width: 10),
            Text(
              _fmtDate(survey.instructionDate!),
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Section card shell ────────────────────────────────────────────────────

class _SectionCard extends StatefulWidget {
  const _SectionCard({
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.onOpen,
    required this.child,
    this.countLabel,
    this.initiallyExpanded = false,
  });

  final Color accentColor;
  final IconData icon;
  final String title;
  final VoidCallback onOpen;
  final Widget child;
  final String? countLabel;
  final bool initiallyExpanded;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              // Tap to expand (icon + title area)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(widget.icon,
                              color: widget.accentColor, size: 17),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.title,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                        ),
                        if (widget.countLabel != null) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              widget.countLabel!,
                              style: TextStyle(
                                  color: widget.accentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // Open button (separate tap target)
              GestureDetector(
                onTap: widget.onOpen,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'Open',
                    style: TextStyle(
                        color: widget.accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              // Expand/collapse toggle arrow
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                  child: AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: AppColors.textTertiary, size: 20),
                  ),
                ),
              ),
            ],
          ),
          // ── Body ────────────────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(
                    height: 1,
                    thickness: 1,
                    color: widget.accentColor.withValues(alpha: 0.15)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: widget.child,
                ),
              ],
            ),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

// ── Section content helper widgets ──────────────────────────────────────

class _AttendeeRow extends StatelessWidget {
  const _AttendeeRow({required this.attendee});
  final AttendeeModel attendee;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              attendee.fullName,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              attendee.rankPosition ?? attendee.roleType?.label ?? '',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              attendee.representing ?? attendee.company ?? '',
              style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.lightAmber,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label · \$count',
        style: const TextStyle(
            fontSize: 11, color: AppColors.amber, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 9, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Shared micro-widgets ──────────────────────────────────────────────────

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill(
      {required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$value $label',
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}


class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        message,
        style: const TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
            fontStyle: FontStyle.italic),
      ),
    );
  }
}
