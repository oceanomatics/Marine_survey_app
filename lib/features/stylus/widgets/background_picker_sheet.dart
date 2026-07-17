// lib/features/stylus/widgets/background_picker_sheet.dart
//
// Bottom sheet for choosing the stylus backdrop: a blank paper style, one of
// the case photos, or a page/region rendered from a Doc Vault document.
// Returns the chosen [StylusBackground] via Navigator.pop.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/api/supabase_client.dart';
import '../../../core/services/drive_storage_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../documents/providers/document_provider.dart';
import '../../photos/models/photo_model.dart';
import '../../photos/providers/photo_provider.dart';
import 'stylus_models.dart';

/// Opens the backdrop picker. Resolves to the chosen [StylusBackground], or
/// null if the sheet was dismissed without a selection.
Future<StylusBackground?> showBackgroundPicker(
  BuildContext context,
  String caseId,
) {
  return showModalBottomSheet<StylusBackground>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BackgroundPickerSheet(caseId: caseId),
  );
}

class _BackgroundPickerSheet extends ConsumerStatefulWidget {
  const _BackgroundPickerSheet({required this.caseId});
  final String caseId;

  @override
  ConsumerState<_BackgroundPickerSheet> createState() =>
      _BackgroundPickerSheetState();
}

class _BackgroundPickerSheetState
    extends ConsumerState<_BackgroundPickerSheet> {
  int _tab = 0; // 0 blank · 1 photo · 2 document
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Choose Background',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ),
              ),
              const SizedBox(height: 12),
              _segmented(),
              const Divider(height: 1),
              if (_busy) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: switch (_tab) {
                  0 => _blankTab(),
                  1 => _photoTab(scrollController),
                  _ => _documentTab(scrollController),
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _segmented() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          for (final (i, mode) in StylusBackgroundMode.values.indexed)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
                child: ChoiceChip(
                  label: Text(mode.label),
                  selected: _tab == i,
                  onSelected: _busy ? null : (_) => setState(() => _tab = i),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Blank ────────────────────────────────────────────────────────────────

  Widget _blankTab() {
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.8,
      children: [
        for (final paper in BlankPaper.values)
          InkWell(
            onTap: () =>
                Navigator.of(context).pop(StylusBackground.blank(paper)),
            borderRadius: BorderRadius.circular(10),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: CustomPaint(
                      painter: BlankPaperPainter(paper: paper, spacing: 12),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(paper.label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
      ],
    );
  }

  // ── Photos ───────────────────────────────────────────────────────────────

  Widget _photoTab(ScrollController controller) {
    final photos = (ref.watch(photosProvider(widget.caseId)).value ?? [])
        .where((p) => p.hasUsablePhoto)
        .toList();
    if (photos.isEmpty) {
      return _empty('No case photos yet', Icons.photo_library_outlined);
    }
    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: photos.length,
      itemBuilder: (context, i) {
        final photo = photos[i];
        return InkWell(
          onTap: _busy ? null : () => _pickPhoto(photo),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _thumb(photo),
          ),
        );
      },
    );
  }

  Widget _thumb(PhotoModel photo) {
    if (!kIsWeb && photo.hasLocalFile) {
      return Image.file(File(photo.thumbnailPath ?? photo.localPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _thumbFallback());
    }
    final id = photo.thumbnailDriveFileId ?? photo.driveFileId;
    if (id == null) return _thumbFallback();
    return FutureBuilder<Uint8List>(
      future: DriveStorageService.downloadFile(id),
      builder: (_, snap) => snap.hasData
          ? Image.memory(snap.data!, fit: BoxFit.cover)
          : Container(color: AppColors.surface),
    );
  }

  Widget _thumbFallback() => Container(
      color: AppColors.surface,
      child: const Icon(Icons.broken_image_outlined,
          color: AppColors.textTertiary));

  Future<void> _pickPhoto(PhotoModel photo) async {
    setState(() => _busy = true);
    try {
      final bytes = await _loadPhotoBytes(photo);
      if (bytes == null) {
        _fail('Could not load that photo');
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop(StylusBackground(
        mode: StylusBackgroundMode.photo,
        imageBytes: bytes,
        sourceLabel: photo.caption ?? 'Case photo',
      ));
    } catch (e) {
      _fail('Could not load that photo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Uint8List?> _loadPhotoBytes(PhotoModel photo) async {
    // Prefer the full-resolution copy for a crisp drawing backdrop.
    if (!kIsWeb && photo.hasLocalFile) {
      try {
        return await File(photo.localPath!).readAsBytes();
      } catch (_) {/* fall through to Drive */}
    }
    final id = photo.driveFileId ?? photo.thumbnailDriveFileId;
    if (id == null) return null;
    return DriveStorageService.downloadFile(id);
  }

  // ── Documents ────────────────────────────────────────────────────────────

  Widget _documentTab(ScrollController controller) {
    final docs = (ref.watch(documentProvider(widget.caseId)).value ?? [])
        .where((d) => d.hasFile && (d.isPdf || d.isImage))
        .toList();
    if (docs.isEmpty) {
      return _empty(
          'No image / PDF documents in the vault', Icons.description_outlined);
    }
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.all(12),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final doc = docs[i];
        return ListTile(
          leading: Icon(doc.isPdf ? Icons.picture_as_pdf : Icons.image,
              color: AppColors.purple),
          title: Text(doc.title,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(doc.isPdf ? 'PDF — tap to choose a page' : 'Image',
              style: const TextStyle(fontSize: 12)),
          onTap: _busy ? null : () => _pickDocument(doc),
        );
      },
    );
  }

  Future<void> _pickDocument(DocumentModel doc) async {
    setState(() => _busy = true);
    try {
      final raw = await SupabaseService.client.storage
          .from('documents')
          .download(doc.filePath!);
      if (doc.isImage) {
        if (!mounted) return;
        Navigator.of(context).pop(StylusBackground(
          mode: StylusBackgroundMode.document,
          imageBytes: raw,
          sourceLabel: doc.title,
        ));
        return;
      }
      // PDF — render the chosen page to an image backdrop.
      final bytes = await _renderPdfPage(raw, doc.title);
      if (bytes == null) {
        if (mounted) setState(() => _busy = false);
        return; // cancelled or failed (already messaged)
      }
      if (!mounted) return;
      Navigator.of(context).pop(StylusBackground(
        mode: StylusBackgroundMode.document,
        imageBytes: bytes,
        sourceLabel: doc.title,
      ));
    } catch (e) {
      _fail('Could not load that document: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Opens [data] as a PDF, lets the surveyor pick a page, and rasterises it.
  Future<Uint8List?> _renderPdfPage(Uint8List data, String title) async {
    PdfDocument? document;
    try {
      document = await PdfDocument.openData(data, sourceName: title);
      final pageCount = document.pages.length;
      int pageNo = 1;
      if (pageCount > 1) {
        final picked = await _promptPage(pageCount);
        if (picked == null) return null; // cancelled
        pageNo = picked;
      }
      final page = document.pages[pageNo - 1];
      // Render at ~2x for a sharp backdrop without exploding memory.
      const scale = 2.0;
      final pdfImage = await page.render(
        fullWidth: page.width * scale,
        fullHeight: page.height * scale,
        backgroundColor: Colors.white,
      );
      if (pdfImage == null) return null;
      try {
        final uiImage = await pdfImage.createImage();
        return await encodeImagePng(uiImage);
      } finally {
        pdfImage.dispose();
      }
    } catch (e) {
      debugPrint('[Stylus] PDF render failed: $e');
      _fail('Could not render that PDF page');
      return null;
    } finally {
      await document?.dispose();
    }
  }

  Future<int?> _promptPage(int pageCount) {
    int selected = 1;
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose page'),
        content: StatefulBuilder(
          builder: (context, setInner) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Page'),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: selected,
                items: [
                  for (var p = 1; p <= pageCount; p++)
                    DropdownMenuItem(value: p, child: Text('$p of $pageCount')),
                ],
                onChanged: (v) => setInner(() => selected = v ?? 1),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: const Text('Use page')),
        ],
      ),
    );
  }

  // ── Shared ───────────────────────────────────────────────────────────────

  Widget _empty(String message, IconData icon) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textTertiary),
            const SizedBox(height: 10),
            Text(message,
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );

  void _fail(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
