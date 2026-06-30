// lib/features/documents/screens/document_vault_screen.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/claude_api.dart';
import '../../../core/api/supabase_client.dart';
import '../../../features/cases/providers/cases_provider.dart';
import '../../../features/photos/models/photo_model.dart';
import '../../../features/photos/providers/photo_provider.dart';
import '../../../features/survey/providers/damage_provider.dart';
import '../../../features/surveyor_notes/models/surveyor_note_model.dart';
import '../../../features/surveyor_notes/providers/surveyor_notes_provider.dart';
import '../../../features/vessel/providers/certificates_provider.dart';
import '../../../features/vessel/providers/class_conditions_provider.dart';
import '../../../features/vessel/providers/vessel_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../providers/document_provider.dart';
import '../widgets/document_tile.dart';

const _kColor = AppColors.amber;

/// Vessel-data keys that VesselModel.applyExtraction() recognises.
/// Any key returned by Claude that is NOT in this set is stored as
/// "unmapped_fields" and shown in the extraction summary for diagnosis.
const _kKnownVesselKeys = {
  'vessel_name', 'previous_name', 'imo_number', 'call_sign', 'mmsi', 'vessel_type', 'flag', 'port_of_registry',
  'gross_tonnage', 'net_tonnage', 'deadweight', 'holds_count', 'tanks_count',
  'length_oa', 'length_bp', 'breadth', 'breadth_qualifier', 'depth',
  'max_draft', 'draft_qualifier', 'year_built', 'build_yard', 'build_country',
  'owners', 'operators', 'class_society', 'class_notation', 'service_speed',
  'propulsion_type', 'propeller_type', 'propulsion_drive_type',
  'mcr_power_value', 'mcr_rpm', 'mcr_power_unit',
};

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
    final allocatedPhotos = ref
        .watch(photosProvider(caseId))
        .value
        ?.where((p) => p.allocation != null)
        .toList() ?? [];

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
        data: (docs) => (docs.isEmpty && allocatedPhotos.isEmpty)
            ? _EmptyVault(onImport: () => _startImport(context, ref))
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(documentProvider(caseId).notifier).refresh(),
                child: _DocList(
                  docs: docs,
                  caseId: caseId,
                  isOnline: isOnline,
                  allocatedPhotos: allocatedPhotos,
                  onImport: () => _startImport(context, ref),
                  onPreview: (doc) => _previewDocument(context, doc),
                  onExtract: (doc) => _runExtraction(context, ref, doc),
                  onExtractPhoto: (photo) =>
                      _runPhotoExtraction(context, ref, photo),
                  onViewExtraction: (doc) =>
                      showExtractionSummary(context, doc),
                  onReapply: (doc) =>
                      reapplyExtraction(context, caseId, doc),
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

  // ── Photo AI extraction ─────────────────────────────────────────────────

  Future<void> _runPhotoExtraction(
      BuildContext context, WidgetRef ref, PhotoModel photo) async {
    if (!context.mounted) return;

    // Show loading indicator briefly while calling Claude.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sending photo to AI…'),
        duration: Duration(seconds: 60),
      ),
    );

    try {
      final bytes = await File(photo.localPath).readAsBytes();
      final raw = await ClaudeApi.extractDocument(
        base64Content: base64Encode(bytes),
        mediaType: 'image/jpeg',
        categoryHint: photo.allocation?.label ?? 'marine document photo',
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final result = _parsePhotoExtraction(photo.id, raw);

      if (!result.hasAny) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data extracted from this photo')),
        );
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ExtractionResultSheet(
          caseId: caseId,
          docTitle: photo.caption ?? photo.allocation?.label ?? 'Photo',
          result: result,
        ),
      );
    } catch (e, st) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        showError(context, 'Extraction failed: $e',
            error: e, stack: st, tag: 'PhotoExtract');
      }
    }
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
      child: Material(
        type: MaterialType.transparency,
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
    this.initialFindingSelected,
    this.initialIncidentSelected,
    this.initialMachinerySelected,
    this.initialConditionSelected,
    this.initialVesselSelected,
  });
  final String caseId;
  final String docTitle;
  final DocExtractionResult result;
  // When re-applying stored extraction, caller can pre-set which items to apply.
  // null = default all to true (fresh extraction). false = item already applied.
  final List<bool>? initialFindingSelected;
  final List<bool>? initialIncidentSelected;
  final List<bool>? initialMachinerySelected;
  final List<bool>? initialConditionSelected;
  final Map<String, bool>? initialVesselSelected;

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
  late final List<bool> _conditionSelected;
  late final Map<String, bool> _vesselSelected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _hardSelected = {
      for (final k in widget.result.hardFields.keys) k: true
    };
    _findingSelected = widget.initialFindingSelected ??
        List.filled(widget.result.contextFindings.length, true);
    _incidentSelected = widget.initialIncidentSelected ??
        List.filled(widget.result.detectedIncidents.length, true);
    _vesselSelected = widget.initialVesselSelected ??
        {for (final k in widget.result.vesselFields.keys) k: true};
    _machinerySelected = widget.initialMachinerySelected ??
        List.filled(widget.result.detectedMachinery.length, true);
    _conditionSelected = widget.initialConditionSelected ??
        List.filled(widget.result.detectedClassConditions.length, true);
  }

  Future<void> _apply() async {
    setState(() => _saving = true);
    try {
      // Pre-compute counts from current selection state.
      final appliedFindingsCount = _findingSelected.where((b) => b).length;
      final appliedIncidentsCount = _incidentSelected.where((b) => b).length;
      final appliedMachineryCount = _machinerySelected.where((b) => b).length;
      final appliedConditionsCount = _conditionSelected.where((b) => b).length;

      // Compute vessel fields: selected (will be applied) and unmapped (unknown to applyExtraction).
      final selectedVesselForSave = Map<String, dynamic>.fromEntries(
        widget.result.vesselFields.entries
            .where((e) => _vesselSelected[e.key] == true && _kKnownVesselKeys.contains(e.key)),
      );
      final unmappedVesselFields = Map<String, dynamic>.fromEntries(
        widget.result.vesselFields.entries
            .where((e) => !_kKnownVesselKeys.contains(e.key) && e.value != null && e.value != ''),
      );

      // 1. Save selected hard fields + full extraction data for review.
      final selectedFields = Map<String, dynamic>.fromEntries(
        widget.result.hardFields.entries
            .where((e) => _hardSelected[e.key] == true),
      );

      // Build full findings list with category for the summary view.
      // Preserve cumulative applied state: an item stays 'applied: true' if it
      // was applied in a previous round even if unchecked this time.
      final allFindings = <Map<String, dynamic>>[
        for (var i = 0; i < widget.result.contextFindings.length; i++) {
          'text': widget.result.contextFindings[i],
          'category': i < widget.result.findingCategories.length
              ? widget.result.findingCategories[i]
              : 'observation',
          'applied': _findingSelected[i] ||
              (widget.initialFindingSelected != null &&
                  !widget.initialFindingSelected![i]),
        },
      ];

      // Include all incidents and machinery with applied flag.
      final allIncidents = <Map<String, dynamic>>[
        for (var i = 0; i < widget.result.detectedIncidents.length; i++)
          {
            ...widget.result.detectedIncidents[i],
            'applied': _incidentSelected[i] ||
                (widget.initialIncidentSelected != null &&
                    !widget.initialIncidentSelected![i]),
          },
      ];
      final allMachinery = <Map<String, dynamic>>[
        for (var i = 0; i < widget.result.detectedMachinery.length; i++)
          {
            ...widget.result.detectedMachinery[i],
            'applied': _machinerySelected[i] ||
                (widget.initialMachinerySelected != null &&
                    !widget.initialMachinerySelected![i]),
          },
      ];

      final allConditions = <Map<String, dynamic>>[
        for (var i = 0; i < widget.result.detectedClassConditions.length; i++)
          {
            ...widget.result.detectedClassConditions[i],
            'applied': _conditionSelected[i] ||
                (widget.initialConditionSelected != null &&
                    !widget.initialConditionSelected![i]),
          },
      ];

      await ref
          .read(documentProvider(widget.caseId).notifier)
          .saveExtracted(
            widget.result.docId,
            selectedFields,
            vesselData: selectedVesselForSave,
            unmappedFields: unmappedVesselFields,
            contextFindings: allFindings,
            detectedIncidents: allIncidents,
            detectedMachinery: allMachinery,
            detectedClassConditions: allConditions,
            findingsApplied: appliedFindingsCount,
            incidentsApplied: appliedIncidentsCount,
            machineryApplied: appliedMachineryCount,
            conditionsApplied: appliedConditionsCount,
          );

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

      // 3. Create occurrences for checked incidents (skip duplicates by title)
      final damageNotifier =
          ref.read(damageProvider(widget.caseId).notifier);
      final existingOccs =
          ref.read(damageProvider(widget.caseId)).value?.occurrences ?? [];
      for (var i = 0; i < widget.result.detectedIncidents.length; i++) {
        if (!_incidentSelected[i]) continue;
        final inc = widget.result.detectedIncidents[i];
        final incTitle = (inc['title']?.toString() ??
            'Occurrence from ${widget.docTitle}').trim();
        final isDuplicate = existingOccs.any((o) =>
            (o.title ?? '').trim().toLowerCase() ==
            incTitle.toLowerCase());
        if (isDuplicate) continue;
        await damageNotifier.createOccurrence(
          caseId:           widget.caseId,
          title:            incTitle,
          dateTime:         inc['date'] != null
              ? DateTime.tryParse(inc['date'].toString())
              : null,
          location:         inc['location']?.toString(),
          briefDescription: inc['description']?.toString(),
        );
      }

      // 4. Apply vessel data + add machinery.
      // If the case has no vessel yet but extraction found vessel data,
      // create a vessel record now and link it to the case automatically.
      String? vesselId = ref
          .read(caseProvider(widget.caseId))
          .value
          ?.vesselId;

      final hasVesselToApply = selectedVesselForSave.isNotEmpty
          || widget.result.detectedMachinery.isNotEmpty
          || widget.result.hasClassConditions;

      if (vesselId == null && hasVesselToApply) {
        debugPrint('[APPLY] No vessel linked — creating one from extracted data');
        final vesselName =
            selectedVesselForSave['vessel_name'] as String?
            ?? widget.result.vesselFields['vessel_name'] as String?
            ?? 'TBC';
        final newVessel = await ref
            .read(vesselForCaseProvider(widget.caseId).notifier)
            .createVessel(caseId: widget.caseId, name: vesselName);
        vesselId = newVessel.vesselId;
        debugPrint('[APPLY] Created vessel: ${newVessel.name} ($vesselId)');
      }

      if (vesselId != null && vesselId.isNotEmpty) {
        // 4a. Apply selected vessel particulars.
        if (selectedVesselForSave.isNotEmpty) {
          debugPrint('[APPLY] Applying ${selectedVesselForSave.length} vessel fields');
          await ref
              .read(vesselForCaseProvider(widget.caseId).notifier)
              .applyExtraction(
                caseId: widget.caseId,
                vesselId: vesselId,
                extracted: selectedVesselForSave,
              );
        }

        // 4b. Add machinery items.
        if (widget.result.detectedMachinery.isNotEmpty) {
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

        // 4c. Add class conditions.
        if (widget.result.hasClassConditions) {
          final condNotifier =
              ref.read(classConditionsProvider(vesselId).notifier);
          for (var i = 0;
              i < widget.result.detectedClassConditions.length;
              i++) {
            if (!_conditionSelected[i]) continue;
            final c = widget.result.detectedClassConditions[i];
            await condNotifier.add(
              vesselId:    vesselId,
              reference:   c['reference']?.toString(),
              description: c['description']?.toString(),
              expiryDate:  c['expiry_date'] != null
                  ? DateTime.tryParse(c['expiry_date'].toString())
                  : null,
            );
          }
        }
      }

      // 5. Create certificate if the document is a certificate type.
      final docType  = widget.result.documentType ?? '';
      final docCat   = widget.result.suggestedCategory ?? '';
      final isCertDoc = docCat == 'certificate' ||
          docType.toLowerCase().contains('certificate');
      if (isCertDoc) {
        final certType = _inferCertType(docType);
        final certNum  = widget.result.hardFields['document_number']?.toString();
        final existing = ref.read(certificatesProvider(widget.caseId)).value ?? [];
        final isDup = existing.any((c) =>
            c.certType == certType &&
            certNum != null &&
            certNum.isNotEmpty &&
            c.certNumber == certNum);
        if (!isDup) {
          final issueDate  = widget.result.hardFields['document_date'] != null
              ? DateTime.tryParse(
                  widget.result.hardFields['document_date'].toString())
              : null;
          final expiryDate = widget.result.hardFields['expiry_date'] != null
              ? DateTime.tryParse(
                  widget.result.hardFields['expiry_date'].toString())
              : null;
          final cert = CertificateModel(
            certId:           '',
            caseId:           widget.caseId,
            vesselId:         vesselId,
            certType:         certType,
            certName:         docType.isNotEmpty ? docType : null,
            issuingAuthority: widget.result.hardFields['issuing_authority']
                ?.toString(),
            issueDate:        issueDate,
            expiryDate:       expiryDate,
            certNumber:       certNum,
            status:           expiryDate != null &&
                    expiryDate.isBefore(DateTime.now())
                ? CertStatus.expired
                : CertStatus.tbc,
            sourceDocId:      widget.result.docId,
            extractedAuto:    true,
          );
          await ref
              .read(certificatesProvider(widget.caseId).notifier)
              .addCertificate(cert);
        }
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static CertType _inferCertType(String documentType) {
    final dt = documentType.toLowerCase();
    if (dt.contains('class')) { return CertType.classCertificate; }
    if (dt.contains('document of compliance') ||
        dt.contains(' doc ') || dt == 'doc') { return CertType.doc; }
    if (dt.contains('safety management') ||
        dt.contains(' smc ') || dt == 'smc') { return CertType.smc; }
    if (dt.contains('load line')) { return CertType.loadLine; }
    if (dt.contains('marpol') || dt.contains('iopp') ||
        dt.contains('oil pollution')) { return CertType.marpol; }
    if (dt.contains('safety equipment')) { return CertType.safetyEquipment; }
    if (dt.contains('safety radio')) { return CertType.safetyRadio; }
    if (dt.contains('safety construction')) { return CertType.safetyConstruction; }
    if (dt.contains('issc') ||
        dt.contains('ship security')) { return CertType.issc; }
    if (dt.contains('dp certificate') ||
        dt.contains('dynamic positioning')) { return CertType.dpCertificate; }
    return CertType.other;
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
      child: Material(
        type: MaterialType.transparency,
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

            // Detected class conditions
            if (result.hasClassConditions) ...[
              const Divider(height: 20, color: AppColors.border),
              const _SectionHeader(
                  'CLASS CONDITIONS', Icons.shield_outlined,
                  subtitle: 'add to vessel class conditions'),
              const SizedBox(height: 6),
              ...List.generate(result.detectedClassConditions.length, (i) {
                final c = result.detectedClassConditions[i];
                final ref_ = c['reference']?.toString();
                final expiry = c['expiry_date']?.toString();
                String? sub;
                if (ref_ != null && expiry != null) {
                  sub = '$ref_  ·  Expires $expiry';
                } else if (ref_ != null) {
                  sub = ref_;
                } else if (expiry != null) {
                  sub = 'Expires $expiry';
                }
                return CheckboxListTile(
                  value: _conditionSelected[i],
                  onChanged: (v) =>
                      setState(() => _conditionSelected[i] = v ?? false),
                  activeColor: const Color(0xFF4A7FA5),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  tileColor: Colors.transparent,
                  dense: true,
                  title: Text(
                    c['description']?.toString() ?? 'Condition',
                    style: TextStyle(
                        fontSize: 12,
                        color: _conditionSelected[i]
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                        decoration: _conditionSelected[i]
                            ? null
                            : TextDecoration.lineThrough),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: sub != null
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
        'previous_name'   => 'Previous Name',
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
        NoteCategory.invoicing     => const Color(0xFF0284C7),
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
    required this.allocatedPhotos,
    required this.onImport,
    required this.onPreview,
    required this.onExtract,
    required this.onExtractPhoto,
    required this.onViewExtraction,
    required this.onReapply,
  });
  final List<DocumentModel> docs;
  final String caseId;
  final bool isOnline;
  final List<PhotoModel> allocatedPhotos;
  final VoidCallback onImport;
  final void Function(DocumentModel) onPreview;
  final void Function(DocumentModel) onExtract;
  final void Function(PhotoModel) onExtractPhoto;
  final void Function(DocumentModel) onViewExtraction;
  final void Function(DocumentModel) onReapply;

  @override
  Widget build(BuildContext context) {
    final grouped = <DocCategory, List<DocumentModel>>{};
    for (final doc in docs) {
      grouped.putIfAbsent(doc.docCategory ?? DocCategory.other, () => [])
          .add(doc);
    }

    // Group allocated photos by allocation type for display.
    final photosByAlloc = <PhotoAllocation, List<PhotoModel>>{};
    for (final ph in allocatedPhotos) {
      if (ph.allocation != null) {
        photosByAlloc.putIfAbsent(ph.allocation!, () => []).add(ph);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      children: [
        // ── Regular documents ───────────────────────────────────────
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
                onViewExtraction: doc.aiExtracted
                    ? () => onViewExtraction(doc)
                    : null,
                onReapply: (doc.aiExtracted && doc.extractedData != null)
                    ? () => onReapply(doc)
                    : null,
              ),
            );
          }),
          const SizedBox(height: 12),
        ],

        // ── Photo documents ─────────────────────────────────────────
        if (photosByAlloc.isNotEmpty) ...[
          const _PhotoSectionHeader(),
          const SizedBox(height: 8),
          for (final entry in photosByAlloc.entries) ...[
            _PhotoAllocHeader(entry.key),
            const SizedBox(height: 6),
            ...entry.value.map((ph) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _PhotoDocTile(
                    photo: ph,
                    isOnline: isOnline,
                    onExtract: isOnline ? () => onExtractPhoto(ph) : null,
                  ),
                )),
            const SizedBox(height: 12),
          ],
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

// ── Photo document widgets ──────────────────────────────────────────────────

class _PhotoSectionHeader extends StatelessWidget {
  const _PhotoSectionHeader();

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 3, height: 14,
        decoration: BoxDecoration(
          color: AppColors.purple, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 8),
      const Text(
        'PHOTO DOCUMENTS',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(width: 8),
      const Tooltip(
        message: 'Photos allocated from the Photo Gallery. '
            'Tap the AI button to extract data.',
        child: Icon(Icons.info_outline, size: 12, color: AppColors.textTertiary),
      ),
    ]);
  }
}

class _PhotoAllocHeader extends StatelessWidget {
  const _PhotoAllocHeader(this.allocation);
  final PhotoAllocation allocation;

  @override
  Widget build(BuildContext context) {
    final color = _allocColor(allocation);
    return Row(children: [
      Container(
        width: 3, height: 14,
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 8),
      Text(
        allocation.label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    ]);
  }
}

class _PhotoDocTile extends StatelessWidget {
  const _PhotoDocTile({
    required this.photo,
    required this.isOnline,
    required this.onExtract,
  });

  final PhotoModel photo;
  final bool isOnline;
  final VoidCallback? onExtract;

  @override
  Widget build(BuildContext context) {
    final alloc = photo.allocation!;
    final color = _allocColor(alloc);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        // Thumbnail
        ClipRRect(
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
          child: Image.file(
            File(photo.thumbnailPath ?? photo.localPath),
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 72, height: 72,
              color: color.withValues(alpha: 0.08),
              child: Icon(_allocIcon(alloc), color: color, size: 28),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Caption + allocation tag
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                photo.caption?.isNotEmpty == true
                    ? photo.caption!
                    : alloc.label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  alloc.label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color),
                ),
              ),
            ],
          ),
        ),

        // AI extract button
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Tooltip(
            message: isOnline
                ? 'Extract data with AI'
                : 'Offline — connect to extract',
            child: IconButton(
              icon: Icon(
                Icons.auto_awesome_outlined,
                color: isOnline ? _kColor : AppColors.textTertiary,
                size: 20,
              ),
              onPressed: onExtract,
            ),
          ),
        ),
      ]),
    );
  }
}

Color _allocColor(PhotoAllocation a) => switch (a) {
      PhotoAllocation.coverPage        => AppColors.purple,
      PhotoAllocation.logbook          => AppColors.midBlue,
      PhotoAllocation.maintenanceRecord => AppColors.teal,
      PhotoAllocation.certificate      => AppColors.amber,
      PhotoAllocation.damageEvidence   => AppColors.coral,
      PhotoAllocation.namePlate        => AppColors.textSecondary,
    };

IconData _allocIcon(PhotoAllocation a) => switch (a) {
      PhotoAllocation.coverPage        => Icons.home_outlined,
      PhotoAllocation.logbook          => Icons.menu_book_outlined,
      PhotoAllocation.maintenanceRecord => Icons.build_outlined,
      PhotoAllocation.certificate      => Icons.verified_outlined,
      PhotoAllocation.damageEvidence   => Icons.warning_amber_outlined,
      PhotoAllocation.namePlate        => Icons.label_outlined,
    };

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

/// Parse a raw Claude extraction response into a [DocExtractionResult].
/// Uses the photo's id as the synthetic docId.
DocExtractionResult _parsePhotoExtraction(
    String photoId, Map<String, dynamic> raw) {
  final hardFields = <String, dynamic>{};
  final rawHard = raw['hard_fields'];
  if (rawHard is Map) {
    for (final e in rawHard.entries) {
      if (e.value != null && e.value != '' && e.value != 0) {
        hardFields[e.key as String] = e.value;
      }
    }
  }

  final findings = <String>[];
  final findingCats = <String>[];
  for (final f in raw['context_findings'] as List? ?? []) {
    if (f is Map) {
      final text = f['text']?.toString() ?? '';
      if (text.isNotEmpty) {
        findings.add(text);
        findingCats.add(f['note_category']?.toString() ?? 'observation');
      }
    } else {
      final text = f.toString();
      if (text.isNotEmpty) {
        findings.add(text);
        findingCats.add('observation');
      }
    }
  }

  final incidents = (raw['detected_incidents'] as List? ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  final machinery = (raw['detected_machinery'] as List? ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  final vesselFields = <String, dynamic>{};
  final rawVessel = raw['vessel_data'];
  if (rawVessel is Map) {
    for (final e in rawVessel.entries) {
      if (e.value != null && e.value != '') {
        vesselFields[e.key as String] = e.value;
      }
    }
  }

  return DocExtractionResult(
    docId: photoId,
    hardFields: hardFields,
    contextFindings: findings,
    findingCategories: findingCats,
    detectedIncidents: incidents,
    detectedMachinery: machinery,
    vesselFields: vesselFields,
    suggestedCategory: raw['suggested_category'] as String?,
    documentType: raw['document_type'] as String?,
  );
}

String _mimeFrom(String ext) => switch (ext) {
      'pdf' => 'application/pdf',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'image/jpeg',
    };

// ── Extraction summary sheet ──────────────────────────────────────────────────
// Shown when the user taps the "✓ Extracted" badge on a document tile.

/// Pretty-label map for known field keys shown in the summary.
const _kFieldLabels = <String, String>{
  // Hard fields
  'vessel_name':       'Vessel Name',
  'imo_number':        'IMO Number',
  'document_date':     'Document Date',
  'document_number':   'Document No.',
  'issuing_authority': 'Issuing Authority',
  'expiry_date':       'Expiry Date',
  'next_due_date':     'Next Due Date',
  'survey_date':       'Survey Date',
  'port_of_survey':    'Port of Survey',
  'class_society':     'Class Society',
  'class_notation':    'Class Notation',
  'surveyor_name':     'Surveyor Name',
  'component':         'Component',
  'serial_number':     'Serial Number',
  'manufacturer':      'Manufacturer',
  'model_ref':         'Model / Ref',
  'hours_run':         'Hours Run',
  'next_service_hours': 'Next Service Hours',
  'invoice_number':    'Invoice No.',
  'supplier':          'Supplier',
  'amount':            'Amount',
  'currency':          'Currency',
  // Vessel data
  'flag':              'Flag',
  'port_of_registry':  'Port of Registry',
  'vessel_type':       'Vessel Type',
  'gross_tonnage':     'Gross Tonnage (GT)',
  'net_tonnage':       'Net Tonnage (NT)',
  'deadweight':        'Deadweight (DWT)',
  'length_oa':         'Length OA (m)',
  'length_bp':         'Length BP (m)',
  'breadth':           'Breadth (m)',
  'breadth_qualifier': 'Breadth Qualifier',
  'depth':             'Depth (m)',
  'max_draft':         'Max Draft (m)',
  'draft_qualifier':   'Draft Qualifier',
  'year_built':        'Year Built',
  'build_yard':        'Build Yard',
  'build_country':     'Build Country',
  'owners':            'Owners',
  'operators':         'Operators',
  'service_speed':     'Service Speed (kn)',
  'propulsion_type':   'Propulsion Type',
  'propeller_type':    'Propeller Type',
  'propulsion_drive_type': 'Drive Type',
  'mcr_power_value':   'MCR Power',
  'mcr_rpm':           'MCR RPM',
  'mcr_power_unit':    'MCR Unit',
  // Unmapped fields likely from future Claude output
  'call_sign':         'Call Sign',
  'mmsi':              'MMSI',
};

void showExtractionSummary(BuildContext context, DocumentModel doc) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ExtractionSummarySheet(doc: doc),
  );
}

/// Re-opens the extraction result sheet from stored JSON so the user can
/// apply items that were skipped the first time, without duplicating data
/// that was already applied (those default to unchecked).
void reapplyExtraction(
    BuildContext context, String caseId, DocumentModel doc) {
  final stored = doc.extractedData;
  if (stored == null) return;

  // ── Reconstruct hard fields ──────────────────────────────────────────────
  final hardFields = Map<String, dynamic>.from(
      (stored['hard_fields'] as Map? ?? {}));

  // ── Reconstruct context findings ─────────────────────────────────────────
  final findings    = <String>[];
  final findingCats = <String>[];
  final findingWasApplied = <bool>[];
  for (final f in stored['context_findings'] as List? ?? []) {
    if (f is Map) {
      final text = f['text']?.toString() ?? '';
      if (text.isNotEmpty) {
        findings.add(text);
        findingCats.add(f['category']?.toString() ?? 'observation');
        findingWasApplied.add(f['applied'] as bool? ?? true);
      }
    }
  }

  // ── Reconstruct list sections (strip the 'applied' flag for the model) ───
  List<Map<String, dynamic>> stripApplied(List raw) => raw
      .whereType<Map>()
      .map((e) {
        final copy = Map<String, dynamic>.from(e);
        copy.remove('applied');
        return copy;
      })
      .toList();

  bool wasApplied(dynamic item) =>
      item is Map && (item['applied'] as bool? ?? true);

  final rawIncidents  = stored['detected_incidents']        as List? ?? [];
  final rawMachinery  = stored['detected_machinery']        as List? ?? [];
  final rawConditions = stored['detected_class_conditions'] as List? ?? [];

  final incidents  = stripApplied(rawIncidents);
  final machinery  = stripApplied(rawMachinery);
  final conditions = stripApplied(rawConditions);

  // ── Vessel fields ────────────────────────────────────────────────────────
  final vesselFields = Map<String, dynamic>.from(
      (stored['vessel_data'] as Map? ?? {}));

  final result = DocExtractionResult(
    docId:                  doc.docId,
    hardFields:             hardFields,
    contextFindings:        findings,
    findingCategories:      findingCats,
    detectedIncidents:      incidents,
    detectedMachinery:      machinery,
    detectedClassConditions: conditions,
    vesselFields:           vesselFields,
  );

  if (!result.hasAny) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('No structured data available to re-apply')),
    );
    return;
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ExtractionResultSheet(
      caseId:    caseId,
      docTitle:  doc.title,
      result:    result,
      // Pre-select only items that were NOT applied before, to avoid duplicates.
      initialFindingSelected:
          List.generate(findings.length, (i) => !findingWasApplied[i]),
      initialIncidentSelected:
          List.generate(rawIncidents.length, (i) => !wasApplied(rawIncidents[i])),
      initialMachinerySelected:
          List.generate(rawMachinery.length, (i) => !wasApplied(rawMachinery[i])),
      initialConditionSelected:
          List.generate(rawConditions.length, (i) => !wasApplied(rawConditions[i])),
      initialVesselSelected: {
        for (final k in vesselFields.keys) k: true,
      },
    ),
  );
}

class _ExtractionSummarySheet extends StatelessWidget {
  const _ExtractionSummarySheet({required this.doc});
  final DocumentModel doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.extractedData ?? {};

    // Detect format: new format has a 'hard_fields' or 'meta' key.
    final isRich = data.containsKey('hard_fields') ||
        data.containsKey('vessel_data') ||
        data.containsKey('meta');

    final hardFields = isRich
        ? Map<String, dynamic>.from(data['hard_fields'] as Map? ?? {})
        : data; // legacy: whole map IS the hard fields
    final vesselData =
        Map<String, dynamic>.from(data['vessel_data'] as Map? ?? {});
    final unmapped =
        Map<String, dynamic>.from(data['unmapped_fields'] as Map? ?? {});

    final rawFindings = (data['context_findings'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final rawIncidents = (data['detected_incidents'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final rawMachinery = (data['detected_machinery'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final meta = data['meta'] as Map?;
    final findingsApplied  = meta?['findings_applied']  as int? ??
        meta?['findings_count'] as int? ?? 0;
    final incidentsApplied = meta?['incidents_applied'] as int? ??
        meta?['incidents_count'] as int? ?? 0;
    final machineryApplied = meta?['machinery_applied'] as int? ??
        meta?['machinery_count'] as int? ?? 0;

    final hasContent = hardFields.isNotEmpty || vesselData.isNotEmpty ||
        unmapped.isNotEmpty || rawFindings.isNotEmpty ||
        rawIncidents.isNotEmpty || rawMachinery.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
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
            width: 40, height: 4,
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
                  doc.title,
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
                if (!hasContent)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No detailed extraction data stored.\n'
                        'Re-extract this document to capture full data.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textTertiary),
                      ),
                    ),
                  ),

                // ── Document fields ────────────────────────────────
                if (hardFields.isNotEmpty) ...[
                  _SummarySection(
                    title: 'Document Fields',
                    color: AppColors.midBlue,
                    icon: Icons.description_outlined,
                    fields: hardFields,
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Vessel particulars ─────────────────────────────
                if (vesselData.isNotEmpty) ...[
                  _SummarySection(
                    title: 'Vessel Particulars',
                    color: AppColors.teal,
                    icon: Icons.directions_boat_outlined,
                    fields: vesselData,
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Surveyor cues (context findings) ──────────────
                if (rawFindings.isNotEmpty) ...[
                  _SummarySectionHeader(
                    title: 'Surveyor Cues'
                        '  (${rawFindings.length} total'
                        '${findingsApplied > 0 ? ', $findingsApplied added to notes' : ''})',
                    color: AppColors.purple,
                    icon: Icons.psychology_outlined,
                  ),
                  const SizedBox(height: 8),
                  ...rawFindings.map((f) {
                    final applied = f['applied'] as bool? ?? false;
                    final cat = (f['category'] as String? ?? 'observation')
                        .replaceAll('_', ' ');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            applied
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 14,
                            color: applied
                                ? AppColors.success
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f['text']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textPrimary,
                                      height: 1.4),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cat,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textTertiary,
                                      fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],

                // ── Incidents / occurrences ────────────────────────
                if (rawIncidents.isNotEmpty) ...[
                  _SummarySectionHeader(
                    title: 'Incidents'
                        '  (${rawIncidents.length} total'
                        '${incidentsApplied > 0 ? ', $incidentsApplied created' : ''})',
                    color: AppColors.coral,
                    icon: Icons.warning_amber_outlined,
                  ),
                  const SizedBox(height: 8),
                  ...rawIncidents.map((inc) {
                    final applied = inc['applied'] as bool? ?? false;
                    final title = inc['title']?.toString() ?? '(no title)';
                    final date = inc['date']?.toString();
                    final location = inc['location']?.toString();
                    final desc = inc['description']?.toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            applied
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 14,
                            color: applied
                                ? AppColors.success
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary)),
                                if (date != null || location != null)
                                  Text(
                                    [
                                      if (date != null) date,
                                      if (location != null) location,
                                    ].join(' · '),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textTertiary),
                                  ),
                                if (desc != null) ...[
                                  const SizedBox(height: 3),
                                  Text(desc,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                          height: 1.4)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],

                // ── Machinery detected ─────────────────────────────
                if (rawMachinery.isNotEmpty) ...[
                  _SummarySectionHeader(
                    title: 'Machinery'
                        '  (${rawMachinery.length} total'
                        '${machineryApplied > 0 ? ', $machineryApplied added' : ''})',
                    color: AppColors.amber,
                    icon: Icons.settings_outlined,
                  ),
                  const SizedBox(height: 8),
                  ...rawMachinery.map((m) {
                    final applied = m['applied'] as bool? ?? false;
                    final type = m['machinery_type']?.toString() ?? '(unknown)';
                    final specs = <String>[
                      if (m['make'] != null) m['make'].toString(),
                      if (m['model'] != null) m['model'].toString(),
                      if (m['serial_number'] != null)
                        'S/N ${m['serial_number']}',
                      if (m['mcr_kw'] != null) '${m['mcr_kw']} kW',
                      if (m['mcr_rpm'] != null) '${m['mcr_rpm']} RPM',
                      if (m['fuel_type'] != null) m['fuel_type'].toString(),
                    ];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            applied
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 14,
                            color: applied
                                ? AppColors.success
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(type,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary)),
                                if (specs.isNotEmpty)
                                  Text(
                                    specs.join(' · '),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],

                // ── Unmapped / ignored fields ─────────────────────
                if (unmapped.isNotEmpty) ...[
                  const _SummarySectionHeader(
                    title: 'Unmapped Fields (debug)',
                    color: AppColors.amber,
                    icon: Icons.bug_report_outlined,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Extracted but not mapped to any app field. '
                          'Add to VesselModel + applyExtraction() to use.',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.amber.withValues(alpha: 0.9),
                              fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 8),
                        ...unmapped.entries.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(children: [
                                Text(
                                  e.key,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: AppColors.amber,
                                      fontWeight: FontWeight.w700),
                                ),
                                const Text(' → ',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textTertiary)),
                                Expanded(
                                  child: Text(
                                    '${e.value}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ]),
                            )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _SummarySectionHeader extends StatelessWidget {
  const _SummarySectionHeader({
    required this.title,
    required this.color,
    required this.icon,
  });
  final String title;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
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
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.title,
    required this.color,
    required this.icon,
    required this.fields,
  });
  final String title;
  final Color color;
  final IconData icon;
  final Map<String, dynamic> fields;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SummarySectionHeader(title: title, color: color, icon: icon),
      const SizedBox(height: 6),
      ...fields.entries.map((e) {
        final label = _kFieldLabels[e.key] ??
            e.key.replaceAll('_', ' ').split(' ').map((w) =>
                w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}'
            ).join(' ');
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500)),
              ),
              Expanded(
                child: Text(
                  '${e.value}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        );
      }),
    ]);
  }
}
