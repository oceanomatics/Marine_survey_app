import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/accounts_models.dart';
import '../providers/accounts_provider.dart';
import '../widgets/edit_account_line_sheet.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/api/claude_api.dart';
import '../../../core/services/fx_rate_service.dart';
import '../../../features/cases/providers/cases_provider.dart';
import '../../../features/settings/providers/account_provider.dart';
import '../../../features/survey/providers/damage_provider.dart';
import '../../../features/survey/providers/repair_period_provider.dart';
import '../../../features/surveyor_notes/models/surveyor_note_model.dart';
import '../../../features/surveyor_notes/providers/surveyor_notes_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/back_app_bar.dart';
import '../../../shared/widgets/app_feedback.dart';

const _kAccent = Color(0xFF2E7D32);

String _fmtMoney(double v, String currency) {
  final parts = v.toStringAsFixed(2).split('.');
  final integral = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '$currency $integral.${parts[1]}';
}

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen(
      {super.key, required this.caseId, required this.documentId});
  final String caseId;
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(repairDocumentsProvider(caseId));
    return docsAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (docs) {
        final doc = docs.where((d) => d.id == documentId).firstOrNull;
        if (doc == null) {
          return const Scaffold(
              body: Center(child: Text('Document not found')));
        }
        return _DetailView(doc: doc, caseId: caseId);
      },
    );
  }
}

class _DetailView extends ConsumerStatefulWidget {
  const _DetailView({required this.doc, required this.caseId});
  final RepairDocumentModel doc;
  final String caseId;

  @override
  ConsumerState<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends ConsumerState<_DetailView> {
  bool _editingHeader = false;
  bool _extracting = false;
  bool _extractingCues = false;
  bool _polishing = false;
  late TextEditingController _notesCtrl;
  late TextEditingController _presentationCtrl;
  DocStatus _status = DocStatus.pendingReview;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.doc.surveyorNotes ?? '');
    _presentationCtrl = TextEditingController(
        text: widget.doc.presentationStatement ??
            widget.doc.aiPresentationDraft ??
            '');
    _status = widget.doc.status;
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _presentationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BackAppBar(
        title: Text(doc.effectiveName,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (!_editingHeader)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit header',
              onPressed: () => setState(() => _editingHeader = true),
            )
          else ...[
            TextButton(
              onPressed: _saveHeader,
              child: const Text('Save',
                  style: TextStyle(color: _kAccent)),
            ),
            TextButton(
              onPressed: () => setState(() => _editingHeader = false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'delete') _confirmDelete(context);
              if (v == 'pdf')   _openPdf(context);
            },
            itemBuilder: (_) => [
              if (doc.sourcePdfPath != null)
                const PopupMenuItem(value: 'pdf', child: Text('View PDF')),
              const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _DocumentHeader(doc: doc, editing: _editingHeader,
              statusValue: _status,
              onStatusChange: (s) => setState(() => _status = s)),
          const SizedBox(height: 12),
          if (doc.aiExtractedAt == null)
            _AiExtractionBanner(
              extracting: _extracting,
              onExtract: _runExtraction,
            ),
          if (doc.aiExtractedAt == null) const SizedBox(height: 12),
          if (_editingHeader) ...[
            _FieldCard(
              label: 'Presentation Statement',
              child: TextField(
                controller: _presentationCtrl,
                maxLines: 3,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'For adjusters report…',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _FieldCard(
              label: "Surveyor's Notes",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Internal notes…',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      border: InputBorder.none,
                    ),
                  ),
                  GestureDetector(
                    onTap: _polishing ? null : _polishNotes,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_polishing)
                            const SizedBox(
                              width: 12, height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5),
                            )
                          else
                            Icon(Icons.auto_awesome,
                                size: 13,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.6)),
                          const SizedBox(width: 4),
                          Text(
                            _polishing ? 'Polishing…' : 'AI Polish',
                            style: TextStyle(
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.7),
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            if (doc.presentationStatement != null ||
                doc.aiPresentationDraft != null)
              _FieldCard(
                label: 'Presentation Statement',
                child: Text(
                  doc.presentationStatement ?? doc.aiPresentationDraft!,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontStyle: doc.presentationStatement == null
                          ? FontStyle.italic
                          : FontStyle.normal),
                ),
              ),
            if (doc.surveyorNotes != null) ...[
              const SizedBox(height: 8),
              _FieldCard(
                label: "Surveyor's Notes",
                child: Text(doc.surveyorNotes!,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 12),
          ],
          _AccountLinesSection(doc: doc, caseId: widget.caseId),
          const SizedBox(height: 16),
          _LinkedCuesSection(
            caseId: widget.caseId,
            documentId: widget.doc.id,
            hasSource: doc.sourcePdfPath != null,
            extracting: _extractingCues,
            onExtract: _runCueExtraction,
          ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: _kAccent,
        foregroundColor: Colors.white,
        tooltip: 'Add account line',
        onPressed: () => _addLine(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _saveHeader() async {
    await ref
        .read(repairDocumentsProvider(widget.caseId).notifier)
        .updateDocument(widget.doc.id, {
      'surveyor_status':        _status.value,
      'surveyor_notes':         _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
      'presentation_statement': _presentationCtrl.text.trim().isEmpty
          ? null
          : _presentationCtrl.text.trim(),
    });
    if (mounted) {
      setState(() => _editingHeader = false);
      showSavedToast(context);
    }
    _applyFxRates();
  }

  /// Auto-fetches FX rate for the document currency → case base currency
  /// and updates all account lines with converted amounts.
  Future<void> _applyFxRates() async {
    final doc = widget.doc;
    if (doc.documentDate == null) return;

    final baseCurrency = ref.read(caseProvider(widget.caseId)).value?.baseCurrency;
    if (baseCurrency == null || baseCurrency == doc.currency) return;

    final apiKey = ref.read(accountProvider).value?.fxApiKey ?? '';
    if (apiKey.isEmpty) return;

    final d = doc.documentDate!;
    final dateStr =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final rate = await FxRateService.getRate(
      from: doc.currency,
      to: baseCurrency,
      apiKey: apiKey,
      date: dateStr,
    );
    if (rate == null || !mounted) return;

    final notifier = ref.read(repairDocumentsProvider(widget.caseId).notifier);
    for (final line in doc.accountLines) {
      await notifier.updateAccountLine(line.copyWith(
        invoiceCurrency: doc.currency,
        fxRateToBase: rate,
        fxRateDate: d,
        baseCurrencyAmount: line.grossAmount * rate,
      ));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${doc.currency} → $baseCurrency @ ${rate.toStringAsFixed(4)} '
          '(${doc.accountLines.length} line${doc.accountLines.length == 1 ? '' : 's'} updated)',
        ),
        backgroundColor: AppColors.teal,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  void _addLine(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditAccountLineSheet(
        caseId: widget.caseId,
        documentId: widget.doc.id,
        defaultCurrency: widget.doc.currency,
        onSave: (line) => ref
            .read(repairDocumentsProvider(widget.caseId).notifier)
            .addAccountLine(line),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete document?'),
        content: const Text(
            'This will permanently remove the document and all its account lines.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(repairDocumentsProvider(widget.caseId).notifier)
                  .deleteDocument(widget.doc.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openPdf(BuildContext context) {
    final path = widget.doc.sourcePdfPath;
    if (path == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PdfViewerScreen(
          title: widget.doc.effectiveName,
          storagePath: path,
        ),
      ),
    );
  }

  Future<void> _polishNotes() async {
    final raw = _notesCtrl.text.trim();
    if (raw.isEmpty) return;
    setState(() => _polishing = true);
    try {
      final polished = await ClaudeApi.polishSurveyorNote(raw);
      _notesCtrl.text = polished;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Polish failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _polishing = false);
    }
  }

  Future<void> _runExtraction() async {
    setState(() => _extracting = true);
    try {
      await ref
          .read(repairDocumentsProvider(widget.caseId).notifier)
          .extractWithAI(widget.doc.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Extraction failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  Future<void> _runCueExtraction() async {
    setState(() => _extractingCues = true);
    try {
      final count = await ref
          .read(repairDocumentsProvider(widget.caseId).notifier)
          .extractContextCues(widget.doc.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(count == 0
              ? 'No additional context found in this document'
              : '$count context cue${count == 1 ? '' : 's'} added'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Extraction failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _extractingCues = false);
    }
  }
}

// ── AI extraction banner ───────────────────────────────────────────────────

class _AiExtractionBanner extends StatelessWidget {
  const _AiExtractionBanner(
      {required this.extracting, required this.onExtract});
  final bool extracting;
  final VoidCallback onExtract;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A5C).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFF1A3A5C).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_outlined,
              color: const Color(0xFF1A3A5C).withValues(alpha: 0.7),
              size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              extracting
                  ? 'Extracting with AI — this may take 15–20 seconds…'
                  : 'Not yet extracted. Tap to read this document with AI.',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          if (extracting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1A3A5C)),
              onPressed: onExtract,
              child: const Text('Extract',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

// ── Linked context cues section ────────────────────────────────────────────

class _LinkedCuesSection extends ConsumerWidget {
  const _LinkedCuesSection({
    required this.caseId,
    required this.documentId,
    required this.hasSource,
    required this.extracting,
    required this.onExtract,
  });

  final String caseId;
  final String documentId;
  final bool hasSource;
  final bool extracting;
  final VoidCallback onExtract;

  static const _kCueAccent = Color(0xFF0891B2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(surveyorNotesProvider(caseId));
    final linked = notesAsync.value
            ?.where((n) => n.linkedToId == documentId)
            .toList() ??
        [];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 15, color: _kCueAccent),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Context Cues from this Document',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kCueAccent,
                    ),
                  ),
                ),
                if (hasSource)
                  extracting
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5, color: _kCueAccent)),
                        )
                      : TextButton(
                          style: TextButton.styleFrom(
                              foregroundColor: _kCueAccent,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap),
                          onPressed: onExtract,
                          child: Text(
                            linked.isEmpty ? 'Extract' : 'Re-extract',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (linked.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Text(
                hasSource
                    ? 'No context cues extracted yet. Tap Extract to scan for\nnon-accounting information (timesheets, hours, scope notes…).'
                    : 'No source document available for extraction.',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: linked.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 12),
              itemBuilder: (_, i) {
                final note = linked[i];
                final isImportant =
                    note.priority == CuePriority.important;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isImportant
                            ? Icons.priority_high
                            : Icons.circle,
                        size: isImportant ? 13 : 7,
                        color: isImportant
                            ? Colors.orange.shade700
                            : _kCueAccent.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          note.content,
                          style: const TextStyle(
                              fontSize: 12, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ── Document header summary ────────────────────────────────────────────────

class _DocumentHeader extends StatelessWidget {
  const _DocumentHeader({
    required this.doc,
    required this.editing,
    required this.statusValue,
    required this.onStatusChange,
  });
  final RepairDocumentModel doc;
  final bool editing;
  final DocStatus statusValue;
  final ValueChanged<DocStatus> onStatusChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.documentType.label,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(doc.effectiveName,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ],
                ),
              ),
              if (doc.totalIncTax != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_fmtMoney(doc.totalIncTax!, doc.currency),
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    if (doc.taxTotal != null)
                      Text('inc. tax ${_fmtMoney(doc.taxTotal!, '')}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
            ],
          ),
          const Divider(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Supplier', doc.supplierName ?? '—'),
                    _row('Category', doc.supplierCategory.label),
                    if (doc.documentNumber != null)
                      _row('Ref', doc.documentNumber!),
                    if (doc.documentDate != null)
                      _row('Date', _fmt(doc.documentDate!)),
                    if (doc.contractRef != null)
                      _row('Contract', doc.contractRef!),
                  ],
                ),
              ),
              if (doc.thumbnailPath != null || doc.sourcePdfPath != null) ...[
                const SizedBox(width: 10),
                _PdfThumbnail(
                  doc: doc,
                  docName: doc.effectiveName,
                ),
              ],
            ],
          ),
          if (doc.mixedNatureFlag)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_outlined,
                      size: 14, color: Colors.orange),
                  SizedBox(width: 4),
                  Text('Mixed cost nature — review lines',
                      style: TextStyle(
                          color: Colors.orange, fontSize: 12)),
                ],
              ),
            ),
          const Divider(height: 16),
          const Text('Status', style: TextStyle(
              color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 6),
          if (editing)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: DocStatus.values
                  .map((s) => _StatusPill(
                        status: s,
                        selected: s == statusValue,
                        onTap: () => onStatusChange(s),
                      ))
                  .toList(),
            )
          else
            _StatusBadge(
                label: statusValue.label,
                color: _statusColor(statusValue)),
          if (doc.aiConfidence != null) ...[
            const SizedBox(height: 8),
            Text(
              'AI confidence: ${(doc.aiConfidence! * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 12)),
            ),
          ],
        ),
      );

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Color _statusColor(DocStatus s) => switch (s) {
        DocStatus.approved      => _kAccent,
        DocStatus.partlyApproved=> Colors.teal,
        DocStatus.queried       => Colors.orange,
        DocStatus.underReview   => const Color(0xFF1A3A5C),
        DocStatus.rejected      => Colors.red,
        _                       => AppColors.textSecondary,
      };
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(
      {required this.status, required this.selected, required this.onTap});
  final DocStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? _kAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? _kAccent : AppColors.border),
          ),
          child: Text(status.label,
              style: TextStyle(
                  fontSize: 11,
                  color: selected
                      ? Colors.white
                      : AppColors.textSecondary,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal)),
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );
}

// ── Invoice line items section ─────────────────────────────────────────────

class _AccountLinesSection extends ConsumerWidget {
  const _AccountLinesSection({required this.doc, required this.caseId});
  final RepairDocumentModel doc;
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = doc.accountLines;

    final occurrences = ref
        .watch(damageProvider(caseId))
        .value
        ?.occurrences ?? const [];
    final repairPeriods = ref
        .watch(repairPeriodsProvider(caseId))
        .value ?? const [];
    final baseCurrency = ref.watch(caseProvider(caseId)).value?.baseCurrency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Invoice Line Items',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ),
        if (lines.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: const Center(
              child: Text('No line items — tap + to add',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ),
          )
        else ...[
          _AccountSummaryBanner(
            lines: lines,
            occurrences: occurrences,
            currency: doc.currency,
            baseCurrency: baseCurrency,
          ),
          const SizedBox(height: 8),
          ...lines.asMap().entries.map((e) => _LineCard(
                line: e.value,
                isAlt: e.key.isOdd,
                caseId: caseId,
                currency: doc.currency,
                occurrences: occurrences,
                repairPeriods: repairPeriods,
              )),
        ],
      ],
    );
  }
}

class _LineCard extends ConsumerWidget {
  const _LineCard({
    required this.line,
    required this.isAlt,
    required this.caseId,
    required this.currency,
    required this.occurrences,
    required this.repairPeriods,
  });
  final AccountLineModel line;
  final bool isAlt;
  final String caseId;
  final String currency;
  final List<OccurrenceModel> occurrences;
  final List<dynamic> repairPeriods;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _lineStatusColor(line.status);
    final itemNum = line.itemNumber ?? (line.lineOrder + 1);

    return GestureDetector(
      onTap: () => _edit(context, ref),
      onLongPress: () => _confirmDelete(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isAlt
              ? AppColors.surface
              : AppColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item number badge
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(right: 10, top: 1),
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text('$itemNum',
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.description ?? '(no description)',
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  // Status pill above amounts
                  Row(
                    children: [
                      _StatusBadge(
                          label: line.status.label, color: statusColor),
                      const SizedBox(width: 6),
                      _Chip(line.costNature.label),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Amounts
                  Row(
                    children: [
                      Text(_fmtMoney(line.grossAmount, currency),
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                      if (line.underwritersPortion > 0) ...[
                        const SizedBox(width: 8),
                        Text('U/W ${_fmtMoney(line.underwritersPortion, currency)}',
                            style: const TextStyle(color: _kAccent, fontSize: 11)),
                      ],
                      if (line.ownersPortion > 0) ...[
                        const SizedBox(width: 8),
                        Text("Owners ${_fmtMoney(line.ownersPortion, currency)}",
                            style: const TextStyle(
                                color: Colors.orange, fontSize: 11)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _lineStatusColor(LineItemStatus s) => switch (s) {
        LineItemStatus.approved    => _kAccent,
        LineItemStatus.queried     => Colors.orange,
        LineItemStatus.apportioned => Colors.teal,
        LineItemStatus.betterment  => Colors.brown,
        LineItemStatus.rejected    => Colors.red,
        _                          => AppColors.textSecondary,
      };

  void _edit(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditAccountLineSheet(
        caseId: caseId,
        documentId: line.documentId,
        existing: line,
        defaultCurrency: currency,
        occurrences: occurrences,
        repairPeriods: repairPeriods.cast(),
        onSave: (updated) => ref
            .read(repairDocumentsProvider(caseId).notifier)
            .updateAccountLine(updated),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove line item?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(repairDocumentsProvider(caseId).notifier)
                  .deleteAccountLine(line.id, line.documentId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.border.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 10)),
      );
}

// ── Account summary banner ─────────────────────────────────────────────────

class _AccountSummaryBanner extends StatelessWidget {
  const _AccountSummaryBanner({
    required this.lines,
    required this.occurrences,
    required this.currency,
    this.baseCurrency,
  });
  final List<AccountLineModel> lines;
  final List<OccurrenceModel> occurrences;
  final String currency;
  final String? baseCurrency;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    // ── Claim rows: one per occurrence (non-betterment UW portions) ──────
    bool hasClaimRows = false;
    for (int i = 0; i < occurrences.length; i++) {
      final occ = occurrences[i];
      final uw = lines
          .where((l) =>
              l.occurrenceId == occ.occurrenceId &&
              l.status != LineItemStatus.betterment)
          .fold(0.0, (s, l) => s + l.underwritersPortion);
      if (uw > 0.005) {
        hasClaimRows = true;
        rows.add(_SummaryRow(
          label: 'Occ. ${i + 1} — ${occ.title ?? 'Occurrence ${i + 1}'}',
          amount: uw,
          currency: currency,
          color: _kAccent,
        ));
      }
    }

    // Unallocated claim (no occurrence assigned)
    final unallocated = lines
        .where((l) =>
            l.occurrenceId == null &&
            l.status != LineItemStatus.betterment)
        .fold(0.0, (s, l) => s + l.underwritersPortion);
    if (unallocated > 0.005) {
      hasClaimRows = true;
      rows.add(_SummaryRow(
        label: 'Unallocated',
        amount: unallocated,
        currency: currency,
        color: _kAccent,
      ));
    }

    // ── Adjustments ──────────────────────────────────────────────────────
    final betterment = lines
        .where((l) => l.status == LineItemStatus.betterment)
        .fold(0.0, (s, l) => s + l.grossAmount);
    final owners = lines.fold(0.0, (s, l) => s + l.ownersPortion);
    final deferred = lines
        .where((l) => l.apportionmentType == 'defer')
        .fold(0.0, (s, l) => s + l.grossAmount);
    final grossTotal = lines.fold(0.0, (s, l) => s + l.grossAmount);

    if (grossTotal < 0.005) return const SizedBox.shrink();

    final hasAdjustments =
        betterment > 0.005 || owners > 0.005 || deferred > 0.005;

    if (hasClaimRows && hasAdjustments) {
      rows.add(Divider(
          height: 14, color: AppColors.border.withValues(alpha: 0.4)));
    }

    if (betterment > 0.005) {
      rows.add(_SummaryRow(
        label: 'Betterment',
        amount: betterment,
        currency: currency,
        color: Colors.brown,
      ));
    }
    if (owners > 0.005) {
      rows.add(_SummaryRow(
        label: "Owner's account",
        amount: owners,
        currency: currency,
        color: Colors.orange,
      ));
    }
    if (deferred > 0.005) {
      rows.add(_SummaryRow(
        label: 'Deferred to adjuster',
        amount: deferred,
        currency: currency,
        color: Colors.blueGrey,
      ));
    }

    // ── FX conversion total ───────────────────────────────────────────────
    final fxBase = baseCurrency;
    if (fxBase != null && fxBase != currency) {
      final fxTotal = lines.fold(0.0, (s, l) => s + (l.baseCurrencyAmount ?? 0));
      final rate = lines
          .where((l) => l.fxRateToBase != null)
          .map((l) => l.fxRateToBase!)
          .firstOrNull;
      if (fxTotal > 0.005 && rate != null) {
        rows.add(Divider(
            height: 14, color: AppColors.border.withValues(alpha: 0.4)));
        rows.add(_FxSummaryRow(
          invoiceCurrency: currency,
          baseCurrency: fxBase,
          rate: rate,
          baseTotal: fxTotal,
        ));
      }
    }

    // ── Total ─────────────────────────────────────────────────────────────
    rows.add(Divider(
        height: 14, color: AppColors.border.withValues(alpha: 0.6)));
    rows.add(_SummaryRow(
      label: 'Total (gross)',
      amount: grossTotal,
      currency: currency,
      color: AppColors.textPrimary,
      bold: true,
    ));

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Account Summary',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
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
              child: Text(
                label,
                style: TextStyle(
                    color: bold
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: bold ? 13 : 12,
                    fontWeight:
                        bold ? FontWeight.w700 : FontWeight.normal),
              ),
            ),
            Text(
              _fmtMoney(amount, currency),
              style: TextStyle(
                  color: color,
                  fontSize: bold ? 14 : 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}

class _FxSummaryRow extends StatelessWidget {
  const _FxSummaryRow({
    required this.invoiceCurrency,
    required this.baseCurrency,
    required this.rate,
    required this.baseTotal,
  });
  final String invoiceCurrency;
  final String baseCurrency;
  final double rate;
  final double baseTotal;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          const Icon(Icons.currency_exchange_outlined,
              size: 12, color: AppColors.teal),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$invoiceCurrency → $baseCurrency @ ${rate.toStringAsFixed(4)}',
              style: const TextStyle(
                  color: AppColors.teal, fontSize: 11),
            ),
          ),
          Text(
            _fmtMoney(baseTotal, baseCurrency),
            style: const TextStyle(
                color: AppColors.teal,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ]),
      );
}

// ── Field card ─────────────────────────────────────────────────────────────

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            child,
          ],
        ),
      );
}

// ── PDF Thumbnail ──────────────────────────────────────────────────────────

class _PdfThumbnail extends StatefulWidget {
  const _PdfThumbnail({required this.doc, required this.docName});
  final RepairDocumentModel doc;
  final String docName;

  @override
  State<_PdfThumbnail> createState() => _PdfThumbnailState();
}

class _PdfThumbnailState extends State<_PdfThumbnail> {
  String? _signedUrl;
  bool _isPregenerated = false;
  bool _isRawImage = false;
  int _quarterTurns = 0;

  static bool _isImagePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
  }

  static String _mediaType(String path) {
    return path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
  }

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  @override
  void didUpdateWidget(_PdfThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doc.thumbnailPath != widget.doc.thumbnailPath ||
        oldWidget.doc.sourcePdfPath != widget.doc.sourcePdfPath) {
      setState(() {
        _signedUrl = null;
        _isPregenerated = false;
        _isRawImage = false;
        _quarterTurns = 0;
      });
      _loadUrl();
    }
  }

  Future<void> _loadUrl() async {
    try {
      final path = widget.doc.thumbnailPath ?? widget.doc.sourcePdfPath;
      if (path == null) return;
      final url = await SupabaseService.getSignedUrl('documents', path);
      if (!mounted) return;
      final pregenerated = widget.doc.thumbnailPath != null;
      final rawImage = !pregenerated && _isImagePath(path);
      setState(() {
        _signedUrl = url;
        _isPregenerated = pregenerated;
        _isRawImage = rawImage;
      });
      if (rawImage) {
        _detectOrientation(url, _mediaType(path));
      }
    } catch (_) {}
  }

  Future<void> _detectOrientation(String url, String mediaType) async {
    try {
      final turns = await ClaudeApi.detectImageOrientation(
        signedUrl: url,
        mediaType: mediaType,
      );
      if (mounted) setState(() => _quarterTurns = turns);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const w = 70.0;
    const h = 90.0;

    if (_signedUrl == null) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.border.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 1.5)),
        ),
      );
    }

    final useImage = _isPregenerated || _isRawImage;

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: useImage
          ? SizedBox(
              width: w,
              height: h,
              child: RotatedBox(
                quarterTurns: _quarterTurns,
                child: Image.network(
                  _signedUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(w, h),
                ),
              ),
            )
          : SizedBox(
              width: w,
              height: h,
              child: PdfDocumentViewBuilder.uri(
                Uri.parse(_signedUrl!),
                builder: (context, document) {
                  if (document == null) {
                    return Container(color: Colors.grey.shade200);
                  }
                  return PdfPageView(
                    document: document,
                    pageNumber: 1,
                    alignment: Alignment.topCenter,
                    decoration: const BoxDecoration(color: Colors.white),
                  );
                },
              ),
            ),
    );

    return GestureDetector(
      onTap: () {
        final pdfPath = widget.doc.sourcePdfPath;
        if (pdfPath == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _PdfViewerScreen(
              title: widget.docName,
              storagePath: pdfPath,
            ),
          ),
        );
      },
      child: content,
    );
  }

  Widget _placeholder(double w, double h) => Container(
        width: w,
        height: h,
        color: Colors.grey.shade200,
        child: const Icon(Icons.picture_as_pdf, size: 24, color: Colors.grey),
      );
}

// ── PDF Viewer Screen ──────────────────────────────────────────────────────

class _PdfViewerScreen extends StatefulWidget {
  const _PdfViewerScreen({required this.title, required this.storagePath});
  final String title;
  final String storagePath;

  @override
  State<_PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<_PdfViewerScreen> {
  String? _signedUrl;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      final url = await SupabaseService.getSignedUrl('documents', widget.storagePath);
      if (mounted) setState(() => _signedUrl = url);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: BackAppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
      ),
      body: _signedUrl == null
          ? const Center(child: CircularProgressIndicator())
          : PdfViewer.uri(
              Uri.parse(_signedUrl!),
              params: const PdfViewerParams(
                  backgroundColor: Color(0xFFE0E0E0)),
            ),
    );
  }
}
