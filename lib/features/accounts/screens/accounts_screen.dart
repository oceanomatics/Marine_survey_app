import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/accounts_models.dart';
import '../providers/accounts_provider.dart';
import '../widgets/import_invoice_sheet.dart';
import '../../../features/survey/providers/damage_provider.dart';
import '../../../features/survey/providers/repair_period_provider.dart';
import '../../../features/survey/models/repair_period_model.dart';
import '../../cases/providers/cases_provider.dart';
import '../../cases/models/case_model.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/back_app_bar.dart';

// ── Constants ──────────────────────────────────────────────────────────────

const _kAccent = Color(0xFF2E7D32);
// Matches _kBudgetColor in repair_periods_screen.dart — same visual
// identity for the same underlying data, viewed from two screens.
const _kBudgetRollupColor = Color(0xFF7B5EA7);

String _fmtMoney(double v, String currency) {
  final parts = v.toStringAsFixed(2).split('.');
  final integral = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '$currency $integral.${parts[1]}';
}

// ── Screen ─────────────────────────────────────────────────────────────────

// Split into two proper top-level tabs (14 July 2026 walkthrough — the old
// single-tab layout was "bloated"): Cost Estimate (through Survey Fee
// Reserve) and Accounts (invoice management, with its own Submitted /
// Context Archive sub-split, unchanged). Each has its own summary at the
// top instead of one shared banner sitting above both.
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String get caseId => widget.caseId;

  @override
  Widget build(BuildContext context) {
    final docsAsync   = ref.watch(repairDocumentsProvider(caseId));
    final occurrences = ref.watch(damageProvider(caseId)).value?.occurrences
        ?? const [];
    final onAccountsTab = _tab.index == 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BackAppBar(
        title: const Text('Accounts'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'AI processing status',
            onPressed: () => context.push('/cases/$caseId/production'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.invalidate(repairDocumentsProvider(caseId)),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: _kAccent,
          labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Cost Estimate'),
            Tab(text: 'Accounts'),
          ],
        ),
      ),
      floatingActionButton: onAccountsTab
          ? FloatingActionButton.extended(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Import Invoice'),
              onPressed: () => _import(context, ref),
            )
          : null,
      body: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (docs) => TabBarView(
          controller: _tab,
          children: [
            // ── Tab 1: Cost Estimate ──────────────────────────────────
            SingleChildScrollView(
              child: _CostEstimateSelector(
                caseId: caseId,
                hasInvoices:
                    docs.where((d) => d.submittedToInsurance).isNotEmpty,
              ),
            ),
            // ── Tab 2: Accounts ───────────────────────────────────────
            _AccountsTab(caseId: caseId, docs: docs, occurrences: occurrences),
          ],
        ),
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

// ── Accounts tab (Submitted / Context Archive) ─────────────────────────────

class _AccountsTab extends StatefulWidget {
  const _AccountsTab({
    required this.caseId,
    required this.docs,
    required this.occurrences,
  });
  final String caseId;
  final List<RepairDocumentModel> docs;
  final List<OccurrenceModel> occurrences;

  @override
  State<_AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<_AccountsTab>
    with SingleTickerProviderStateMixin {
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
        _SummaryBanner(
          summary: summary,
          occurrences: widget.occurrences,
          allLines: submitted.expand((d) => d.accountLines).toList(),
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
                  // Clarified — this tab was "purpose unclear" (14 July
                  // 2026 walkthrough): these are documents/invoices
                  // imported but not yet marked submitted to the insurer.
                  emptyText: 'No unsubmitted documents',
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
          // Skip if a manual Yes/No chip tap already landed in the same
          // window this callback was scheduled in (2026-07-13 review) —
          // _pendingStatus is set synchronously by _updateStatus, so if
          // it's non-null here the surveyor's own explicit choice already
          // won and must not be silently overwritten by the auto-derive.
          if (mounted && _pendingStatus == null) _updateStatus(needed);
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
          _RepairPeriodBudgetRollup(caseId: widget.caseId),
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
          children: [
            Icon(Icons.info_outline, size: 13, color: _kAccent),
            SizedBox(width: 6),
            // Flexible, not a bare Text — on any phone narrower than ~550dp
            // logical width this label overflowed the Row (caught by a
            // widget test, never live-reported since it's not the kind of
            // thing a surveyor would think to screenshot-and-report).
            Flexible(
              child: Text('Purely Estimated — no invoices received yet',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: _kAccent)),
            ),
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

/// Read-only rollup of the per-repair-period "Budget Estimate" items entered
/// on the Repair Periods screen (`_BudgetSection` there) — those are a
/// separate mechanism from the manual line items above and previously had
/// no visibility anywhere else once entered (14 July 2026 walkthrough §22:
/// "No feedback/rollup of cost estimates entered at the repair-period level
/// — not visible anywhere once entered"). Deliberately NOT summed into the
/// "Cost Estimate" total above — that would silently conflate two distinct
/// figures (case-level manual estimate vs. per-period underwriter budgets),
/// which risks being misread as the case's total exposure.
class _RepairPeriodBudgetRollup extends ConsumerWidget {
  const _RepairPeriodBudgetRollup({required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periods = ref.watch(repairPeriodsProvider(caseId)).valueOrNull ?? [];
    final withBudget = periods.where((p) => p.budgetItems.isNotEmpty).toList();
    if (withBudget.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: GestureDetector(
        onTap: () => context.go('/cases/$caseId/repairs'),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _kBudgetRollupColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBudgetRollupColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.calculate_outlined,
                      size: 13, color: _kBudgetRollupColor),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text('REPAIR-PERIOD BUDGET ESTIMATES',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: _kBudgetRollupColor)),
                  ),
                  Icon(Icons.chevron_right,
                      size: 14, color: _kBudgetRollupColor),
                ],
              ),
              const SizedBox(height: 8),
              for (final p in withBudget) _budgetRow(p),
            ],
          ),
        ),
      ),
    );
  }

  Widget _budgetRow(RepairPeriodModel p) {
    final total = p.budgetItems.fold(0.0, (s, i) => s + i.amount);
    final label = p.title?.trim().isNotEmpty == true
        ? p.title!
        : (p.location?.trim().isNotEmpty == true
            ? p.location!
            : 'Repair period');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textPrimary)),
          ),
          Text(
            '${_fmtMoney(total, p.budgetBaseCurrency)} (${p.budgetItems.length})',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kBudgetRollupColor),
          ),
        ],
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
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      if (widget.item.amount == 0) return;
      ref
          .read(costEstimateItemsProvider(widget.caseId).notifier)
          .updateItem(widget.item.copyWith(amount: 0));
      return;
    }
    // Strip thousands separators/currency symbols/whitespace (e.g.
    // "$1,234.50") before parsing rather than silently writing 0 on any
    // unparsable input — a line item silently zeroing out (and dropping
    // out of the cost-estimate total with no error shown) was the reported
    // "total doesn't add up" bug, 14 July 2026 walkthrough.
    final cleaned = trimmed.replaceAll(RegExp(r'[^0-9.\-]'), '');
    final value = double.tryParse(cleaned);
    if (value == null) {
      _amountCtrl.text = widget.item.amount == 0
          ? ''
          : _fmtAmount(widget.item.amount);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not read that amount — reverted.')),
      );
      return;
    }
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

  // Condensed into one compact table-like row, not a two-row bordered card
  // (14 July 2026 walkthrough — "oversized cards... should be condensed
  // into a compact table instead").
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(
            bottom:
                BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 108,
            child: DropdownButtonFormField<CostEstimateCategory>(
              initialValue: widget.item.category,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                border: InputBorder.none,
              ),
              style:
                  const TextStyle(fontSize: 11.5, color: AppColors.textPrimary),
              items: CostEstimateCategory.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.label, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: _commitCategory,
            ),
          ),
          Expanded(
            child: _AutoSaveField(
              controller: _descCtrl,
              onCommit: _commitDescription,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Description (optional)',
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: InputBorder.none,
              ),
            ),
          ),
          _AutoSaveField(
            controller: _amountCtrl,
            onCommit: _commitAmount,
            width: 90,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              prefixText: '${widget.currency} ',
              prefixStyle: const TextStyle(
                  fontSize: 10.5, color: AppColors.textTertiary),
              hintText: 'Amount',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: InputBorder.none,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            color: AppColors.textSecondary,
            tooltip: 'Remove line',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => ref
                .read(costEstimateItemsProvider(widget.caseId).notifier)
                .deleteItem(widget.item.id),
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
      // Commit AND drop focus on submit — previously only committed, so the
      // keyboard stayed up after pressing Enter/Done with nothing visibly
      // happening (14 July 2026 walkthrough complaint).
      onSubmitted: (_) {
        _commit();
        _focusNode.unfocus();
      },
      onEditingComplete: () {
        _commit();
        _focusNode.unfocus();
      },
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
                  if (doc.extractionProcessing) ...[
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 6),
                    const _StatusBadge(
                        label: 'Extracting…', color: AppColors.amber),
                    const SizedBox(width: 6),
                  ] else if (doc.extractionFailed) ...[
                    const _StatusBadge(
                        label: 'Extraction failed', color: AppColors.error),
                    const SizedBox(width: 6),
                  ],
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
