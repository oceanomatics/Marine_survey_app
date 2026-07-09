import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/accounts_models.dart';
import '../providers/accounts_provider.dart';
import '../widgets/import_invoice_sheet.dart';
import '../../../features/survey/providers/damage_provider.dart';
import '../../cases/providers/cases_provider.dart';
import '../../cases/models/case_model.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/back_app_bar.dart';

// ── Constants ──────────────────────────────────────────────────────────────

const _kAccent = Color(0xFF2E7D32);

String _fmtMoney(double v, String currency) {
  final parts = v.toStringAsFixed(2).split('.');
  final integral = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '$currency $integral.${parts[1]}';
}

// ── Screen ─────────────────────────────────────────────────────────────────

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync   = ref.watch(repairDocumentsProvider(caseId));
    final occurrences = ref.watch(damageProvider(caseId)).value?.occurrences
        ?? const [];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BackAppBar(
        title: const Text('Accounts'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.invalidate(repairDocumentsProvider(caseId)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Import Invoice'),
        onPressed: () => _import(context, ref),
      ),
      body: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (docs) =>
            _Body(caseId: caseId, docs: docs, occurrences: occurrences),
      ),
    );
  }

  void _import(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ImportInvoiceSheet(
        caseId: caseId,
        onImported: (_) {
          ref.invalidate(repairDocumentsProvider(caseId));
        },
      ),
    );
  }
}

// ── Body ───────────────────────────────────────────────────────────────────

class _Body extends StatefulWidget {
  const _Body({
    required this.caseId,
    required this.docs,
    required this.occurrences,
  });
  final String caseId;
  final List<RepairDocumentModel> docs;
  final List<OccurrenceModel> occurrences;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submitted = widget.docs.where((d) => d.submittedToInsurance).toList();
    final context_  = widget.docs.where((d) => !d.submittedToInsurance).toList();
    final summary   = AccountsSummary.fromDocuments(submitted);

    return Column(
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Cost Estimate always renders above Account Summary (§3.12
                // item 44) — the estimate is the forward-looking figure the
                // surveyor cares about first; the summary is the retrospective
                // record of what's actually been submitted.
                _CostEstimateSelector(
                  caseId: widget.caseId,
                  hasInvoices: submitted.isNotEmpty,
                ),
                _SummaryBanner(
                  summary: summary,
                  occurrences: widget.occurrences,
                  allLines: submitted.expand((d) => d.accountLines).toList(),
                ),
              ],
            ),
          ),
        ),
        TabBar(
          controller: _tabs,
          labelColor: _kAccent,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: _kAccent,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(text: 'Submitted (${submitted.length})'),
            Tab(text: 'Context Archive (${context_.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _DocList(docs: submitted, caseId: widget.caseId,
                  emptyText: 'No submitted invoices yet'),
              _DocList(docs: context_, caseId: widget.caseId,
                  emptyText: 'No context documents',
                  dimmed: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocList extends StatelessWidget {
  const _DocList({
    required this.docs,
    required this.caseId,
    required this.emptyText,
    this.dimmed = false,
  });
  final List<RepairDocumentModel> docs;
  final String caseId;
  final String emptyText;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 48,
                color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            Text(emptyText,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      itemCount: docs.length,
      itemBuilder: (_, i) => Opacity(
        opacity: dimmed ? 0.7 : 1.0,
        child: _DocumentCard(doc: docs[i], caseId: caseId),
      ),
    );
  }
}

// ── Summary banner ─────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({
    required this.summary,
    required this.occurrences,
    required this.allLines,
  });
  final AccountsSummary summary;
  final List<OccurrenceModel> occurrences;
  final List<AccountLineModel> allLines;

  @override
  Widget build(BuildContext context) {
    // Proper empty state (§3.12 item 41) — previously this fell through to
    // the normal banner with every row conditionally suppressed by its
    // `> 0.005` guard, leaving just the "Summary" label over a blank
    // surface-coloured rectangle. Show an explicit message instead.
    if (summary.totalDocuments == 0) {
      return Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 22, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No invoices submitted yet — the account summary will '
                'populate once invoices are imported and submitted.',
                style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                    fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    final cur = summary.primaryCurrency;

    // Build financial rows
    final finRows = <Widget>[];

    for (int i = 0; i < occurrences.length; i++) {
      final occ = occurrences[i];
      final uw = allLines
          .where((l) =>
              l.occurrenceId == occ.occurrenceId &&
              l.status != LineItemStatus.betterment)
          .fold(0.0, (s, l) => s + l.underwritersPortion);
      if (uw > 0.005) {
        finRows.add(_FinRow(
          label: 'Occ. ${i + 1} — ${occ.title ?? 'Occurrence ${i + 1}'}',
          amount: uw,
          currency: cur,
          color: _kAccent,
        ));
      }
    }

    final unallocated = allLines
        .where((l) =>
            l.occurrenceId == null &&
            l.status != LineItemStatus.betterment)
        .fold(0.0, (s, l) => s + l.underwritersPortion);
    if (unallocated > 0.005) {
      finRows.add(_FinRow(
        label: 'Unallocated',
        amount: unallocated,
        currency: cur,
        color: _kAccent,
      ));
    }

    final betterment = allLines
        .where((l) => l.status == LineItemStatus.betterment)
        .fold(0.0, (s, l) => s + l.grossAmount);
    if (betterment > 0.005) {
      finRows.add(_FinRow(
        label: 'Betterment',
        amount: betterment,
        currency: cur,
        color: Colors.brown,
      ));
    }

    if (summary.totalApprovedOwners > 0.005) {
      finRows.add(_FinRow(
        label: "Owner's account",
        amount: summary.totalApprovedOwners,
        currency: cur,
        color: Colors.orange,
      ));
    }

    final deferred = allLines
        .where((l) => l.apportionmentType == 'defer')
        .fold(0.0, (s, l) => s + l.grossAmount);
    if (deferred > 0.005) {
      finRows.add(_FinRow(
        label: 'Deferred to adjuster',
        amount: deferred,
        currency: cur,
        color: Colors.blueGrey,
      ));
    }

    if (summary.totalSubmitted > 0.005) {
      finRows.add(Divider(
          height: 12, color: AppColors.border.withValues(alpha: 0.5)));
      finRows.add(_FinRow(
        label: 'Total (gross)',
        amount: summary.totalSubmitted,
        currency: cur,
        color: AppColors.textPrimary,
        bold: true,
      ));
    }

    // ── Red flags / unfinished business ──────────────────────────────────
    final flags = <({String text, Color color, IconData icon})>[];

    final pendingLines = allLines
        .where((l) => l.status == LineItemStatus.pendingReview)
        .length;
    if (pendingLines > 0) {
      flags.add((
        text: '$pendingLines line${pendingLines == 1 ? '' : 's'} pending review',
        color: Colors.orange,
        icon: Icons.hourglass_empty_outlined,
      ));
    }

    final queriedLines = allLines
        .where((l) => l.status == LineItemStatus.queried)
        .length;
    if (queriedLines > 0) {
      flags.add((
        text: '$queriedLines line${queriedLines == 1 ? '' : 's'} queried',
        color: Colors.red,
        icon: Icons.help_outline,
      ));
    }

    final unallocatedLines = occurrences.isNotEmpty
        ? allLines.where((l) => l.occurrenceId == null).length
        : 0;
    if (unallocatedLines > 0) {
      flags.add((
        text: '$unallocatedLines line${unallocatedLines == 1 ? '' : 's'} not allocated to an occurrence',
        color: AppColors.textSecondary,
        icon: Icons.link_off_outlined,
      ));
    }

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Summary',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          if (finRows.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...finRows,
          ],
          if (flags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Divider(height: 1, color: AppColors.border.withValues(alpha: 0.4)),
            const SizedBox(height: 6),
            ...flags.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(f.icon, size: 12, color: f.color),
                      const SizedBox(width: 6),
                      Text(f.text,
                          style: TextStyle(
                              color: f.color, fontSize: 11)),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

// ── Cost estimate (Clause G-1 + §3.12 redesign) ─────────────────────────────
//
// Replaces the old single "Estimated Cost" figure + manual 3-way status
// picker + yes/no "Cost Inclusions" chips with:
//   - editable line items (suggested category + free-text description +
//     amount), so the estimate is itemised/explainable
//   - a free-text caveat/comment box
//   - an auto-derived status: no invoices at all -> "purely estimated"
//     automatically; once invoices exist, a yes/no prompt for "further
//     invoices expected?" drives ongoing vs. completed
//
// `cases.cost_includes_general_expenses` / `cost_includes_towing` are left
// alone on the model/DB (still read by the Report Builder's Advice Summary,
// see advice_summary_card.dart / advice_summary_rows.dart) — only this
// screen's yes/no chip UI for them is retired.

class _CostEstimateSelector extends ConsumerStatefulWidget {
  const _CostEstimateSelector({
    required this.caseId,
    required this.hasInvoices,
  });
  final String caseId;
  final bool hasInvoices;

  @override
  ConsumerState<_CostEstimateSelector> createState() =>
      _CostEstimateSelectorState();
}

class _CostEstimateSelectorState extends ConsumerState<_CostEstimateSelector> {
  final _feeHoursCtrl = TextEditingController();
  final _feeExpensesCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  String? _pendingStatus;
  bool _initialised = false;
  bool? _lastHasInvoices;

  @override
  void dispose() {
    _feeHoursCtrl.dispose();
    _feeExpensesCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String status) async {
    if (!mounted) return;
    setState(() => _pendingStatus = status);
    await ref
        .read(caseProvider(widget.caseId).notifier)
        .updateCaseRefs(costEstimateStatus: status);
  }

  Future<void> _updateFeeHours(String text) async {
    final value = double.tryParse(text.trim());
    if (value == null) return;
    await ref
        .read(caseProvider(widget.caseId).notifier)
        .updateCaseRefs(surveyFeeReserveHours: value);
  }

  Future<void> _updateFeeExpenses(String text) async {
    final value = double.tryParse(text.trim());
    if (value == null) return;
    await ref
        .read(caseProvider(widget.caseId).notifier)
        .updateCaseRefs(surveyFeeReserveExpenses: value);
  }

  Future<void> _updateComment(String text) async {
    await ref
        .read(caseProvider(widget.caseId).notifier)
        .updateCaseRefs(costEstimateComment: text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final caseModel = ref.watch(caseProvider(widget.caseId)).value;
    final items = ref.watch(costEstimateItemsProvider(widget.caseId)).value ?? [];
    if (caseModel == null) return const SizedBox.shrink();

    if (!_initialised) {
      _initialised = true;
      _feeHoursCtrl.text = caseModel.surveyFeeReserveHours != null
          ? caseModel.surveyFeeReserveHours!.toStringAsFixed(1)
          : '';
      _feeExpensesCtrl.text = caseModel.surveyFeeReserveExpenses != null
          ? caseModel.surveyFeeReserveExpenses!.toStringAsFixed(0)
          : '';
      _commentCtrl.text = caseModel.costEstimateComment ?? '';
    }

    // Auto-derive cost_estimate_status (§3.12 item 43) whenever whether any
    // invoices exist flips, instead of requiring manual selection. No
    // invoices -> always "purely estimated"; once invoices exist, default to
    // "ongoing" (more invoices expected) until the surveyor explicitly says
    // otherwise via the Yes/No prompt below.
    if (_lastHasInvoices != widget.hasInvoices) {
      _lastHasInvoices = widget.hasInvoices;
      final needed = !widget.hasInvoices
          ? 'no_invoices_yet'
          : (caseModel.costEstimateStatus == 'completed_all_invoices'
              ? 'completed_all_invoices'
              : 'ongoing_partial_invoices');
      if (needed != caseModel.costEstimateStatus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateStatus(needed);
        });
      }
    }

    final currency = caseModel.baseCurrency ?? '';
    final total = items.fold(0.0, (s, i) => s + i.amount);

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Cost Estimate',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
              if (items.isNotEmpty)
                Text(_fmtMoney(total, currency),
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          _buildStatusSection(caseModel),

          const SizedBox(height: 12),
          ...items.map((item) => _LineItemRow(
                key: ValueKey(item.id),
                item: item,
                caseId: widget.caseId,
                currency: currency,
              )),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => ref
                  .read(costEstimateItemsProvider(widget.caseId).notifier)
                  .addItem(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add line'),
              style: TextButton.styleFrom(
                foregroundColor: _kAccent,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 10),
          const Text('Caveats / Comments',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          _AutoSaveField(
            controller: _commentCtrl,
            onCommit: _updateComment,
            maxLines: 3,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'e.g. estimate still dependent on drydock quote',
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8))),
            ),
          ),

          const SizedBox(height: 14),
          const Text('Survey Fee Reserve',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Row(
            children: [
              _AutoSaveField(
                controller: _feeHoursCtrl,
                onCommit: _updateFeeHours,
                width: 100,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: 'hrs',
                  hintText: 'Hours',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 10),
              _AutoSaveField(
                controller: _feeExpensesCtrl,
                onCommit: _updateFeeExpenses,
                width: 160,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  prefixText: '$currency ',
                  hintText: 'Expenses',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(CaseModel caseModel) {
    if (!widget.hasInvoices) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _kAccent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kAccent.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 13, color: _kAccent),
            SizedBox(width: 6),
            Text('Purely Estimated — no invoices received yet',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: _kAccent)),
          ],
        ),
      );
    }

    final status = _pendingStatus ?? caseModel.costEstimateStatus;
    final expectMore = status != 'completed_all_invoices';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Further invoices still expected?',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statusChip('Yes', expectMore,
                () => _updateStatus('ongoing_partial_invoices')),
            const SizedBox(width: 6),
            _statusChip('No — final accounting', !expectMore,
                () => _updateStatus('completed_all_invoices')),
          ],
        ),
      ],
    );
  }

  Widget _statusChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _kAccent.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? _kAccent : AppColors.border,
              width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? _kAccent : AppColors.textSecondary)),
      ),
    );
  }
}

/// One editable cost-estimate line item: suggested category + free-text
/// description + amount. Owns its own controllers, keyed by item id
/// (`ValueKey` in the parent's list) so edits in one row survive rebuilds
/// triggered by other rows or by provider refreshes elsewhere on screen.
class _LineItemRow extends ConsumerStatefulWidget {
  const _LineItemRow({
    required this.item,
    required this.caseId,
    required this.currency,
    super.key,
  });
  final CostEstimateItemModel item;
  final String caseId;
  final String currency;

  @override
  ConsumerState<_LineItemRow> createState() => _LineItemRowState();
}

class _LineItemRowState extends ConsumerState<_LineItemRow> {
  late final _descCtrl = TextEditingController(text: widget.item.description ?? '');
  late final _amountCtrl = TextEditingController(
      text: widget.item.amount == 0 ? '' : _fmtAmount(widget.item.amount));

  static String _fmtAmount(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _commitDescription(String text) {
    final trimmed = text.trim();
    if (trimmed == (widget.item.description ?? '')) return;
    ref.read(costEstimateItemsProvider(widget.caseId).notifier).updateItem(
        widget.item.copyWith(description: trimmed.isEmpty ? null : trimmed));
  }

  void _commitAmount(String text) {
    final value = double.tryParse(text.trim()) ?? 0;
    if (value == widget.item.amount) return;
    ref
        .read(costEstimateItemsProvider(widget.caseId).notifier)
        .updateItem(widget.item.copyWith(amount: value));
  }

  void _commitCategory(CostEstimateCategory? cat) {
    if (cat == null || cat == widget.item.category) return;
    ref
        .read(costEstimateItemsProvider(widget.caseId).notifier)
        .updateItem(widget.item.copyWith(category: cat));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<CostEstimateCategory>(
                  initialValue: widget.item.category,
                  isDense: true,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  items: CostEstimateCategory.values
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.label, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: _commitCategory,
                ),
              ),
              const SizedBox(width: 8),
              _AutoSaveField(
                controller: _amountCtrl,
                onCommit: _commitAmount,
                width: 110,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  prefixText: '${widget.currency} ',
                  hintText: 'Amount',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.textSecondary,
                tooltip: 'Remove line',
                visualDensity: VisualDensity.compact,
                onPressed: () => ref
                    .read(costEstimateItemsProvider(widget.caseId).notifier)
                    .deleteItem(widget.item.id),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _AutoSaveField(
            controller: _descCtrl,
            onCommit: _commitDescription,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Description (optional)',
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8))),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text field that reliably commits its value both on explicit keyboard
/// submission (Done/Enter) *and* on focus loss (tapping elsewhere).
///
/// Root cause of §3.12 item 40 ("estimated cost won't save"): the old field
/// only called its update function from `TextField.onSubmitted`/
/// `onEditingComplete`, which fire only when the user explicitly presses the
/// keyboard's submit action — tapping away to dismiss the keyboard (the more
/// natural gesture) fires neither callback, so the typed value was silently
/// discarded. This wrapper adds a `FocusNode` listener that commits whenever
/// focus is lost, regardless of how the user leaves the field, while still
/// also committing on explicit submission for the no-focus-change case (e.g.
/// pressing "Done" then immediately backgrounding the app).
class _AutoSaveField extends StatefulWidget {
  const _AutoSaveField({
    required this.controller,
    required this.onCommit,
    this.decoration,
    this.keyboardType,
    this.style,
    this.width,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final ValueChanged<String> onCommit;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextStyle? style;
  final double? width;
  final int maxLines;

  @override
  State<_AutoSaveField> createState() => _AutoSaveFieldState();
}

class _AutoSaveFieldState extends State<_AutoSaveField> {
  final _focusNode = FocusNode();
  late String _lastCommitted = widget.controller.text;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _commit();
  }

  void _commit() {
    final text = widget.controller.text;
    if (text == _lastCommitted) return;
    _lastCommitted = text;
    widget.onCommit(text);
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      style: widget.style,
      decoration: widget.decoration,
      maxLines: widget.maxLines,
      onSubmitted: (_) => _commit(),
      onEditingComplete: _commit,
    );
    return widget.width != null ? SizedBox(width: widget.width, child: field) : field;
  }
}

class _FinRow extends StatelessWidget {
  const _FinRow({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
    this.bold = false,
  });
  final String label;
  final double amount;
  final String currency;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: bold
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: bold ? 13 : 12,
                      fontWeight: bold
                          ? FontWeight.w700
                          : FontWeight.normal)),
            ),
            Text(_fmtMoney(amount, currency),
                style: TextStyle(
                    color: color,
                    fontSize: bold ? 14 : 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ── Document card ──────────────────────────────────────────────────────────

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.doc, required this.caseId});
  final RepairDocumentModel doc;
  final String caseId;

  @override
  Widget build(BuildContext context) {
    final status = doc.status;
    final statusColor = _statusColor(status);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/cases/$caseId/accounts/${doc.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      doc.effectiveName,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                  ),
                  _StatusBadge(label: status.label, color: statusColor),
                ],
              ),
              if (doc.supplierName != null) ...[
                const SizedBox(height: 4),
                Text(doc.supplierName!,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.category_outlined,
                    label: doc.documentType.label,
                  ),
                  if (doc.documentDate != null)
                    _InfoChip(
                      icon: Icons.calendar_today_outlined,
                      label: _fmtDate(doc.documentDate!),
                    ),
                  const Spacer(),
                  if (doc.totalIncTax != null)
                    Text(
                      _fmtMoney(doc.totalIncTax!, doc.currency),
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                ],
              ),
              if (doc.accountLines.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '${doc.accountLines.length} line${doc.accountLines.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
              if (doc.aiPresentationDraft != null) ...[
                const SizedBox(height: 6),
                Text(
                  doc.aiPresentationDraft!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(DocStatus s) => switch (s) {
        DocStatus.approved      => _kAccent,
        DocStatus.partlyApproved=> Colors.teal,
        DocStatus.queried       => Colors.orange,
        DocStatus.underReview   => const Color(0xFF1A3A5C),
        DocStatus.rejected      => Colors.red,
        _                       => AppColors.textSecondary,
      };

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style:
                TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: AppColors.textSecondary),
            const SizedBox(width: 3),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      );
}
