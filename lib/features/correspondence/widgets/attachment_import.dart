// lib/features/correspondence/widgets/attachment_import.dart
//
// Shared EML-attachment import: the filter dialog (hides small signature
// images) + upload of the kept attachments into the case Document Vault.
// Used by every import path — file picker, Gmail picker and the Inbox
// "Link to case" — so attachments are never silently dropped (24 July 2026).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/eml_parser.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../documents/providers/document_provider.dart';

const _kColor = Color(0xFF2A6099);

/// Shows the attachment filter dialog for [attachments] and uploads the ones
/// the surveyor keeps into the case Document Vault (category Correspondence),
/// cross-linked to the source correspondence via [sourceIdFor]. No-op when
/// there are no attachments.
Future<void> promptImportAttachments(
  BuildContext context,
  WidgetRef ref, {
  required String caseId,
  required List<EmlAttachment> attachments,
  String? Function(EmlAttachment)? sourceIdFor,
}) async {
  if (attachments.isEmpty || !context.mounted) return;
  final selected = await showDialog<List<EmlAttachment>>(
    context: context,
    builder: (_) => AttachmentImportDialog(attachments: attachments),
  );
  if (selected == null || selected.isEmpty || !context.mounted) return;
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
      sourceCorrespondenceId: sourceIdFor?.call(att),
    );
  }
  if (context.mounted) {
    showSavedToast(context,
        label: '${selected.length} attachment(s) saved to Document Vault');
  }
}

// ── Attachment save dialog ──────────────────────────────────────────────────

class AttachmentImportDialog extends StatefulWidget {
  const AttachmentImportDialog({super.key, required this.attachments});
  final List<EmlAttachment> attachments;

  @override
  State<AttachmentImportDialog> createState() => _AttachmentImportDialogState();
}

class _AttachmentImportDialogState extends State<AttachmentImportDialog> {
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

