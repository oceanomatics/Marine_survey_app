// lib/features/cases/screens/case_home_screen.dart
//
// The central hub for an open case. Opens on the tablet when you
// board a vessel. All five input modes accessible from here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/cases_provider.dart';
import '../models/case_model.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/error_widget.dart';
import '../../capture/screens/quick_capture_screen.dart';
import '../../capture/screens/camera_screen.dart';

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
      ),
    );
  }
}

class _CaseHomeView extends StatelessWidget {
  const _CaseHomeView({
    required this.caseId,
    required this.survey,
    required this.checklistProgress,
    required this.pendingCaptures,
  });

  final String caseId;
  final CaseModel survey;
  final double checklistProgress;
  final int pendingCaptures;

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/cases'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              survey.vesselName ?? 'Vessel TBC',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              survey.jobNumber,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          // Status chip
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
          const SizedBox(width: 8),
        ],
      ),

      // ── Quick Capture FAB ──────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickCapture(context),
        backgroundColor: AppColors.coral,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.bolt, size: 22),
        label: const Text(
          'Quick Capture',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      body: SingleChildScrollView(
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Case header card ─────────────────────────────────────────
            _CaseHeaderCard(survey: survey, progress: checklistProgress),
            const SizedBox(height: 20),

            // ── Five input mode buttons ───────────────────────────────────
            Text('Data Capture',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    )),
            const SizedBox(height: 10),
            isTablet
                ? _TabletCaptureGrid(caseId: caseId)
                : _PhoneCaptureList(caseId: caseId),

            const SizedBox(height: 24),

            // ── Survey modules ────────────────────────────────────────────
            Text('Survey Modules',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    )),
            const SizedBox(height: 10),
            isTablet
                ? _TabletModuleGrid(
                    caseId: caseId, pendingCaptures: pendingCaptures)
                : _PhoneModuleList(
                    caseId: caseId, pendingCaptures: pendingCaptures),

            const SizedBox(height: 24),

            // ── Checklist progress ────────────────────────────────────────
            _ChecklistProgressCard(
              caseId: caseId,
              progress: checklistProgress,
            ),

            const SizedBox(height: 80), // FAB clearance
          ],
        ),
      ),
    );
  }

  void _showQuickCapture(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickCaptureSheet(caseId: caseId),
    );
  }

  Color _statusColor(CaseStatus status) => switch (status) {
        CaseStatus.open => AppColors.info,
        CaseStatus.prelimIssued => AppColors.warning,
        CaseStatus.adviceIssued => AppColors.warning,
        CaseStatus.finalIssued => AppColors.success,
        CaseStatus.closed => AppColors.textSecondary,
      };
}

// ── Case Header Card ───────────────────────────────────────────────────────

class _CaseHeaderCard extends StatelessWidget {
  const _CaseHeaderCard({required this.survey, required this.progress});
  final CaseModel survey;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Case type badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lightPurple,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    survey.caseType.label,
                    style: const TextStyle(
                      color: AppColors.purple,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (survey.outputFormat != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      survey.outputFormat!.label,
                      style: const TextStyle(
                        color: AppColors.midBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (survey.claimReference != null) ...[
              _InfoRow('Claim ref', survey.claimReference!),
              const SizedBox(height: 4),
            ],
            if (survey.clientName != null) ...[
              _InfoRow('Client', survey.clientName!),
              const SizedBox(height: 4),
            ],
            if (survey.instructionDate != null) ...[
              _InfoRow('Instructed', _formatDate(survey.instructionDate!)),
            ],
            const SizedBox(height: 14),
            // Checklist progress bar
            Row(
              children: [
                const Text('Checklist',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0 ? AppColors.success : AppColors.midBlue,
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

// ── Capture Mode Buttons (Tablet — 2x3 grid) ──────────────────────────────

class _TabletCaptureGrid extends StatelessWidget {
  const _TabletCaptureGrid({required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: _captureButtons(context, caseId),
    );
  }
}

class _PhoneCaptureList extends StatelessWidget {
  const _PhoneCaptureList({required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _captureButtons(context, caseId)
          .map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: b,
              ))
          .toList(),
    );
  }
}

List<Widget> _captureButtons(BuildContext context, String caseId) => [
      _CaptureButton(
        icon: Icons.camera_alt_outlined,
        label: 'Camera',
        subtitle: 'Photo & scan',
        color: AppColors.midBlue,
        bgColor: AppColors.lightBlue,
        onTap: () => context.go('/cases/$caseId/camera'),
      ),
      _CaptureButton(
        icon: Icons.mic_outlined,
        label: 'Voice Note',
        subtitle: 'Record & transcribe',
        color: AppColors.teal,
        bgColor: AppColors.lightTeal,
        onTap: () => context.go('/cases/$caseId/voice'),
      ),
      _CaptureButton(
        icon: Icons.edit_outlined,
        label: 'Stylus Note',
        subtitle: 'Freehand sketch',
        color: AppColors.purple,
        bgColor: AppColors.lightPurple,
        onTap: () {}, // Phase 1.1
      ),
    ];

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(subtitle,
                        style: TextStyle(
                            color: color.withValues(alpha: 0.7), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Survey Module Buttons ─────────────────────────────────────────────────

class _TabletModuleGrid extends StatelessWidget {
  const _TabletModuleGrid(
      {required this.caseId, required this.pendingCaptures});
  final String caseId;
  final int pendingCaptures;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: _moduleButtons(context, caseId, pendingCaptures),
    );
  }
}

class _PhoneModuleList extends StatelessWidget {
  const _PhoneModuleList({required this.caseId, required this.pendingCaptures});
  final String caseId;
  final int pendingCaptures;

  @override
  Widget build(BuildContext context) {
    final buttons = _moduleButtons(context, caseId, pendingCaptures);
    return Column(
      children: [
        for (int i = 0; i < buttons.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(child: buttons[i]),
                const SizedBox(width: 12),
                Expanded(
                    child: i + 1 < buttons.length
                        ? buttons[i + 1]
                        : const SizedBox()),
              ],
            ),
          ),
      ],
    );
  }
}

List<Widget> _moduleButtons(
        BuildContext context, String caseId, int pendingCaptures) =>
    [
      _ModuleButton(
        icon: Icons.directions_boat_outlined,
        label: 'Vessel',
        color: AppColors.teal,
        bgColor: AppColors.lightTeal,
        onTap: () => context.go('/cases/$caseId/vessel'),
      ),
      _ModuleButton(
        icon: Icons.warning_amber_outlined,
        label: 'Damage',
        color: AppColors.coral,
        bgColor: AppColors.lightCoral,
        onTap: () => context.go('/cases/$caseId/damage'),
      ),
      _ModuleButton(
        icon: Icons.folder_outlined,
        label: 'Documents',
        color: AppColors.amber,
        bgColor: AppColors.lightAmber,
        onTap: () => context.go('/cases/$caseId/documents'),
      ),
      _ModuleButton(
        icon: Icons.checklist_outlined,
        label: 'Checklist',
        color: AppColors.green,
        bgColor: AppColors.lightGreen,
        onTap: () => context.go('/cases/$caseId/checklist'),
      ),
      _ModuleButton(
        icon: Icons.description_outlined,
        label: 'Reports',
        color: AppColors.navy,
        bgColor: AppColors.lightBlue,
        onTap: () => context.go('/cases/$caseId/reports'),
      ),
      _ModuleButton(
        icon: Icons.inbox_outlined,
        label: 'Inbox',
        color: pendingCaptures > 0 ? AppColors.coral : AppColors.textSecondary,
        bgColor: pendingCaptures > 0
            ? AppColors.lightCoral
            : const Color(0xFFF1EFE8),
        badge: pendingCaptures > 0 ? pendingCaptures.toString() : null,
        onTap: () => context.go('/cases/$caseId/capture'),
      ),
      _ModuleButton(
        icon: Icons.mic_none_outlined,
        label: 'Interview',
        color: AppColors.purple,
        bgColor: AppColors.lightPurple,
        onTap: () {}, // Phase 1 — coming soon
      ),
      _ModuleButton(
        icon: Icons.receipt_outlined,
        label: 'Invoices',
        color: AppColors.midBlue,
        bgColor: AppColors.lightBlue,
        onTap: () {}, // Phase 1
      ),
    ];

class _ModuleButton extends StatelessWidget {
  const _ModuleButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (badge != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: AppColors.coral,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
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

// ── Checklist Progress Card ───────────────────────────────────────────────

class _ChecklistProgressCard extends StatelessWidget {
  const _ChecklistProgressCard({required this.caseId, required this.progress});
  final String caseId;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/cases/$caseId/checklist'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.checklist_outlined,
                    color: AppColors.green, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Survey Checklist',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      progress >= 1.0
                          ? 'All items complete ✓'
                          : '${(progress * 100).round()}% complete — tap to review',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
