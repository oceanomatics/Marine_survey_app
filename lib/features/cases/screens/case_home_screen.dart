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
import '../../capture/screens/camera_screen.dart';
import '../../survey/providers/damage_provider.dart';
import '../../survey/providers/attendees_provider.dart';
import '../../capture/providers/voice_note_provider.dart';
import '../../attendances/providers/attendances_provider.dart';
import '../../attendances/models/attendance_model.dart';
import '../../timeline/providers/timeline_provider.dart';
import '../../timeline/models/timeline_event_model.dart';
import '../../survey/providers/repair_period_provider.dart';
import '../../survey/models/repair_period_model.dart';
import '../../surveyor_notes/providers/surveyor_notes_provider.dart';
import '../../surveyor_notes/models/surveyor_note_model.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../accounts/models/accounts_models.dart';
import '../../settings/providers/organisations_provider.dart';
import '../../vessel/providers/certificates_provider.dart';
import '../../vessel/providers/vessel_provider.dart';
import '../../vessel/screens/certificates_screen.dart';
import '../../reports/providers/report_provider.dart';

const _kTimelineColor = Color(0xFF2E7CB7);

const _kCurrencies = [
  'AUD', 'USD', 'GBP', 'EUR', 'SGD', 'NZD',
  'JPY', 'HKD', 'AED', 'NOK', 'DKK', 'SEK',
];

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

class _SurveyNavRail extends ConsumerWidget {
  const _SurveyNavRail({required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caseModel = ref.watch(caseProvider(caseId)).value;
    final notes = ref.watch(surveyorNotesProvider(caseId)).value ?? [];
    final unallocatedCount = notes
        .where((n) =>
            n.reportSection == null && n.priority != CuePriority.ignored)
        .length;

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
                    onTap: () => context.go('/cases/$caseId/correspondence'),
                  ),
                  _NavItem(
                    icon: Icons.label_outline,
                    label: 'Context',
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
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _CaseEditorSheet(caseId: caseId),
        ),
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

// ── Case editor sheet ─────────────────────────────────────────────────────

class _CaseEditorSheet extends ConsumerStatefulWidget {
  const _CaseEditorSheet({required this.caseId});
  final String caseId;

  @override
  ConsumerState<_CaseEditorSheet> createState() => _CaseEditorSheetState();
}

class _CaseEditorSheetState extends ConsumerState<_CaseEditorSheet> {
  late final TextEditingController _jobCtrl;
  late final TextEditingController _claimCtrl;
  late final TextEditingController _policyUcrCtrl;
  late final TextEditingController _policyNumberCtrl;
  late final TextEditingController _instructingPartyCtrl;
  late final TextEditingController _assuredCtrl;
  late final TextEditingController _surveyLocationCtrl;
  DateTime? _instructionDate;
  DateTime? _dateOfFirstAttendance;
  CaseStatus? _status;
  CaseType? _caseType;
  OutputFormat? _outputFormat;
  PolicyType? _policyType;
  InstructingPartyRole? _instructingPartyRole;
  String? _organisationId;
  String? _baseCurrency;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = ref.read(caseProvider(widget.caseId)).value;
    _jobCtrl               = TextEditingController(
        text: c?.hasPlaceholderJobNumber == true ? '' : (c?.jobNumber ?? ''));
    _claimCtrl             = TextEditingController(text: c?.claimReference ?? '');
    _policyUcrCtrl         = TextEditingController(text: c?.policyUcr ?? '');
    _policyNumberCtrl      = TextEditingController(text: c?.policyNumber ?? '');
    _instructingPartyCtrl  = TextEditingController(text: c?.instructingParty ?? '');
    _assuredCtrl           = TextEditingController(text: c?.assured ?? '');
    _surveyLocationCtrl    = TextEditingController(text: c?.surveyLocation ?? '');
    _instructionDate       = c?.instructionDate;
    _dateOfFirstAttendance = c?.dateOfFirstAttendance;
    _status                = c?.status;
    _caseType              = c?.caseType;
    _outputFormat          = c?.outputFormat;
    _policyType            = c?.policyType;
    _instructingPartyRole  = c?.instructingPartyRole;
    _organisationId        = c?.organisationId;
    _baseCurrency          = c?.baseCurrency;
  }

  @override
  void dispose() {
    _jobCtrl.dispose();
    _claimCtrl.dispose();
    _policyUcrCtrl.dispose();
    _policyNumberCtrl.dispose();
    _instructingPartyCtrl.dispose();
    _assuredCtrl.dispose();
    _surveyLocationCtrl.dispose();
    super.dispose();
  }

  String? _v(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final rawJob = _v(_jobCtrl);
      await ref.read(caseProvider(widget.caseId).notifier).updateCaseRefs(
        jobNumber:             rawJob ?? 'TMP-${DateTime.now().millisecondsSinceEpoch}',
        claimReference:        _v(_claimCtrl),
        status:                _status,
        caseType:              _caseType,
        instructionDate:       _instructionDate,
        outputFormat:          _outputFormat,
        organisationId:        _organisationId,
        baseCurrency:          _baseCurrency,
        policyUcr:             _v(_policyUcrCtrl),
        policyNumber:          _v(_policyNumberCtrl),
        policyType:            _policyType,
        instructingParty:      _v(_instructingPartyCtrl),
        instructingPartyRole:  _instructingPartyRole,
        assured:               _v(_assuredCtrl),
        dateOfFirstAttendance: _dateOfFirstAttendance,
        surveyLocation:        _v(_surveyLocationCtrl),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_note_outlined,
                    color: AppColors.navy, size: 17),
              ),
              const SizedBox(width: 10),
              const Text('Edit Case Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20,
                    color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
            const SizedBox(height: 16),

            _field('Job / File Number', _jobCtrl,
                hint: 'e.g. AU-M53-056789'),
            const SizedBox(height: 10),
            _field('Claim Reference', _claimCtrl,
                hint: 'e.g. GARD-2025-0123456'),
            const SizedBox(height: 10),
            _field('Policy / UCR Reference', _policyUcrCtrl,
                hint: 'TBC'),
            const SizedBox(height: 10),
            _field('Policy Number', _policyNumberCtrl,
                hint: 'TBC'),
            const SizedBox(height: 10),

            // Instruction date
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _instructionDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _instructionDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 15, color: AppColors.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _instructionDate != null
                          ? '${_instructionDate!.day.toString().padLeft(2, '0')}/'
                              '${_instructionDate!.month.toString().padLeft(2, '0')}/'
                              '${_instructionDate!.year}'
                          : 'Instruction Date',
                      style: TextStyle(
                        fontSize: 14,
                        color: _instructionDate != null
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                  if (_instructionDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _instructionDate = null),
                      child: const Icon(Icons.clear,
                          size: 16, color: AppColors.textTertiary),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            // Survey type
            DropdownButtonFormField<CaseType>(
              initialValue: _caseType,
              decoration: _inputDeco('Survey Type'),
              items: CaseType.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.label,
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _caseType = v),
            ),
            const SizedBox(height: 10),

            // Status
            DropdownButtonFormField<CaseStatus>(
              initialValue: _status,
              decoration: _inputDeco('Status'),
              items: CaseStatus.values
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.label,
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _status = v),
            ),
            const SizedBox(height: 10),

            // Report format
            DropdownButtonFormField<OutputFormat>(
              initialValue: _outputFormat,
              decoration: _inputDeco('Report Format'),
              items: OutputFormat.values
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f.label,
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _outputFormat = v),
            ),
            const SizedBox(height: 16),

            // ── Survey Details ───────────────────────────────────────────
            const Divider(height: 1),
            const SizedBox(height: 14),
            const Text('Survey Details',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 10),

            _field('Instructing Party', _instructingPartyCtrl,
                hint: 'e.g. Gard AS, Swedish Club'),
            const SizedBox(height: 10),

            DropdownButtonFormField<InstructingPartyRole>(
              initialValue: _instructingPartyRole,
              decoration: _inputDeco('Instructing Party Role'),
              items: InstructingPartyRole.values
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.label,
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _instructingPartyRole = v),
            ),
            const SizedBox(height: 10),

            _field('Assured', _assuredCtrl,
                hint: 'e.g. Shipowner Pty Ltd'),
            const SizedBox(height: 10),

            DropdownButtonFormField<PolicyType>(
              initialValue: _policyType,
              decoration: _inputDeco('Policy Type'),
              items: PolicyType.values
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.label,
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _policyType = v),
            ),
            const SizedBox(height: 10),

            _field('Survey Location', _surveyLocationCtrl,
                hint: 'e.g. Port of Brisbane, Qld'),
            const SizedBox(height: 10),

            // Date of first attendance
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateOfFirstAttendance ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() => _dateOfFirstAttendance = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.event_outlined,
                      size: 15, color: AppColors.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _dateOfFirstAttendance != null
                          ? '${_dateOfFirstAttendance!.day.toString().padLeft(2, '0')}/'
                              '${_dateOfFirstAttendance!.month.toString().padLeft(2, '0')}/'
                              '${_dateOfFirstAttendance!.year}'
                          : 'Date of First Attendance',
                      style: TextStyle(
                        fontSize: 14,
                        color: _dateOfFirstAttendance != null
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                  if (_dateOfFirstAttendance != null)
                    GestureDetector(
                      onTap: () => setState(() => _dateOfFirstAttendance = null),
                      child: const Icon(Icons.clear,
                          size: 16, color: AppColors.textTertiary),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // ── Organisation ─────────────────────────────────────────────
            const Divider(height: 1),
            const SizedBox(height: 14),
            const Text('Organisation',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 10),

            Consumer(builder: (context, ref, _) {
              final orgsAsync = ref.watch(organisationsProvider);
              return orgsAsync.when(
                loading: () => const SizedBox(height: 56,
                    child: Center(child: LinearProgressIndicator())),
                error: (_, __) => const SizedBox.shrink(),
                data: (orgs) => DropdownButtonFormField<String?>(
                  initialValue: orgs.any((o) => o.organisationId == _organisationId)
                      ? _organisationId
                      : null,
                  decoration: _inputDeco('Firm / Organisation'),
                  items: [
                    const DropdownMenuItem(
                        value: null,
                        child: Text('— None —',
                            style: TextStyle(fontSize: 13,
                                color: AppColors.textTertiary))),
                    ...orgs.map((o) => DropdownMenuItem(
                          value: o.organisationId,
                          child: Text(o.name,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) => setState(() => _organisationId = v),
                ),
              );
            }),
            const SizedBox(height: 16),

            // ── Financials ───────────────────────────────────────────────
            const Divider(height: 1),
            const SizedBox(height: 14),
            const Text('Financials',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              initialValue: _kCurrencies.contains(_baseCurrency) ? _baseCurrency : null,
              decoration: _inputDeco('Base Currency'),
              items: _kCurrencies
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _baseCurrency = v),
            ),
            const SizedBox(height: 18),

            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
            fontSize: 13, color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      );

  Widget _field(String label, TextEditingController ctrl, {String? hint}) =>
      TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: _inputDeco(label, hint: hint),
      );
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
            icon: Icons.record_voice_over_outlined,
            label: 'Interview',
            accent: AppColors.purple,
            onTap: () => context.go('/cases/$caseId/interview'),
          ),
          _CaptureToolButton(
            icon: Icons.draw_outlined,
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
    final voices = ref.watch(voiceNotesProvider(caseId)).value ?? [];
    final visits = ref.watch(attendancesProvider(caseId)).value ?? [];
    final timeline = ref.watch(timelineProvider(caseId)).value ?? [];
    final repairPeriods = ref.watch(repairPeriodsProvider(caseId)).value ?? [];
    final repairDocs = ref.watch(repairDocumentsProvider(caseId)).value ?? [];
    final certs = ref.watch(certificatesProvider(caseId)).value ?? [];
    final outputs = ref.watch(reportOutputsProvider(caseId)).value ?? [];
    final vessel = ref.watch(vesselForCaseProvider(caseId)).value;

    // Show amber left-border highlight on sections touched by the latest import.
    final review = ref.watch(importReviewProvider);
    final highlighted = (review?.caseId == caseId)
        ? review!.affectedSections
        : const <String>{};

    final List<Widget> sections = _sections(
        context, damage, attendees, voices, visits, timeline, repairPeriods,
        repairDocs, certs, outputs, vessel,
        highlighted: highlighted);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
    List<VoiceNoteModel> voices,
    List<SurveyAttendanceModel> visits,
    List<TimelineEventModel> timeline,
    List<RepairPeriodModel> repairPeriods,
    List<RepairDocumentModel> repairDocs,
    List<CertificateModel> certs,
    List<ReportOutput> outputs,
    VesselModel? vessel, {
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
        title: 'Certificates',
        countLabel: certs.isEmpty ? null : '${certs.length}',
        initiallyExpanded: certs.isNotEmpty,
        onOpen: () => Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => CertificatesScreen(caseId: caseId))),
        child: _certificatesContent(certs),
      ),
      _SectionCard(
        accentColor: const Color(0xFF4A7FA5),
        icon: Icons.shield_outlined,
        title: 'Class & Statutory',
        onOpen: () => showModalBottomSheet(
          context: ctx,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _StatutoryEditSheet(caseId: caseId, vessel: vessel),
        ),
        child: _statutoryContent(vessel),
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
        accentColor: AppColors.midBlue,
        icon: Icons.build_outlined,
        title: 'Repairs',
        countLabel: repairPeriods.isEmpty
            ? null
            : '${repairPeriods.length} period${repairPeriods.length == 1 ? '' : 's'}',
        initiallyExpanded: repairPeriods.isNotEmpty,
        onOpen: () => ctx.go('/cases/$caseId/repairs'),
        child: _repairsContent(repairPeriods),
      ),

      _SectionCard(
        accentColor: AppColors.green,
        icon: Icons.receipt_outlined,
        title: 'Accounts',
        countLabel: repairDocs.isEmpty ? null : '${repairDocs.length}',
        onOpen: () => ctx.go('/cases/$caseId/accounts'),
        child: _accountsContent(repairDocs, damage?.occurrences ?? []),
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
        accentColor: AppColors.purple,
        icon: Icons.more_horiz_outlined,
        title: 'Other Matters of Relevance',
        onOpen: () => ctx.go('/cases/$caseId/reports'),
        child: const _SectionEmpty('Other matters — draft in Report Builder'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visits.map((v) {
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
            ),
          );
        }),
        if (attendees.isNotEmpty && visits.isNotEmpty)
          const Divider(height: 12, thickness: 0.5),
        ...attendees.map((a) => _AttendeeRow(attendee: a)),
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

  Widget _accountsContent(
    List<RepairDocumentModel> docs,
    List<OccurrenceModel> occurrences,
  ) {
    if (docs.isEmpty) return const _SectionEmpty('No invoices imported yet');
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
        Text('Summary',
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

  Widget _statutoryContent(VesselModel? vessel) {
    if (vessel == null) return const _SectionEmpty('No vessel linked yet');
    final hasAny = vessel.classStatus != null ||
        vessel.classConditions != null ||
        vessel.lastDrydockDate != null ||
        vessel.pscLastInspection != null ||
        vessel.ispsStatus != null ||
        (vessel.ismIncidentReported ?? false) ||
        (vessel.classIncidentReported ?? false);
    if (!hasAny) return const _SectionEmpty('Tap Open to add class & statutory details');

    String fmtDate(DateTime? d) =>
        d == null ? '—' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (vessel.classStatus != null) ...[
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
          ],
          if (vessel.classConditions != null && vessel.classConditions!.isNotEmpty)
            _StatutoryRow(label: 'Conditions', value: vessel.classConditions!),
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
            _StatutoryRow(label: 'ISM incident', value: 'Reported to flag/class'),
          if (vessel.classIncidentReported == true)
            _StatutoryRow(label: 'Class incident', value: 'Reported'),
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

// ── Class & Statutory edit sheet ──────────────────────────────────────────

class _StatutoryEditSheet extends ConsumerStatefulWidget {
  const _StatutoryEditSheet({required this.caseId, this.vessel});
  final String caseId;
  final VesselModel? vessel;

  @override
  ConsumerState<_StatutoryEditSheet> createState() => _StatutoryEditSheetState();
}

class _StatutoryEditSheetState extends ConsumerState<_StatutoryEditSheet> {
  final _classConditionsCtrl  = TextEditingController();
  final _drydockYardCtrl      = TextEditingController();

  ClassStatus?  _classStatus;
  PscResult?    _pscResult;
  IspsStatus?   _ispsStatus;
  DateTime?     _drydockDate;
  DateTime?     _pscDate;
  bool          _ismIncident   = false;
  bool          _classIncident = false;
  bool          _saving        = false;

  @override
  void initState() {
    super.initState();
    final v = widget.vessel;
    if (v == null) return;
    _classStatus           = v.classStatus;
    _classConditionsCtrl.text = v.classConditions ?? '';
    _drydockDate           = v.lastDrydockDate;
    _drydockYardCtrl.text  = v.lastDrydockYard ?? '';
    _pscDate               = v.pscLastInspection;
    _pscResult             = v.pscLastResult;
    _ispsStatus            = v.ispsStatus;
    _ismIncident           = v.ismIncidentReported  ?? false;
    _classIncident         = v.classIncidentReported ?? false;
  }

  @override
  void dispose() {
    _classConditionsCtrl.dispose();
    _drydockYardCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = widget.vessel;
    if (v == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(vesselForCaseProvider(widget.caseId).notifier).saveVessel(
        vesselId: v.vesselId,
        fields: {
          'class_status':           _classStatus?.value,
          'class_conditions':       _classConditionsCtrl.text.trim().isEmpty ? null : _classConditionsCtrl.text.trim(),
          'last_drydock_date':      _drydockDate?.toIso8601String().split('T').first,
          'last_drydock_yard':      _drydockYardCtrl.text.trim().isEmpty ? null : _drydockYardCtrl.text.trim(),
          'psc_last_inspection':    _pscDate?.toIso8601String().split('T').first,
          'psc_last_result':        _pscResult?.value,
          'isps_status':            _ispsStatus?.value,
          'ism_incident_reported':  _ismIncident,
          'class_incident_reported': _classIncident,
        },
      );
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      if (mounted) showError(context, 'Save failed: $e', error: e, stack: st, tag: 'Statutory');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate(DateTime? current, ValueChanged<DateTime?> onPicked) async {
    final d = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) onPicked(d);
  }

  String _fmtDate(DateTime? d) =>
      d == null ? 'Not set' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    if (widget.vessel == null) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: const Text('No vessel linked to this case yet.',
            style: TextStyle(color: AppColors.textTertiary)),
      );
    }

    Widget sectionHeader(String title) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(title,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 0.8)),
    );

    Widget chipRow<T>(List<T> values, T? selected, String Function(T) label,
        ValueChanged<T?> onChanged) {
      return Wrap(
        spacing: 8,
        children: values.map((v) {
          final active = v == selected;
          return ChoiceChip(
            label: Text(label(v),
                style: TextStyle(
                    fontSize: 12,
                    color: active ? Colors.white : AppColors.textSecondary)),
            selected: active,
            selectedColor: AppColors.midBlue,
            backgroundColor: AppColors.surface,
            onSelected: (_) => setState(() => onChanged(active ? null : v)),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        }).toList(),
      );
    }

    Widget dateRow(String label, DateTime? date, ValueChanged<DateTime?> onPicked) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        trailing: TextButton(
          onPressed: () => _pickDate(date, onPicked),
          child: Text(_fmtDate(date),
              style: const TextStyle(fontSize: 13, color: AppColors.midBlue)),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Class & Statutory',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            sectionHeader('CLASSIFICATION'),
            chipRow(
              ClassStatus.values, _classStatus,
              (s) => s.value.replaceAll('_', ' ').toUpperCase(),
              (v) { _classStatus = v; },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _classConditionsCtrl,
              decoration: const InputDecoration(
                labelText: 'Class conditions',
                hintText: 'Any conditions attached to class',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
            sectionHeader('DRYDOCKING'),
            dateRow('Last drydock date', _drydockDate,
                (d) => setState(() => _drydockDate = d)),
            TextField(
              controller: _drydockYardCtrl,
              decoration: const InputDecoration(
                labelText: 'Drydock yard',
                hintText: 'e.g. Sembcorp Marine, Singapore',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            sectionHeader('PORT STATE CONTROL'),
            dateRow('Last PSC inspection', _pscDate,
                (d) => setState(() => _pscDate = d)),
            chipRow(
              PscResult.values, _pscResult,
              (r) => r.value.replaceAll('_', ' ').toUpperCase(),
              (v) { _pscResult = v; },
            ),
            sectionHeader('ISPS'),
            chipRow(
              IspsStatus.values, _ispsStatus,
              (s) => s.value.replaceAll('_', ' ').toUpperCase(),
              (v) { _ispsStatus = v; },
            ),
            sectionHeader('INCIDENTS'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('ISM incident reported to flag/class',
                  style: TextStyle(fontSize: 13)),
              value: _ismIncident,
              onChanged: (v) => setState(() => _ismIncident = v),
              activeThumbColor: AppColors.midBlue,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Class incident reported',
                  style: TextStyle(fontSize: 13)),
              value: _classIncident,
              onChanged: (v) => setState(() => _classIncident = v),
              activeThumbColor: AppColors.midBlue,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: AppColors.midBlue),
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
