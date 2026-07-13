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
import '../../../core/services/gmail_service.dart';
import '../../../core/services/google_auth_service.dart';
import '../../../core/utils/eml_parser.dart';
import '../../../features/cases/providers/cases_provider.dart';
import '../../../features/documents/providers/document_provider.dart';
import '../../../features/parties/providers/parties_provider.dart';
import '../../../features/photos/services/google_drive_service.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../features/surveyor_notes/providers/surveyor_notes_provider.dart';
import '../../../features/surveyor_notes/models/surveyor_note_model.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import 'gmail_message_picker_screen.dart';
import '../../../shared/widgets/back_app_bar.dart';
import 'package:go_router/go_router.dart';
import '../providers/mail_poll_provider.dart';

const _kColor = Color(0xFF2A6099);

class CorrespondenceScreen extends ConsumerWidget {
  const CorrespondenceScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final corrAsync = ref.watch(correspondenceProvider(caseId));
    final unseenMail = ref.watch(mailPollProvider).unseenCount;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(
        title: const Text('Correspondence'),
        actions: [
          // §3.14: same shared new-mail signal as the Cases list Inbox
          // icon — a nudge that there's un-triaged mail, surfaced here too
          // since a surveyor working a case's Correspondence trail is
          // exactly who'd want to know about it, without conflating the
          // count with anything case-specific (Inbox mail isn't filed to a
          // case yet, so it can't be scoped to this one).
          IconButton(
            icon: Badge(
              label: Text('$unseenMail'),
              isLabelVisible: unseenMail > 0,
              child: const Icon(Icons.mail_outline, color: Colors.white),
            ),
            onPressed: () => context.go('/inbox'),
            tooltip: unseenMail > 0 ? 'Inbox — $unseenMail new' : 'Inbox',
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
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _CorrCard(
                  key: ValueKey(items[i].id),
                  item: items[i],
                  caseId: caseId,
                  onPreview: () => items[i].isEml
                      ? _openEmailPreview(context, items[i])
                      : _openPdfPreview(context, ref, items[i]),
                  onDelete: () => ref
                      .read(correspondenceProvider(caseId).notifier)
                      .delete(items[i].id),
                ),
              ),
      ),
    );
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

    final (_, attachments) = await ref
        .read(correspondenceProvider(caseId).notifier)
        .importEml(caseId: caseId, bytes: file.bytes!, filename: file.name);

    if (!context.mounted) return;

    if (attachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email imported — no attachments found')),
      );
      return;
    }

    final selected = await showDialog<List<EmlAttachment>>(
      context: context,
      builder: (ctx) => _AttachmentDialog(attachments: attachments),
    );

    if (selected != null && selected.isNotEmpty && context.mounted) {
      final docNotifier = ref.read(documentProvider(caseId).notifier);
      for (final att in selected) {
        await docNotifier.uploadAndCreate(
          caseId: caseId,
          bytes: att.bytes,
          filename: att.filename,
          mimeType: att.mimeType,
          title: att.filename,
          category: DocCategory.correspondence,
          willExtract: false,
        );
      }
      if (context.mounted) {
        showSavedToast(context,
            label: '${selected.length} attachment(s) saved to Document Vault');
      }
    }
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
    for (final (bytes, subject) in result) {
      final (_, attachments) = await notifier.importEml(
          caseId: caseId, bytes: bytes, filename: '$subject.eml');
      allAttachments.addAll(attachments);
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${result.length} message(s) imported — ready for AI extraction')),
    );

    if (allAttachments.isEmpty) return;

    final selected = await showDialog<List<EmlAttachment>>(
      context: context,
      builder: (ctx) => _AttachmentDialog(attachments: allAttachments),
    );

    if (selected != null && selected.isNotEmpty && context.mounted) {
      final docNotifier = ref.read(documentProvider(caseId).notifier);
      for (final att in selected) {
        await docNotifier.uploadAndCreate(
          caseId: caseId,
          bytes: att.bytes,
          filename: att.filename,
          mimeType: att.mimeType,
          title: att.filename,
          category: DocCategory.correspondence,
          willExtract: false,
        );
      }
      if (context.mounted) {
        showSavedToast(context,
            label: '${selected.length} attachment(s) saved to Document Vault');
      }
    }
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
  });

  final CorrespondenceModel item;
  final String caseId;
  final VoidCallback onPreview;
  final VoidCallback onDelete;

  @override
  ConsumerState<_CorrCard> createState() => _CorrCardState();
}

class _CorrCardState extends ConsumerState<_CorrCard> {
  bool _expanded = false;

  CorrespondenceModel get item => widget.item;

  // ── Add to Parties ────────────────────────────────────────────────────────

  Future<void> _addToParties() async {
    if (item.parties.isEmpty) return;

    final selected = await showDialog<List<ExtractedParty>>(
      context: context,
      builder: (_) => _AddToPartiesDialog(parties: item.parties),
    );
    if (selected == null || selected.isEmpty || !mounted) return;

    final added = await ref
        .read(assuredContactsProvider(widget.caseId).notifier)
        .addFromExtracted(widget.caseId, selected);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          added == 0
              ? 'All parties already in the stakeholders list'
              : '$added stakeholder(s) added to Parties',
        ),
      ));
    }
  }

  // ── AI extraction (with case refs confirmation) ───────────────────────────

  Future<void> _extract() async {
    ExtractedCaseRefs? refs;
    try {
      refs = await ref
          .read(correspondenceProvider(widget.caseId).notifier)
          .extract(item.id);
    } catch (e) {
      if (mounted) {
        showError(context, 'Extraction failed: $e', error: e, tag: 'Correspondence');
      }
      return;
    }
    if (refs == null || !mounted) return;
    final extractedRefs = refs;

    final currentCase = ref.read(caseProvider(widget.caseId)).value;
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _CaseRefsDialog(
        caseId: widget.caseId,
        refs: extractedRefs,
        currentCase: currentCase,
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
          natureOfContent: NatureOfContent.followUpOpenQuestion,
          priority: CuePriority.important,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action added to context notes')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        Row(children: [
                          item.status == CorrStatus.completed
                              ? GestureDetector(
                                  onTap: _showExtractionSummary,
                                  child: _StatusChip(status: item.status),
                                )
                              : _StatusChip(status: item.status),
                          if (item.corrDate != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('dd MMM yy').format(item.corrDate!),
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.textTertiary),
                            ),
                          ],
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

            // Parties chips + "Add to Parties" button
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
                    const SizedBox(width: 6),
                    TextButton.icon(
                      onPressed: _addToParties,
                      icon: const Icon(Icons.group_add_outlined, size: 13),
                      label: const Text('Add to Parties',
                          style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        foregroundColor: _kColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  void _showExtractionSummary() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CorrExtractionSummarySheet(item: item),
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
              decoration: const InputDecoration(labelText: 'To'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _subjectCtrl,
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

// ── Case refs confirmation dialog ─────────────────────────────────────────

class _CaseRefsDialog extends ConsumerStatefulWidget {
  const _CaseRefsDialog({
    required this.caseId,
    required this.refs,
    required this.currentCase,
  });
  final String caseId;
  final ExtractedCaseRefs refs;
  final dynamic currentCase; // CaseModel?

  @override
  ConsumerState<_CaseRefsDialog> createState() => _CaseRefsDialogState();
}

class _CaseRefsDialogState extends ConsumerState<_CaseRefsDialog> {
  late bool _applyJob;
  late bool _applyClaim;
  late bool _applyVessel;
  late bool _applyDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.currentCase;
    _applyJob = widget.refs.technicalFileNo != null &&
        (c == null || (c.hasPlaceholderFileNo as bool));
    _applyClaim = widget.refs.claimReference != null &&
        (c == null || (c.claimReference == null));
    _applyVessel = widget.refs.vesselName != null;
    _applyDate = widget.refs.instructionDate != null &&
        (c == null || c.instructionDate == null);
  }

  Future<void> _apply() async {
    setState(() => _saving = true);
    try {
      final notifier = ref.read(caseProvider(widget.caseId).notifier);
      await notifier.updateCaseRefs(
        technicalFileNo: _applyJob ? widget.refs.technicalFileNo : null,
        claimReference: _applyClaim ? widget.refs.claimReference : null,
        instructionDate: _applyDate ? widget.refs.instructionDate : null,
      );
      if (_applyVessel && widget.refs.vesselName != null) {
        await notifier.upsertVesselName(widget.refs.vesselName!);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final refs = widget.refs;
    final c = widget.currentCase;

    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.auto_awesome_outlined, size: 18, color: _kColor),
        SizedBox(width: 8),
        Text('Apply extracted references',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select which values to apply to this case:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (refs.technicalFileNo != null)
              _RefRow(
                label: 'Technical File No.',
                extracted: refs.technicalFileNo!,
                current: (c?.hasPlaceholderFileNo == true ||
                        c?.technicalFileNo == null)
                    ? null
                    : c?.technicalFileNo as String?,
                checked: _applyJob,
                onChanged: (v) => setState(() => _applyJob = v ?? false),
              ),
            if (refs.claimReference != null)
              _RefRow(
                label: 'Claim Reference',
                extracted: refs.claimReference!,
                current: c?.claimReference as String?,
                checked: _applyClaim,
                onChanged: (v) => setState(() => _applyClaim = v ?? false),
              ),
            if (refs.vesselName != null)
              _RefRow(
                label: 'Vessel Name',
                extracted: refs.vesselName!,
                current: c?.vesselName as String?,
                checked: _applyVessel,
                onChanged: (v) => setState(() => _applyVessel = v ?? false),
              ),
            if (refs.instructionDate != null)
              _RefRow(
                label: 'Instruction Date',
                extracted:
                    '${refs.instructionDate!.day.toString().padLeft(2, '0')}/'
                    '${refs.instructionDate!.month.toString().padLeft(2, '0')}/'
                    '${refs.instructionDate!.year}',
                current: c?.instructionDate != null
                    ? '${(c!.instructionDate as DateTime).day.toString().padLeft(2, '0')}/'
                        '${(c.instructionDate as DateTime).month.toString().padLeft(2, '0')}/'
                        '${(c.instructionDate as DateTime).year}'
                    : null,
                checked: _applyDate,
                onChanged: (v) => setState(() => _applyDate = v ?? false),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Ignore'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _apply,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kColor,
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: Colors.white))
              : const Text('Apply'),
        ),
      ],
    );
  }
}

class _RefRow extends StatelessWidget {
  const _RefRow({
    required this.label,
    required this.extracted,
    required this.current,
    required this.checked,
    required this.onChanged,
  });
  final String label;
  final String extracted;
  final String? current;
  final bool checked;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: checked,
      onChanged: onChanged,
      activeColor: _kColor,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      tileColor: Colors.transparent,
      dense: true,
      title: Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('→ $extracted',
              style: const TextStyle(fontSize: 11, color: _kColor)),
          if (current != null)
            Text('current: $current',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

// ── Add to Parties dialog ──────────────────────────────────────────────────

class _AddToPartiesDialog extends StatefulWidget {
  const _AddToPartiesDialog({required this.parties});
  final List<ExtractedParty> parties;

  @override
  State<_AddToPartiesDialog> createState() => _AddToPartiesDialogState();
}

class _AddToPartiesDialogState extends State<_AddToPartiesDialog> {
  late final Map<ExtractedParty, bool> _checked;

  @override
  void initState() {
    super.initState();
    _checked = {for (final p in widget.parties) p: true};
  }

  int get _count => _checked.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add to Parties'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: widget.parties.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = widget.parties[i];
            return CheckboxListTile(
              value: _checked[p] ?? false,
              onChanged: (v) => setState(() => _checked[p] = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: _kColor,
              tileColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(p.name,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(
                [if (p.company != null) p.company!, if (p.role != null) p.role!]
                    .join(' · '),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, <ExtractedParty>[]),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _count == 0
              ? null
              : () => Navigator.pop(
                    context,
                    _checked.entries
                        .where((e) => e.value)
                        .map((e) => e.key)
                        .toList(),
                  ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kColor,
            foregroundColor: Colors.white,
          ),
          child: Text('Add $_count'),
        ),
      ],
    );
  }
}

// ── Attachment save dialog ──────────────────────────────────────────────────

class _AttachmentDialog extends StatefulWidget {
  const _AttachmentDialog({required this.attachments});
  final List<EmlAttachment> attachments;

  @override
  State<_AttachmentDialog> createState() => _AttachmentDialogState();
}

class _AttachmentDialogState extends State<_AttachmentDialog> {
  double _minImageKb = 20;
  late final Map<EmlAttachment, bool> _checked;

  bool get _hasImages => widget.attachments.any((a) => a.isImage);
  bool _passes(EmlAttachment a) => !a.isImage || a.sizeKb >= _minImageKb;

  @override
  void initState() {
    super.initState();
    _checked = {for (final a in widget.attachments) a: _passes(a)};
  }

  void _reapplyFilter() {
    for (final a in widget.attachments) {
      if (a.isImage) _checked[a] = _passes(a);
    }
  }

  List<EmlAttachment> get _visible =>
      widget.attachments.where(_passes).toList();

  int get _hiddenCount => widget.attachments.where((a) => !_passes(a)).length;
  int get _selectedCount => _checked.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return AlertDialog(
      title: Text('${widget.attachments.length} Attachment(s) Found'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_hasImages) ...[
              Row(children: [
                const Icon(Icons.filter_alt_outlined,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  'Hide images under ${_minImageKb.round()} KB',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                Expanded(
                  child: Slider(
                    value: _minImageKb,
                    min: 0,
                    max: 200,
                    divisions: 20,
                    activeColor: _kColor,
                    onChanged: (v) => setState(() {
                      _minImageKb = v;
                      _reapplyFilter();
                    }),
                  ),
                ),
              ]),
              if (_hiddenCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '$_hiddenCount small image(s) hidden — likely email signatures',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontStyle: FontStyle.italic),
                  ),
                ),
              const Divider(height: 1),
            ],
            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      child: Text('All attachments hidden by filter.',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textTertiary)))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final att = visible[i];
                        return CheckboxListTile(
                          value: _checked[att] ?? false,
                          onChanged: (v) =>
                              setState(() => _checked[att] = v ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: _kColor,
                          tileColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          secondary: att.isImage
                              ? _ImageThumb(
                                  bytes: att.bytes, filename: att.filename)
                              : _FileTypeIcon(mimeType: att.mimeType),
                          title: Text(att.filename,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1),
                          subtitle: Text(att.displaySize,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textTertiary)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, <EmlAttachment>[]),
          child: const Text('Skip All'),
        ),
        ElevatedButton(
          onPressed: _selectedCount == 0
              ? null
              : () => Navigator.pop(
                    context,
                    _checked.entries
                        .where((e) => e.value)
                        .map((e) => e.key)
                        .toList(),
                  ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kColor,
            foregroundColor: Colors.white,
          ),
          child: Text('Save Selected ($_selectedCount)'),
        ),
      ],
    );
  }
}

// ── Image thumbnail with tap-to-zoom ──────────────────────────────────────

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.bytes, required this.filename});
  final Uint8List bytes;
  final String filename;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
                child: Row(children: [
                  Expanded(
                    child: Text(filename,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
              ),
              InteractiveViewer(
                  child: Image.memory(bytes, fit: BoxFit.contain)),
            ],
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Image.memory(bytes, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

// ── File type icon ─────────────────────────────────────────────────────────

class _FileTypeIcon extends StatelessWidget {
  const _FileTypeIcon({required this.mimeType});
  final String mimeType;

  @override
  Widget build(BuildContext context) {
    final mt = mimeType.toLowerCase();
    final icon = mt.contains('pdf')
        ? Icons.picture_as_pdf_outlined
        : mt.contains('word') ||
                mt.contains('document') ||
                mt.contains('msword')
            ? Icons.description_outlined
            : mt.contains('excel') || mt.contains('spreadsheet')
                ? Icons.table_chart_outlined
                : Icons.attach_file;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _kColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: _kColor, size: 24),
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
        CorrStatus.processing => AppColors.warning,
        CorrStatus.completed => AppColors.success,
        CorrStatus.failed => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(status.label,
          style: TextStyle(
              fontSize: 9, color: _color, fontWeight: FontWeight.w700)),
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
