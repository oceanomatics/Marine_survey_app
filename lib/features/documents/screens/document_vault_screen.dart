// lib/features/documents/screens/document_vault_screen.dart

import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/supabase_client.dart';
import '../../../features/cases/providers/cases_provider.dart';
import '../../../features/survey/providers/damage_provider.dart';
import '../../../features/surveyor_notes/models/surveyor_note_model.dart';
import '../../../features/surveyor_notes/providers/surveyor_notes_provider.dart';
import '../../../features/vessel/providers/vessel_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../providers/document_provider.dart';
import '../widgets/document_tile.dart';

const _kColor = AppColors.amber;

// ── Connectivity provider ──────────────────────────────────────────────────

final _isOnlineProvider = StreamProvider<bool>((ref) => Connectivity()
    .onConnectivityChanged
    .map((r) => !r.contains(ConnectivityResult.none)));

// ── Screen ─────────────────────────────────────────────────────────────────

class DocumentVaultScreen extends ConsumerWidget {
  const DocumentVaultScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentProvider(caseId));
    final isOnline = ref.watch(_isOnlineProvider).value ?? true;

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
        backgroundColor: _kColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Import',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: docsAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading documents…'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (docs) => docs.isEmpty
            ? _EmptyVault(onImport: () => _startImport(context, ref))
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(documentProvider(caseId).notifier).refresh(),
                child: _DocList(
                  docs: docs,
                  caseId: caseId,
                  isOnline: isOnline,
                  onImport: () => _startImport(context, ref),
                  onPreview: (doc) => _previewDocument(context, doc),
                  onExtract: (doc) => _runExtraction(context, ref, doc),
                ),
              ),
      ),
    );
  }

  // ── Import ─────────────────────────────────────────────────────────────

  Future<void> _startImport(BuildContext context, WidgetRef ref) async {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: _srcIcon(Icons.insert_drive_file_outlined),
            title: const Text('Choose file',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('PDF, image or DOCX'),
            onTap: () async {
              Navigator.pop(ctx);
              await _pickFile(context, ref);
            },
          ),
          ListTile(
            leading: _srcIcon(Icons.camera_alt_outlined),
            title: const Text('Take photo',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Camera'),
            onTap: () async {
              Navigator.pop(ctx);
              await _pickCamera(context, ref);
            },
          ),
          ListTile(
            leading: _srcIcon(Icons.photo_library_outlined),
            title: const Text('From gallery',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Photo library'),
            onTap: () async {
              Navigator.pop(ctx);
              await _pickGallery(context, ref);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _srcIcon(IconData icon) => Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: _kColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _kColor, size: 22),
      );

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.bytes == null || !context.mounted) return;
    final ext = f.extension?.toLowerCase() ?? 'pdf';
    final mime = _mimeFrom(ext);
    await _showImportSheet(context, ref,
        bytes: f.bytes!, filename: f.name, mimeType: mime);
  }

  Future<void> _pickCamera(BuildContext context, WidgetRef ref) async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 90, maxWidth: 2048);
    if (picked == null || !context.mounted) return;
    final bytes = await picked.readAsBytes();
    if (!context.mounted) return;
    await _showImportSheet(context, ref,
        bytes: bytes, filename: picked.name, mimeType: 'image/jpeg');
  }

  Future<void> _pickGallery(BuildContext context, WidgetRef ref) async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null || !context.mounted) return;
    final bytes = await picked.readAsBytes();
    if (!context.mounted) return;
    await _showImportSheet(context, ref,
        bytes: bytes, filename: picked.name, mimeType: 'image/jpeg');
  }

  Future<void> _showImportSheet(
    BuildContext context,
    WidgetRef ref, {
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DocImportSheet(
        caseId: caseId,
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
      ),
    );
  }

  // ── AI Extraction ───────────────────────────────────────────────────────

  Future<void> _runExtraction(
      BuildContext context, WidgetRef ref, DocumentModel doc) async {
    final result = await ref
        .read(documentProvider(caseId).notifier)
        .extract(doc.docId);

    if (result == null || !context.mounted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Extraction failed — check connectivity and retry'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (!result.hasAny) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data extracted from this document')),
        );
        await ref.read(documentProvider(caseId).notifier)
            .saveExtracted(doc.docId, {});
      }
      return;
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExtractionResultSheet(
        caseId: caseId,
        docTitle: doc.title,
        result: result,
      ),
    );
  }

  // ── Preview ─────────────────────────────────────────────────────────────

  Future<void> _previewDocument(
      BuildContext context, DocumentModel doc) async {
    if (!doc.hasFile || doc.filePath == null) return;

    String signedUrl;
    try {
      signedUrl = await SupabaseService.client.storage
          .from('documents')
          .createSignedUrl(doc.filePath!, 3600);
    } catch (e, st) {
      if (context.mounted) {
        showError(context, 'Cannot open document: $e',
            error: e, stack: st, tag: 'Document');
      }
      return;
    }
    if (!context.mounted) return;

    if (doc.isImage) {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              _ImagePreviewScreen(title: doc.title, imageUrl: signedUrl)));
    } else if (doc.isPdf) {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              _PdfViewerScreen(title: doc.title, url: signedUrl)));
    } else {
      final uri = Uri.parse(signedUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open document')));
      }
    }
  }

  // ── Log requested ───────────────────────────────────────────────────────

  void _showAddRequested(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log requested document',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Record a document you have requested but not yet received.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
                hintText: 'e.g. Bridge logbook extract — 17/08/2025'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final title = ctrl.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(ctx);
              await ref.read(documentProvider(caseId).notifier).addRecord(
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

// ── Import sheet ───────────────────────────────────────────────────────────

class _DocImportSheet extends ConsumerStatefulWidget {
  const _DocImportSheet({
    required this.caseId,
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });
  final String caseId;
  final Uint8List bytes;
  final String filename;
  final String mimeType;

  @override
  ConsumerState<_DocImportSheet> createState() => _DocImportSheetState();
}

class _DocImportSheetState extends ConsumerState<_DocImportSheet> {
  DocCategory _category = DocCategory.other;
  late final TextEditingController _titleCtrl;
  bool _saving = false;

  static const _importable = [
    DocCategory.certificate,
    DocCategory.classSurveyReport,
    DocCategory.conditionOfClass,
    DocCategory.previousSurveyReport,
    DocCategory.inspectionReport,
    DocCategory.serviceReport,
    DocCategory.logbookExtract,
    DocCategory.maintenanceRecord,
    DocCategory.statementOfFacts,
    DocCategory.incidentReport,
    DocCategory.oilAnalysis,
    DocCategory.invoice,
    DocCategory.intelligenceReport,
    DocCategory.other,
  ];

  @override
  void initState() {
    super.initState();
    final name = widget.filename
        .replaceAll(RegExp(r'\.(pdf|docx|jpg|jpeg|png)$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[_\-]'), ' ')
        .trim();
    _titleCtrl = TextEditingController(text: name);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(documentProvider(widget.caseId).notifier).uploadAndCreate(
            caseId: widget.caseId,
            bytes: widget.bytes,
            filename: widget.filename,
            mimeType: widget.mimeType,
            title: title,
            category: _category,
            willExtract: true,
          );
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      if (mounted) {
        showError(context, 'Upload failed: $e',
            error: e, stack: st, tag: 'Document');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // File preview
            _FilePreview(bytes: widget.bytes, mimeType: widget.mimeType),
            const SizedBox(height: 14),

            // Category
            const Text('Document type',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _importable.map((c) {
                final selected = _category == c;
                return GestureDetector(
                  onTap: () => setState(() => _category = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? _kColor.withValues(alpha: 0.15)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? _kColor : AppColors.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      c.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected
                            ? _kColor
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Title
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: _kColor, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save to Vault',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── File preview widget ─────────────────────────────────────────────────────

class _FilePreview extends StatelessWidget {
  const _FilePreview({required this.bytes, required this.mimeType});
  final Uint8List bytes;
  final String mimeType;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 240,
        color: Colors.grey.shade100,
        child: _buildInner(),
      ),
    );
  }

  Widget _buildInner() {
    if (mimeType.startsWith('image/')) {
      return Image.memory(bytes,
          fit: BoxFit.contain, width: double.infinity);
    }
    if (mimeType == 'application/pdf') {
      return AbsorbPointer(
        child: PdfViewer.data(
          bytes,
          sourceName: 'preview',
          params: const PdfViewerParams(backgroundColor: Colors.white),
        ),
      );
    }
    // DOCX / other
    return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.description_outlined,
            size: 56, color: AppColors.midBlue),
        SizedBox(height: 10),
        Text('Preview not available',
            style: TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      ]),
    );
  }
}

// ── Extraction result sheet ────────────────────────────────────────────────

class _ExtractionResultSheet extends ConsumerStatefulWidget {
  const _ExtractionResultSheet({
    required this.caseId,
    required this.docTitle,
    required this.result,
  });
  final String caseId;
  final String docTitle;
  final DocExtractionResult result;

  @override
  ConsumerState<_ExtractionResultSheet> createState() =>
      _ExtractionResultSheetState();
}

class _ExtractionResultSheetState
    extends ConsumerState<_ExtractionResultSheet> {
  late final Map<String, bool> _hardSelected;
  late final List<bool> _findingSelected;
  late final List<bool> _incidentSelected;
  late final List<bool> _machinerySelected;
  late final Map<String, bool> _vesselSelected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _hardSelected = {
      for (final k in widget.result.hardFields.keys) k: true
    };
    _findingSelected =
        List.filled(widget.result.contextFindings.length, true);
    _incidentSelected =
        List.filled(widget.result.detectedIncidents.length, true);
    _vesselSelected = {
      for (final k in widget.result.vesselFields.keys) k: true
    };
    _machinerySelected =
        List.filled(widget.result.detectedMachinery.length, true);
  }

  Future<void> _apply() async {
    setState(() => _saving = true);
    try {
      // 1. Save selected hard fields
      final selectedFields = Map<String, dynamic>.fromEntries(
        widget.result.hardFields.entries
            .where((e) => _hardSelected[e.key] == true),
      );
      await ref
          .read(documentProvider(widget.caseId).notifier)
          .saveExtracted(widget.result.docId, selectedFields);

      // 2. Create context notes — preserve original indices for category lookup
      final selectedIndices = <int>[];
      for (var i = 0; i < widget.result.contextFindings.length; i++) {
        if (_findingSelected[i]) selectedIndices.add(i);
      }
      final total = selectedIndices.length;
      final notesNotifier =
          ref.read(surveyorNotesProvider(widget.caseId).notifier);
      // Insert in reverse order so created_at DESC retrieval shows finding 1 at top
      for (var j = total - 1; j >= 0; j--) {
        final origIdx = selectedIndices[j];
        final cats = widget.result.findingCategories;
        final catStr =
            cats.length > origIdx ? cats[origIdx] : 'observation';
        await notesNotifier.add(
          caseId:   widget.caseId,
          content:  widget.result.contextFindings[origIdx],
          category: NoteCategory.fromValue(catStr),
          priority: CuePriority.normal,
          source:   '${widget.docTitle} (${j + 1}/$total)',
        );
      }

      // 3. Create occurrences for checked incidents
      final damageNotifier =
          ref.read(damageProvider(widget.caseId).notifier);
      for (var i = 0; i < widget.result.detectedIncidents.length; i++) {
        if (!_incidentSelected[i]) continue;
        final inc = widget.result.detectedIncidents[i];
        await damageNotifier.createOccurrence(
          caseId:           widget.caseId,
          title:            inc['title']?.toString() ??
              'Occurrence from ${widget.docTitle}',
          dateTime:         inc['date'] != null
              ? DateTime.tryParse(inc['date'].toString())
              : null,
          location:         inc['location']?.toString(),
          briefDescription: inc['description']?.toString(),
        );
      }

      // 4. Apply vessel data + add machinery (if case has a vessel linked)
      final vesselId = ref
          .read(caseProvider(widget.caseId))
          .value
          ?.vesselId;
      if (vesselId != null && vesselId.isNotEmpty) {
        // 4a. Apply selected vessel particulars
        if (widget.result.hasVesselData) {
          final selectedVessel = Map<String, dynamic>.fromEntries(
            widget.result.vesselFields.entries
                .where((e) => _vesselSelected[e.key] == true),
          );
          if (selectedVessel.isNotEmpty) {
            await ref
                .read(vesselForCaseProvider(widget.caseId).notifier)
                .applyExtraction(
                  caseId: widget.caseId,
                  vesselId: vesselId,
                  extracted: selectedVessel,
                );
          }
        }

        // 4b. Add machinery items
        final machineryNotifier =
            ref.read(machineryProvider(vesselId).notifier);
        for (var i = 0; i < widget.result.detectedMachinery.length; i++) {
          if (!_machinerySelected[i]) continue;
          final m = widget.result.detectedMachinery[i];
          await machineryNotifier.addMachinery(MachineryModel(
            machineryId:  '',
            vesselId:     vesselId,
            machineryType: m['machinery_type']?.toString() ?? 'Unknown',
            role:          m['role']?.toString(),
            make:          m['make']?.toString(),
            model:         m['model']?.toString(),
            serialNumber:  m['serial_number']?.toString(),
            mcrKw:   (m['mcr_kw'] as num?)?.toDouble(),
            mcrRpm:  (m['mcr_rpm'] as num?)?.toDouble(),
            fuelType: m['fuel_type']?.toString(),
          ));
        }
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _kColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_outlined,
                    color: _kColor, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Extraction Results',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  if (result.documentType != null)
                    Text(result.documentType!,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.close,
                    size: 20, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
            const SizedBox(height: 14),

            // Hard fields
            if (result.hasHardData) ...[
              const _SectionHeader(
                  'STRUCTURED DATA', Icons.table_rows_outlined,
                  subtitle: 'saved to document record'),
              const SizedBox(height: 6),
              ...result.hardFields.entries.map((e) => CheckboxListTile(
                    value: _hardSelected[e.key] ?? true,
                    onChanged: (v) =>
                        setState(() => _hardSelected[e.key] = v ?? false),
                    activeColor: _kColor,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    tileColor: Colors.transparent,
                    dense: true,
                    title: Text(
                      _labelFor(e.key),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                    subtitle: Text(
                      e.value.toString(),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary),
                    ),
                  )),
            ],

            // Context findings
            if (result.hasFindings) ...[
              if (result.hasHardData) ...[
                const Divider(height: 20, color: AppColors.border),
              ],
              const _SectionHeader(
                  'CONTEXT FINDINGS', Icons.label_outline,
                  subtitle: 'added as context cues'),
              const SizedBox(height: 6),
              ...List.generate(
                result.contextFindings.length,
                (i) {
                  final catStr = result.findingCategories.length > i
                      ? result.findingCategories[i]
                      : 'observation';
                  final cat = NoteCategory.fromValue(catStr);
                  return CheckboxListTile(
                    value: _findingSelected[i],
                    onChanged: (v) =>
                        setState(() => _findingSelected[i] = v ?? false),
                    activeColor: AppColors.teal,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    tileColor: Colors.transparent,
                    dense: true,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CatChip(cat),
                        const SizedBox(height: 3),
                        Text(
                          result.contextFindings[i],
                          style: TextStyle(
                              fontSize: 12,
                              color: _findingSelected[i]
                                  ? AppColors.textPrimary
                                  : AppColors.textTertiary,
                              decoration: _findingSelected[i]
                                  ? null
                                  : TextDecoration.lineThrough),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            // Vessel particulars (intelligence documents)
            if (result.hasVesselData) ...[
              if (result.hasHardData || result.hasFindings)
                const Divider(height: 20, color: AppColors.border),
              const _SectionHeader(
                  'VESSEL PARTICULARS', Icons.directions_boat_outlined,
                  subtitle: 'apply to vessel record'),
              const SizedBox(height: 6),
              ...result.vesselFields.entries.map((e) => CheckboxListTile(
                    value: _vesselSelected[e.key] ?? true,
                    onChanged: (v) =>
                        setState(() => _vesselSelected[e.key] = v ?? false),
                    activeColor: AppColors.teal,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    tileColor: Colors.transparent,
                    dense: true,
                    title: Text(
                      _vesselFieldLabel(e.key),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                    subtitle: Text(
                      e.value.toString(),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary),
                    ),
                  )),
            ],

            // Detected incidents
            if (result.hasIncidents) ...[
              const Divider(height: 20, color: AppColors.border),
              const _SectionHeader(
                  'DETECTED EVENTS', Icons.warning_amber_outlined,
                  subtitle: 'create as case occurrences'),
              const SizedBox(height: 6),
              ...List.generate(result.detectedIncidents.length, (i) {
                final inc = result.detectedIncidents[i];
                final date = inc['date']?.toString();
                final loc  = inc['location']?.toString();
                final meta = [if (date != null) date, if (loc != null) loc]
                    .join(' · ');
                return CheckboxListTile(
                  value: _incidentSelected[i],
                  onChanged: (v) =>
                      setState(() => _incidentSelected[i] = v ?? false),
                  activeColor: AppColors.coral,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  tileColor: Colors.transparent,
                  dense: true,
                  title: Text(
                    inc['title']?.toString() ?? 'Unnamed event',
                    style: TextStyle(
                        fontSize: 12,
                        color: _incidentSelected[i]
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                        decoration: _incidentSelected[i]
                            ? null
                            : TextDecoration.lineThrough),
                  ),
                  subtitle: meta.isNotEmpty
                      ? Text(meta,
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textTertiary))
                      : null,
                );
              }),
            ],

            // Detected machinery
            if (result.hasMachinery) ...[
              const Divider(height: 20, color: AppColors.border),
              const _SectionHeader(
                  'DETECTED MACHINERY', Icons.settings_outlined,
                  subtitle: 'add to vessel machinery list'),
              const SizedBox(height: 6),
              ...List.generate(result.detectedMachinery.length, (i) {
                final m = result.detectedMachinery[i];
                final make  = m['make']?.toString();
                final model = m['model']?.toString();
                final sub   = [if (make != null) make, if (model != null) model]
                    .join(' ');
                return CheckboxListTile(
                  value: _machinerySelected[i],
                  onChanged: (v) =>
                      setState(() => _machinerySelected[i] = v ?? false),
                  activeColor: AppColors.midBlue,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  tileColor: Colors.transparent,
                  dense: true,
                  title: Text(
                    m['machinery_type']?.toString() ?? 'Unknown machinery',
                    style: TextStyle(
                        fontSize: 12,
                        color: _machinerySelected[i]
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                        decoration: _machinerySelected[i]
                            ? null
                            : TextDecoration.lineThrough),
                  ),
                  subtitle: sub.isNotEmpty
                      ? Text(sub,
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textTertiary))
                      : null,
                );
              }),
            ],

            const SizedBox(height: 16),

            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Discard'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _saving ? null : _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Apply',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  String _labelFor(String key) => key
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  String _vesselFieldLabel(String key) => switch (key) {
        'vessel_name'     => 'Vessel Name',
        'imo_number'      => 'IMO Number',
        'call_sign'       => 'Call Sign',
        'mmsi'            => 'MMSI',
        'vessel_type'     => 'Vessel Type',
        'flag'            => 'Flag',
        'port_of_registry'=> 'Port of Registry',
        'gross_tonnage'   => 'Gross Tonnage',
        'net_tonnage'     => 'Net Tonnage',
        'deadweight'      => 'Deadweight (DWT)',
        'year_built'      => 'Year Built',
        'build_yard'      => 'Build Yard',
        'build_country'   => 'Build Country',
        'owners'          => 'Registered Owners',
        'operators'       => 'Technical Managers',
        'class_society'   => 'Classification Society',
        'class_notation'  => 'Class Notation',
        'service_speed'   => 'Service Speed (kts)',
        _                 => _labelFor(key),
      };
}

class _CatChip extends StatelessWidget {
  const _CatChip(this.category);
  final NoteCategory category;

  @override
  Widget build(BuildContext context) {
    final color = _catColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category.label,
        style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  static Color _catColor(NoteCategory cat) => switch (cat) {
        NoteCategory.observation   => const Color(0xFF2A6099),
        NoteCategory.measurement   => const Color(0xFF7B5EA7),
        NoteCategory.followUp      => const Color(0xFFD97706),
        NoteCategory.interview     => const Color(0xFF0891B2),
        NoteCategory.technical     => const Color(0xFFDC2626),
        NoteCategory.operations    => const Color(0xFF0F766E),
        NoteCategory.previousWorks => const Color(0xFF6B7280),
        NoteCategory.policy        => const Color(0xFF4338CA),
        NoteCategory.general       => const Color(0xFF4A7A5A),
      };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, this.icon, {this.subtitle});
  final String label;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 13, color: AppColors.textTertiary),
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 0.6)),
      if (subtitle != null) ...[
        const SizedBox(width: 6),
        Text('— $subtitle',
            style: const TextStyle(
                fontSize: 10, color: AppColors.textTertiary)),
      ],
    ]);
  }
}

// ── Document list ──────────────────────────────────────────────────────────

class _DocList extends StatelessWidget {
  const _DocList({
    required this.docs,
    required this.caseId,
    required this.isOnline,
    required this.onImport,
    required this.onPreview,
    required this.onExtract,
  });
  final List<DocumentModel> docs;
  final String caseId;
  final bool isOnline;
  final VoidCallback onImport;
  final void Function(DocumentModel) onPreview;
  final void Function(DocumentModel) onExtract;

  @override
  Widget build(BuildContext context) {
    final grouped = <DocCategory, List<DocumentModel>>{};
    for (final doc in docs) {
      grouped.putIfAbsent(doc.docCategory ?? DocCategory.other, () => [])
          .add(doc);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      children: [
        for (final entry in grouped.entries) ...[
          _CategoryHeader(entry.key),
          const SizedBox(height: 6),
          ...entry.value.map((doc) {
            final canExtract = doc.extractionPending && isOnline;
            final isProcessing = doc.extractionProcessing;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: DocumentTile(
                doc: doc,
                onPreview: doc.hasFile ? () => onPreview(doc) : null,
                onExtract: (canExtract && !isProcessing)
                    ? () => onExtract(doc)
                    : null,
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
        width: 3, height: 14,
        decoration: BoxDecoration(
          color: _kColor, borderRadius: BorderRadius.circular(2)),
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

// ── Empty state ─────────────────────────────────────────────────────────────

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
                backgroundColor: _kColor, foregroundColor: Colors.white),
          ),
        ]),
      ),
    );
  }
}

// ── PDF viewer ──────────────────────────────────────────────────────────────

class _PdfViewerScreen extends StatelessWidget {
  const _PdfViewerScreen({required this.title, required this.url});
  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
      body: PdfViewer.uri(
        Uri.parse(url),
        params: const PdfViewerParams(backgroundColor: Color(0xFFE0E0E0)),
      ),
    );
  }
}

// ── Image preview ───────────────────────────────────────────────────────────

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
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis),
      ),
      body: PhotoView(
        imageProvider: NetworkImage(imageUrl),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (_, __) => const Center(
            child: CircularProgressIndicator(color: _kColor)),
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

// ── Helpers ─────────────────────────────────────────────────────────────────

String _mimeFrom(String ext) => switch (ext) {
      'pdf' => 'application/pdf',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'image/jpeg',
    };
