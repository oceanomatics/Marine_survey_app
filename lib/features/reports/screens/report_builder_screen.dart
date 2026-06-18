// lib/features/reports/screens/report_builder_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/report_provider.dart';
import '../widgets/report_preview.dart';
import '../widgets/section_editor.dart';
import '../widgets/new_output_sheet.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';

class ReportBuilderScreen extends ConsumerStatefulWidget {
  const ReportBuilderScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<ReportBuilderScreen> createState() =>
      _ReportBuilderScreenState();
}

class _ReportBuilderScreenState
    extends ConsumerState<ReportBuilderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ReportOutput? _activeOutput;
  bool _buildingDraft = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    final sections = ref.watch(sectionDraftProvider(widget.caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Report Builder'),
            if (_activeOutput != null)
              Text(
                '${_activeOutput!.outputType.label}'
                '${_activeOutput!.sequenceNo > 1 ? ' No.${_activeOutput!.sequenceNo}' : ''}'
                ' — ${_activeOutput!.status.label}',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.7)),
              ),
          ],
        ),
        bottom: _activeOutput != null
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor:
                    Colors.white.withValues(alpha: 0.55),
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
                ],
              )
            : null,
        actions: [
          if (_activeOutput != null && sections.isNotEmpty)
            _StatusActions(
              output: _activeOutput!,
              allApproved:
                  sections.values.every((s) => s.approved),
              onStatusChange: (status) => _updateStatus(status),
            ),
        ],
      ),
      body: outputsAsync.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (outputs) {
          if (outputs.isEmpty || _activeOutput == null) {
            return _NoOutputs(
              outputs: outputs,
              onSelect: (o) => setState(() => _activeOutput = o),
              onCreate: () => _showNewOutput(context),
            );
          }
          return assembledAsync.when(
            loading: () => const AppLoadingWidget(
                message: 'Loading case data...'),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (assembled) {
              if (sections.isEmpty && !_buildingDraft) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _buildDraft(assembled);
                });
              }
              return TabBarView(
                controller: _tabController,
                children: [
                  // ── Editor tab ──────────────────────────────────
                  _EditorTab(
                    sections: sections,
                    caseId: widget.caseId,
                    isLocked: _activeOutput!.isLocked,
                    onAiDraft: () => _buildDraft(assembled, aiDraft: true),
                    buildingDraft: _buildingDraft,
                  ),
                  // ── Preview tab ─────────────────────────────────
                  ReportPreview(
                    output: _activeOutput!,
                    assembled: assembled,
                    sections: sections,
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: _activeOutput == null
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
    final existingCount = ref
        .read(reportOutputsProvider(widget.caseId))
        .valueOrNull
        ?.length ?? 0;
    final jobNumber = ref
        .read(assembledDataProvider(widget.caseId))
        .valueOrNull
        ?.caseData['job_number'] as String? ?? widget.caseId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewOutputSheet(
        caseId: widget.caseId,
        jobNumber: jobNumber,
        existingCount: existingCount,
        onCreate: (type, reportNumber, sequenceNo) async {
          final output = await ref
              .read(reportOutputsProvider(widget.caseId).notifier)
              .createOutput(
                caseId:       widget.caseId,
                type:         type,
                reportNumber: reportNumber,
                sequenceNo:   sequenceNo,
              );
          setState(() => _activeOutput = output);
        },
      ),
    );
  }

  Future<void> _buildDraft(AssembledReportData assembled,
      {bool aiDraft = false}) async {
    setState(() => _buildingDraft = true);
    await ref
        .read(sectionDraftProvider(widget.caseId).notifier)
        .buildSections(assembled, aiDraft: aiDraft);
    setState(() => _buildingDraft = false);
  }

  Future<void> _updateStatus(ReportStatus status) async {
    await ref
        .read(reportOutputsProvider(widget.caseId).notifier)
        .updateStatus(_activeOutput!.outputId, status);
    setState(() => _activeOutput =
        _activeOutput!.copyWith(status: status));
  }
}

extension on ReportOutput {
  ReportOutput copyWith({ReportStatus? status}) => ReportOutput(
        outputId:    outputId,
        caseId:      caseId,
        outputType:  outputType,
        status:      status ?? this.status,
        sections:    sections,
        reportNumber: reportNumber,
        sequenceNo:  sequenceNo,
        issuedDate:  issuedDate,
        issuedTo:    issuedTo,
        filePath:    filePath,
        createdAt:   createdAt,
      );
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
                    width: 36, height: 36,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
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
            style: TextStyle(
                fontSize: 13, color: AppColors.textTertiary),
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
    required this.isLocked,
    required this.onAiDraft,
    required this.buildingDraft,
  });

  final Map<SectionType, ReportSection> sections;
  final String caseId;
  final bool isLocked;
  final VoidCallback onAiDraft;
  final bool buildingDraft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (buildingDraft) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: AppColors.midBlue),
          SizedBox(height: 16),
          Text('Assembling report sections...',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ]),
      );
    }

    return Column(
      children: [
        // AI draft banner
        if (!isLocked)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            color: AppColors.lightPurple,
            child: Row(children: [
              const Icon(Icons.auto_awesome,
                  size: 14, color: AppColors.purple),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Narrative sections can be AI-drafted from your collected data',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.purple),
                ),
              ),
              TextButton(
                onPressed: onAiDraft,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  backgroundColor:
                      AppColors.purple.withValues(alpha: 0.1),
                ),
                child: const Text('Draft with AI',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.purple,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),

        // Sections list
        Expanded(
          child: sections.isEmpty
              ? const Center(
                  child: Text('Building sections...',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: sections.length,
                  itemBuilder: (_, i) {
                    final entry =
                        sections.entries.toList()[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SectionEditor(
                        section: entry.value,
                        isLocked: isLocked,
                        onContentChanged: (content) => ref
                            .read(sectionDraftProvider(caseId)
                                .notifier)
                            .updateContent(entry.key, content),
                        onToggleApproved: () => ref
                            .read(sectionDraftProvider(caseId)
                                .notifier)
                            .toggleApproved(entry.key),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ReportStatus>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onSelected: onStatusChange,
      itemBuilder: (_) => [
        if (output.status == ReportStatus.draft)
          const PopupMenuItem(
            value: ReportStatus.submittedQc,
            child: Text('Submit for QC'),
          ),
        if (output.status == ReportStatus.submittedQc)
          const PopupMenuItem(
            value: ReportStatus.qcComments,
            child: Text('Add QC Comments'),
          ),
        if (output.status == ReportStatus.qcComments)
          const PopupMenuItem(
            value: ReportStatus.approved,
            child: Text('Mark Approved'),
          ),
        if (output.status == ReportStatus.approved)
          const PopupMenuItem(
            value: ReportStatus.issued,
            child: Text('Mark Issued'),
          ),
        if (output.status == ReportStatus.issued)
          const PopupMenuItem(
            value: ReportStatus.locked,
            child: Text('Lock Report'),
          ),
      ],
    );
  }
}
