import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/accounts_models.dart';
import '../providers/accounts_provider.dart';
import '../widgets/import_invoice_sheet.dart';
import '../../../features/survey/providers/damage_provider.dart';
import '../../cases/providers/cases_provider.dart';
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
                _SummaryBanner(
                  summary: summary,
                  occurrences: widget.occurrences,
                  allLines: submitted.expand((d) => d.accountLines).toList(),
                ),
                _CostEstimateSelector(caseId: widget.caseId),
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

// ── Cost estimate status (Clause G-1) ───────────────────────────────────────

const _kCostStatusOptions = {
  'no_invoices_yet':          'No Invoices Yet',
  'ongoing_partial_invoices': 'Ongoing — Partial Invoices',
  'completed_all_invoices':   'Completed — All Invoices In',
};

class _CostEstimateSelector extends ConsumerStatefulWidget {
  const _CostEstimateSelector({required this.caseId});
  final String caseId;

  @override
  ConsumerState<_CostEstimateSelector> createState() =>
      _CostEstimateSelectorState();
}

const _kTowingOptions = {
  'yes': 'Yes',
  'no': 'No',
  'n_a': 'N/A',
};

class _CostEstimateSelectorState extends ConsumerState<_CostEstimateSelector> {
  final _estimateCtrl = TextEditingController();
  final _feeHoursCtrl = TextEditingController();
  final _feeExpensesCtrl = TextEditingController();
  String? _pendingStatus;
  bool _initialised = false;

  @override
  void dispose() {
    _estimateCtrl.dispose();
    _feeHoursCtrl.dispose();
    _feeExpensesCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _pendingStatus = status);
    await ref
        .read(caseProvider(widget.caseId).notifier)
        .updateCaseRefs(costEstimateStatus: status);
  }

  Future<void> _updateEstimate(String text) async {
    final value = double.tryParse(text.trim());
    if (value == null) return;
    await ref
        .read(caseProvider(widget.caseId).notifier)
        .updateCaseRefs(estimatedRepairCost: value);
  }

  Future<void> _updateGeneralExpenses(bool value) async {
    await ref
        .read(caseProvider(widget.caseId).notifier)
        .updateCaseRefs(costIncludesGeneralExpenses: value);
  }

  Future<void> _updateTowing(String value) async {
    await ref
        .read(caseProvider(widget.caseId).notifier)
        .updateCaseRefs(costIncludesTowing: value);
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

  @override
  Widget build(BuildContext context) {
    final caseModel = ref.watch(caseProvider(widget.caseId)).value;
    if (caseModel == null) return const SizedBox.shrink();

    final status = _pendingStatus ?? caseModel.costEstimateStatus;
    if (!_initialised) {
      _initialised = true;
      if (caseModel.estimatedRepairCost != null) {
        _estimateCtrl.text =
            caseModel.estimatedRepairCost!.toStringAsFixed(0);
      }
      if (caseModel.surveyFeeReserveHours != null) {
        _feeHoursCtrl.text =
            caseModel.surveyFeeReserveHours!.toStringAsFixed(1);
      }
      if (caseModel.surveyFeeReserveExpenses != null) {
        _feeExpensesCtrl.text =
            caseModel.surveyFeeReserveExpenses!.toStringAsFixed(0);
      }
    }

    final showEstimateField =
        status == 'no_invoices_yet' || status == 'ongoing_partial_invoices';

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cost Estimate Status',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _kCostStatusOptions.entries.map((e) {
              final selected = status == e.key;
              return GestureDetector(
                onTap: () => _updateStatus(e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? _kAccent.withValues(alpha: 0.12)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: selected ? _kAccent : AppColors.border,
                        width: selected ? 1.5 : 1),
                  ),
                  child: Text(e.value,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected
                              ? _kAccent
                              : AppColors.textSecondary)),
                ),
              );
            }).toList(),
          ),
          if (showEstimateField) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _estimateCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  prefixText: '${caseModel.baseCurrency ?? ''} ',
                  hintText: 'Estimated cost',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onSubmitted: _updateEstimate,
                onEditingComplete: () => _updateEstimate(_estimateCtrl.text),
              ),
            ),
          ],

          const SizedBox(height: 14),
          const Text('Cost Inclusions',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _YesNoChips(
                label: 'General expenses',
                value: caseModel.costIncludesGeneralExpenses == true
                    ? 'yes'
                    : caseModel.costIncludesGeneralExpenses == false
                        ? 'no'
                        : null,
                options: const {'yes': 'Yes', 'no': 'No'},
                accent: _kAccent,
                onChanged: (v) => _updateGeneralExpenses(v == 'yes'),
              ),
              _YesNoChips(
                label: 'Towing costs',
                value: caseModel.costIncludesTowing,
                options: _kTowingOptions,
                accent: _kAccent,
                onChanged: _updateTowing,
              ),
            ],
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
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _feeHoursCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
                  onSubmitted: _updateFeeHours,
                  onEditingComplete: () => _updateFeeHours(_feeHoursCtrl.text),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _feeExpensesCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixText: '${caseModel.baseCurrency ?? ''} ',
                    hintText: 'Expenses',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onSubmitted: _updateFeeExpenses,
                  onEditingComplete: () =>
                      _updateFeeExpenses(_feeExpensesCtrl.text),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small labelled Yes/No(/N-A) chip row — shared by the cost-inclusion
/// toggles above.
class _YesNoChips extends StatelessWidget {
  const _YesNoChips({
    required this.label,
    required this.value,
    required this.options,
    required this.accent,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final Map<String, String> options;
  final Color accent;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: options.entries.map((e) {
            final selected = value == e.key;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => onChanged(e.key),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? accent.withValues(alpha: 0.12)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: selected ? accent : AppColors.border,
                        width: selected ? 1.5 : 1),
                  ),
                  child: Text(e.value,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected ? accent : AppColors.textSecondary)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
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
