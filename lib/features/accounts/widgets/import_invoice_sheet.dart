import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/accounts_models.dart';
import '../providers/accounts_provider.dart';
import '../../../core/api/claude_api.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/utils/document_warp.dart';
import '../../../shared/theme/app_theme.dart';

const _kAccent = Color(0xFF2E7D32);
const _kBatch  = Color(0xFF1A5276);

class ImportInvoiceSheet extends ConsumerStatefulWidget {
  const ImportInvoiceSheet({
    super.key,
    required this.caseId,
    required this.onImported,
  });
  final String caseId;
  final void Function(List<RepairDocumentModel> docs) onImported;

  @override
  ConsumerState<ImportInvoiceSheet> createState() => _ImportInvoiceSheetState();
}

class _ImportInvoiceSheetState extends ConsumerState<ImportInvoiceSheet> {
  _Step _step = _Step.pick;
  bool _batchMode = false;
  String? _filename;
  List<int>? _bytes;
  String _mimeType = 'application/pdf';
  String? _error;
  bool _busy = false;
  String? _busyLabel;

  // batch review
  List<BatchInvoiceSegment> _segments = [];
  String? _uploadedPath;   // storage path after upload

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _step == _Step.review ? 0.92 : 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            _handle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  const Text('Import Document',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_step == _Step.pick)
                    _ModeToggle(
                      batch: _batchMode,
                      onToggle: (v) => setState(() => _batchMode = v),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [_body()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _body() => switch (_step) {
        _Step.pick   => _pickView(),
        _Step.ready  => _readyView(),
        _Step.review => _reviewView(),
        _Step.done   => const SizedBox.shrink(),
      };

  // ── Pick ──────────────────────────────────────────────────────────────────

  Widget _pickView() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_batchMode)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _kBatch.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBatch.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome_outlined,
                      color: _kBatch, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Batch mode — AI will identify individual invoices '
                      'within the PDF and let you review before importing.',
                      style: TextStyle(
                          color: _kBatch, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          GestureDetector(
            onTap: _pick,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36),
              decoration: BoxDecoration(
                color: (_batchMode ? _kBatch : _kAccent).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: (_batchMode ? _kBatch : _kAccent).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.upload_file_outlined,
                      size: 48,
                      color: (_batchMode ? _kBatch : _kAccent)
                          .withValues(alpha: 0.7)),
                  const SizedBox(height: 12),
                  Text('Tap to select PDF',
                      style: TextStyle(
                          color: _batchMode ? _kBatch : _kAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('PDF, JPG or PNG',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ],
      );

  // ── Ready ─────────────────────────────────────────────────────────────────

  Widget _readyView() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fileChip(),
          const SizedBox(height: 12),
          Text(
            _batchMode
                ? 'AI will scan the PDF for multiple invoices. '
                  'You will review and confirm each one before saving.'
                : 'The document will be saved. '
                  'Run AI extraction from the document screen afterwards.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          if (_busy) _progressRow() else _actionButton(),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ],
      );

  Widget _fileChip() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file_outlined,
                color: Colors.red, size: 26),
            const SizedBox(width: 10),
            Expanded(
                child: Text(_filename ?? '',
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13))),
            if (!_busy)
              IconButton(
                icon: const Icon(Icons.close,
                    color: AppColors.textSecondary, size: 18),
                onPressed: () => setState(() {
                  _step = _Step.pick;
                  _bytes = null;
                  _filename = null;
                }),
              ),
          ],
        ),
      );

  Widget _progressRow() => Row(
        children: [
          const SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: _kBatch),
          ),
          const SizedBox(width: 12),
          Text(_busyLabel ?? 'Working…',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      );

  Widget _actionButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _batchMode ? _kBatch : _kAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          icon: Icon(_batchMode
              ? Icons.auto_awesome_outlined
              : Icons.cloud_upload_outlined),
          label: Text(_batchMode ? 'Analyse PDF' : 'Save Document'),
          onPressed: _batchMode ? _analyseBatch : _uploadSingle,
        ),
      );

  // ── Review (batch) ────────────────────────────────────────────────────────

  Widget _reviewView() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fileChip(),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${_segments.length} documents identified',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const Spacer(),
              Text(
                '${_segments.where((s) => s.submittedToInsurance).length} submitted  '
                '·  ${_segments.where((s) => !s.submittedToInsurance).length} context',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Review AI\'s assessment. Toggle "Submitted" / "Context" for each item.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          ..._segments.asMap().entries.map((e) =>
              _SegmentTile(
                seg: e.value,
                onToggle: (v) =>
                    setState(() => _segments[e.key].submittedToInsurance = v),
              )),
          const SizedBox(height: 20),
          if (_busy) _progressRow() else _confirmButton(),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ],
      );

  Widget _confirmButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _kAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.save_outlined),
          label: Text('Import ${_segments.length} Documents'),
          onPressed: _confirmBatch,
        ),
      );

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _pick() async {
    setState(() => _error = null);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) {
      setState(() => _error = 'Could not read file.');
      return;
    }
    final ext = (file.extension ?? 'pdf').toLowerCase();
    _mimeType = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png'           => 'image/png',
      _               => 'application/pdf',
    };
    setState(() {
      _bytes    = file.bytes!;
      _filename = file.name;
      _step     = _Step.ready;
    });
  }

  Future<void> _uploadSingle() async {
    if (_bytes == null) return;
    debugPrint('[Accounts] uploadSingle start — file: $_filename  mime: $_mimeType  size: ${_bytes!.length}');
    setState(() { _busy = true; _error = null; _busyLabel = 'Uploading…'; });
    try {
      Uint8List? thumbnailBytes;
      String? displayName;
      if (_mimeType.startsWith('image/')) {
        thumbnailBytes = await _perspectiveCorrect();
        // Extract title from corrected scan (or original if warp failed)
        final titleSource = thumbnailBytes ?? Uint8List.fromList(_bytes!);
        final titleMime   = thumbnailBytes != null ? 'image/png' : _mimeType;
        displayName = await _autoExtractTitle(titleSource, titleMime);
      }
      setState(() => _busyLabel = 'Uploading…');
      debugPrint('[Accounts] calling importPdf…');
      final doc = await ref
          .read(repairDocumentsProvider(widget.caseId).notifier)
          .importPdf(
            bytes: _bytes!,
            filename: _filename ?? 'document.pdf',
            mimeType: _mimeType,
            thumbnailBytes: thumbnailBytes,
            displayName: displayName,
          );
      debugPrint('[Accounts] importPdf success — id: ${doc.id}  name: ${doc.displayName}');
      widget.onImported([doc]);
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      debugPrint('[Accounts] uploadSingle ERROR: $e\n$st');
      if (mounted) setState(() { _busy = false; _error = 'Upload failed: $e'; });
    }
  }

  /// Quick invoice title extraction for auto-naming an imported image.
  /// Returns "InvoiceNo — Supplier — DD/MM/YYYY" or null on failure.
  Future<String?> _autoExtractTitle(Uint8List bytes, String mediaType) async {
    try {
      if (mounted) setState(() => _busyLabel = 'Reading document details…');
      final b64 = base64Encode(bytes);
      final extracted = await ClaudeApi.extractInvoiceData(
        base64Content: b64,
        mediaType: mediaType,
      );
      final docNumber = extracted['document_number'] as String?;
      final supplier  = extracted['supplier_name']   as String?;
      final rawDate   = extracted['document_date']   as String?;
      final docDate   = rawDate != null ? DateTime.tryParse(rawDate) : null;
      final parts = [
        if (docNumber?.isNotEmpty == true) docNumber!,
        if (supplier?.isNotEmpty  == true) supplier!,
        if (docDate != null)
          '${docDate.day.toString().padLeft(2, '0')}/'
          '${docDate.month.toString().padLeft(2, '0')}/'
          '${docDate.year}',
      ];
      return parts.isNotEmpty ? parts.join(' — ') : null;
    } catch (e) {
      debugPrint('[Accounts] autoExtractTitle failed (will use filename): $e');
      return null;
    }
  }

  /// Detects the four corners of a document in the image, then applies a
  /// perspective warp to produce a flat rectangular scan as a PNG.
  /// Returns null if no document was detected (caller uses original image).
  Future<Uint8List?> _perspectiveCorrect() async {
    try {
      final b64 = base64Encode(_bytes!);
      if (mounted) setState(() => _busyLabel = 'Detecting document corners…');

      final rawCorners = await ClaudeApi.detectDocumentCorners(
        base64Image: b64,
        mediaType: _mimeType,
      );
      if (rawCorners == null || rawCorners.length != 4) return null;

      if (mounted) setState(() => _busyLabel = 'Applying perspective correction…');

      final codec = await ui.instantiateImageCodec(Uint8List.fromList(_bytes!));
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;
      codec.dispose();

      final corners = rawCorners
          .map((xy) => Offset(
                xy[0] * srcImage.width,
                xy[1] * srcImage.height,
              ))
          .toList();

      final result = await DocumentWarp.warp(
        srcImage: srcImage,
        srcCorners: corners,
      );
      srcImage.dispose();
      return result;
    } catch (e) {
      debugPrint('[Accounts] perspectiveCorrect failed (will use original): $e');
      return null;
    }
  }

  Future<void> _analyseBatch() async {
    if (_bytes == null) return;
    debugPrint('[Accounts] analyseBatch start — file: $_filename  size: ${_bytes!.length}');
    setState(() {
      _busy = true; _error = null;
      _busyLabel = 'Uploading PDF…';
    });
    try {
      final storagePath =
          '${widget.caseId}/accounts/${DateTime.now().millisecondsSinceEpoch}_$_filename';
      debugPrint('[Accounts] uploading to storage: $storagePath');
      await SupabaseService.uploadFile(
        bucket: 'documents',
        path: storagePath,
        bytes: _bytes!,
        mimeType: _mimeType,
      );
      _uploadedPath = storagePath;
      debugPrint('[Accounts] upload OK — analysing with Claude…');

      setState(() => _busyLabel = 'Analysing with AI — this may take a minute…');

      final base64Content = base64Encode(_bytes!);
      debugPrint('[Accounts] base64 length: ${base64Content.length}');
      final rawSegments = await ClaudeApi.analyzeMultiInvoicePdf(
        base64Content: base64Content,
        mediaType: _mimeType,
      );
      debugPrint('[Accounts] Claude returned ${rawSegments.length} segments');

      _segments = rawSegments
          .asMap()
          .entries
          .map((e) => BatchInvoiceSegment.fromJson(e.value, e.key))
          .toList();
      debugPrint('[Accounts] segments parsed: ${_segments.map((s) => s.displayLabel).join(", ")}');

      setState(() { _busy = false; _step = _Step.review; });
    } catch (e, st) {
      debugPrint('[Accounts] analyseBatch ERROR: $e\n$st');
      if (mounted) setState(() { _busy = false; _error = 'Analysis failed: $e'; });
    }
  }

  Future<void> _confirmBatch() async {
    if (_uploadedPath == null) return;
    setState(() { _busy = true; _busyLabel = 'Saving records…'; _error = null; });
    try {
      final docs = await ref
          .read(repairDocumentsProvider(widget.caseId).notifier)
          .importBatchSegments(
            storagePath: _uploadedPath!,
            segments: _segments,
          );
      widget.onImported(docs);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = 'Save failed: $e'; });
    }
  }
}

// ── Mode toggle ────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.batch, required this.onToggle});
  final bool batch;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onToggle(!batch),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: batch
                ? _kBatch.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: batch
                    ? _kBatch.withValues(alpha: 0.5)
                    : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.layers_outlined,
                  size: 14,
                  color: batch ? _kBatch : AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('Batch',
                  style: TextStyle(
                      fontSize: 12,
                      color: batch ? _kBatch : AppColors.textSecondary,
                      fontWeight:
                          batch ? FontWeight.w600 : FontWeight.normal)),
            ],
          ),
        ),
      );
}

// ── Segment tile (review step) ─────────────────────────────────────────────

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({required this.seg, required this.onToggle});
  final BatchInvoiceSegment seg;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final submitted = seg.submittedToInsurance;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: submitted
            ? AppColors.background
            : AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: submitted
              ? _kAccent.withValues(alpha: 0.3)
              : AppColors.border.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(seg.displayLabel,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
                _SubmissionToggle(
                    submitted: submitted, onToggle: onToggle),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                _Chip('pp. ${seg.pageStart}–${seg.pageEnd}',
                    AppColors.textSecondary),
                if (seg.date != null) _Chip(seg.date!, AppColors.textSecondary),
                if (seg.totalAmount != null)
                  _Chip(
                    '${seg.currency ?? ''} ${seg.totalAmount!.toStringAsFixed(0)}',
                    submitted ? _kAccent : AppColors.textSecondary,
                  ),
              ],
            ),
            if (seg.reason != null) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(seg.reason!,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubmissionToggle extends StatelessWidget {
  const _SubmissionToggle(
      {required this.submitted, required this.onToggle});
  final bool submitted;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Pill(
            label: 'Submitted',
            active: submitted,
            activeColor: _kAccent,
            onTap: () => onToggle(true),
          ),
          const SizedBox(width: 4),
          _Pill(
            label: 'Context',
            active: !submitted,
            activeColor: Colors.blueGrey,
            onTap: () => onToggle(false),
          ),
        ],
      );
}

class _Pill extends StatelessWidget {
  const _Pill(
      {required this.label,
      required this.active,
      required this.activeColor,
      required this.onTap});
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: active
                    ? activeColor.withValues(alpha: 0.6)
                    : AppColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: active ? activeColor : AppColors.textSecondary,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal)),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontSize: 11)),
      );
}

enum _Step { pick, ready, review, done }
