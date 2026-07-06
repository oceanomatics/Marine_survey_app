// lib/features/reports/screens/report_builder_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/report_provider.dart';
import '../widgets/report_preview.dart';
import '../widgets/section_editor.dart';
import '../widgets/new_output_sheet.dart';
import '../widgets/advice_summary_card.dart';

import '../widgets/export_button.dart';
import '../widgets/sign_off_sheet.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/case_photo_picker_sheet.dart';
import '../../../shared/widgets/drive_photo_image.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../cases/providers/cases_provider.dart';
import '../../photos/models/photo_model.dart';
import '../../photos/providers/photo_provider.dart';

class ReportBuilderScreen extends ConsumerStatefulWidget {
  const ReportBuilderScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<ReportBuilderScreen> createState() =>
      _ReportBuilderScreenState();
}

class _ReportBuilderScreenState extends ConsumerState<ReportBuilderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Only the id is kept as local state — the actual ReportOutput is always
  // derived fresh from reportOutputsProvider on every build (see below).
  // Previously this held the whole ReportOutput, frozen at selection time,
  // which meant any mutation elsewhere (cover photo, changes summary) never
  // showed up here without a matching manual patch — exactly the bug where
  // changing the cover photo didn't update the preview.
  String? _activeOutputId;
  bool _buildingDraft = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outputsAsync = ref.watch(reportOutputsProvider(widget.caseId));
    final assembledAsync = ref.watch(assembledDataProvider(widget.caseId));

    final outputs = outputsAsync.value ?? const <ReportOutput>[];
    final activeOutput = outputs.cast<ReportOutput?>().firstWhere(
          (o) => o?.outputId == _activeOutputId,
          orElse: () => null,
        );
    // Sections are scoped per report output — each output gets its own
    // draft state so switching between e.g. Preliminary and Final on the
    // same case doesn't bleed stale sections across.
    final sections = activeOutput != null
        ? ref.watch(sectionDraftProvider(
            (caseId: widget.caseId, outputId: activeOutput.outputId)))
        : const <SectionType, ReportSection>{};

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Report Builder'),
            if (activeOutput != null)
              Text(
                '${activeOutput.outputType.label}'
                '${activeOutput.sequenceNo > 1 ? ' No.${activeOutput.sequenceNo}' : ''}'
                ' — ${activeOutput.status.label}',
                style: TextStyle(
                    fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
              ),
          ],
        ),
        bottom: activeOutput != null
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.edit_outlined, size: 15),
                        const SizedBox(width: 6),
                        const Text('Editor'),
                        if (sections.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: sections.values
                                          .where((s) => s.approved)
                                          .length ==
                                      sections.length
                                  ? AppColors.success
                                  : Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${sections.values.where((s) => s.approved).length}/${sections.length}',
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.preview_outlined, size: 15),
                        SizedBox(width: 6),
                        Text('Preview'),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fact_check_outlined, size: 15),
                        SizedBox(width: 6),
                        Text('Postprocessing'),
                      ],
                    ),
                  ),
                ],
              )
            : null,
      ),
      body: outputsAsync.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (outputs) {
          if (outputs.isEmpty || activeOutput == null) {
            return _NoOutputs(
              outputs: outputs,
              onSelect: (o) => setState(() => _activeOutputId = o.outputId),
              onCreate: () => _showNewOutput(context),
            );
          }
          return assembledAsync.when(
            loading: () =>
                const AppLoadingWidget(message: 'Loading case data...'),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (assembled) {
              if (sections.isEmpty && !_buildingDraft) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // aiDraft: true — Background / Causation / General
                  // Services auto-draft from available data and context
                  // cues on first build of a report, rather than requiring
                  // a manual "Draft with AI" click per section. Safe to
                  // call on every mount: buildSections() only actually
                  // invokes the AI when no persisted section content
                  // exists yet for that type (see report_provider.dart).
                  _buildDraft(assembled, activeOutput, aiDraft: true);
                });
              }
              return TabBarView(
                controller: _tabController,
                children: [
                  // ── Editor tab ──────────────────────────────────
                  _EditorTab(
                    sections: sections,
                    caseId: widget.caseId,
                    outputId: activeOutput.outputId,
                    isLocked: activeOutput.isLocked,
                    buildingDraft: _buildingDraft,
                    output: activeOutput,
                    assembled: assembled,
                  ),
                  // ── Preview tab ─────────────────────────────────
                  ReportPreview(
                    output: activeOutput,
                    assembled: assembled,
                    sections: sections,
                    caseId: widget.caseId,
                  ),
                  // ── Postprocessing tab ───────────────────────────
                  _PostprocessingTab(
                    output: activeOutput,
                    assembled: assembled,
                    sections: sections,
                    caseId: widget.caseId,
                    allApproved: sections.values.every((s) => s.approved),
                    onStatusChange: (status) => _updateStatus(status),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: activeOutput == null
          ? FloatingActionButton.extended(
              onPressed: () => _showNewOutput(context),
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New Report',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }

  void _showNewOutput(BuildContext context) {
    final existingCount =
        ref.read(reportOutputsProvider(widget.caseId)).valueOrNull?.length ?? 0;
    // Prefer assembled data; fall back to caseProvider (always loaded by now).
    final technicalFileNo = (ref
            .read(assembledDataProvider(widget.caseId))
            .valueOrNull
            ?.caseData['technical_file_no'] as String?) ??
        ref.read(caseProvider(widget.caseId)).valueOrNull?.technicalFileNo ??
        '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewOutputSheet(
        caseId: widget.caseId,
        technicalFileNo: technicalFileNo,
        existingCount: existingCount,
        onCreate: (type, reportNumber, sequenceNo) async {
          final output = await ref
              .read(reportOutputsProvider(widget.caseId).notifier)
              .createOutput(
                caseId: widget.caseId,
                type: type,
                reportNumber: reportNumber,
                sequenceNo: sequenceNo,
              );
          setState(() => _activeOutputId = output.outputId);
        },
      ),
    );
  }

  Future<void> _buildDraft(AssembledReportData assembled, ReportOutput output,
      {bool aiDraft = false}) async {
    setState(() => _buildingDraft = true);
    await ref
        .read(sectionDraftProvider(
            (caseId: widget.caseId, outputId: output.outputId)).notifier)
        .buildSections(assembled, output: output, aiDraft: aiDraft);
    setState(() => _buildingDraft = false);
  }

  Future<void> _updateStatus(ReportStatus status) async {
    final outputId = _activeOutputId;
    if (outputId == null) return;
    await ref
        .read(reportOutputsProvider(widget.caseId).notifier)
        .updateStatus(outputId, status);
  }
}

// ── No outputs state ───────────────────────────────────────────────────────

class _NoOutputs extends StatelessWidget {
  const _NoOutputs({
    required this.outputs,
    required this.onSelect,
    required this.onCreate,
  });

  final List<ReportOutput> outputs;
  final ValueChanged<ReportOutput> onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    if (outputs.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Select a report to edit',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          ...outputs.map((o) => Card(
                child: ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.description_outlined,
                        color: AppColors.midBlue, size: 18),
                  ),
                  title: Text(
                    '${o.outputType.label}'
                    '${o.sequenceNo > 1 ? ' No.${o.sequenceNo}' : ''}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(o.status.label,
                      style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textTertiary),
                  onTap: () => onSelect(o),
                ),
              )),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create new report'),
          ),
        ],
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.description_outlined,
              size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          const Text('No reports yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text(
            'Create a Preliminary Report,\nAdvice or Final Report',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create first report'),
          ),
        ]),
      ),
    );
  }
}

// ── Editor tab ─────────────────────────────────────────────────────────────

class _EditorTab extends ConsumerWidget {
  const _EditorTab({
    required this.sections,
    required this.caseId,
    required this.outputId,
    required this.isLocked,
    required this.buildingDraft,
    required this.output,
    required this.assembled,
  });

  final Map<SectionType, ReportSection> sections;
  final String caseId;
  final String outputId;
  final bool isLocked;
  final bool buildingDraft;
  final ReportOutput output;
  final AssembledReportData assembled;

  static const _aiDraftableTypes = {
    SectionType.background,
    SectionType.causation,
    SectionType.generalServices,
    SectionType.previousWorks,
    SectionType.extraExpenses,
    SectionType.contractualHire,
    SectionType.otherMatters,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (buildingDraft) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: AppColors.midBlue),
          SizedBox(height: 16),
          Text('Assembling report sections...',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ]),
      );
    }

    if (sections.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: _CoverPhotoPicker(caseId: caseId),
          ),
          const Expanded(
            child: Center(
              child: Text('Building sections...',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
          ),
        ],
      );
    }

    // Single scrollable list — the cover photo picker and Advice Summary
    // card are header items (index 0/1) rather than fixed siblings of the
    // section list, so a tall/expanded Advice Summary card can never starve
    // the section list of height (that was a real overflow-and-disappear
    // bug found on-device: a RenderFlex overflow here hid the entire
    // section-by-section editor below it).
    // executiveSummary is excluded here — the AdviceSummaryCard above *is*
    // its editor (spec: the Advice Summary table is the Executive Summary,
    // there is no separate free-text section rendered anywhere anymore —
    // see docs/report_builder_editor_notes.md "Section: Executive Summary
    // (Advice Summary Table)"), so showing its old free-text box here
    // would be a dead field the surveyor could fill in for nothing.
    final orderedKeys = oceanoSectionOrder
        .where(
            (t) => t != SectionType.executiveSummary && sections.containsKey(t))
        .toList();
    final notifier = ref.read(
        sectionDraftProvider((caseId: caseId, outputId: outputId)).notifier);

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orderedKeys.length + 2,
      itemBuilder: (_, i) {
        if (i == 0) return _CoverPhotoPicker(caseId: caseId);
        if (i == 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 10),
            child: Column(
              children: [
                AdviceSummaryCard(
                  output: output,
                  assembled: assembled,
                  isLocked: isLocked,
                ),
                const SizedBox(height: 4),
                const Divider(height: 1, color: AppColors.border),
              ],
            ),
          );
        }

        final key = orderedKeys[i - 2];
        final section = sections[key]!;
        final hasGeneralServiceCues = assembled.surveyorNotes
            .any((n) => n['report_section'] == 'general_expenses');
        final canAiDraft = !isLocked &&
            !section.isLocked &&
            section.content.isEmpty &&
            _aiDraftableTypes.contains(key) &&
            (key != SectionType.generalServices || hasGeneralServiceCues);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SectionEditor(
            section: section,
            isLocked: isLocked,
            assembled: assembled,
            sectionNumber: oceanoSectionNumber(key),
            onContentChanged: (content) => notifier.updateContent(key, content),
            onSurveyorReviewChanged: (review) =>
                notifier.setSurveyorReview(key, review),
            onDraftWithAi: canAiDraft
                ? () {
                    final assembled =
                        ref.read(assembledDataProvider(caseId)).valueOrNull;
                    if (assembled != null) {
                      notifier.draftSectionWithAi(key, assembled);
                    }
                  }
                : null,
          ),
        );
      },
    );
  }
}

// ── Cover photo picker (top of Editor tab) ─────────────────────────────────

class _CoverPhotoPicker extends ConsumerWidget {
  const _CoverPhotoPicker({required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(photosProvider(caseId)).value ?? [];
    // Single case-wide cover photo — shared with the Photo Gallery and
    // Vessel Particulars, kept in sync via PhotoAllocation.coverPage.
    final coverPhoto = photos.coverPhoto;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: coverPhoto != null
                ? DrivePhotoImage(
                    photo: coverPhoto,
                    fit: BoxFit.cover,
                    noSourceBuilder: (_) => const Icon(Icons.image_outlined,
                        size: 16, color: AppColors.textTertiary),
                    errorBuilder: (_) => const Icon(Icons.image_outlined,
                        size: 16, color: AppColors.textTertiary),
                  )
                : const Icon(Icons.image_outlined,
                    size: 16, color: AppColors.textTertiary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coverPhoto != null
                      ? (coverPhoto.caption?.isNotEmpty == true
                          ? coverPhoto.caption!
                          : 'Cover photo')
                      : 'No cover photo',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Shared across Gallery, Vessel Particulars & Report',
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final picked = await showModalBottomSheet<List<PhotoModel>>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => CasePhotoPickerSheet(
                  caseId: caseId,
                  title: 'Select Cover Photo',
                ),
              );
              if (picked == null || picked.isEmpty) return;
              await ref
                  .read(photosProvider(caseId).notifier)
                  .updateAllocation(picked.first.id, PhotoAllocation.coverPage);
            },
            style: TextButton.styleFrom(
                foregroundColor: AppColors.navy,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            child: const Text('Change',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Preview tab footer ─────────────────────────────────────────────────────

class _PostprocessingTab extends ConsumerWidget {
  const _PostprocessingTab({
    required this.output,
    required this.assembled,
    required this.sections,
    required this.caseId,
    required this.allApproved,
    required this.onStatusChange,
  });

  final ReportOutput output;
  final AssembledReportData assembled;
  final Map<SectionType, ReportSection> sections;
  final String caseId;
  final bool allApproved;
  final ValueChanged<ReportStatus> onStatusChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFinal = output.outputType == OutputType.final_;
    final case_ = ref.watch(caseProvider(caseId)).value;
    final signedAttending = case_?.signedOffAttending ?? false;
    final signedReviewing = case_?.signedOffReviewing ?? false;
    final signed = (signedAttending ? 1 : 0) + (signedReviewing ? 1 : 0);
    final bothSigned = signedAttending && signedReviewing;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status / QC stepper
          _StatusActions(
            output: output,
            allApproved: allApproved,
            onStatusChange: onStatusChange,
          ),
          const SizedBox(height: 16),

          // Changes summary — only shown when this report supersedes a prior version
          if (output.supersedesVersion != null)
            _ChangesSummaryField(output: output, caseId: caseId),

          // Sign-off row — Final reports only
          if (isFinal) ...[
            Row(
              children: [
                Icon(
                  bothSigned ? Icons.verified_outlined : Icons.draw_outlined,
                  size: 16,
                  color:
                      bothSigned ? AppColors.success : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  bothSigned
                      ? 'Signed off ($signed/2)'
                      : 'Sign-off required ($signed/2)',
                  style: TextStyle(
                      fontSize: 12,
                      color: bothSigned
                          ? AppColors.success
                          : AppColors.textSecondary),
                ),
                const Spacer(),
                if (!bothSigned)
                  TextButton(
                    onPressed: () => showSignOffSheet(context, caseId),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.navy,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6)),
                    child: const Text('Sign Off',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          ExportButton(
            output: output,
            assembled: assembled,
            sections: sections,
          ),
        ],
      ),
    );
  }
}

// ── Changes summary field ──────────────────────────────────────────────────

class _ChangesSummaryField extends ConsumerStatefulWidget {
  const _ChangesSummaryField({required this.output, required this.caseId});

  final ReportOutput output;
  final String caseId;

  @override
  ConsumerState<_ChangesSummaryField> createState() =>
      _ChangesSummaryFieldState();
}

class _ChangesSummaryFieldState extends ConsumerState<_ChangesSummaryField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.output.changesSummary ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.history_outlined,
              size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              maxLines: 1,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Changes from ${widget.output.supersedesVersion}…',
                hintStyle: const TextStyle(
                    fontSize: 12, color: AppColors.textTertiary),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide:
                      const BorderSide(color: AppColors.midBlue, width: 1.5),
                ),
              ),
              onSubmitted: (v) => _save(v.trim()),
              onTapOutside: (_) => _save(_ctrl.text.trim()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(String value) async {
    if (value == (widget.output.changesSummary ?? '')) return;
    await ref
        .read(reportOutputsProvider(widget.caseId).notifier)
        .updateChangesSummary(widget.output.outputId, value);
  }
}

// ── Status actions ─────────────────────────────────────────────────────────

class _StatusActions extends StatelessWidget {
  const _StatusActions({
    required this.output,
    required this.allApproved,
    required this.onStatusChange,
  });

  final ReportOutput output;
  final bool allApproved;
  final ValueChanged<ReportStatus> onStatusChange;

  ({ReportStatus status, String label})? get _nextAction =>
      switch (output.status) {
        ReportStatus.draft => (
            status: ReportStatus.selfReviewed,
            label: 'Mark Self-Reviewed'
          ),
        ReportStatus.selfReviewed => (
            status: ReportStatus.submittedQc,
            label: 'Submit for QC'
          ),
        ReportStatus.submittedQc => (
            status: ReportStatus.qcComments,
            label: 'Add QC Comments'
          ),
        ReportStatus.qcComments => (
            status: ReportStatus.approved,
            label: 'Mark Approved'
          ),
        ReportStatus.approved => (
            status: ReportStatus.issued,
            label: 'Mark Issued'
          ),
        ReportStatus.issued => (
            status: ReportStatus.locked,
            label: 'Lock Report'
          ),
        ReportStatus.locked => null,
      };

  @override
  Widget build(BuildContext context) {
    final next = _nextAction;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            output.status == ReportStatus.locked
                ? Icons.lock_outline
                : Icons.rule_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Status',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.4)),
                Text(output.status.label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
          if (next != null)
            ElevatedButton(
              onPressed: () => onStatusChange(next.status),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(next.label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
