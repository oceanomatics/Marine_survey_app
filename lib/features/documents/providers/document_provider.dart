// lib/features/documents/providers/document_provider.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/api/claude_api.dart';

// ── Document category ──────────────────────────────────────────────────────

enum DocCategory {
  certificate('certificate', 'Certificate'),
  classSurveyReport('class_survey_report', 'Class Survey Report'),
  conditionOfClass('condition_of_class', 'Condition of Class'),
  previousSurveyReport('previous_survey_report', 'Previous Survey Report'),
  inspectionReport('inspection_report', 'Inspection Report'),
  serviceReport('service_report', 'Service Report'),
  logbookExtract('logbook_extract', 'Logbook Extract'),
  maintenanceRecord('maintenance_record', 'Maintenance Record'),
  statementOfFacts('statement_of_facts', 'Statement of Facts'),
  incidentReport('incident_report', 'Incident Report'),
  oilAnalysis('oil_analysis', 'Oil Analysis'),
  invoice('invoice', 'Invoice'),
  correspondence('correspondence', 'Correspondence'),
  intelligenceReport('intelligence_report', 'Intelligence Report'),
  other('other', 'Other');

  const DocCategory(this.value, this.label);
  final String value;
  final String label;

  static DocCategory fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => DocCategory.other);

  // Legacy DB values that may still exist
  static DocCategory fromLegacyValue(String v) => switch (v) {
        'class_report' => DocCategory.classSurveyReport,
        _ => fromValue(v),
      };
}

enum DocAvailability {
  enclosed('enclosed', 'Enclosed'),
  requested('requested', 'Requested'),
  notAvailable('not_available', 'Not Available'),
  tbc('tbc', 'TBC');

  const DocAvailability(this.value, this.label);
  final String value;
  final String label;

  static DocAvailability fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => DocAvailability.tbc);
}

// ── Document model ─────────────────────────────────────────────────────────

@immutable
class DocumentModel {
  const DocumentModel({
    required this.docId,
    required this.caseId,
    required this.title,
    this.docCategory,
    this.docType,
    this.source,
    this.docDate,
    this.receivedDate,
    this.filePath,
    this.fileType,
    this.fileSizeKb,
    this.availability = DocAvailability.enclosed,
    this.aiExtracted = false,
    this.extractionStatus,
    this.extractedData,
    this.language = 'en',
    this.notes,
    this.createdAt,
  });

  final String docId;
  final String caseId;
  final String title;
  final DocCategory? docCategory;
  final String? docType;
  final String? source;
  final DateTime? docDate;
  final DateTime? receivedDate;
  final String? filePath;
  final String? fileType;
  final double? fileSizeKb;
  final DocAvailability availability;
  final bool aiExtracted;
  final String? extractionStatus;
  final Map<String, dynamic>? extractedData;
  final String language;
  final String? notes;
  final DateTime? createdAt;

  bool get hasFile => filePath != null && filePath!.isNotEmpty;
  bool get isImage =>
      fileType != null &&
      ['jpg', 'jpeg', 'png', 'webp'].contains(fileType!.toLowerCase());
  bool get isPdf => fileType != null && fileType!.toLowerCase() == 'pdf';
  bool get isDocx => fileType != null && fileType!.toLowerCase() == 'docx';
  bool get extractionPending =>
      hasFile && !aiExtracted && extractionStatus == 'pending';
  bool get extractionProcessing => extractionStatus == 'processing';
  bool get extractionFailed => extractionStatus == 'failed';

  factory DocumentModel.fromJson(Map<String, dynamic> j) => DocumentModel(
        docId: j['doc_id'] as String,
        caseId: j['case_id'] as String,
        title: j['title'] as String,
        docCategory: j['doc_category'] != null
            ? DocCategory.fromLegacyValue(j['doc_category'] as String)
            : null,
        docType: j['doc_type'] as String?,
        source: j['source'] as String?,
        docDate: j['doc_date'] != null
            ? DateTime.tryParse(j['doc_date'] as String)
            : null,
        receivedDate: j['received_date'] != null
            ? DateTime.tryParse(j['received_date'] as String)
            : null,
        filePath: j['file_path'] as String?,
        fileType: j['file_type'] as String?,
        fileSizeKb: (j['file_size_kb'] as num?)?.toDouble(),
        availability:
            DocAvailability.fromValue(j['availability'] as String? ?? 'tbc'),
        aiExtracted: j['ai_extracted'] as bool? ?? false,
        extractionStatus: j['extraction_status'] as String?,
        extractedData: j['extracted_data'] != null
            ? Map<String, dynamic>.from(j['extracted_data'] as Map)
            : null,
        language: j['language'] as String? ?? 'en',
        notes: j['notes'] as String?,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );

  DocumentModel copyWith({
    String? title,
    DocCategory? docCategory,
    String? docType,
    String? extractionStatus,
    Map<String, dynamic>? extractedData,
    bool? aiExtracted,
    String? notes,
  }) =>
      DocumentModel(
        docId: docId,
        caseId: caseId,
        title: title ?? this.title,
        docCategory: docCategory ?? this.docCategory,
        docType: docType ?? this.docType,
        source: source,
        docDate: docDate,
        receivedDate: receivedDate,
        filePath: filePath,
        fileType: fileType,
        fileSizeKb: fileSizeKb,
        availability: availability,
        aiExtracted: aiExtracted ?? this.aiExtracted,
        extractionStatus: extractionStatus ?? this.extractionStatus,
        extractedData: extractedData ?? this.extractedData,
        language: language,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}

// ── Extraction result ──────────────────────────────────────────────────────

@immutable
class DocExtractionResult {
  const DocExtractionResult({
    required this.docId,
    required this.hardFields,
    required this.contextFindings,
    required this.findingCategories,
    required this.detectedIncidents,
    required this.detectedMachinery,
    this.vesselFields = const {},
    this.suggestedCategory,
    this.documentType,
  });

  final String docId;
  final Map<String, dynamic> hardFields;
  final List<String> contextFindings;
  final List<String> findingCategories;
  final List<Map<String, dynamic>> detectedIncidents;
  final List<Map<String, dynamic>> detectedMachinery;
  /// Vessel particulars extracted from intelligence documents (Equasis etc).
  final Map<String, dynamic> vesselFields;
  final String? suggestedCategory;
  final String? documentType;

  bool get hasHardData    => hardFields.isNotEmpty;
  bool get hasFindings    => contextFindings.isNotEmpty;
  bool get hasIncidents   => detectedIncidents.isNotEmpty;
  bool get hasMachinery   => detectedMachinery.isNotEmpty;
  bool get hasVesselData  => vesselFields.isNotEmpty;
  bool get hasAny => hasHardData || hasFindings || hasIncidents || hasMachinery || hasVesselData;
}

// ── Document provider ──────────────────────────────────────────────────────

final documentProvider =
    AsyncNotifierProviderFamily<DocumentNotifier, List<DocumentModel>, String>(
  DocumentNotifier.new,
);

class DocumentNotifier
    extends FamilyAsyncNotifier<List<DocumentModel>, String> {
  @override
  Future<List<DocumentModel>> build(String caseId) => _fetch(caseId);

  Future<List<DocumentModel>> _fetch(String caseId) async {
    final data = await SupabaseService.client
        .from('documents')
        .select()
        .eq('case_id', caseId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => DocumentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Upload a file and create a document record.
  /// All uploaded docs get extraction_status: 'pending' — extract is manual.
  Future<DocumentModel> uploadAndCreate({
    required String caseId,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required String title,
    DocCategory? category,
    bool willExtract = true,
  }) async {
    final ext = filename.split('.').last.toLowerCase();
    final safeFilename = _sanitizeFilename(filename);
    final storagePath =
        '$caseId/documents/${DateTime.now().millisecondsSinceEpoch}_$safeFilename';

    await SupabaseService.uploadFile(
      bucket: 'documents',
      path: storagePath,
      bytes: bytes,
      mimeType: mimeType,
    );

    final data = await SupabaseService.client
        .from('documents')
        .insert({
          'case_id': caseId,
          'title': title,
          'doc_category': category?.value,
          'file_path': storagePath,
          'file_type': ext,
          'file_size_kb': (bytes.length / 1024).roundToDouble(),
          'availability': 'enclosed',
          'received_date': DateTime.now().toIso8601String().split('T').first,
          'ai_extracted': false,
          'extraction_status': willExtract ? 'pending' : 'not_applicable',
        })
        .select()
        .single();

    final doc = DocumentModel.fromJson(data);
    try {
      state = AsyncData(await _fetch(arg));
    } catch (_) {
      final current = state.value ?? [];
      state = AsyncData([doc, ...current]);
    }
    return doc;
  }

  /// Run AI extraction on a document already in the vault.
  /// Returns [DocExtractionResult] for the caller to show in the results sheet.
  /// Does NOT write extracted data to DB — call [saveExtracted] to confirm.
  Future<DocExtractionResult?> extract(String docId) async {
    _patchStatus(docId, 'processing');
    try {
      final current = state.value ?? [];
      final doc = current.firstWhere((d) => d.docId == docId);
      if (doc.filePath == null) return null;

      final bytes = await SupabaseService.client.storage
          .from('documents')
          .download(doc.filePath!);

      final ext = doc.fileType?.toLowerCase() ?? 'pdf';
      final mediaType = switch (ext) {
        'pdf'            => 'application/pdf',
        'jpg' || 'jpeg'  => 'image/jpeg',
        'png'            => 'image/png',
        _                => 'application/pdf',
      };

      final raw = await ClaudeApi.extractDocument(
        base64Content: base64Encode(bytes),
        mediaType: mediaType,
        categoryHint: doc.docCategory?.label ?? 'marine document',
      );

      final hardFields = <String, dynamic>{};
      final rawHard = raw['hard_fields'];
      if (rawHard is Map) {
        for (final e in rawHard.entries) {
          if (e.value != null && e.value != '' && e.value != 0) {
            hardFields[e.key as String] = e.value;
          }
        }
      }

      // Parse findings — supports both old (string) and new ({text, note_category}) formats
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

      // Vessel particulars from intelligence documents (Equasis, Lloyd's, etc.)
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
        docId: docId,
        hardFields: hardFields,
        contextFindings: findings,
        findingCategories: findingCats,
        detectedIncidents: incidents,
        detectedMachinery: machinery,
        vesselFields: vesselFields,
        suggestedCategory: raw['suggested_category'] as String?,
        documentType: raw['document_type'] as String?,
      );
    } catch (e) {
      _patchStatus(docId, 'failed');
      await SupabaseService.client
          .from('documents')
          .update({'extraction_status': 'failed'}).eq('doc_id', docId);
      return null;
    }
  }

  /// Persist the user-selected extraction result and mark the document extracted.
  /// [selectedHardFields] are the doc-specific hard fields (cert number, dates…).
  /// Optional [vesselData], [unmappedFields], and counts enrich the stored
  /// payload so the "✓ Extracted" summary sheet can show the full picture.
  Future<void> saveExtracted(
    String docId,
    Map<String, dynamic> selectedHardFields, {
    Map<String, dynamic>? vesselData,
    Map<String, dynamic>? unmappedFields,
    List<Map<String, dynamic>> contextFindings = const [],
    List<Map<String, dynamic>> detectedIncidents = const [],
    List<Map<String, dynamic>> detectedMachinery = const [],
    int findingsApplied = 0,
    int incidentsApplied = 0,
    int machineryApplied = 0,
  }) async {
    final storedData = <String, dynamic>{
      if (selectedHardFields.isNotEmpty) 'hard_fields': selectedHardFields,
      if (vesselData?.isNotEmpty == true) 'vessel_data': vesselData,
      if (unmappedFields?.isNotEmpty == true) 'unmapped_fields': unmappedFields,
      if (contextFindings.isNotEmpty) 'context_findings': contextFindings,
      if (detectedIncidents.isNotEmpty) 'detected_incidents': detectedIncidents,
      if (detectedMachinery.isNotEmpty) 'detected_machinery': detectedMachinery,
      'meta': {
        'findings_applied': findingsApplied,
        'incidents_applied': incidentsApplied,
        'machinery_applied': machineryApplied,
        'findings_total': contextFindings.length,
        'incidents_total': detectedIncidents.length,
        'machinery_total': detectedMachinery.length,
      },
    };

    await SupabaseService.client.from('documents').update({
      'extracted_data': storedData,
      'ai_extracted': true,
      'extraction_status': 'completed',
    }).eq('doc_id', docId);

    final current = state.value ?? [];
    state = AsyncData(current.map((d) {
      if (d.docId != docId) return d;
      return d.copyWith(
        extractedData: storedData,
        aiExtracted: true,
        extractionStatus: 'completed',
      );
    }).toList());
  }

  /// Add a document record without a file (e.g. "requested" item).
  Future<DocumentModel> addRecord({
    required String caseId,
    required String title,
    DocCategory? category,
    DocAvailability availability = DocAvailability.requested,
    String? notes,
  }) async {
    final data = await SupabaseService.client
        .from('documents')
        .insert({
          'case_id': caseId,
          'title': title,
          'doc_category': category?.value,
          'availability': availability.value,
          if (notes != null) 'notes': notes,
        })
        .select()
        .single();

    final doc = DocumentModel.fromJson(data);
    try {
      state = AsyncData(await _fetch(arg));
    } catch (_) {
      final current = state.value ?? [];
      state = AsyncData([doc, ...current]);
    }
    return doc;
  }

  Future<void> deleteDocument(DocumentModel doc) async {
    if (doc.filePath != null && doc.filePath!.isNotEmpty) {
      try {
        await SupabaseService.client.storage
            .from('documents')
            .remove([doc.filePath!]);
      } catch (e) {
        debugPrint('[DocumentProvider] storage delete failed: $e');
      }
    }
    try {
      await SupabaseService.client
          .from('certificates')
          .update({'source_doc_id': null})
          .eq('source_doc_id', doc.docId);
    } catch (_) {}
    await SupabaseService.client
        .from('documents')
        .delete()
        .eq('doc_id', doc.docId);
    final current = state.value ?? [];
    state = AsyncData(current.where((d) => d.docId != doc.docId).toList());
  }

  Future<void> updateMetadata(
    String docId, {
    String? title,
    DocCategory? category,
  }) async {
    final updates = <String, dynamic>{
      if (title != null) 'title': title,
      if (category != null) 'doc_category': category.value,
    };
    if (updates.isEmpty) return;
    await SupabaseService.client
        .from('documents')
        .update(updates)
        .eq('doc_id', docId);
    final current = state.value ?? [];
    state = AsyncData(current.map((d) {
      if (d.docId != docId) return d;
      return d.copyWith(
        title: title ?? d.title,
        docCategory: category ?? d.docCategory,
      );
    }).toList());
  }

  Future<void> renameDocument(String docId, String newTitle) async {
    await SupabaseService.client
        .from('documents')
        .update({'title': newTitle})
        .eq('doc_id', docId);
    final current = state.value ?? [];
    state = AsyncData(current
        .map((d) => d.docId == docId ? d.copyWith(title: newTitle) : d)
        .toList());
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }

  void _patchStatus(String docId, String status) {
    final current = state.value ?? [];
    state = AsyncData(current.map((d) {
      if (d.docId != docId) return d;
      return d.copyWith(extractionStatus: status);
    }).toList());
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

String _sanitizeFilename(String filename) {
  // Transliterate common accented characters to ASCII equivalents
  const accents = {
    'à':'a','â':'a','ä':'a','á':'a','ã':'a','å':'a',
    'è':'e','é':'e','ê':'e','ë':'e',
    'ì':'i','î':'i','ï':'i','í':'i',
    'ò':'o','ô':'o','ö':'o','ó':'o','õ':'o','ø':'o',
    'ù':'u','û':'u','ü':'u','ú':'u',
    'ý':'y','ÿ':'y',
    'ç':'c','ñ':'n','ß':'ss',
    'À':'A','Â':'A','Ä':'A','Á':'A','Ã':'A','Å':'A',
    'È':'E','É':'E','Ê':'E','Ë':'E',
    'Ì':'I','Î':'I','Ï':'I','Í':'I',
    'Ò':'O','Ô':'O','Ö':'O','Ó':'O','Õ':'O','Ø':'O',
    'Ù':'U','Û':'U','Ü':'U','Ú':'U',
    'Ç':'C','Ñ':'N',
  };
  var s = filename;
  for (final e in accents.entries) {
    s = s.replaceAll(e.key, e.value);
  }
  // Replace any remaining non-safe characters (spaces, parens, etc.) with _
  s = s.replaceAll(RegExp(r'[^\w.\-]'), '_');
  // Collapse consecutive underscores
  s = s.replaceAll(RegExp(r'_+'), '_');
  return s;
}

// ── Connectivity provider ──────────────────────────────────────────────────

// Kept for backward compatibility — new code uses documentProvider directly.
@immutable
class ExtractionResult {
  const ExtractionResult({
    required this.docId,
    required this.rawFields,
    required this.vesselFields,
    required this.certFields,
    this.confidence = 'medium',
    this.documentType,
  });
  final String docId;
  final Map<String, dynamic> rawFields;
  final Map<String, dynamic> vesselFields;
  final Map<String, dynamic> certFields;
  final String confidence;
  final String? documentType;
  bool get hasVesselData => vesselFields.isNotEmpty;
  bool get hasCertData => certFields.isNotEmpty;
}
