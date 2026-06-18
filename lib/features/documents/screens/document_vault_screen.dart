// lib/features/documents/screens/document_vault_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../../core/utils/robust_downloader.dart';
import '../providers/document_provider.dart';
import '../widgets/document_tile.dart';
import '../widgets/import_options_sheet.dart';
import '../widgets/doc_type_selector_sheet.dart';
import 'extraction_review_screen.dart';
import 'full_extraction_review_screen.dart';
import '../../../core/api/supabase_client.dart';
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
          IconButton(
            icon: const Icon(Icons.playlist_add, color: Colors.white),
            tooltip: 'Log requested document',
            onPressed: () => _showAddRequested(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startImport(context, ref),
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
            ? _EmptyVault(onImport: () => _startImport(context, ref))
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(documentProvider(caseId).notifier).refresh(),
                child: _DocList(
                  docs: docs,
                  caseId: caseId,
                  onImport: () => _startImport(context, ref),
                  onPreview: (doc) => _previewDocument(context, doc),
                  onExtract: (doc) => _reExtractDocument(context, ref, doc),
                ),
              ),
      ),
    );
  }

  // ── Import flow ──────────────────────────────────────────────────────────

  /// Step 1: choose document type, then source.
  Future<void> _startImport(BuildContext context, WidgetRef ref) async {
    final importResult = await showDocTypeSelectorSheet(context);
    if (importResult == null || !context.mounted) return;

    final category     = importResult.category;
    final contextNotes = importResult.contextNotes;

    // Reports (PDF/DOCX only) go straight to the file picker.
    final reportType = category == DocCategory.inspectionReport ||
        category == DocCategory.classReport;

    if (reportType) {
      await _importFromFile(context, ref,
          category: category, contextNotes: contextNotes);
      return;
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ImportOptionsSheet(
        onCamera: () async {
          Navigator.pop(context);
          await _importFromCamera(context, ref, category: category);
        },
        onGallery: () async {
          Navigator.pop(context);
          await _importFromGallery(context, ref, category: category);
        },
        onFile: () async {
          Navigator.pop(context);
          await _importFromFile(context, ref, category: category);
        },
      ),
    );
  }

  Future<void> _importFromCamera(
      BuildContext context, WidgetRef ref,
      {required DocCategory category}) async {
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
      category: category,
    );
  }

  Future<void> _importFromGallery(
      BuildContext context, WidgetRef ref,
      {required DocCategory category}) async {
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
      category: category,
    );
  }

  Future<void> _importFromFile(
      BuildContext context, WidgetRef ref,
      {required DocCategory category, String? contextNotes}) async {
    final reportType = category == DocCategory.inspectionReport ||
        category == DocCategory.classReport;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: reportType
          ? ['pdf', 'docx']
          : ['pdf', 'jpg', 'jpeg', 'png', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    if (!context.mounted) return;

    final ext = file.extension?.toLowerCase() ?? 'pdf';
    final mime = switch (ext) {
      'pdf' => 'application/pdf',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'image/jpeg',
    };

    await _processImport(
      context: context,
      ref: ref,
      bytes: file.bytes!,
      filename: file.name,
      mimeType: mime,
      category: category,
      contextNotes: contextNotes,
    );
  }

  Future<void> _processImport({
    required BuildContext context,
    required WidgetRef ref,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required DocCategory category,
    String? contextNotes,
  }) async {
    final title = await _askTitle(context, filename);
    if (title == null || !context.mounted) return;

    final willExtract = category == DocCategory.certificate ||
        category == DocCategory.inspectionReport ||
        category == DocCategory.classReport;

    DocumentModel? doc;
    try {
      doc = await ref
          .read(documentProvider(caseId).notifier)
          .uploadAndCreate(
            caseId: caseId,
            bytes: bytes,
            filename: filename,
            mimeType: mimeType,
            title: title,
            category: category,
            willExtract: willExtract,
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error));
      }
      return;
    }

    if (!context.mounted) return;

    if (category == DocCategory.inspectionReport ||
        category == DocCategory.classReport) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FullExtractionReviewScreen(
          caseId: caseId,
          doc: doc!,
          bytes: bytes,
          mimeType: mimeType,
          contextNotes: contextNotes,
        ),
      ));
    } else if (category == DocCategory.certificate) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ExtractionReviewScreen(
          caseId: caseId,
          doc: doc!,
          bytes: bytes,
          mimeType: mimeType,
        ),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Document added to vault'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2)));
    }
  }

  Future<String?> _askTitle(BuildContext context, String filename) async {
    final suggested = filename
        .replaceAll(
            RegExp(r'\.(pdf|docx|jpg|jpeg|png)$', caseSensitive: false), '')
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
            hintText: 'e.g. Class Certificate — MV EXAMPLE',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Continue')),
        ],
      ),
    );
  }

  // ── Preview ──────────────────────────────────────────────────────────────

  Future<void> _previewDocument(
      BuildContext context, DocumentModel doc) async {
    if (!doc.hasFile || doc.filePath == null) return;

    String signedUrl;
    try {
      signedUrl = await SupabaseService.client.storage
          .from('documents')
          .createSignedUrl(doc.filePath!, 3600);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Cannot open document: $e'),
            backgroundColor: AppColors.error));
      }
      return;
    }

    if (!context.mounted) return;

    if (doc.isImage) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _ImagePreviewScreen(
          title: doc.title,
          imageUrl: signedUrl,
        ),
      ));
    } else if (doc.isPdf) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _PdfViewerScreen(
          title: doc.title,
          url: signedUrl,
        ),
      ));
    } else {
      // DOCX and other formats — open externally
      final uri = Uri.parse(signedUrl);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open document')));
      }
    }
  }

  // ── Manual re-extraction ─────────────────────────────────────────────────

  Future<void> _reExtractDocument(
      BuildContext context, WidgetRef ref, DocumentModel doc) async {
    if (doc.filePath == null) return;

    // Get a fresh signed URL — goes straight to the CDN and supports
    // HTTP Range requests, which the raw Supabase API gateway may not.
    String signedUrl;
    try {
      signedUrl = await SupabaseService.client.storage
          .from('documents')
          .createSignedUrl(doc.filePath!, 3600);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Cannot access document: $e'),
            backgroundColor: AppColors.error));
      }
      return;
    }

    final progressNotifier = ValueNotifier<(int, int)>((0, 0));

    if (!context.mounted) {
      progressNotifier.dispose();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ValueListenableBuilder<(int, int)>(
        valueListenable: progressNotifier,
        builder: (_, prog, __) {
          final frac = prog.$2 > 0 ? (prog.$1 / prog.$2).clamp(0.0, 1.0) : null;
          return Center(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(
                      value: frac, color: AppColors.amber),
                  const SizedBox(height: 14),
                  Text(
                    prog.$2 > 0
                        ? 'Downloading… '
                          '${(prog.$1 / 1024).toStringAsFixed(0)} / '
                          '${(prog.$2 / 1024).toStringAsFixed(0)} KB'
                        : 'Downloading document…',
                    style: const TextStyle(fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  if (frac != null) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: frac,
                      backgroundColor: AppColors.border,
                      color: AppColors.amber,
                      minHeight: 4,
                    ),
                  ],
                ]),
              ),
            ),
          );
        },
      ),
    );

    Uint8List bytes;
    try {
      bytes = await RobustDownloader.download(
        signedUrl,
        onProgress: (received, total) =>
            progressNotifier.value = (received, total),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Download failed after retries: $e'),
            backgroundColor: AppColors.error));
      }
      progressNotifier.dispose();
      return;
    }

    if (!context.mounted) {
      progressNotifier.dispose();
      return;
    }
    Navigator.pop(context);
    progressNotifier.dispose();

    final ext = doc.fileType?.toLowerCase() ?? 'pdf';
    final mimeType = switch (ext) {
      'pdf'           => 'application/pdf',
      'docx'          => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png'           => 'image/png',
      _               => 'application/octet-stream',
    };

    final isReport = doc.docCategory == DocCategory.inspectionReport ||
        doc.docCategory == DocCategory.classReport;

    if (isReport) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FullExtractionReviewScreen(
          caseId: caseId,
          doc: doc,
          bytes: bytes,
          mimeType: mimeType,
        ),
      ));
    } else {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ExtractionReviewScreen(
          caseId: caseId,
          doc: doc,
          bytes: bytes,
          mimeType: mimeType,
        ),
      ));
    }

    ref.read(documentProvider(caseId).notifier).refresh();
  }

  // ── Log requested doc ────────────────────────────────────────────────────

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
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
              child: const Text('Cancel')),
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

// ── Document list ──────────────────────────────────────────────────────────

class _DocList extends StatelessWidget {
  const _DocList({
    required this.docs,
    required this.caseId,
    required this.onImport,
    required this.onPreview,
    required this.onExtract,
  });
  final List<DocumentModel> docs;
  final String caseId;
  final VoidCallback onImport;
  final void Function(DocumentModel) onPreview;
  final void Function(DocumentModel) onExtract;

  @override
  Widget build(BuildContext context) {
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
          ...entry.value.map((doc) {
            final canExtract = doc.hasFile &&
                !doc.aiExtracted &&
                doc.extractionStatus != null &&
                doc.extractionStatus != 'not_applicable';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: DocumentTile(
                doc: doc,
                onPreview: doc.hasFile ? () => onPreview(doc) : null,
                onExtract: canExtract ? () => onExtract(doc) : null,
              ),
            );
          }),
          const SizedBox(height: 12),
        ],
      ],
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
        width: 3,
        height: 14,
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

// ── Empty state ────────────────────────────────────────────────────────────

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
            'Import certificates, reports, service docs\nor other supporting documents.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
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

// ── PDF viewer ─────────────────────────────────────────────────────────────

class _PdfViewerScreen extends StatelessWidget {
  const _PdfViewerScreen({required this.title, required this.url});
  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
      ),
      body: PdfViewer.uri(
        Uri.parse(url),
        params: const PdfViewerParams(
          backgroundColor: Color(0xFFE0E0E0),
        ),
      ),
    );
  }
}

// ── Image preview ──────────────────────────────────────────────────────────

class _ImagePreviewScreen extends StatelessWidget {
  const _ImagePreviewScreen({required this.title, required this.imageUrl});
  final String title;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis),
      ),
      body: PhotoView(
        imageProvider: NetworkImage(imageUrl),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (_, __) => const Center(
          child: CircularProgressIndicator(color: AppColors.amber),
        ),
        errorBuilder: (_, __, ___) => const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.broken_image_outlined,
                color: Colors.white54, size: 48),
            SizedBox(height: 12),
            Text('Could not load image',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}
