// lib/features/capture/screens/quick_capture_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/quick_capture_provider.dart';
import '../widgets/capture_item_card.dart';
import '../widgets/route_picker_sheet.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/back_app_bar.dart';

class QuickCaptureScreen extends ConsumerStatefulWidget {
  const QuickCaptureScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<QuickCaptureScreen> createState() =>
      _QuickCaptureScreenState();
}

class _QuickCaptureScreenState
    extends ConsumerState<QuickCaptureScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _routingAll = false;

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
    final captureAsync =
        ref.watch(quickCaptureProvider(widget.caseId));

    return captureAsync.when(
      loading: () => const Scaffold(
          body: AppLoadingWidget(message: 'Loading inbox...')),
      error: (e, _) => Scaffold(
        appBar: BackAppBar(title: const Text('Quick Capture Inbox')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (cs) => _buildScaffold(cs),
    );
  }

  Widget _buildScaffold(QuickCaptureState cs) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quick Capture Inbox'),
            Text(
              '${cs.pendingCount} pending',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
        bottom: TabBar(
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
                  const Text('Pending'),
                  if (cs.pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.coral,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        cs.pendingCount.toString(),
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Text(
                  'Routed (${cs.routed.length})'),
            ),
          ],
        ),
        actions: [
          if (cs.pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _routingAll ? null : () => _routeAll(cs),
                icon: _routingAll
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 16),
                label: const Text('Route All',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Pending tab ─────────────────────────────────────────
          cs.pending.isEmpty
              ? _EmptyPending()
              : _CaptureList(
                  items: cs.pending,
                  caseId: widget.caseId,
                  showActions: true,
                  onRoute: (item) => _showRoutePicker(item),
                  onDiscard: (id) => ref
                      .read(quickCaptureProvider(widget.caseId)
                          .notifier)
                      .discardCapture(id),
                ),

          // ── Routed tab ──────────────────────────────────────────
          cs.routed.isEmpty
              ? _EmptyRouted()
              : _CaptureList(
                  items: cs.routed,
                  caseId: widget.caseId,
                  showActions: false,
                  onRoute: (_) {},
                  onDiscard: (_) {},
                ),
        ],
      ),
    );
  }

  void _showRoutePicker(QuickCaptureModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoutePickerSheet(
        item: item,
        onRoute: (destination) async {
          await ref
              .read(quickCaptureProvider(widget.caseId).notifier)
              .routeCapture(
                captureId: item.captureId,
                destination: destination,
              );
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _routeAll(QuickCaptureState cs) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Route all with AI?'),
        content: Text(
          'Claude will suggest a destination for each of the '
          '${cs.pendingCount} pending items. You can review them '
          'in the Routed tab afterwards.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Route All'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _routingAll = true);
    try {
      await ref
          .read(quickCaptureProvider(widget.caseId).notifier)
          .routeAllWithAI();
      // Switch to routed tab
      _tabController.animateTo(1);
    } finally {
      if (mounted) setState(() => _routingAll = false);
    }
  }
}

// ── List view ─────────────────────────────────────────────────────────────

class _CaptureList extends StatelessWidget {
  const _CaptureList({
    required this.items,
    required this.caseId,
    required this.showActions,
    required this.onRoute,
    required this.onDiscard,
  });

  final List<QuickCaptureModel> items;
  final String caseId;
  final bool showActions;
  final ValueChanged<QuickCaptureModel> onRoute;
  final ValueChanged<String> onDiscard;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => CaptureItemCard(
        item: items[i],
        showActions: showActions,
        onRoute: () => onRoute(items[i]),
        onDiscard: () => onDiscard(items[i].captureId),
      ),
    );
  }
}

// ── Empty states ───────────────────────────────────────────────────────────

class _EmptyPending extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined,
              size: 64, color: AppColors.textTertiary),
          SizedBox(height: 16),
          Text('Inbox is clear',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          SizedBox(height: 8),
          Text(
            'Tap the Quick Capture button on the\nCase Home screen to add items',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ]),
      ),
    );
  }
}

class _EmptyRouted extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline,
              size: 64, color: AppColors.textTertiary),
          SizedBox(height: 16),
          Text('No routed items yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          SizedBox(height: 8),
          Text(
            'Items you route from the Pending tab\nwill appear here',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ]),
      ),
    );
  }
}
