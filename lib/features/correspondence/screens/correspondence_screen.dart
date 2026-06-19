// lib/features/correspondence/screens/correspondence_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/correspondence_model.dart';
import '../providers/correspondence_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';

const _kColor = Color(0xFF2A6099);

class CorrespondenceScreen extends ConsumerWidget {
  const CorrespondenceScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final corrAsync = ref.watch(correspondenceProvider(caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Correspondence')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _uploadPdf(context, ref),
        backgroundColor: _kColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Upload PDF',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: corrAsync.when(
        loading: () =>
            const AppLoadingWidget(message: 'Loading correspondence…'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => items.isEmpty
            ? _EmptyState(onUpload: () => _uploadPdf(context, ref))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _CorrCard(
                  item: items[i],
                  onExtract: () => ref
                      .read(correspondenceProvider(caseId).notifier)
                      .extract(items[i].id),
                  onPreview: () => _openPreview(context, items[i]),
                  onDelete: () => ref
                      .read(correspondenceProvider(caseId).notifier)
                      .delete(items[i].id),
                ),
              ),
      ),
    );
  }

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

  void _openPreview(BuildContext context, CorrespondenceModel item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PdfPreviewScreen(item: item),
      ),
    );
  }
}

// ── Correspondence card ────────────────────────────────────────────────────

class _CorrCard extends StatelessWidget {
  const _CorrCard({
    required this.item,
    required this.onExtract,
    required this.onPreview,
    required this.onDelete,
  });

  final CorrespondenceModel item;
  final VoidCallback onExtract;
  final VoidCallback onPreview;
  final VoidCallback onDelete;

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
          // ── Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _kColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf_outlined,
                      color: _kColor, size: 20),
                ),
                const SizedBox(width: 10),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(children: [
                        _StatusChip(status: item.status),
                        if (item.corrDate != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd MMM yyyy').format(item.corrDate!),
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary),
                          ),
                        ],
                        if (item.fileSizeKb != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${(item.fileSizeKb! / 1024).toStringAsFixed(1)} MB',
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textTertiary),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      size: 18, color: AppColors.textTertiary),
                  onSelected: (v) {
                    if (v == 'preview') onPreview();
                    if (v == 'extract') onExtract();
                    if (v == 'delete') _confirmDelete(context);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'preview',
                      child: Row(children: [
                        Icon(Icons.visibility_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Preview PDF',
                            style: TextStyle(fontSize: 13)),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'extract',
                      child: Row(children: [
                        Icon(Icons.auto_awesome_outlined,
                            size: 16, color: _kColor),
                        SizedBox(width: 8),
                        Text('Extract with AI',
                            style: TextStyle(
                                fontSize: 13, color: _kColor)),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(
                                color: Colors.red, fontSize: 13)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Sender / recipient ─────────────────────────────────────
          if (item.sender != null || item.recipient != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(children: [
                if (item.sender != null)
                  _MetaChip(
                      icon: Icons.send_outlined,
                      label: item.sender!),
                if (item.sender != null && item.recipient != null)
                  const SizedBox(width: 8),
                if (item.recipient != null)
                  _MetaChip(
                      icon: Icons.inbox_outlined,
                      label: item.recipient!),
              ]),
            ),

          // ── Summary ────────────────────────────────────────────────
          if (item.summary != null && item.summary!.isNotEmpty) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Text(
                item.summary!,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // ── Parties chips ──────────────────────────────────────────
          if (item.parties.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: item.parties.map((p) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
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
                )).toList(),
              ),
            ),
          ],

          // ── Action items ───────────────────────────────────────────
          if (item.actions.isNotEmpty) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
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
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.arrow_right,
                                size: 14,
                                color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(a,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],

          // ── Preview button ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(children: [
              OutlinedButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.visibility_outlined, size: 14),
                label: const Text('Preview',
                    style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kColor,
                  side: const BorderSide(color: _kColor),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                ),
              ),
              const SizedBox(width: 8),
              if (item.status == CorrStatus.pending ||
                  item.status == CorrStatus.failed)
                OutlinedButton.icon(
                  onPressed: item.status == CorrStatus.processing
                      ? null
                      : onExtract,
                  icon: item.status == CorrStatus.processing
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5))
                      : const Icon(Icons.auto_awesome_outlined,
                          size: 14, color: _kColor),
                  label: const Text('Extract',
                      style:
                          TextStyle(fontSize: 12, color: _kColor)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kColor,
                    side:
                        const BorderSide(color: _kColor),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete correspondence?'),
        content:
            const Text('The local PDF file will also be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── PDF preview screen ─────────────────────────────────────────────────────

class _PdfPreviewScreen extends StatelessWidget {
  const _PdfPreviewScreen({required this.item});
  final CorrespondenceModel item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.title, maxLines: 1,
          overflow: TextOverflow.ellipsis)),
      body: PdfViewer.file(item.localPath),
    );
  }
}

// ── Status chip ────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final CorrStatus status;

  Color get _color => switch (status) {
        CorrStatus.pending    => AppColors.textTertiary,
        CorrStatus.processing => AppColors.warning,
        CorrStatus.completed  => AppColors.success,
        CorrStatus.failed     => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            fontSize: 9,
            color: _color,
            fontWeight: FontWeight.w700),
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
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onUpload});
  final VoidCallback onUpload;

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
            child: const Icon(Icons.mail_outline,
                color: _kColor, size: 30),
          ),
          const SizedBox(height: 16),
          const Text('No correspondence uploaded',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text(
              'Upload PDFs — AI will extract parties,\nsummary and action items',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Upload PDF'),
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
