// lib/features/documents/screens/production_manager_screen.dart
//
// §4.1 Production Manager — per-case status of what's been AI-processed,
// what's pending, and what failed and needs retry. Client-side scope
// decided with the surveyor 13 July 2026: this reads the same
// extraction_status columns the (now auto-firing, non-blocking) Document
// Vault and Accounts extraction flows already write to — there is no
// separate server-side job-queue table, so "what's queued" here means
// "what this app process has fired or will fire", not a truly independent
// backend queue (see docs/TODO.md §4.1 for the full scope note).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/back_app_bar.dart';
import '../../accounts/models/accounts_models.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../providers/document_provider.dart';

enum _ItemKind { document, invoice }

class _Item {
  const _Item({
    required this.kind,
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
  });

  final _ItemKind kind;
  final String id;
  final String title;
  final String
      status; // pending | processing | ready_for_review | completed | failed
  final DateTime? createdAt;

  IconData get icon => kind == _ItemKind.document
      ? Icons.description_outlined
      : Icons.receipt_long_outlined;
}

class ProductionManagerScreen extends ConsumerWidget {
  const ProductionManagerScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentProvider(caseId));
    final invoicesAsync = ref.watch(repairDocumentsProvider(caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BackAppBar(title: Text('AI Processing')),
      body: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (docs) => invoicesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (invoices) => _Body(
            caseId: caseId,
            items: _collect(docs, invoices),
          ),
        ),
      ),
    );
  }

  /// Only items the extraction pipeline actually knows about — i.e. a
  /// non-null, non-'not_applicable' extraction_status. Docs added without a
  /// file (addRecord) or explicitly opted out (willExtract: false) never
  /// enter this list, same as they never show an Extract button today.
  List<_Item> _collect(
      List<DocumentModel> docs, List<RepairDocumentModel> invoices) {
    final items = <_Item>[
      for (final d in docs)
        if (d.extractionStatus != null &&
            d.extractionStatus != 'not_applicable')
          _Item(
            kind: _ItemKind.document,
            id: d.docId,
            title: d.title,
            status: d.extractionStatus!,
            createdAt: d.createdAt,
          ),
      for (final inv in invoices)
        if (inv.extractionStatus != null)
          _Item(
            kind: _ItemKind.invoice,
            id: inv.id,
            title: inv.effectiveName.isNotEmpty ? inv.effectiveName : 'Invoice',
            status: inv.extractionStatus!,
            createdAt: inv.createdAt,
          ),
    ];
    items.sort((a, b) {
      const order = {
        'processing': 0,
        'ready_for_review': 1,
        'failed': 2,
        'pending': 3,
        'completed': 4,
      };
      final byStatus = (order[a.status] ?? 9).compareTo(order[b.status] ?? 9);
      if (byStatus != 0) return byStatus;
      final ad = a.createdAt ?? DateTime(2000);
      final bd = b.createdAt ?? DateTime(2000);
      return bd.compareTo(ad);
    });
    return items;
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.caseId, required this.items});
  final String caseId;
  final List<_Item> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined,
                size: 48,
                color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            const Text('No AI extraction activity yet',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 4),
            const Text(
              'Documents and invoices you import start extraction\n'
              'automatically — this list fills in as that happens.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final processing = items.where((i) => i.status == 'processing').length;
    final needsReview =
        items.where((i) => i.status == 'ready_for_review').length;
    final failed = items.where((i) => i.status == 'failed').length;

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: AppColors.background,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _SummaryStat(
                  label: 'Processing',
                  value: processing,
                  color: AppColors.amber),
              _SummaryStat(
                  label: 'Ready to review',
                  value: needsReview,
                  color: AppColors.midBlue),
              _SummaryStat(
                  label: 'Failed', value: failed, color: AppColors.error),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _ItemCard(caseId: caseId, item: items[i]),
          ),
        ),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat(
      {required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('$value $label',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
        ],
      );
}

class _ItemCard extends ConsumerStatefulWidget {
  const _ItemCard({required this.caseId, required this.item});
  final String caseId;
  final _Item item;

  @override
  ConsumerState<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends ConsumerState<_ItemCard> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      if (widget.item.kind == _ItemKind.document) {
        await ref
            .read(documentProvider(widget.caseId).notifier)
            .extract(widget.item.id);
      } else {
        await ref
            .read(repairDocumentsProvider(widget.caseId).notifier)
            .extractWithAI(widget.item.id);
      }
    } catch (_) {
      // Status already recorded as 'failed' — the badge below reflects it.
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  void _open(BuildContext context) {
    final base = '/cases/${widget.caseId}';
    context.push(widget.item.kind == _ItemKind.document
        ? '$base/documents?reviewDocId=${widget.item.id}'
        : '$base/accounts/${widget.item.id}');
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final (label, color) = switch (item.status) {
      'processing' => ('Extracting…', AppColors.amber),
      'ready_for_review' => ('Ready to review', AppColors.midBlue),
      'failed' => ('Failed', AppColors.error),
      'completed' => ('Done', AppColors.success),
      _ => ('Queued', AppColors.textSecondary),
    };

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(item.icon, size: 18, color: AppColors.textTertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
              const SizedBox(width: 8),
              if (item.status == 'processing' || _retrying)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600)),
                ),
                if (item.status == 'failed') ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    color: AppColors.midBlue,
                    tooltip: 'Retry',
                    onPressed: _retry,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
