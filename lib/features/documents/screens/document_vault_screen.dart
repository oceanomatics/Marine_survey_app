// lib/features/documents/screens/document_vault_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/document_provider.dart';
import '../widgets/document_tile.dart';
import '../widgets/import_options_sheet.dart';
import 'extraction_review_screen.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';

class DocumentVaultScreen extends ConsumerWidget {
  const DocumentVaultScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentProvider(caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Document Vault'),
        actions: [
          // Add requested item (no file)
          IconButton(
            icon: const Icon(Icons.playlist_add, color: Colors.white),
            tooltip: 'Log requested document',
            onPressed: () => _showAddRequested(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showImportOptions(context, ref),
        backgroundColor: AppColors.amber,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Import Document',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: docsAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading documents...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (docs) => docs.isEmpty
            ? _EmptyVault(onImport: () => _showImportOptions(context, ref))
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(documentProvider(caseId).notifier).refresh(),
                child: _DocList(
                  docs: docs,
                  caseId: caseId,
                  onImport: () => _showImportOptions(context, ref),
                ),
              ),
      ),
    );
  }

  void _showImportOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ImportOptionsSheet(
        onCamera: () async {
          Navigator.pop(context);
          await _importFromCamera(context, ref);
        },
        onGallery: () async {
          Navigator.pop(context);
          await _importFromGallery(context, ref);
        },
        onFile: () async {
          Navigator.pop(context);
          await _importFromFile(context, ref);
        },
      ),
    );
  }

  Future<void> _importFromCamera(
      BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 2048,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!context.mounted) return;
    await _processImport(
      context: context,
      ref: ref,
      bytes: bytes,
      filename: picked.name,
      mimeType: 'image/jpeg',
    );
  }

  Future<void> _importFromGallery(
      BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!context.mounted) return;
    await _processImport(
      context: context,
      ref: ref,
      bytes: bytes,
      filename: picked.name,
      mimeType: 'image/jpeg',
    );
  }

  Future<void> _importFromFile(
      BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    if (!context.mounted) return;

    final ext = file.extension?.toLowerCase() ?? 'pdf';
    final mime = ext == 'pdf' ? 'application/pdf' : 'image/jpeg';

    await _processImport(
      context: context,
      ref: ref,
      bytes: file.bytes!,
      filename: file.name,
      mimeType: mime,
    );
  }

  Future<void> _processImport({
    required BuildContext context,
    required WidgetRef ref,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    // Show title dialog first
    final title = await _askTitle(context, filename);
    if (title == null || !context.mounted) return;

    // Upload the file and create doc record
    DocumentModel? doc;
    try {
      doc = await ref.read(documentProvider(caseId).notifier).uploadAndCreate(
            caseId: caseId,
            bytes: bytes,
            filename: filename,
            mimeType: mimeType,
            title: title,
            category: DocCategory.certificate,
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'),
              backgroundColor: AppColors.error),
        );
      }
      return;
    }

    // Navigate to extraction review
    if (context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExtractionReviewScreen(
            caseId: caseId,
            doc: doc!,
            bytes: bytes,
            mimeType: mimeType,
          ),
        ),
      );
    }
  }

  Future<String?> _askTitle(BuildContext context, String filename) async {
    // Suggest a clean title from filename
    final suggested = filename
        .replaceAll(RegExp(r'\.(pdf|jpg|jpeg|png)$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[_\-]'), ' ')
        .trim();

    final ctrl = TextEditingController(text: suggested);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Document title',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Class Certificate — MINRES ODIN',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showAddRequested(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log requested document',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Record a document you have requested\nbut not yet received.',
              style:
                  TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. Bridge logbook extract — 17/08/2025',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = ctrl.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(ctx);
              await ref
                  .read(documentProvider(caseId).notifier)
                  .addRecord(
                    caseId: caseId,
                    title: title,
                    availability: DocAvailability.requested,
                  );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ── Document list ─────────────────────────────────────────────────────────

class _DocList extends StatelessWidget {
  const _DocList(
      {required this.docs, required this.caseId, required this.onImport});
  final List<DocumentModel> docs;
  final String caseId;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    // Group by category
    final grouped = <DocCategory, List<DocumentModel>>{};
    for (final doc in docs) {
      final cat = doc.docCategory ?? DocCategory.other;
      grouped.putIfAbsent(cat, () => []).add(doc);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      children: [
        for (final entry in grouped.entries) ...[
          _CategoryHeader(entry.key),
          const SizedBox(height: 6),
          ...entry.value.map((doc) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: DocumentTile(
                  doc: doc,
                  onDelete: (docId) =>
                      _confirmDelete(context, docId),
                ),
              )),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
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
            onPressed: () {
              Navigator.pop(ctx);
              // Provider access via consumer — handled in DocumentTile
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader(this.category);
  final DocCategory category;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 3, height: 14,
        decoration: BoxDecoration(
          color: AppColors.amber,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        category.label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    ]);
  }
}

// ── Empty state ───────────────────────────────────────────────────────────

class _EmptyVault extends StatelessWidget {
  const _EmptyVault({required this.onImport});
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.folder_open_outlined,
              size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          const Text('No documents yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text(
            'Import a certificate, PDF or photo\nto extract vessel data automatically',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Import first document'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: Colors.white),
          ),
        ]),
      ),
    );
  }
}
