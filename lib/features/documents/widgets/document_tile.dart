// lib/features/documents/widgets/document_tile.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/document_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/error_handler.dart';

class DocumentTile extends ConsumerWidget {
  const DocumentTile({
    super.key,
    required this.doc,
    this.onPreview,
    this.onExtract,
  });

  final DocumentModel doc;
  final VoidCallback? onPreview;
  final VoidCallback? onExtract;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          // File type icon
          GestureDetector(
            onTap: onPreview,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _iconBg(doc),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_icon(doc), color: _iconColor(doc), size: 20),
            ),
          ),
          const SizedBox(width: 12),

          // Title and metadata
          Expanded(
            child: GestureDetector(
              onTap: onPreview,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(children: [
                    _Badge(doc.availability.label,
                        _availColor(doc.availability)),
                    const SizedBox(width: 6),
                    if (doc.extractionProcessing)
                      const _Badge('Extracting…', AppColors.amber)
                    else if (doc.aiExtracted)
                      const _Badge('✓ Extracted', AppColors.success)
                    else if (doc.extractionFailed)
                      const _Badge('Extraction failed', AppColors.error),
                    if (doc.isDocx) ...[
                      const SizedBox(width: 6),
                      const _Badge('DOCX', AppColors.midBlue),
                    ],
                  ]),
                  if (doc.docDate != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(doc.docDate!),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Spinner while extracting, wand icon when pending/failed
          if (doc.extractionProcessing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.amber),
              ),
            )
          else if (onExtract != null)
            IconButton(
              icon: const Icon(Icons.auto_awesome, size: 18),
              color: AppColors.amber,
              tooltip: doc.extractionFailed
                  ? 'Retry AI extraction'
                  : 'Extract data with AI',
              onPressed: onExtract,
            ),

          // Preview button (for docs with files)
          if (onPreview != null)
            IconButton(
              icon: const Icon(Icons.open_in_new_outlined, size: 18),
              color: AppColors.midBlue,
              tooltip: doc.isImage ? 'View image' : 'Open document',
              onPressed: onPreview,
            ),

          // Overflow menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert,
                color: AppColors.textTertiary, size: 18),
            onSelected: (v) {
              if (v == 'rename') _showRename(context, ref);
              if (v == 'edit') _showEditMetadata(context, ref);
              if (v == 'delete') _confirmDelete(context, ref);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.tune_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Edit metadata', style: TextStyle(fontSize: 13)),
                ]),
              ),
              const PopupMenuItem(
                value: 'rename',
                child: Row(children: [
                  Icon(Icons.drive_file_rename_outline_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Rename', style: TextStyle(fontSize: 13)),
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, color: AppColors.error, size: 16),
                  SizedBox(width: 8),
                  Text('Delete',
                      style: TextStyle(color: AppColors.error, fontSize: 13)),
                ]),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  void _showEditMetadata(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController(text: doc.title);
    DocCategory? selectedCat = doc.docCategory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Edit Metadata',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            const Text('Title',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: titleCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Document title',
                hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Category',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: DocCategory.values.map((cat) {
                final sel = selectedCat == cat;
                return GestureDetector(
                  onTap: () => setState(() => selectedCat = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.midBlue.withValues(alpha: 0.1) : Colors.white,
                      border: Border.all(
                          color: sel ? AppColors.midBlue : AppColors.border,
                          width: sel ? 1.5 : 1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(cat.label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                            color: sel ? AppColors.midBlue : AppColors.textSecondary)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.midBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () async {
                  final newTitle = titleCtrl.text.trim();
                  Navigator.pop(ctx);
                  try {
                    await ref
                        .read(documentProvider(doc.caseId).notifier)
                        .updateMetadata(doc.docId,
                            title: newTitle.isNotEmpty ? newTitle : null,
                            category: selectedCat);
                  } catch (e, st) {
                    if (context.mounted) {
                      showError(context, 'Update failed: $e',
                          error: e, stack: st, tag: 'Document');
                    }
                  }
                },
                child: const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showRename(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(text: doc.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Document title'),
          onSubmitted: (_) async {
            final title = ctrl.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(ctx);
            try {
              await ref
                  .read(documentProvider(doc.caseId).notifier)
                  .renameDocument(doc.docId, title);
            } catch (e, st) {
              if (context.mounted) showError(context, 'Rename failed: $e', error: e, stack: st, tag: 'Document');
            }
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final title = ctrl.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref
                    .read(documentProvider(doc.caseId).notifier)
                    .renameDocument(doc.docId, title);
              } catch (e, st) {
                if (context.mounted) showError(context, 'Rename failed: $e', error: e, stack: st, tag: 'Document');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(documentProvider(doc.caseId).notifier)
                    .deleteDocument(doc);
              } catch (e, st) {
                if (context.mounted) showError(context, 'Delete failed: $e', error: e, stack: st, tag: 'Document');
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  IconData _icon(DocumentModel d) {
    if (d.isPdf) return Icons.picture_as_pdf_outlined;
    if (d.isDocx) return Icons.description_outlined;
    if (d.isImage) return Icons.image_outlined;
    if (d.availability == DocAvailability.requested) {
      return Icons.hourglass_empty_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  Color _iconBg(DocumentModel d) {
    if (d.isPdf) return AppColors.lightCoral;
    if (d.isDocx) return AppColors.lightBlue;
    if (d.isImage) return AppColors.lightBlue;
    if (d.availability == DocAvailability.requested) return AppColors.lightAmber;
    return AppColors.lightAmber;
  }

  Color _iconColor(DocumentModel d) {
    if (d.isPdf) return AppColors.coral;
    if (d.isDocx) return AppColors.midBlue;
    if (d.isImage) return AppColors.midBlue;
    if (d.availability == DocAvailability.requested) return AppColors.amber;
    return AppColors.amber;
  }

  Color _availColor(DocAvailability av) => switch (av) {
        DocAvailability.enclosed => AppColors.success,
        DocAvailability.requested => AppColors.warning,
        DocAvailability.notAvailable => AppColors.error,
        DocAvailability.tbc => AppColors.textSecondary,
      };

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
