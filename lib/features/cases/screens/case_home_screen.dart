// lib/features/cases/screens/case_home_screen.dart
//
// Main case hub: vertical nav rail (left) + pseudo-report overview (right).
// AppBar carries a checklist progress bar at its base.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/cases_provider.dart';
import '../../../shared/utils/error_handler.dart';
import '../models/case_model.dart';
import '../../../core/providers/import_review.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/error_widget.dart';
import '../../survey/providers/damage_provider.dart';
import '../../survey/providers/attendees_provider.dart';
import '../../attendances/providers/attendances_provider.dart';
import '../../attendances/models/attendance_model.dart';
import '../../timeline/providers/timeline_provider.dart';
import '../../timeline/models/timeline_event_model.dart';
import '../../survey/providers/repair_period_provider.dart';
import '../../survey/models/repair_period_model.dart';
import '../../survey/providers/nature_of_repairs_provider.dart';
import '../../survey/models/nature_of_repairs_model.dart';
import '../../surveyor_notes/providers/surveyor_notes_provider.dart';
import '../../surveyor_notes/models/surveyor_note_model.dart';
import '../../correspondence/providers/case_inbox_provider.dart';
import '../../../shared/widgets/context_cues_panel.dart' show repairPeriodLinkType;
import '../../accounts/providers/accounts_provider.dart';
import '../../accounts/models/accounts_models.dart';
import '../../vessel/providers/certificates_provider.dart';
import '../../vessel/providers/vessel_provider.dart';
import '../../vessel/screens/vessel_compliance_screen.dart';
import '../../reports/providers/case_completeness_provider.dart';
import '../../reports/providers/report_provider.dart';
import '../../reports/utils/case_completeness.dart';
import '../../action_items/providers/action_items_provider.dart';
import '../../documents/providers/document_provider.dart';
import '../../documents/utils/document_request_email.dart';
import '../../parties/providers/parties_provider.dart';
import '../../../core/services/gmail_service.dart';
import '../../capture/screens/camera_screen.dart' show QuickCaptureSheet;
import '../../ai_tasks/widgets/ai_task_indicator.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/photo_picker_sheet.dart';
import '../../photos/providers/photo_provider.dart';

const _kTimelineColor = Color(0xFF2E7CB7);

// ── Shell ─────────────────────────────────────────────────────────────────

class CaseHomeScreen extends ConsumerWidget {
  const CaseHomeScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caseAsync = ref.watch(caseProvider(caseId));
    final progressAsync = ref.watch(checklistProgressProvider(caseId));

    return caseAsync.when(
      loading: () => const Scaffold(body: AppLoadingWidget()),
      error: (e, _) => Scaffold(body: AppErrorWidget(error: e.toString())),
      data: (survey) => _CaseHomeView(
        caseId: caseId,
        survey: survey,
        checklistProgress: progressAsync.value ?? 0,
        onDeleteCase: () => _deleteCase(context, ref, survey),
      ),
    );
  }

  Future<void> _deleteCase(
      BuildContext context, WidgetRef ref, CaseModel survey) async {
    final label = survey.title ?? survey.vesselName ?? survey.technicalFileNo;

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
    } catch (e, st) {
      if (context.mounted) showError(context, 'Delete failed: $e', error: e, stack: st, tag: 'App');
    }
  }
}

// ── Scaffold ──────────────────────────────────────────────────────────────

class _CaseHomeView extends StatelessWidget {
  const _CaseHomeView({
    required this.caseId,
    required this.survey,
    required this.checklistProgress,
    required this.onDeleteCase,
  });

  final String caseId;
  final CaseModel survey;
  final double checklistProgress;
  final VoidCallback onDeleteCase;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
          _SurveyNavRail(caseId: caseId),
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
      // TODO.md §3.6 (8 July 2026): previously showed the full composite
      // case title (job no. – vessel – survey type – occurrence brief,
      // see project_case_title_format) as the primary line — often long
      // enough to truncate/feel "not always visible". Vessel name now
      // leads (short, single line), with the rest as a subline instead.
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            survey.vesselName ?? survey.title ?? survey.technicalFileNo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
          ),
          Text(
            [
              survey.caseType.label,
              survey.technicalFileNo,
              if ((survey.instructingParty ?? '').isNotEmpty)
                survey.instructingParty!,
            ].join(' – '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65), fontSize: 11),
          ),
        ],
      ),
      actions: [
        // TODO.md §3.6 (8 July 2026): existed visually but wasn't wired to
        // navigate — now the checklist quick-link it looks like.
        InkWell(
          onTap: () => context.go('/cases/${survey.caseId}/checklist'),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
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
        const AiTaskIndicator(),
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

class _SurveyNavRail extends ConsumerWidget {
  const _SurveyNavRail({required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caseModel = ref.watch(caseProvider(caseId)).value;
    final notes = ref.watch(surveyorNotesProvider(caseId)).value ?? [];
    final unallocatedCount = notes
        .where((n) =>
            n.caseSection == null && n.priority != CuePriority.ignored)
        .length;
    // New (filtered, not-yet-imported) mail matching this case — same count
    // shown on the Correspondence app-bar (16 July 2026 reports).
    final newMailCount = ref.watch(caseNewMailCountProvider(caseId)).value ?? 0;

    return Container(
      width: 68,
      color: const Color(0xFFD5E8F5),
      child: Column(
        children: [
          // ── Case editor header (fixed, not scrolled) ─────────────────
          _CaseEditorButton(caseId: caseId, caseModel: caseModel),
          const Divider(height: 1, color: Color(0xFFB8D5EC)),
          // ── Nav items scroll in landscape ────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 4),
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
                    icon: Icons.photo_library_outlined,
                    label: 'Photos',
                    accent: AppColors.purple,
                    onTap: () => context.go('/cases/$caseId/photos'),
                  ),
                  _NavItem(
                    icon: Icons.checklist_outlined,
                    label: 'Checklist',
                    accent: AppColors.green,
                    onTap: () => context.go('/cases/$caseId/checklist'),
                  ),
                  _NavItem(
                    icon: Icons.mail_outline,
                    label: 'Mail',
                    accent: const Color(0xFF2A6099),
                    badgeCount: newMailCount,
                    onTap: () => context.go('/cases/$caseId/correspondence'),
                  ),
                  _NavItem(
                    icon: Icons.sticky_note_2_outlined,
                    // Reverted to "Notes" (16 July 2026): the 14 July rename to
                    // "Advice to Owner" was a misunderstanding — this is the
                    // surveyor's notes screen (SurveyorNotesScreen, /notes),
                    // not an owner-advice document. Kept the /notes route.
                    label: 'Notes',
                    accent: const Color(0xFF4A7A5A),
                    badgeCount: unallocatedCount,
                    onTap: () => context.go('/cases/$caseId/notes'),
                  ),
                  _NavItem(
                    icon: Icons.health_and_safety_outlined,
                    label: 'HSE',
                    accent: const Color(0xFFD4500A),
                    onTap: () => context.go('/cases/$caseId/hse'),
                  ),
                  _NavItem(
                    icon: Icons.auto_awesome_outlined,
                    label: 'Analyst',
                    accent: const Color(0xFF1E3A5F),
                    onTap: () => context.go('/cases/$caseId/analyst'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Case editor button (top of nav rail) ──────────────────────────────────

class _CaseEditorButton extends StatelessWidget {
  const _CaseEditorButton({required this.caseId, required this.caseModel});
  final String caseId;
  final CaseModel? caseModel;

  @override
  Widget build(BuildContext context) {
    const jobNo = 'Case';

    return Tooltip(
      message: 'Edit case details',
      child: InkWell(
        onTap: () => context.go('/cases/$caseId/edit'),
        child: SizedBox(
          width: 68,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_note_outlined,
                      color: AppColors.navy, size: 20),
                ),
                const SizedBox(height: 3),
                const Text(
                  jobNo,
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bottom capture toolbar ────────────────────────────────────────────────

class _CaptureToolbar extends ConsumerWidget {
  const _CaptureToolbar({required this.caseId});
  final String caseId;

  // The dedicated /camera route was a stub ("coming next session") that
  // never actually captured anything — a live regression flagged in the
  // 14 July 2026 walkthrough. Reuse the same camera-capture + upload path
  // already used everywhere else in the app (PhotoPickerSheet.resolveBytes
  // + photosProvider.addPhoto) instead of routing to the stub screen.
  Future<void> _captureAndUpload(BuildContext context, WidgetRef ref) async {
    final bytesList = await PhotoPickerSheet.resolveBytes(
        PhotoPickSource.camera,
        context: context);
    if (bytesList.isEmpty || !context.mounted) return;
    try {
      await ref
          .read(photosProvider(caseId).notifier)
          .addPhoto(caseId: caseId, bytes: bytesList.first);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Photo added')));
      }
    } catch (e) {
      // A failed upload (e.g. connection abort mid-upload) must not crash the
      // capture flow — the photo is cached/queued locally and syncs later.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Photo saved locally — will sync when back online. ($e)')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            onTap: () => _captureAndUpload(context, ref),
          ),
          // Scan Doc — capture a document, detect its outline, dewarp it flat,
          // then save to the Doc Vault and queue it for AI extraction (reuses
          // the vault's scan pipeline via ?scan=1).
          _CaptureToolButton(
            icon: Icons.document_scanner_outlined,
            label: 'Scan Doc',
            accent: AppColors.navy,
            onTap: () => context.go('/cases/$caseId/documents?scan=1'),
          ),
          _CaptureToolButton(
            icon: Icons.record_voice_over_outlined,
            label: 'Interview',
            accent: AppColors.purple,
            onTap: () => context.go('/cases/$caseId/interview'),
          ),
          _CaptureToolButton(
            icon: Icons.draw_outlined,
            label: 'Stylus',
            accent: AppColors.navy,
            onTap: () => context.go('/cases/$caseId/stylus'),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.85),
                    fontSize: 10,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                  ),
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
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  final int badgeCount;

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
                  if (badgeCount > 0)
                    Positioned(
                      top: 0,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFD5E8F5), width: 1.5),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
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

// ── Case completeness (§4.3) ────────────────────────────────────────────

/// Compact "is this case ready" summary — a progress bar over the five
/// required sections (see case_completeness.dart for what counts) plus a
/// tap-to-expand breakdown covering the optional/tracked ones too.
class _CompletenessCard extends StatefulWidget {
  const _CompletenessCard({required this.completeness});
  final CaseCompleteness completeness;

  @override
  State<_CompletenessCard> createState() => _CompletenessCardState();
}

class _CompletenessCardState extends State<_CompletenessCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.completeness;
    final ratio = c.requiredTotal == 0 ? 0.0 : c.requiredComplete / c.requiredTotal;
    final color = c.isFullyComplete ? AppColors.success : AppColors.amber;

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
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    c.isFullyComplete
                        ? Icons.check_circle_outline
                        : Icons.donut_large_outlined,
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.isFullyComplete
                              ? 'Case ready — all required sections populated'
                              : '${c.requiredComplete} of ${c.requiredTotal} '
                                  'required sections complete',
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 5,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textTertiary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: c.sections
                    .map((s) => _CompletenessChip(section: s))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompletenessChip extends StatelessWidget {
  const _CompletenessChip({required this.section});
  final SectionCompleteness section;

  @override
  Widget build(BuildContext context) {
    final color = section.complete
        ? AppColors.success
        : (section.required ? AppColors.error : AppColors.textTertiary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(section.complete ? Icons.check : Icons.remove,
              size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            section.required ? section.label : '${section.label} (optional)',
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
          ),
        ],
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
    final damage = ref.watch(damageProvider(caseId)).value;
    final attendees = ref.watch(attendeesProvider(caseId)).value ?? [];
    final visits = ref.watch(attendancesProvider(caseId)).value ?? [];
    final timeline = ref.watch(timelineProvider(caseId)).value ?? [];
    final repairPeriods = ref.watch(repairPeriodsProvider(caseId)).value ?? [];
    final natureOfRepairs = ref.watch(natureOfRepairsProvider(caseId)).value;
    final repairDocs = ref.watch(repairDocumentsProvider(caseId)).value ?? [];
    final certs = ref.watch(certificatesProvider(caseId)).value ?? [];
    final outputs = ref.watch(reportOutputsProvider(caseId)).value ?? [];
    final vessel = ref.watch(vesselForCaseProvider(caseId)).value;
    final documents = ref.watch(documentProvider(caseId)).value ?? [];
    final surveyorNotes = ref.watch(surveyorNotesProvider(caseId)).value ?? [];

    // Show amber left-border highlight on sections touched by the latest import.
    final review = ref.watch(importReviewProvider);
    final highlighted = (review?.caseId == caseId)
        ? review!.affectedSections
        : const <String>{};

    final List<Widget> sections = _sections(
        context, damage, attendees, visits, timeline, repairPeriods,
        natureOfRepairs, repairDocs, certs, outputs, vessel, documents,
        surveyorNotes, survey,
        highlighted: highlighted);

    // §4.7: open + pending-review action item count for the entry-point
    // card — inserted at the very top of the section list (2026-07-13
    // audit: surveyor wants "what needs doing" as the first thing seen,
    // right under the Completeness card).
    final actionItems = ref.watch(actionItemsProvider(caseId)).value ?? [];
    final openActionItems = actionItems
        .where((i) =>
            i.pendingReview || i.status == ActionItemStatus.open)
        .length;
    sections.insert(
      0,
      _SectionCard(
        accentColor: AppColors.purple,
        icon: Icons.checklist_outlined,
        title: 'Action Items',
        countLabel: openActionItems == 0 ? null : '$openActionItems',
        onOpen: () => context.go('/cases/$caseId/action-items'),
        child: openActionItems == 0
            ? const _SectionEmpty('No open action items')
            : Text('$openActionItems item${openActionItems == 1 ? '' : 's'} '
                'need attention — tap Open to review',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
      ),
    );

    // §4.3: case-wide completeness — shared provider (case_completeness_
    // provider.dart) so this and the Checklist auto-tick engine read the
    // exact same computation instead of two hand-maintained copies.
    final completeness = ref.watch(caseCompletenessProvider(caseId));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CompletenessCard(completeness: completeness),
          const SizedBox(height: 8),
          for (final s in sections) ...[s, const SizedBox(height: 8)],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Unified sections (format differences handled at report builder stage) ──

  List<Widget> _sections(
    BuildContext ctx,
    DamageState? damage,
    List<AttendeeModel> attendees,
    List<SurveyAttendanceModel> visits,
    List<TimelineEventModel> timeline,
    List<RepairPeriodModel> repairPeriods,
    NatureOfRepairs? natureOfRepairs,
    List<RepairDocumentModel> repairDocs,
    List<CertificateModel> certs,
    List<ReportOutput> outputs,
    VesselModel? vessel,
    List<DocumentModel> documents,
    List<SurveyorNote> surveyorNotes,
    CaseModel survey, {
    Set<String> highlighted = const <String>{},
  }) {
    final occ = damage?.primaryOccurrence ?? damage?.occurrences.firstOrNull;
    final attendanceCount = visits.length;
    return [
      _SectionCard(
        accentColor: const Color(0xFFBF7E3A),
        icon: Icons.people_outline,
        title: 'Attendance & Representatives',
        countLabel: attendanceCount == 0 ? null : '$attendanceCount',
        initiallyExpanded: attendanceCount > 0,
        highlighted: highlighted.contains('attendees'),
        onOpen: () => ctx.go('/cases/$caseId/attendances'),
        child: _attendanceContent(visits, attendees),
      ),
      _SectionCard(
        accentColor: AppColors.purple,
        icon: Icons.verified_outlined,
        title: 'Certificates & Class',
        countLabel: certs.isEmpty ? null : '${certs.length}',
        initiallyExpanded: certs.isNotEmpty,
        onOpen: () => Navigator.push(ctx,
            MaterialPageRoute(
                builder: (_) => VesselComplianceScreen(caseId: caseId))),
        child: _complianceContent(certs, vessel),
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
        icon: Icons.event_note_outlined,
        title: 'Occurrence',
        countLabel: (damage?.occurrences.length ?? 0) > 0
            ? '${damage!.occurrences.length}'
            : null,
        initiallyExpanded: occ != null,
        highlighted: highlighted.contains('occurrences'),
        onOpen: () => ctx.go('/cases/$caseId/occurrence'),
        child: _occurrenceContent(damage),
      ),
      _SectionCard(
        accentColor: AppColors.midBlue,
        icon: Icons.history_outlined,
        title: 'Background',
        onOpen: () => ctx.go('/cases/$caseId/background'),
        child: _narrativeContent(
          occ?.backgroundNarrative,
          'Background narrative — tap Open to edit',
        ),
      ),
      _SectionCard(
        accentColor: AppColors.amber,
        icon: Icons.gavel_outlined,
        title: 'Allegation / Causation',
        onOpen: () => ctx.go('/cases/$caseId/causation'),
        child: _causationContent(occ),
      ),
      _SectionCard(
        accentColor: AppColors.coral,
        icon: Icons.warning_amber_outlined,
        title: 'Extent of Damage',
        countLabel: (damage?.totalDamageItems ?? 0) > 0
            ? '${damage!.totalDamageItems} items'
            : null,
        initiallyExpanded: (damage?.totalDamageItems ?? 0) > 0,
        highlighted: highlighted.contains('damage'),
        onOpen: () => ctx.go('/cases/$caseId/damage'),
        child: _extentOfDamageContent(damage),
      ),
      _SectionCard(
        accentColor: AppColors.teal,
        icon: Icons.fact_check_outlined,
        title: 'Nature of the Repairs',
        countLabel: () {
          final n = _natureOfRepairsCount(natureOfRepairs);
          return n == 0 ? null : '$n';
        }(),
        onOpen: () => ctx.go('/cases/$caseId/nature-of-repairs'),
        child: _natureOfRepairsContent(natureOfRepairs),
      ),
      _SectionCard(
        accentColor: AppColors.midBlue,
        icon: Icons.build_outlined,
        title: 'Repair Periods',
        countLabel: repairPeriods.isEmpty
            ? null
            : '${repairPeriods.length} period${repairPeriods.length == 1 ? '' : 's'}',
        initiallyExpanded: repairPeriods.isNotEmpty,
        onOpen: () => ctx.go('/cases/$caseId/repairs'),
        child: _repairsContent(repairPeriods),
      ),
      _SectionCard(
        accentColor: AppColors.textSecondary,
        icon: Icons.remove_circle_outline,
        title: 'Work Not Concerning Average',
        countLabel: () {
          final n = _repairPeriodScopedCueCount(
              surveyorNotes, CaseSection.notAverage);
          return n == 0 ? null : '$n';
        }(),
        onOpen: () => ctx.go('/cases/$caseId/wnca'),
        child: _repairPeriodScopedContent(
            surveyorNotes, repairPeriods, CaseSection.notAverage),
      ),
      _SectionCard(
        accentColor: AppColors.green,
        icon: Icons.build_circle_outlined,
        title: 'General Services & Access',
        countLabel: () {
          final n = _repairPeriodScopedCueCount(
              surveyorNotes, CaseSection.generalExpenses);
          return n == 0 ? null : '$n';
        }(),
        onOpen: () => ctx.go('/cases/$caseId/general-expenses'),
        child: _repairPeriodScopedContent(
            surveyorNotes, repairPeriods, CaseSection.generalExpenses),
      ),

      // Split into two separate cards, not one merged "Accounts" card
      // (14 July 2026 walkthrough — the combined card read as unclear
      // about which numbers belonged to the estimate vs. actual invoices).
      _SectionCard(
        accentColor: AppColors.green,
        icon: Icons.calculate_outlined,
        title: 'Cost Estimate',
        countLabel: null,
        onOpen: () => ctx.go('/cases/$caseId/accounts'),
        child: _costEstimateMiniContent(survey),
      ),

      _SectionCard(
        accentColor: AppColors.green,
        icon: Icons.receipt_outlined,
        title: 'Accounts Summary',
        countLabel: repairDocs.isEmpty ? null : '${repairDocs.length}',
        onOpen: () => ctx.go('/cases/$caseId/accounts'),
        child: _accountsContent(repairDocs, damage?.occurrences ?? []),
      ),
      _SectionCard(
        accentColor: AppColors.amber,
        icon: Icons.folder_outlined,
        title: 'Documentation',
        countLabel: documents.isEmpty ? null : '${documents.length}',
        onOpen: () => ctx.go('/cases/$caseId/documents'),
        child: _documentationContent(documents),
      ),
      _SectionCard(
        accentColor: AppColors.midBlue,
        icon: Icons.attach_money_outlined,
        title: 'Additional Information',
        countLabel: () {
          final n = _expenseCueCount(surveyorNotes) + survey.otherMattersClauseIds.length;
          return n == 0 ? null : '$n';
        }(),
        onOpen: () => ctx.go('/cases/$caseId/expenses'),
        child: _expensesContent(surveyorNotes, survey),
      ),
      _SectionCard(
        accentColor: AppColors.midBlue,
        icon: Icons.description_outlined,
        title: 'Report Status',
        countLabel: outputs.isEmpty ? null : '${outputs.length}',
        initiallyExpanded: outputs.isNotEmpty,
        onOpen: () => ctx.go('/cases/$caseId/reports'),
        child: _reportStatusContent(outputs),
      ),
    ];
  }

  // ── Content builders ──────────────────────────────────────────────────────

  Widget _certificatesContent(List<CertificateModel> certs) {
    if (certs.isEmpty) {
      return const _SectionEmpty('No certificates recorded — tap Open to add');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: certs.map((c) {
        final status = c.effectiveStatus;
        final statusColor = switch (status) {
          CertStatus.valid       => AppColors.success,
          CertStatus.expired     => AppColors.error,
          CertStatus.suspended   => AppColors.warning,
          CertStatus.notSighted  => AppColors.textSecondary,
          CertStatus.tbc         => AppColors.textTertiary,
        };
        final expiry = c.expiryDate != null
            ? '${c.expiryDate!.day.toString().padLeft(2, '0')}/'
              '${c.expiryDate!.month.toString().padLeft(2, '0')}/'
              '${c.expiryDate!.year}'
            : null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6, height: 6,
                margin: const EdgeInsets.only(top: 5, right: 8),
                decoration: BoxDecoration(
                    color: statusColor, shape: BoxShape.circle),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(c.certName ?? c.certType.label,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(status.label,
                            style: TextStyle(
                                fontSize: 9, color: statusColor,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    if (expiry != null || c.certNumber != null)
                      Text(
                        [
                          if (c.certNumber != null) c.certNumber!,
                          if (expiry != null) 'Exp: $expiry',
                        ].join('  ·  '),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _attendanceContent(
    List<SurveyAttendanceModel> visits,
    List<AttendeeModel> attendees,
  ) {
    if (visits.isEmpty && attendees.isEmpty) {
      return const _SectionEmpty('No attendance recorded — tap Open to add');
    }
    // Attendees carried over from the pre-attendance-linking era have no
    // attendance_id — list them separately rather than under a visit.
    final unlinked = attendees.where((a) => a.attendanceId == null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < visits.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _visitRow(visits[i]),
          ...attendees
              .where((a) => a.attendanceId == visits[i].attendanceId)
              .map((a) => Padding(
                    padding: const EdgeInsets.only(left: 14, top: 4),
                    child: _AttendeeRow(attendee: a),
                  )),
        ],
        if (unlinked.isNotEmpty) ...[
          if (visits.isNotEmpty) const Divider(height: 16, thickness: 0.5),
          ...unlinked.map((a) => _AttendeeRow(attendee: a)),
        ],
      ],
    );
  }

  Widget _visitRow(SurveyAttendanceModel v) {
    final dateStr = v.attendanceDate != null
        ? '${v.attendanceDate!.day.toString().padLeft(2, '0')}/'
            '${v.attendanceDate!.month.toString().padLeft(2, '0')}/'
            '${v.attendanceDate!.year}'
        : 'TBC';
    return Row(
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
              Row(children: [
                Text(v.attendanceType.label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                const SizedBox(width: 6),
                Text(dateStr,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ]),
              if (v.location != null)
                Text(v.location!,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              if (v.vesselStatus != null)
                Text(v.vesselStatus!.label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _occurrenceContent(DamageState? damage) {
    if (damage == null || damage.occurrences.isEmpty) {
      return const _SectionEmpty(
          'No occurrences recorded — tap Open to add');
    }
    final multiOcc = damage.occurrences.length > 1;
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
                  if (multiOcc && occ.isPrimary) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: AppColors.teal.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'PRIMARY',
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: AppColors.teal,
                            letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
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

    // Sort occurrences by date ascending; null dates go last.
    final sortedOccs = [...damage.occurrences]..sort((a, b) {
        if (a.dateTime == null && b.dateTime == null) return 0;
        if (a.dateTime == null) return 1;
        if (b.dateTime == null) return -1;
        return a.dateTime!.compareTo(b.dateTime!);
      });

    // Assign display numbers in date order (may differ from DB occurrence_no
    // if renumbering hasn't propagated yet).
    final displayNo = <String, int>{};
    for (int i = 0; i < sortedOccs.length; i++) {
      displayNo[sortedOccs[i].occurrenceId] = i + 1;
    }

    final rows = <Widget>[];
    for (final occ in sortedOccs) {
      final items = damage.itemsForOccurrence(occ.occurrenceId);
      if (items.isEmpty) continue;
      final no = displayNo[occ.occurrenceId] ?? occ.occurrenceNo;

      // Occurrence header
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: 4, top: rows.isEmpty ? 0 : 8),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.coral,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'Occ. $no',
              style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              occ.title ?? 'Occurrence $no',
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ));

      // Damage items for this occurrence
      for (final item in items) {
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 5, left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(top: 6, right: 8),
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
                        item.damageDescription!.length > 80
                            ? '${item.damageDescription!.substring(0, 80)}…'
                            : item.damageDescription!,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _DamageCategoryChip(category: item.damageCategory),
            ],
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }

  Widget _causationContent(OccurrenceModel? occ) {
    if (occ == null) {
      return const _SectionEmpty(
          'No occurrence recorded — tap Open to add');
    }

    final causeTypeLabel = occ.causeType != null
        ? _causeTypeLabel(occ.causeType!)
        : null;
    final allegationLabel = _allegationLabel(occ.allegationType);
    final agreementLabel = occ.allegationType == 'formal_allegation'
        ? _agreementLabel(occ.causeAgreement)
        : null;

    if (causeTypeLabel == null && allegationLabel == null) {
      return const _SectionEmpty(
          'Tap Open to record allegation and cause');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (causeTypeLabel != null)
          _CausationChip(label: causeTypeLabel, color: AppColors.amber),
        if (allegationLabel != null) ...[
          const SizedBox(height: 5),
          _CausationChip(
            label: allegationLabel,
            color: occ.allegationType == 'formal_allegation'
                ? AppColors.coral
                : AppColors.green,
          ),
        ],
        if (agreementLabel != null) ...[
          const SizedBox(height: 5),
          _CausationChip(
            label: agreementLabel,
            color: occ.causeAgreement == 'agree'
                ? AppColors.green
                : occ.causeAgreement == 'disagree'
                    ? AppColors.coral
                    : AppColors.textSecondary,
          ),
        ],
        if (occ.certaintyLevel != null) ...[
          const SizedBox(height: 6),
          Text('Certainty: ${occ.certaintyLevel!.label}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
        if (occ.thirdPartyFindings.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
              '${occ.thirdPartyFindings.length} third-party finding'
              '${occ.thirdPartyFindings.length == 1 ? '' : 's'} recorded',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textTertiary)),
        ],
      ],
    );
  }

  String? _causeTypeLabel(String value) {
    const map = {
      'grounding': 'Grounding / Stranding',
      'collision': 'Collision',
      'contact': 'Contact',
      'fire': 'Fire',
      'explosion': 'Explosion',
      'flooding': 'Flooding',
      'heavy_weather': 'Heavy Weather',
      'machinery_failure': 'Machinery Failure',
      'structural_failure': 'Structural Failure',
      'crew_error': 'Crew / Nav. Error',
      'port_damage': 'Port / Berth Damage',
      'ice_damage': 'Ice Damage',
      'lightning': 'Lightning Strike',
      'malicious': 'Malicious Damage',
      'other': 'Other',
    };
    return map[value];
  }

  String? _allegationLabel(String? type) {
    switch (type) {
      case 'formal_allegation':   return 'Formal Allegation';
      case 'no_formal_allegation': return 'No Formal Allegation';
      case 'tbc':                 return 'Allegation: TBC';
      default:                    return null;
    }
  }

  String? _agreementLabel(String? agreement) {
    switch (agreement) {
      case 'agree':    return 'Position: We Agree';
      case 'disagree': return 'Position: We Disagree';
      case 'tbc':      return 'Position: TBC';
      default:         return null;
    }
  }

  // Nature of the Repairs — early indicator questions + anticipated repair
  // sequence, usable before any repair period exists (5 July 2026): "if we
  // attend a vessel right after the incident... there are at least some
  // indications of where this claim is going."
  static final _natureOfRepairsQuestions = [
    ('Drydocking required', (NatureOfRepairs n) => n.drydockingRequired),
    ("Assured's plan formulated", (NatureOfRepairs n) => n.assuredPlanFormulated),
    ('Further inspections planned', (NatureOfRepairs n) => n.furtherInspectionsPlanned),
    ('Parts with long lead time', (NatureOfRepairs n) => n.partsLongLeadTime),
    ('Foreseeable difficulties', (NatureOfRepairs n) => n.foreseeableDifficulties),
  ];

  int _natureOfRepairsCount(NatureOfRepairs? n) {
    if (n == null) return 0;
    final ticked = _natureOfRepairsQuestions.where((q) => q.$2(n)).length;
    return ticked + n.sequenceItems.length;
  }

  Widget _natureOfRepairsContent(NatureOfRepairs? n) {
    if (n == null || n.isEmpty) {
      return const _SectionEmpty('No indications recorded yet — tap Open to add');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final q in _natureOfRepairsQuestions)
          if (q.$2(n))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 5, color: AppColors.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(q.$1,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
        if (n.sequenceItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 5, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Anticipated sequence of repairs',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
                Text('${n.sequenceItems.length}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
          ),
      ],
    );
  }

  // Work Not Concerning Average / General Services & Access — both
  // repair-period-scoped case sections (see
  // repair_period_scoped_cues_screen.dart, docs/context_cue_system_review.md
  // §3.1/§3.2): cues tagged with the section, each optionally linked to a
  // specific repair period, or sitting in the "not allocated" bucket.
  int _repairPeriodScopedCueCount(List<SurveyorNote> notes, CaseSection section) =>
      notes.where((n) => n.caseSection == section).length;

  Widget _repairPeriodScopedContent(
    List<SurveyorNote> notes,
    List<RepairPeriodModel> periods,
    CaseSection section,
  ) {
    final sectionNotes = notes.where((n) => n.caseSection == section).toList();
    if (sectionNotes.isEmpty) {
      return const _SectionEmpty('No cues recorded — tap Open to add');
    }
    final unassigned = sectionNotes
        .where((n) =>
            n.linkedToType != repairPeriodLinkType || n.linkedToId == null)
        .length;
    final byPeriod = <String, int>{};
    for (final n in sectionNotes) {
      if (n.linkedToType == repairPeriodLinkType && n.linkedToId != null) {
        byPeriod[n.linkedToId!] = (byPeriod[n.linkedToId!] ?? 0) + 1;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (unassigned > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 5, color: AppColors.warning),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Not allocated to a period',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
                Text('$unassigned',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
          ),
        for (final p in periods)
          if (byPeriod[p.periodId] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 5, color: AppColors.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(p.displayTitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
                  Text('${byPeriod[p.periodId]}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            ),
      ],
    );
  }

  Widget _repairsContent(List<RepairPeriodModel> periods) {
    if (periods.isEmpty) {
      return const _SectionEmpty('No repair periods — tap Open to add');
    }
    // Status of Repairs — derived from period dates rather than manually
    // entered (relocated from the report builder's Advice Summary card,
    // 4 July 2026: "status of repairs can be deducted from the repair
    // periods").
    final derivedStatus = deriveRepairStatus(periods);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 12, color: AppColors.textTertiary),
            const SizedBox(width: 5),
            Text('Status of Repairs: ${derivedStatus.label}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ]),
        ),
        ...periods.map((period) {
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
        }),
      ],
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

  // Additional Information — count/summary for the combined section card
  // (previousWorks/extraExpenses/contractualHire/otherMatters context cues
  // + the Advice to Assured legal clause ticklist; see
  // additional_information_screen.dart for the full editor). Work Not
  // Concerning Average has its own standalone section/card (see
  // _wncaContent above) — not part of this tag set. generalExpenses
  // dropped (5 July 2026) — its front-end entry was retired as redundant
  // with the repair-period services checklist.
  static const _expenseTags = {
    CaseSection.previousWorks,
    CaseSection.extraExpenses,
    CaseSection.contractualHire,
    CaseSection.otherMatters,
  };

  int _expenseCueCount(List<SurveyorNote> notes) =>
      notes.where((n) => _expenseTags.contains(n.caseSection)).length;

  Widget _expensesContent(List<SurveyorNote> notes, CaseModel survey) {
    final cues = notes.where((n) => _expenseTags.contains(n.caseSection)).toList();
    final tickedClauses = survey.otherMattersClauseIds.length;
    if (cues.isEmpty && tickedClauses == 0) {
      return const _SectionEmpty('No cues recorded — tap Open to add');
    }
    final byTag = <CaseSection, int>{};
    for (final n in cues) {
      byTag[n.caseSection!] = (byTag[n.caseSection!] ?? 0) + 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final tag in _expenseTags)
          if (byTag[tag] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 5, color: AppColors.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(tag.label,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
                  Text('${byTag[tag]}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            ),
        if (tickedClauses > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 5, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Advice to Assured (legal clauses)',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
                Text('$tickedClauses',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
          ),
      ],
    );
  }

  /// Compact one-line Cost Estimate indicator — its own "Cost Estimate"
  /// card, separate from Accounts Summary below (14 July 2026 walkthrough;
  /// previously stacked together in one "Accounts" card, which read as
  /// unclear which numbers belonged to which). Status and total are read
  /// straight off `survey` — `estimated_repair_cost` is kept in sync with
  /// the sum of `case_cost_estimate_items` by
  /// `CostEstimateItemsNotifier._syncEstimatedTotal()`, so no separate
  /// line-item fetch is needed just for this summary line.
  Widget _costEstimateMiniContent(CaseModel survey) {
    final status = survey.costEstimateStatus;
    final label = switch (status) {
      'completed_all_invoices'   => 'Final Accounting',
      'ongoing_partial_invoices' => 'Ongoing — Further Invoices Expected',
      _                          => 'Purely Estimated',
    };
    final amount = survey.estimatedRepairCost;
    final currency = survey.baseCurrency ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.calculate_outlined,
              size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Expanded(
            child: Text('Cost Estimate — $label',
                style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          if (amount != null && amount > 0.005)
            Text('$currency ${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _accountsContent(
    List<RepairDocumentModel> docs,
    List<OccurrenceModel> occurrences,
  ) {
    if (docs.isEmpty) {
      // Nothing invoiced yet doesn't mean nothing to report — the whole
      // estimate is effectively outstanding/unallocated until invoices
      // land. Previously this branch just said "No invoices imported yet"
      // with no visibility into that (14 July 2026 walkthrough).
      final estimate = survey.estimatedRepairCost;
      final currency = survey.baseCurrency ?? '';
      if (estimate != null && estimate > 0.005) {
        return _accountAmountRow(
            'Unallocated (nothing invoiced yet)',
            '$currency ${estimate.toStringAsFixed(0)}',
            AppColors.textSecondary);
      }
      return const _SectionEmpty('No invoices imported yet');
    }
    final summary  = AccountsSummary.fromDocuments(docs);
    final allLines = docs.expand((d) => d.accountLines).toList();
    final cur      = summary.primaryCurrency;

    String fmt(double v) {
      final parts = v.toStringAsFixed(0).split('.');
      return '$cur ${parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';
    }

    final finRows = <Widget>[];

    for (int i = 0; i < occurrences.length; i++) {
      final occ = occurrences[i];
      final uw  = allLines
          .where((l) =>
              l.occurrenceId == occ.occurrenceId &&
              l.status != LineItemStatus.betterment)
          .fold(0.0, (s, l) => s + l.underwritersPortion);
      if (uw > 0.005) {
        finRows.add(_accountAmountRow(
          'Occ. ${i + 1} — ${occ.title ?? 'Occurrence ${i + 1}'}',
          fmt(uw), AppColors.green));
      }
    }

    final unallocated = allLines
        .where((l) =>
            l.occurrenceId == null &&
            l.status != LineItemStatus.betterment)
        .fold(0.0, (s, l) => s + l.underwritersPortion);
    if (unallocated > 0.005) {
      finRows.add(_accountAmountRow('Unallocated', fmt(unallocated), AppColors.green));
    }

    final betterment = allLines
        .where((l) => l.status == LineItemStatus.betterment)
        .fold(0.0, (s, l) => s + l.grossAmount);
    if (betterment > 0.005) {
      finRows.add(_accountAmountRow('Betterment', fmt(betterment), Colors.brown));
    }

    if (summary.totalApprovedOwners > 0.005) {
      finRows.add(_accountAmountRow(
          "Owner's account", fmt(summary.totalApprovedOwners), Colors.orange));
    }

    final deferred = allLines
        .where((l) => l.apportionmentType == 'defer')
        .fold(0.0, (s, l) => s + l.grossAmount);
    if (deferred > 0.005) {
      finRows.add(_accountAmountRow(
          'Deferred to adjuster', fmt(deferred), Colors.blueGrey));
    }

    if (summary.totalSubmitted > 0.005) {
      finRows.add(Divider(height: 10, color: AppColors.border.withValues(alpha: 0.4)));
      finRows.add(_accountAmountRow(
        'Total (gross)', fmt(summary.totalSubmitted), AppColors.textPrimary,
        bold: true));
    }

    // ── Flags ────────────────────────────────────────────────────────────
    final pendingLines = allLines
        .where((l) => l.status == LineItemStatus.pendingReview)
        .length;
    final queriedLines = allLines
        .where((l) => l.status == LineItemStatus.queried)
        .length;
    final unallocatedLines = occurrences.isNotEmpty
        ? allLines.where((l) => l.occurrenceId == null).length
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Summary',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4)),
        if (finRows.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...finRows,
        ],
        if (pendingLines > 0 || queriedLines > 0 || unallocatedLines > 0) ...[
          const SizedBox(height: 4),
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.3)),
          const SizedBox(height: 4),
          if (pendingLines > 0)
            _accountFlagRow(
                Icons.hourglass_empty_outlined,
                '$pendingLines line${pendingLines == 1 ? '' : 's'} pending review',
                Colors.orange),
          if (queriedLines > 0)
            _accountFlagRow(
                Icons.help_outline,
                '$queriedLines line${queriedLines == 1 ? '' : 's'} queried',
                Colors.red),
          if (unallocatedLines > 0)
            _accountFlagRow(
                Icons.link_off_outlined,
                '$unallocatedLines line${unallocatedLines == 1 ? '' : 's'} not allocated',
                AppColors.textSecondary),
        ],
      ],
    );
  }

  Widget _accountFlagRow(IconData icon, String text, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 5),
            Expanded(
              child: Text(text,
                  style: TextStyle(color: color, fontSize: 10)),
            ),
          ],
        ),
      );

  Widget _accountAmountRow(String label, String value, Color color,
      {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight:
                          bold ? FontWeight.w600 : FontWeight.normal)),
            ),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: bold ? 12 : 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );


  Widget _documentationContent(List<DocumentModel> documents) {
    if (documents.isEmpty) {
      return const _SectionEmpty('No documents recorded — tap Open to add');
    }
    // §3.4/§2.15 (10 July 2026): 'enclosed' alone no longer means "in the
    // report" — migration 034's includedInReport splits it further into
    // what actually ships vs what's retained on file but not attached.
    final inReport = documents
        .where((d) =>
            d.availability == DocAvailability.enclosed && d.includedInReport)
        .length;
    final onFileNotInReport = documents
        .where((d) =>
            d.availability == DocAvailability.enclosed && !d.includedInReport)
        .length;
    final requestedDocs =
        documents.where((d) => d.availability == DocAvailability.requested).toList();
    final notAvailable = documents
        .where((d) => d.availability == DocAvailability.notAvailable)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _accountAmountRow('In Report', '$inReport', AppColors.success),
        if (onFileNotInReport > 0)
          _accountAmountRow(
              'On File — Not in Report', '$onFileNotInReport', AppColors.textSecondary),
        if (requestedDocs.isNotEmpty)
          _accountAmountRow(
              'Requested — Not Yet Received', '${requestedDocs.length}', AppColors.amber),
        if (notAvailable > 0)
          _accountAmountRow('Not Available', '$notAvailable', AppColors.error),
        // TODO.md §3.4: auto-generated email listing outstanding requested
        // documents, built 9 July 2026. The 3-way availability split
        // (In Report / On File — Not in Report / Requested) landed 10 July
        // 2026 via migration 034's includedInReport boolean — the surveyor
        // chose a separate boolean over a new DocAvailability enum value,
        // which meant the existing Document Vault could gain the missing
        // status-management controls (toggle + "mark as received") instead
        // of needing a structurally separate screen.
        if (requestedDocs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _SendDocumentRequestButton(
                caseId: survey.caseId, requestedDocs: requestedDocs),
          ),
      ],
    );
  }

  Widget _reportStatusContent(List<ReportOutput> outputs) {
    if (outputs.isEmpty) {
      return const _SectionEmpty('No reports created yet — tap Open to start');
    }

    // Sort oldest first so version numbers read top-to-bottom
    final sorted = [...outputs]
      ..sort((a, b) => (a.createdAt ?? DateTime(2000))
          .compareTo(b.createdAt ?? DateTime(2000)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            _vColHeader('Version', flex: 2),
            _vColHeader('Type',    flex: 3),
            _vColHeader('Status',  flex: 3),
            _vColHeader('Date',    flex: 3),
          ]),
        ),
        const Divider(height: 1),
        ...sorted.map((o) => _VersionRow(output: o)),
      ],
    );
  }

  static Widget _vColHeader(String label, {int flex = 1}) => Expanded(
        flex: flex,
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 0.6,
          ),
        ),
      );

  Widget _complianceContent(List<CertificateModel> certs, VesselModel? vessel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _certificatesContent(certs),
        if (vessel != null && (vessel.classStatus != null ||
            vessel.lastDrydockDate != null ||
            vessel.pscLastInspection != null ||
            vessel.ispsStatus != null ||
            (vessel.ismIncidentReported ?? false) ||
            (vessel.classIncidentReported ?? false))) ...[
          if (certs.isNotEmpty) const Divider(height: 14, thickness: 0.5),
          _statutoryContent(vessel),
        ],
      ],
    );
  }

  Widget _statutoryContent(VesselModel vessel) {
    String fmtDate(DateTime? d) =>
        d == null ? '—' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (vessel.classStatus != null)
            _StatutoryRow(
              label: 'Class status',
              child: _StatusChip(
                label: vessel.classStatus!.value.replaceAll('_', ' ').toUpperCase(),
                color: vessel.classStatus == ClassStatus.classed
                    ? AppColors.success
                    : vessel.classStatus == ClassStatus.conditional
                        ? AppColors.amber
                        : AppColors.coral,
              ),
            ),
          if (vessel.lastDrydockDate != null)
            _StatutoryRow(
              label: 'Last drydock',
              value: '${fmtDate(vessel.lastDrydockDate)}'
                  '${vessel.lastDrydockYard != null ? " — ${vessel.lastDrydockYard}" : ""}',
            ),
          if (vessel.pscLastInspection != null)
            _StatutoryRow(
              label: 'PSC inspection',
              value: '${fmtDate(vessel.pscLastInspection)}'
                  '${vessel.pscLastResult != null ? " — ${vessel.pscLastResult!.value.replaceAll("_", " ")}" : ""}',
            ),
          if (vessel.ispsStatus != null)
            _StatutoryRow(label: 'ISPS', value: vessel.ispsStatus!.value.replaceAll('_', ' ')),
          if (vessel.ismIncidentReported == true)
            const _StatutoryRow(label: 'ISM', value: 'Incident reported in the ISM'),
          if (vessel.classIncidentReported == true)
            const _StatutoryRow(label: 'Class', value: 'Incident reported to Class'),
        ],
      ),
    );
  }

}

// ── Report version row ────────────────────────────────────────────────────

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.output});
  final ReportOutput output;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(output.status);
    final date = output.issuedDate ?? output.createdAt;
    final dateStr = date != null
        ? '${date.day.toString().padLeft(2, '0')}-'
          '${_month(date.month)}-${date.year}'
        : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        // Version code
        Expanded(
          flex: 2,
          child: Text(
            output.versionCode,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              color: AppColors.midBlue,
            ),
          ),
        ),
        // Type
        Expanded(
          flex: 3,
          child: Text(
            output.outputType.label,
            style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
          ),
        ),
        // Status badge
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: statusColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                output.status.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ),
        ),
        // Date
        Expanded(
          flex: 3,
          child: Text(
            dateStr,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
      ]),
    );
  }

  Color _statusColor(ReportStatus s) => switch (s) {
        ReportStatus.issued  => AppColors.success,
        ReportStatus.locked  => AppColors.navy,
        ReportStatus.approved => AppColors.teal,
        ReportStatus.submittedQc || ReportStatus.qcComments => AppColors.amber,
        _ => AppColors.textTertiary,
      };

  static String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
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
    this.highlighted = false,
  });

  final Color accentColor;
  final IconData icon;
  final String title;
  final VoidCallback onOpen;
  final Widget child;
  final String? countLabel;
  final bool initiallyExpanded;
  final bool highlighted;

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
        color: widget.highlighted
            ? AppColors.lightAmber
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.highlighted)
            Container(height: 3, color: AppColors.warning),
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
              attendee.title != null
                  ? '${attendee.title!.label} ${attendee.fullName}'
                  : attendee.fullName,
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

class _DamageCategoryChip extends StatelessWidget {
  const _DamageCategoryChip({required this.category});
  final DamageCategory category;

  static const _labels = {
    DamageCategory.structuralExternal:    'Structural',
    DamageCategory.structuralInternal:    'Structural',
    DamageCategory.mechanical:            'Mechanical',
    DamageCategory.electricalElectronics: 'Electrical',
    DamageCategory.other:                 'Other',
  };

  static const _colors = {
    DamageCategory.structuralExternal:    AppColors.coral,
    DamageCategory.structuralInternal:    AppColors.navy,
    DamageCategory.mechanical:            AppColors.amber,
    DamageCategory.electricalElectronics: AppColors.purple,
    DamageCategory.other:                 AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[category] ?? 'Other';
    final color = _colors[category] ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 9, color: color, fontWeight: FontWeight.w700),
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

class _CausationChip extends StatelessWidget {
  const _CausationChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Statutory helpers ─────────────────────────────────────────────────────

class _StatutoryRow extends StatelessWidget {
  const _StatutoryRow({required this.label, this.value, this.child});
  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: child ??
                Text(value ?? '—',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ── Documentation Request email (TODO.md §3.4, 8 July 2026) ────────────────

class _SendDocumentRequestButton extends ConsumerWidget {
  const _SendDocumentRequestButton({
    required this.caseId,
    required this.requestedDocs,
  });
  final String caseId;
  final List<DocumentModel> requestedDocs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _openComposeSheet(context, ref),
        icon: const Icon(Icons.mail_outline, size: 15),
        label: const Text('Send Documentation Request',
            style: TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.amber,
          side: const BorderSide(color: AppColors.amber),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Future<void> _openComposeSheet(BuildContext context, WidgetRef ref) async {
    final caseModel = ref.read(caseProvider(caseId)).value;
    if (caseModel == null) return;
    final parties = ref.read(partiesProvider(caseId)).value;
    final draft = buildDocumentRequestEmail(
        caseModel: caseModel, requested: requestedDocs);

    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DocumentRequestComposeSheet(
        initialTo: parties?.assuredRepEmail ?? '',
        subject: draft.subject,
        body: draft.body,
      ),
    );
  }
}

class _DocumentRequestComposeSheet extends StatefulWidget {
  const _DocumentRequestComposeSheet({
    required this.initialTo,
    required this.subject,
    required this.body,
  });
  final String initialTo;
  final String subject;
  final String body;

  @override
  State<_DocumentRequestComposeSheet> createState() =>
      _DocumentRequestComposeSheetState();
}

class _DocumentRequestComposeSheetState
    extends State<_DocumentRequestComposeSheet> {
  late final TextEditingController _toCtrl;
  late final TextEditingController _bodyCtrl;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _toCtrl = TextEditingController(text: widget.initialTo);
    _bodyCtrl = TextEditingController(text: widget.body);
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_toCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Recipient email is required');
      return;
    }
    setState(() { _sending = true; _error = null; });
    try {
      await GmailService.sendMessage(
        to: _toCtrl.text.trim(),
        subject: widget.subject,
        bodyText: _bodyCtrl.text,
      );
      if (mounted) {
        Navigator.pop(context);
        showSavedToast(context, label: 'Documentation request sent');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Send failed: $e — check Gmail is connected in Settings';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Send Documentation Request',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text(
                'Review before sending — this goes out from your connected '
                'Gmail account.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _toCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                decoration: const InputDecoration(
                    labelText: 'To', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                readOnly: true,
                controller: TextEditingController(text: widget.subject),
                decoration: const InputDecoration(
                    labelText: 'Subject', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyCtrl,
                maxLines: 10,
                decoration: const InputDecoration(
                    labelText: 'Message', border: OutlineInputBorder()),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _sending ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_outlined, size: 15),
                      label: const Text('Send'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
