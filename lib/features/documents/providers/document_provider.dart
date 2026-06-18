// lib/features/documents/providers/document_provider.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/api/claude_api.dart';

// ── Document model ─────────────────────────────────────────────────────────

enum DocCategory {
  certificate('certificate', 'Certificate'),
  classReport('class_report', 'Class Report'),
  inspectionReport('inspection_report', 'Inspection Report'),
  logbookExtract('logbook_extract', 'Logbook Extract'),
  maintenanceRecord('maintenance_record', 'Maintenance Record'),
  serviceReport('service_report', 'Service Report'),
  statementOfFacts('statement_of_facts', 'Statement of Facts'),
  oilAnalysis('oil_analysis', 'Oil Analysis'),
  invoice('invoice', 'Invoice'),
  correspondence('correspondence', 'Correspondence'),
  other('other', 'Other');

  const DocCategory(this.value, this.label);
  final String value;
  final String label;

  static DocCategory fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => DocCategory.other);
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
  final String language;
  final String? notes;
  final DateTime? createdAt;

  bool get hasFile => filePath != null && filePath!.isNotEmpty;
  bool get isImage =>
      fileType != null &&
      ['jpg', 'jpeg', 'png', 'webp'].contains(fileType!.toLowerCase());
  bool get isPdf => fileType != null && fileType!.toLowerCase() == 'pdf';
  bool get isDocx => fileType != null && fileType!.toLowerCase() == 'docx';

  factory DocumentModel.fromJson(Map<String, dynamic> j) => DocumentModel(
        docId: j['doc_id'] as String,
        caseId: j['case_id'] as String,
        title: j['title'] as String,
        docCategory: j['doc_category'] != null
            ? DocCategory.fromValue(j['doc_category'] as String)
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
        language: j['language'] as String? ?? 'en',
        notes: j['notes'] as String?,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );
}

// ── Extraction result — what Claude found ──────────────────────────────────

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
  final Map<String, dynamic> rawFields; // everything Claude returned
  final Map<String, dynamic> vesselFields; // fields that map to vessels table
  final Map<String, dynamic>
      certFields; // fields that map to certificates table
  final String confidence;
  final String? documentType;

  bool get hasVesselData => vesselFields.isNotEmpty;
  bool get hasCertData => certFields.isNotEmpty;
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
  /// [willExtract] controls whether extraction_status is set to 'pending'.
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
    final storagePath =
        '$caseId/documents/${DateTime.now().millisecondsSinceEpoch}_$filename';

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

    // Prepend to list
    final current = state.value ?? [];
    state = AsyncData([doc, ...current]);

    return doc;
  }

  /// Add a document record without a file (e.g. "requested" item)
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
    final current = state.value ?? [];
    state = AsyncData([doc, ...current]);
    return doc;
  }

  Future<void> deleteDocument(DocumentModel doc) async {
    // Delete the storage file first so we don't leave orphans.
    if (doc.filePath != null && doc.filePath!.isNotEmpty) {
      try {
        await SupabaseService.client.storage
            .from('documents')
            .remove([doc.filePath!]);
      } catch (e) {
        debugPrint('[DocumentProvider] storage delete failed: $e');
      }
    }
    // Nullify any FK references before deleting the row (certificates may
    // have source_doc_id pointing here). Non-fatal if the column is absent.
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

  Future<void> renameDocument(String docId, String newTitle) async {
    await SupabaseService.client
        .from('documents')
        .update({'title': newTitle})
        .eq('doc_id', docId);
    final current = state.value ?? [];
    state = AsyncData(current
        .map((d) => d.docId == docId ? _copyWithTitle(d, newTitle) : d)
        .toList());
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }
}

DocumentModel _copyWithTitle(DocumentModel d, String title) =>
    DocumentModel(
      docId: d.docId, caseId: d.caseId, title: title,
      docCategory: d.docCategory, docType: d.docType, source: d.source,
      docDate: d.docDate, receivedDate: d.receivedDate, filePath: d.filePath,
      fileType: d.fileType, fileSizeKb: d.fileSizeKb,
      availability: d.availability, aiExtracted: d.aiExtracted,
      extractionStatus: d.extractionStatus, language: d.language,
      notes: d.notes, createdAt: d.createdAt,
    );

// ── AI Extraction provider ─────────────────────────────────────────────────

/// Holds extraction state for a single document being processed
@immutable
class ExtractionState {
  const ExtractionState({
    this.isLoading = false,
    this.result,
    this.error,
  });
  final bool isLoading;
  final ExtractionResult? result;
  final String? error;

  ExtractionState copyWith({
    bool? isLoading,
    ExtractionResult? result,
    String? error,
  }) =>
      ExtractionState(
        isLoading: isLoading ?? this.isLoading,
        result: result ?? this.result,
        error: error ?? this.error,
      );
}

final extractionProvider =
    StateNotifierProvider<ExtractionNotifier, ExtractionState>(
  (_) => ExtractionNotifier(),
);

class ExtractionNotifier extends StateNotifier<ExtractionState> {
  ExtractionNotifier() : super(const ExtractionState());

  /// Run Claude extraction on image bytes
  Future<ExtractionResult?> extractFromImage({
    required String docId,
    required Uint8List bytes,
    required String mimeType,
    String? documentHint,
  }) async {
    state = const ExtractionState(isLoading: true);
    try {
      final base64 = base64Encode(bytes);
      final raw = await ClaudeApi.extractCertificateData(
        base64Image: base64,
        mediaType: mimeType,
        documentHint: documentHint,
      );

      final result = _buildResult(docId, raw);
      state = ExtractionState(result: result);

      // Mark document as extracted in Supabase
      await SupabaseService.client.from('documents').update({
        'ai_extracted': true,
        'extraction_status': 'completed',
        'doc_type': raw['document_type'] as String?,
      }).eq('doc_id', docId);

      return result;
    } catch (e) {
      state = ExtractionState(error: e.toString());
      await SupabaseService.client
          .from('documents')
          .update({'extraction_status': 'failed'}).eq('doc_id', docId);
      return null;
    }
  }

  void clear() => state = const ExtractionState();

  ExtractionResult _buildResult(String docId, Map<String, dynamic> raw) {
    // Fields that map to the vessels table
    final vesselFields = <String, dynamic>{};
    final fieldMap = {
      'vessel_name': 'name',
      'imo_number': 'imo_number',
      'vessel_type': 'vessel_type',
      'flag': 'flag',
      'port_of_registry': 'port_of_registry',
      'gross_tonnage': 'gross_tonnage',
      'net_tonnage': 'net_tonnage',
      'deadweight': 'deadweight',
      'length_oa': 'length_oa',
      'length_bp': 'length_bp',
      'breadth': 'breadth',
      'depth': 'depth',
      'max_draft': 'max_draft',
      'year_built': 'year_built',
      'build_yard': 'build_yard',
      'build_country': 'build_country',
      'owners': 'owners',
      'operators': 'operators',
      'class_society': 'class_society',
      'class_notation': 'class_notation',
      'service_speed': 'service_speed',
    };
    for (final entry in fieldMap.entries) {
      if (raw[entry.key] != null) {
        vesselFields[entry.value] = raw[entry.key];
      }
    }

    // Fields that map to the certificates table
    final certFields = <String, dynamic>{};
    if (raw['document_type'] != null) {
      certFields['cert_type'] = _mapCertType(raw['document_type'] as String);
      certFields['cert_name'] = raw['document_type'];
    }
    if (raw['issuing_authority'] != null) {
      certFields['issuing_authority'] = raw['issuing_authority'];
    }
    if (raw['issue_date'] != null) certFields['issue_date'] = raw['issue_date'];
    if (raw['expiry_date'] != null) {
      certFields['expiry_date'] = raw['expiry_date'];
    }
    if (raw['annual_survey_date'] != null) {
      certFields['annual_survey_date'] = raw['annual_survey_date'];
    }
    if (raw['cert_number'] != null) {
      certFields['cert_number'] = raw['cert_number'];
    }

    return ExtractionResult(
      docId: docId,
      rawFields: raw,
      vesselFields: vesselFields,
      certFields: certFields,
      documentType: raw['document_type'] as String?,
    );
  }

  String _mapCertType(String docType) {
    final t = docType.toLowerCase();
    if (t.contains('class')) return 'class_certificate';
    if (t.contains('doc') || t.contains('compliance')) return 'doc';
    if (t.contains('smc') || t.contains('safety management')) return 'smc';
    if (t.contains('load line')) return 'load_line';
    if (t.contains('marpol')) return 'marpol';
    if (t.contains('psc') || t.contains('port state')) return 'psc_inspection';
    if (t.contains('iopp')) return 'iopp';
    if (t.contains('dp')) return 'dp_certificate';
    return 'other';
  }
}
