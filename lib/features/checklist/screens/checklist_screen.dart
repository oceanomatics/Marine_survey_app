// lib/features/checklist/screens/checklist_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/checklist_provider.dart';
import '../widgets/checklist_item_tile.dart';
import '../widgets/stage_progress_header.dart';
import '../widgets/add_item_sheet.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/back_app_bar.dart';

class ChecklistScreen extends ConsumerStatefulWidget {
  const ChecklistScreen({super.key, required this.caseId, this.stage});
  final String caseId;
  final String? stage; // optional: jump straight to a stage

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _stages = ChecklistStage.values;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.stage != null
        ? _stages.indexWhere((s) => s.value == widget.stage).clamp(0, 3)
        : 0;
    _tabController = TabController(
        length: _stages.length, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checklistAsync = ref.watch(checklistProvider(widget.caseId));

    return checklistAsync.when(
      loading: () => const Scaffold(body: AppLoadingWidget()),
      error: (e, _) => Scaffold(
        appBar: BackAppBar(title: const Text('Checklist')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (cl) => _buildScaffold(cl),
    );
  }

  Widget _buildScaffold(ChecklistState cl) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Survey Checklist'),
            Text(
              '${cl.completedCount} of ${cl.totalCount} complete',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Column(
            children: [
              // Overall progress bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: cl.progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      cl.progress >= 1.0
                          ? AppColors.success
                          : Colors.white,
                    ),
                    minHeight: 4,
                  ),
                ),
              ),
              // Stage tabs
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor:
                    Colors.white.withValues(alpha: 0.55),
                labelStyle: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600),
                tabs: _stages.map((stage) {
                  final done = cl.stageCompleted(stage);
                  final total = cl.stageTotal(stage);
                  final complete = cl.stageComplete(stage);
                  return Tab(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (complete)
                              const Padding(
                                padding: EdgeInsets.only(right: 3),
                                child: Icon(Icons.check_circle,
                                    size: 11, color: Colors.greenAccent),
                              ),
                            Text(stage.label),
                          ],
                        ),
                        Text(
                          '$done/$total',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white
                                .withValues(alpha: complete ? 1 : 0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItem(context,
            _stages[_tabController.index]),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        tooltip: 'Add custom item',
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _stages
            .map((stage) => _StageTab(
                  caseId: widget.caseId,
                  stage: stage,
                  cl: cl,
                ))
            .toList(),
      ),
    );
  }

  void _showAddItem(BuildContext context, ChecklistStage stage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddChecklistItemSheet(
        stage: stage,
        onAdd: (text) => ref
            .read(checklistProvider(widget.caseId).notifier)
            .addCustomItem(
              caseId: widget.caseId,
              stage: stage,
              text: text,
            ),
      ),
    );
  }
}

// ── Stage tab content ──────────────────────────────────────────────────────

class _StageTab extends ConsumerWidget {
  const _StageTab({
    required this.caseId,
    required this.stage,
    required this.cl,
  });

  final String caseId;
  final ChecklistStage stage;
  final ChecklistState cl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = cl.forStage(stage);

    if (items.isEmpty) {
      return _EmptyStage(stage: stage);
    }

    return CustomScrollView(
      slivers: [
        // Stage progress header
        SliverToBoxAdapter(
          child: StageProgressHeader(
            stage: stage,
            completed: cl.stageCompleted(stage),
            total: cl.stageTotal(stage),
            progress: cl.stageProgress(stage),
            onMarkAllDone: cl.stageComplete(stage)
                ? null
                : () => ref
                    .read(checklistProvider(caseId).notifier)
                    .completeStage(stage),
          ),
        ),

        // Checklist items
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final item = items[i];
              return ChecklistItemTile(
                item: item,
                onToggle: () => ref
                    .read(checklistProvider(caseId).notifier)
                    .toggleItem(item),
                onNotesSaved: (notes) => ref
                    .read(checklistProvider(caseId).notifier)
                    .updateNotes(item, notes),
                onDelete: item.isCustom
                    ? () => ref
                        .read(checklistProvider(caseId).notifier)
                        .deleteCustomItem(item.checklistId)
                    : null,
                onNavigate: item.linkedSection != null
                    ? () => _navigateToSection(context, caseId, item)
                    : null,
              );
            },
            childCount: items.length,
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  void _navigateToSection(
      BuildContext context, String caseId, ChecklistItem item) {
    final section = item.linkedSection;
    if (section == null) return;

    final route = switch (section) {
      'vessel_particulars' => '/cases/$caseId/vessel',
      'damage_description' => '/cases/$caseId/damage',
      'cover'              => '/cases/$caseId/camera?section=cover',
      _                    => null,
    };
    if (route != null) context.go(route);
  }
}

class _EmptyStage extends StatelessWidget {
  const _EmptyStage({required this.stage});
  final ChecklistStage stage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.checklist_outlined,
            size: 56, color: AppColors.textTertiary),
        const SizedBox(height: 14),
        Text(
          'No items for ${stage.label}',
          style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        const Text('Tap + to add a custom item',
            style: TextStyle(
                fontSize: 12, color: AppColors.textTertiary)),
      ]),
    );
  }
}
