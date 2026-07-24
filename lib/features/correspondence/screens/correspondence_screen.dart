// lib/features/correspondence/screens/correspondence_screen.dart

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/correspondence_model.dart';
import '../providers/correspondence_provider.dart';
import '../utils/correspondence_threads.dart';
import '../widgets/attachment_import.dart';
import '../../documents/screens/document_vault_screen.dart'
    show ExtractionReviewSheet;
import '../../../core/api/claude_api.dart';
import '../../../core/services/gmail_service.dart';
import '../../../core/services/google_auth_service.dart';
import '../../../core/utils/eml_parser.dart';
import '../../../features/cases/providers/cases_provider.dart';
import '../../../features/documents/providers/document_provider.dart';
import '../../../features/photos/services/google_drive_service.dart';
import '../../../features/surveyor_notes/providers/surveyor_notes_provider.dart';
import '../../../features/surveyor_notes/models/surveyor_note_model.dart';
import '../../ai_tasks/providers/ai_tasks_provider.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import 'gmail_message_picker_screen.dart';
import '../../../shared/widgets/back_app_bar.dart';
import 'package:go_router/go_router.dart';
import '../providers/case_inbox_provider.dart';

const _kColor = Color(0xFF2A6099);

class CorrespondenceScreen extends ConsumerWidget {
  const CorrespondenceScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final corrAsync = ref.watch(correspondenceProvider(caseId));
    // Case-scoped new-mail count (16 July 2026): mail matching THIS case's
    // vessel/file-no that isn't already filed here. Replaces the old global
    // un-triaged count now that the Inbox can be filtered to the case — a
    // surveyor on this screen wants "new mail for THIS case", not the whole
    // mailbox. Silent path, so it never pops an OAuth prompt.
    final newMail = ref.watch(caseNewMailCountProvider(caseId)).value ?? 0;
    final newMailLabel = newMail > 99 ? '99+' : '$newMail';

    return PopScope(
      // Correspondence is reachable from Case Home, the Inbox and the new-case
      // flow, so a plain pop can overshoot to the case list. Force both the
      // system/gesture back and the AppBar back (below) to Case Home.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/cases/$caseId');
      },
      child: Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(
        title: const Text('Correspondence'),
        backRoute: '/cases/$caseId',
        actions: [
          // Extra right padding + an inward badge offset so the count label
          // (esp. "99+") isn't clipped by the IconButton's tight 48px bounds
          // or the screen edge — the badge default pushes the label out past
          // the icon top-right, which the AppBar action area crops.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Badge(
                offset: const Offset(-6, -2),
                label: Text(newMailLabel),
                isLabelVisible: newMail > 0,
                child: const Icon(Icons.mail_outline, color: Colors.white),
              ),
              onPressed: () => context.go('/inbox?caseId=$caseId'),
              tooltip: newMail > 0
                  ? 'Inbox — $newMailLabel new for this case'
                  : 'Inbox',
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        backgroundColor: _kColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: corrAsync.when(
        loading: () =>
            const AppLoadingWidget(message: 'Loading correspondence…'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => items.isEmpty
            ? _EmptyState(onAdd: () => _showAddSheet(context, ref))
            : Builder(builder: (context) {
                // One card per TRAIL: emails sharing a subject collapse into a
                // single thread card whose face is the newest message and
                // whose "Trail (N)" opens the full exchange — rather than every
                // message showing as its own card (24 July 2026 report).
                final threads = groupCorrespondenceThreads(items);
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                  itemCount: threads.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final thread = threads[i];
                    final rep = thread.messages.last; // newest
                    return _CorrCard(
                      key: ValueKey(rep.id),
                      item: rep,
                      caseId: caseId,
                      thread: thread.isMultiMessage ? thread : null,
                      onPreview: () => rep.isEml
                          ? _openEmailPreview(context, rep)
                          : _openPdfPreview(context, ref, rep),
                      onDelete: () => ref
                          .read(correspondenceProvider(caseId).notifier)
                          .delete(rep.id),
                    );
                  },
                );
              }),
      ),
    ));
  }

  // ── Bottom sheet: choose PDF or EML ───────────────────────────────────────

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _kColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined,
                    color: _kColor, size: 22),
              ),
              title: const Text('Upload PDF',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Scanned letter, fax or email printout'),
              onTap: () {
                Navigator.pop(ctx);
                _uploadPdf(context, ref);
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _kColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.email_outlined, color: _kColor, size: 22),
              ),
              title: const Text('Import Email (.eml)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('EML file — attachments saved to Doc Vault'),
              onTap: () {
                Navigator.pop(ctx);
                _importEml(context, ref);
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _kColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.mark_email_read_outlined,
                    color: _kColor, size: 22),
              ),
              title: const Text('Import from Gmail',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Pick a message from your inbox'),
              onTap: () {
                Navigator.pop(ctx);
                _importFromGmail(context, ref);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── PDF upload ─────────────────────────────────────────────────────────────

  Future<void> _uploadPdf(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null || !context.mounted) return;

    await ref.read(correspondenceProvider(caseId).notifier).addFromBytes(
          caseId: caseId,
          bytes: file.bytes!,
          filename: file.name,
        );
  }

  // ── EML import ─────────────────────────────────────────────────────────────

  Future<void> _importEml(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['eml'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null || !context.mounted) return;

    final (corr, attachments) = await ref
        .read(correspondenceProvider(caseId).notifier)
        .importEml(caseId: caseId, bytes: file.bytes!, filename: file.name);

    if (!context.mounted) return;

    if (attachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email imported — no attachments found')),
      );
      return;
    }

    await promptImportAttachments(
      context,
      ref,
      caseId: caseId,
      attachments: attachments,
      sourceIdFor: (_) => corr.id,
    );
  }

  // ── Gmail import ───────────────────────────────────────────────────────────

  /// Builds a Gmail search query from the case's identifying data (vessel
  /// name, job number, claim reference) so the import picker opens already
  /// filtered to case-relevant conversations instead of the whole inbox.
  String? _caseGmailQuery(WidgetRef ref) {
    final c = ref.read(caseProvider(caseId)).value;
    if (c == null) return null;
    final terms = <String>[
      if (c.vesselName != null && c.vesselName!.isNotEmpty) c.vesselName!,
      if (!c.hasPlaceholderFileNo) c.technicalFileNo,
      if (c.claimReference != null && c.claimReference!.isNotEmpty)
        c.claimReference!,
    ];
    if (terms.isEmpty) return null;
    return terms.map((t) => '"$t"').join(' OR ');
  }

  Future<void> _importFromGmail(BuildContext context, WidgetRef ref) async {
    final query = _caseGmailQuery(ref);
    final result = await Navigator.push<List<(Uint8List, String)>>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => GmailMessagePickerScreen(initialQuery: query),
      ),
    );
    if (result == null || result.isEmpty || !context.mounted) return;

    final notifier = ref.read(correspondenceProvider(caseId).notifier);
    final allAttachments = <EmlAttachment>[];
    // §3.14: a batch import covers several messages at once, so track which
    // correspondence record each pooled attachment actually came from —
    // identity-keyed (the exact same EmlAttachment instances flow through
    // the picker dialog and back), not a value-equality map.
    final attachmentCorrId = <EmlAttachment, String>{};
    for (final (bytes, subject) in result) {
      final (corr, attachments) = await notifier.importEml(
          caseId: caseId, bytes: bytes, filename: '$subject.eml');
      allAttachments.addAll(attachments);
      for (final att in attachments) {
        attachmentCorrId[att] = corr.id;
      }
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${result.length} message(s) imported — ready for AI extraction')),
    );

    await promptImportAttachments(
      context,
      ref,
      caseId: caseId,
      attachments: allAttachments,
      sourceIdFor: (att) => attachmentCorrId[att],
    );
  }

  // ── Preview ────────────────────────────────────────────────────────────────

  Future<void> _openPdfPreview(
      BuildContext context, WidgetRef ref, CorrespondenceModel item) async {
    // Web has no local file cache (dart:io isn't available there) — always
    // stream bytes straight from Drive into an in-memory viewer instead.
    if (kIsWeb) {
      if (item.driveFileId == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('This file has not been uploaded to Drive yet')));
        }
        return;
      }
      Uint8List bytes;
      try {
        bytes = await GoogleDriveService.downloadFile(item.driveFileId!);
      } catch (e) {
        if (context.mounted) {
          showError(context, 'Could not download this file from Drive: $e',
              error: e, tag: 'Correspondence');
        }
        return;
      }
      if (!context.mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => _PdfBytesPreviewScreen(item: item, bytes: bytes)));
      return;
    }

    final resolved = item.hasLocalFile
        ? item
        : await ref
            .read(correspondenceProvider(caseId).notifier)
            .ensureLocalFile(item.id);
    if (resolved == null || !resolved.hasLocalFile) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not download this file from Drive')));
      }
      return;
    }
    if (!context.mounted) return;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => _PdfPreviewScreen(item: resolved)));
  }

  void _openEmailPreview(BuildContext context, CorrespondenceModel item) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => _EmailPreviewScreen(item: item)));
  }
}

// ── Collapsible correspondence card ───────────────────────────────────────

class _CorrCard extends ConsumerStatefulWidget {
  const _CorrCard({
    super.key,
    required this.item,
    required this.caseId,
    required this.onPreview,
    required this.onDelete,
    this.thread,
  });

  final CorrespondenceModel item;
  final String caseId;
  final VoidCallback onPreview;
  final VoidCallback onDelete;

  /// §3.14: set only when this item belongs to a multi-message thread —
  /// drives the "Trail (N)" action opening the thread summary sheet.
  final CorrespondenceThread? thread;

  @override
  ConsumerState<_CorrCard> createState() => _CorrCardState();
}

class _CorrCardState extends ConsumerState<_CorrCard> {
  bool _expanded = false;

  CorrespondenceModel get item => widget.item;

  // ── AI extraction (per-item review sheet) ─────────────────────────────────

  Future<void> _extract() async {
    DocExtractionResult? result;
    try {
      result = await ref
          .read(correspondenceProvider(widget.caseId).notifier)
          .extract(item.id);
    } catch (e) {
      if (mounted) {
        showError(context, 'Extraction failed: $e', error: e, tag: 'Correspondence');
      }
      return;
    }
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nothing was extracted from this correspondence.')),
      );
      return;
    }
    await _openReviewSheet(result);
  }

  /// Opens the SHARED extraction review sheet (same as documents), telling it
  /// not to write back to a documents row and to clear the correspondence
  /// pending_extraction once imported.
  Future<void> _openReviewSheet(DocExtractionResult result) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExtractionReviewSheet(
        caseId: widget.caseId,
        docTitle: item.title,
        result: result,
        writeBackToDocument: false,
        sourceRecordId: item.id,
        onImported: () => ref
            .read(correspondenceProvider(widget.caseId).notifier)
            .clearPendingExtraction(item.id),
      ),
    );
  }

  // ── Reply via Gmail ────────────────────────────────────────────────────────

  Future<void> _reply() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => _GmailReplyDialog(item: item),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply sent')),
      );
    }
  }

  // ── Send action to context notes ──────────────────────────────────────────

  Future<void> _sendToContext(String action) async {
    await ref.read(surveyorNotesProvider(widget.caseId).notifier).add(
          caseId: widget.caseId,
          content: action,
          priority: CuePriority.important,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action added to context notes')),
      );
    }
  }

  /// §3.14: attachments saved to Document Vault from this trail item
  /// (`source_correspondence_id`, migration 036) — the cross-link so a
  /// filed attachment doesn't read as an orphan back here.
  int _filedInVaultCount() =>
      (ref.watch(documentProvider(widget.caseId)).value ?? const [])
          .where((d) => d.sourceCorrespondenceId == item.id)
          .length;

  @override
  Widget build(BuildContext context) {
    final filedInVault = _filedInVaultCount();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row (always visible) ────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _kColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      item.isEml
                          ? Icons.email_outlined
                          : Icons.picture_as_pdf_outlined,
                      color: _kColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Title + chips
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                          maxLines: _expanded ? 3 : 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        // Wrap (not Row) so the status chip + date + parties/
                        // actions/vault/trail badges never overflow a narrow
                        // card — the always-on date pushed this over on small
                        // widths (24 July 2026).
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runSpacing: 4,
                          children: [
                          item.status == CorrStatus.completed
                              ? GestureDetector(
                                  onTap: _showExtractionSummary,
                                  child: _StatusChip(status: item.status),
                                )
                              : _StatusChip(status: item.status),
                          // Always show a date: the email's own date when
                          // parsed, else the import date so no item is dateless
                          // (24 July 2026 — "I want the date of the emails
                          // appearing").
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd MMM yy')
                                .format(item.corrDate ?? item.createdAt),
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textTertiary),
                          ),
                          if (!_expanded && item.parties.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '${item.parties.length} parties',
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.textTertiary),
                            ),
                          ],
                          if (!_expanded && item.actions.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '${item.actions.length} actions',
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.textTertiary),
                            ),
                          ],
                          if (filedInVault > 0) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () =>
                                  context.push('/cases/${widget.caseId}/documents'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$filedInVault in Vault',
                                  style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.success),
                                ),
                              ),
                            ),
                          ],
                          if (widget.thread != null) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: _showThreadSummary,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Trail (${widget.thread!.messages.length})',
                                  style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.teal),
                                ),
                              ),
                            ),
                          ],
                        ]),
                      ],
                    ),
                  ),

                  // Overflow menu + collapse toggle
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          size: 18, color: AppColors.textTertiary),
                      onSelected: (v) {
                        if (v == 'preview') widget.onPreview();
                        if (v == 'extract') _extract();
                        if (v == 'reply') _reply();
                        if (v == 'delete') _confirmDelete();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'preview',
                          child: Row(children: [
                            const Icon(Icons.visibility_outlined, size: 16),
                            const SizedBox(width: 8),
                            Text(item.isEml ? 'View Email' : 'Preview PDF',
                                style: const TextStyle(fontSize: 13)),
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'extract',
                          child: Row(children: [
                            Icon(Icons.auto_awesome_outlined,
                                size: 16, color: _kColor),
                            SizedBox(width: 8),
                            Text('Extract with AI',
                                style: TextStyle(fontSize: 13, color: _kColor)),
                          ]),
                        ),
                        if (item.isEml && item.sender != null)
                          const PopupMenuItem(
                            value: 'reply',
                            child: Row(children: [
                              Icon(Icons.reply_outlined,
                                  size: 16, color: _kColor),
                              SizedBox(width: 8),
                              Text('Reply via Gmail',
                                  style:
                                      TextStyle(fontSize: 13, color: _kColor)),
                            ]),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline,
                                color: Colors.red, size: 16),
                            SizedBox(width: 8),
                            Text('Delete',
                                style:
                                    TextStyle(color: Colors.red, fontSize: 13)),
                          ]),
                        ),
                      ],
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                  ]),
                ],
              ),
            ),
          ),

          // ── Expanded body ──────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.border),

            // Sender / recipient
            if (item.sender != null || item.recipient != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Row(children: [
                  if (item.sender != null)
                    Flexible(
                      child: _MetaChip(
                          icon: Icons.send_outlined, label: item.sender!),
                    ),
                  if (item.sender != null && item.recipient != null)
                    const SizedBox(width: 8),
                  if (item.recipient != null)
                    Flexible(
                      child: _MetaChip(
                          icon: Icons.inbox_outlined, label: item.recipient!),
                    ),
                ]),
              ),

            // File size
            if (item.fileSizeKb != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
                child: Text(
                  '${(item.fileSizeKb! / 1024).toStringAsFixed(1)} MB',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textTertiary),
                ),
              ),

            // Summary
            if (item.summary != null && item.summary!.isNotEmpty) ...[
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Text(
                  item.summary!,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4),
                ),
              ),
            ],

            // Parties chips (import them via the Extracted-data review sheet)
            if (item.parties.isNotEmpty) ...[
              if (item.summary == null)
                const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: item.parties
                            .map((p) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _kColor.withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: _kColor.withValues(alpha: 0.2)),
                                  ),
                                  child: Text(
                                    p.role != null
                                        ? '${p.name} · ${p.role}'
                                        : p.name,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textPrimary),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action items
            if (item.actions.isNotEmpty) ...[
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ACTION ITEMS',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                            letterSpacing: 0.6)),
                    const SizedBox(height: 5),
                    ...item.actions.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.arrow_right,
                                  size: 14, color: AppColors.textTertiary),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(a,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary)),
                              ),
                              const SizedBox(width: 4),
                              Tooltip(
                                message: 'Send to context notes',
                                child: InkWell(
                                  onTap: () => _sendToContext(a),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: Icon(
                                      Icons.add_task,
                                      size: 14,
                                      color: _kColor.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ],

            // Bottom action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
              child: Row(children: [
                OutlinedButton.icon(
                  onPressed: widget.onPreview,
                  icon: Icon(
                    item.isEml
                        ? Icons.email_outlined
                        : Icons.visibility_outlined,
                    size: 14,
                  ),
                  label: Text(item.isEml ? 'View Email' : 'Preview',
                      style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kColor,
                    side: const BorderSide(color: _kColor),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
                const SizedBox(width: 8),
                if (item.status == CorrStatus.pending ||
                    item.status == CorrStatus.failed)
                  OutlinedButton.icon(
                    onPressed:
                        item.status == CorrStatus.processing ? null : _extract,
                    icon: item.status == CorrStatus.processing
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5))
                        : const Icon(Icons.auto_awesome_outlined,
                            size: 14, color: _kColor),
                    label: const Text('Extract',
                        style: TextStyle(fontSize: 12, color: _kColor)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kColor,
                      side: const BorderSide(color: _kColor),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                  ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showExtractionSummary() async {
    // One surface for extracted data: if there's a not-yet-imported extraction,
    // open the actionable review sheet (view + import); once imported/cleared,
    // fall back to the read-only summary of what was found.
    final result = await ref
        .read(correspondenceProvider(widget.caseId).notifier)
        .pendingExtractionFor(item.id);
    if (!mounted) return;
    if (result != null && result.hasAny) {
      await _openReviewSheet(result);
      return;
    }
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CorrExtractionSummarySheet(item: item),
    );
  }

  void _showThreadSummary() {
    final thread = widget.thread;
    if (thread == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ThreadSummarySheet(thread: thread, caseId: widget.caseId),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete correspondence?'),
        content: const Text('The local file will also be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Gmail reply dialog ─────────────────────────────────────────────────────

class _GmailReplyDialog extends StatefulWidget {
  const _GmailReplyDialog({required this.item});
  final CorrespondenceModel item;

  @override
  State<_GmailReplyDialog> createState() => _GmailReplyDialogState();
}

class _GmailReplyDialogState extends State<_GmailReplyDialog> {
  late final TextEditingController _toCtrl;
  late final TextEditingController _subjectCtrl;
  final _bodyCtrl = TextEditingController();
  bool _sending = false;
  String? _error;

  /// Extracts the bare address from a "Display Name <addr@host>" header, or
  /// returns the input unchanged if it's already a bare address.
  static String _extractEmail(String raw) {
    final match = RegExp(r'<([^>]+)>').firstMatch(raw);
    return match?.group(1) ?? raw.trim();
  }

  @override
  void initState() {
    super.initState();
    _toCtrl =
        TextEditingController(text: _extractEmail(widget.item.sender ?? ''));
    _subjectCtrl = TextEditingController(
        text: widget.item.title.startsWith('Re: ')
            ? widget.item.title
            : 'Re: ${widget.item.title}');
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_toCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await GmailService.sendMessage(
        to: _toCtrl.text.trim(),
        subject: _subjectCtrl.text.trim(),
        bodyText: _bodyCtrl.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on GoogleSignInCancelled {
      if (mounted) Navigator.pop(context, false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Send failed: $e';
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reply via Gmail'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _toCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'To'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _subjectCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyCtrl,
              decoration: const InputDecoration(labelText: 'Message'),
              maxLines: 6,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _sending ? null : _send,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kColor,
            foregroundColor: Colors.white,
          ),
          child: _sending
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: Colors.white))
              : const Text('Send'),
        ),
      ],
    );
  }
}



// ── PDF preview screen ─────────────────────────────────────────────────────

class _PdfPreviewScreen extends StatelessWidget {
  const _PdfPreviewScreen({required this.item});
  final CorrespondenceModel item;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: BackAppBar(
            title:
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
        body: PdfViewer.file(item.localPath!),
      );
}

/// Web variant — no local file cache is available there (dart:io doesn't
/// work on web), so the PDF bytes are downloaded straight from Drive and
/// handed to pdfrx's in-memory viewer instead of a file path.
class _PdfBytesPreviewScreen extends StatelessWidget {
  const _PdfBytesPreviewScreen({required this.item, required this.bytes});
  final CorrespondenceModel item;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: BackAppBar(
            title:
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
        body: PdfViewer.data(bytes, sourceName: item.id),
      );
}

// ── Email body preview screen ──────────────────────────────────────────────

class _EmailPreviewScreen extends StatelessWidget {
  const _EmailPreviewScreen({required this.item});
  final CorrespondenceModel item;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: BackAppBar(
            title:
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.sender != null)
                _HeaderRow(label: 'From', value: item.sender!),
              if (item.recipient != null)
                _HeaderRow(label: 'To', value: item.recipient!),
              if (item.corrDate != null)
                _HeaderRow(
                  label: 'Date',
                  value: DateFormat('dd MMM yyyy HH:mm').format(item.corrDate!),
                ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              SelectableText(
                item.bodyText ?? '(No body text)',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary, height: 1.5),
              ),
            ],
          ),
        ),
      );
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 46,
          child: Text('$label:',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary)),
        ),
        Expanded(
          child: Text(value,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
        ),
      ]),
    );
  }
}

// ── Status chip ────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final CorrStatus status;

  Color get _color => switch (status) {
        CorrStatus.pending => AppColors.textTertiary,
        // Blue, not orange: "Processing…" is a transient status, not a
        // warning/action-needed (23 July 2026 report).
        CorrStatus.processing => AppColors.info,
        CorrStatus.completed => AppColors.success,
        CorrStatus.failed => AppColors.error,
      };

  IconData? get _icon => switch (status) {
        CorrStatus.pending => null,
        CorrStatus.processing => Icons.hourglass_top,
        // Sparkle makes it unmistakably an AI result, not a manual status
        // (16 July 2026: "make it more clear AI extracted").
        CorrStatus.completed => Icons.auto_awesome,
        CorrStatus.failed => Icons.error_outline,
      };

  @override
  Widget build(BuildContext context) {
    // The completed (AI-extracted) chip is rendered solid so it reads at a
    // glance across a long list — the whole point of the report note.
    final bool solid = status == CorrStatus.completed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? _color : _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
            color: solid ? _color : _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_icon != null) ...[
            Icon(_icon,
                size: 10, color: solid ? Colors.white : _color),
            const SizedBox(width: 3),
          ],
          Text(status.label,
              style: TextStyle(
                  fontSize: 9,
                  color: solid ? Colors.white : _color,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Meta chip ──────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: AppColors.textTertiary),
      const SizedBox(width: 3),
      Flexible(
        child: Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _kColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mail_outline, color: _kColor, size: 30),
          ),
          const SizedBox(height: 16),
          const Text('No correspondence yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text(
              'Upload PDFs or import .eml emails\nAI extracts parties, summary and actions',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Correspondence'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Correspondence extraction summary sheet ───────────────────────────────────

class _CorrExtractionSummarySheet extends StatelessWidget {
  const _CorrExtractionSummarySheet({required this.item});
  final CorrespondenceModel item;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Icon(Icons.auto_awesome,
                  size: 16, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          const Divider(),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // ── Identity fields ─────────────────────────────────
                _CorrSummarySection(
                  title: 'Header',
                  color: _kColor,
                  icon: Icons.email_outlined,
                  rows: [
                    if (item.sender != null) _CorrRow('From', item.sender!),
                    if (item.recipient != null) _CorrRow('To', item.recipient!),
                    if (item.corrDate != null)
                      _CorrRow('Date',
                          DateFormat('dd MMM yyyy').format(item.corrDate!)),
                  ],
                ),

                // ── Summary ────────────────────────────────────────
                if (item.summary != null && item.summary!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _CorrSummarySection(
                    title: 'Summary',
                    color: AppColors.midBlue,
                    icon: Icons.summarize_outlined,
                    rows: const [],
                    body: item.summary!,
                  ),
                ],

                // ── Parties ────────────────────────────────────────
                if (item.parties.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _CorrSummarySection(
                    title: 'Parties (${item.parties.length})',
                    color: AppColors.teal,
                    icon: Icons.people_outline,
                    rows: item.parties.map((p) {
                      final detail = [
                        if (p.company != null) p.company!,
                        if (p.role != null) p.role!,
                        if (p.email != null) p.email!,
                      ].join(' · ');
                      return _CorrRow(p.name, detail.isEmpty ? '—' : detail);
                    }).toList(),
                  ),
                ],

                // ── Action items ───────────────────────────────────
                if (item.actions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const _CorrSummarySectionHeader(
                    title: 'Action Items',
                    color: AppColors.coral,
                    icon: Icons.task_alt_outlined,
                  ),
                  const SizedBox(height: 6),
                  ...item.actions.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.coral,
                                    fontWeight: FontWeight.w700)),
                            Expanded(
                              child: Text(a,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textPrimary)),
                            ),
                          ],
                        ),
                      )),
                ],

                // ── Key dates ──────────────────────────────────────
                if (item.keyDates.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const _CorrSummarySectionHeader(
                    title: 'Key Dates',
                    color: AppColors.purple,
                    icon: Icons.calendar_today_outlined,
                  ),
                  const SizedBox(height: 6),
                  ...item.keyDates.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $d',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textPrimary)),
                      )),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// §3.14: thread-level trail summary — the deterministic sequence (who/
/// when/subject) is always shown; the narrative synthesis is a separate
/// on-demand AI call (button tap, not automatic) since it's a genuine paid
/// call per thread, same posture as the per-message extraction summary.
class _ThreadSummarySheet extends ConsumerStatefulWidget {
  const _ThreadSummarySheet({required this.thread, required this.caseId});
  final CorrespondenceThread thread;
  final String caseId;

  @override
  ConsumerState<_ThreadSummarySheet> createState() =>
      _ThreadSummarySheetState();
}

class _ThreadSummarySheetState extends ConsumerState<_ThreadSummarySheet> {
  String? _narrative;
  bool _generating = false;
  Object? _error;

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final messages = widget.thread.messages
          .map((m) => {
                'from': m.sender,
                'date': m.corrDate != null
                    ? DateFormat('dd MMM yyyy').format(m.corrDate!)
                    : null,
                // Prefer the message's own extracted summary (concise,
                // already AI-cleaned) — only fall back to a raw body
                // snippet if it was never extracted, and even then cap it
                // so one huge message can't blow out the call's cost.
                'text': (m.summary?.isNotEmpty ?? false)
                    ? m.summary
                    : (m.bodyText?.isNotEmpty ?? false)
                        ? m.bodyText!.substring(
                            0, m.bodyText!.length.clamp(0, 500))
                        : null,
              })
          .toList();
      final result = await ref.read(aiTasksProvider.notifier).run(
            label: 'Summarising "${widget.thread.subject}"',
            caseId: widget.caseId,
            estimate: const Duration(seconds: 15),
            action: () => ClaudeApi.draftCorrespondenceTrailSummary(
              subject: widget.thread.subject,
              messages: messages,
            ),
          );
      if (mounted) setState(() => _narrative = result);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = widget.thread;
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Icon(Icons.forum_outlined, size: 16, color: AppColors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  thread.subject,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${thread.messages.length} messages in this trail',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textTertiary),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Divider(),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // ── AI narrative (on demand) ────────────────────────
                const _CorrSummarySectionHeader(
                  title: 'Exchange Summary',
                  color: AppColors.midBlue,
                  icon: Icons.summarize_outlined,
                ),
                const SizedBox(height: 6),
                if (_narrative != null)
                  Text(_narrative!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          height: 1.45))
                else if (_error != null)
                  Text('Could not generate a summary: $_error',
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.error))
                else
                  const Text(
                    'Not generated yet — tap below to summarise how this '
                    'exchange developed.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        fontStyle: FontStyle.italic),
                  ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _generating ? null : _generate,
                  icon: _generating
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5))
                      : const Icon(Icons.auto_awesome_outlined, size: 14),
                  label: Text(
                      _narrative == null ? 'Generate Summary' : 'Regenerate',
                      style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.midBlue,
                    side: const BorderSide(color: AppColors.midBlue),
                  ),
                ),

                const SizedBox(height: 18),

                // ── Deterministic sequence ───────────────────────────
                const _CorrSummarySectionHeader(
                  title: 'Sequence',
                  color: AppColors.teal,
                  icon: Icons.list_alt_outlined,
                ),
                const SizedBox(height: 8),
                ...thread.messages.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 5, right: 8),
                            decoration: const BoxDecoration(
                                color: AppColors.teal, shape: BoxShape.circle),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  [
                                    if (m.corrDate != null)
                                      DateFormat('dd MMM yyyy')
                                          .format(m.corrDate!),
                                    if (m.sender != null) m.sender!,
                                  ].join(' — '),
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary),
                                ),
                                if (m.title != thread.subject)
                                  Text(m.title,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textTertiary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _CorrSummarySectionHeader extends StatelessWidget {
  const _CorrSummarySectionHeader({
    required this.title,
    required this.color,
    required this.icon,
  });
  final String title;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.4)),
      ]);
}

class _CorrRow {
  const _CorrRow(this.label, this.value);
  final String label;
  final String value;
}

class _CorrSummarySection extends StatelessWidget {
  const _CorrSummarySection({
    required this.title,
    required this.color,
    required this.icon,
    required this.rows,
    this.body,
  });
  final String title;
  final Color color;
  final IconData icon;
  final List<_CorrRow> rows;
  final String? body;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty && body == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _CorrSummarySectionHeader(title: title, color: color, icon: icon),
      const SizedBox(height: 6),
      if (body != null)
        Text(body!,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textPrimary, height: 1.45)),
      ...rows.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 110,
                child: Text(r.label,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500)),
              ),
              Expanded(
                child: Text(r.value,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textPrimary)),
              ),
            ]),
          )),
    ]);
  }
}
