// lib/features/documents/providers/document_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/api/claude_api.dart';
import '../../ai_tasks/providers/ai_tasks_provider.dart';

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

// Sentinel: distinguishes "not provided" from null in copyWith / updateMetadata
const _sentinel = Object();

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
    this.requestedDate,
    this.filePath,
    this.fileType,
    this.fileSizeKb,
    this.availability = DocAvailability.enclosed,
    this.aiExtracted = false,
    this.extractionStatus,
    this.extractedData,
    this.pendingExtraction,
    this.language = 'en',
    this.notes,
    this.createdAt,
    this.annexureAssignment,
    this.surveyorConfirmed = false,
    this.isCoverPhoto = false,
    this.includedInReport = true,
    this.sourceCorrespondenceId,
  });

  final String docId;
  final String caseId;
  final String title;
  final DocCategory? docCategory;
  final String? docType;
  final String? source;
  final DateTime? docDate;
  final DateTime? receivedDate;

  /// Clause K-2: date the document was requested (availability == requested).
  final DateTime? requestedDate;
  final String? filePath;
  final String? fileType;
  final double? fileSizeKb;
  final DocAvailability availability;
  final bool aiExtracted;
  final String? extractionStatus;
  final Map<String, dynamic>? extractedData;

  /// §4.1: the RAW (un-confirmed) Claude extraction result, persisted so a
  /// background-run extraction survives navigating away without losing the
  /// work already done. Only meaningful when [extractionStatus] is
  /// 'ready_for_review'; cleared once the surveyor confirms via
  /// saveExtracted(). Distinct from [extractedData], which only ever holds
  /// the surveyor-confirmed subset.
  final Map<String, dynamic>? pendingExtraction;
  final String language;
  final String? notes;
  final DateTime? createdAt;
  final String? annexureAssignment;
  final bool surveyorConfirmed;
  final bool isCoverPhoto;

  /// §3.4/§2.15 (10 July 2026): distinguishes "enclosed in the exported
  /// report" from "retained on file but not enclosed" — only meaningful
  /// when [availability] == [DocAvailability.enclosed]; ignored (harmless)
  /// otherwise. Migration 034, defaults true.
  final bool includedInReport;

  /// §3.14 (13 July 2026): set when this document was created from a
  /// Correspondence attachment (`correspondence_screen.dart`'s EML/Gmail
  /// import flows) — the cross-link back to that trail item, migration 036.
  /// Null for every other document (manual upload, requested record, etc.).
  final String? sourceCorrespondenceId;

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

  /// §4.1: extraction ran (possibly in the background) and is waiting for
  /// the surveyor to open the review sheet and confirm what to keep.
  bool get extractionReadyForReview =>
      extractionStatus == 'ready_for_review' && pendingExtraction != null;

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
        requestedDate: j['requested_date'] != null
            ? DateTime.tryParse(j['requested_date'] as String)
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
        pendingExtraction: j['pending_extraction'] != null
            ? Map<String, dynamic>.from(j['pending_extraction'] as Map)
            : null,
        language: j['language'] as String? ?? 'en',
        notes: j['notes'] as String?,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
        annexureAssignment: j['annexure_assignment'] as String?,
        surveyorConfirmed: j['surveyor_confirmed'] as bool? ?? false,
        isCoverPhoto: j['is_cover_photo'] as bool? ?? false,
        includedInReport: j['included_in_report'] as bool? ?? true,
        sourceCorrespondenceId: j['source_correspondence_id'] as String?,
      );

  DocumentModel copyWith({
    String? title,
    DocCategory? docCategory,
    String? docType,
    DateTime? docDate,
    String? extractionStatus,
    Map<String, dynamic>? extractedData,
    Object? pendingExtraction = _sentinel,
    bool? aiExtracted,
    String? notes,
    Object? annexureAssignment = _sentinel,
    bool? surveyorConfirmed,
    bool? isCoverPhoto,
    DocAvailability? availability,
    bool? includedInReport,
  }) =>
      DocumentModel(
        docId: docId,
        caseId: caseId,
        title: title ?? this.title,
        docCategory: docCategory ?? this.docCategory,
        docType: docType ?? this.docType,
        source: source,
        docDate: docDate ?? this.docDate,
        receivedDate: receivedDate,
        requestedDate: requestedDate,
        filePath: filePath,
        fileType: fileType,
        fileSizeKb: fileSizeKb,
        availability: availability ?? this.availability,
        aiExtracted: aiExtracted ?? this.aiExtracted,
        extractionStatus: extractionStatus ?? this.extractionStatus,
        extractedData: extractedData ?? this.extractedData,
        pendingExtraction: identical(pendingExtraction, _sentinel)
            ? this.pendingExtraction
            : pendingExtraction as Map<String, dynamic>?,
        language: language,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        annexureAssignment: identical(annexureAssignment, _sentinel)
            ? this.annexureAssignment
            : annexureAssignment as String?,
        surveyorConfirmed: surveyorConfirmed ?? this.surveyorConfirmed,
        isCoverPhoto: isCoverPhoto ?? this.isCoverPhoto,
        includedInReport: includedInReport ?? this.includedInReport,
        sourceCorrespondenceId: sourceCorrespondenceId,
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
    this.findingCaseSections = const [],
    this.findingOrigins = const [],
    this.findingPages = const [],
    required this.detectedIncidents,
    required this.detectedMachinery,
    this.detectedClassConditions = const [],
    this.detectedContacts = const [],
    this.vesselFields = const {},
    this.suggestedCategory,
    this.documentType,
    this.keyDates = const [],
    this.costEstimates = const [],
    this.actionItems = const [],
    this.backgroundText,
    this.caseRefs = const {},
  });

  final String docId;
  final Map<String, dynamic> hardFields;
  final List<String> contextFindings;
  final List<String> findingCategories;

  /// AI-suggested `CaseSection.value` per finding, parallel to [contextFindings];
  /// null entries mean the extraction didn't offer a guess for that finding
  /// (docs/context_cue_system_review.md §3.5).
  final List<String?> findingCaseSections;

  /// AI-suggested `CueOrigin.value` per finding, parallel to [contextFindings].
  final List<String?> findingOrigins;

  /// Source document page number per finding, parallel to [contextFindings];
  /// null entries mean the page couldn't be determined.
  final List<int?> findingPages;
  final List<Map<String, dynamic>> detectedIncidents;
  final List<Map<String, dynamic>> detectedMachinery;
  final List<Map<String, dynamic>> detectedClassConditions;

  /// Named people extracted from the document with their professional
  /// title/function in `role` (e.g. Chief Engineer, Class Surveyor). Applied
  /// to the case's Stakeholders / Parties list. Each map: name, role,
  /// company, email, phone.
  final List<Map<String, dynamic>> detectedContacts;

  /// Vessel particulars extracted from intelligence documents (Equasis etc).
  final Map<String, dynamic> vesselFields;
  final String? suggestedCategory;
  final String? documentType;

  // ── Correspondence extras (empty for documents) ─────────────────────────
  /// Dated events extracted from a source; each map: date, description,
  /// kind ("event" | "attendance"), location. Attendance = the surveyor's OWN
  /// attendance → a survey attendance; event → a timeline event.
  final List<Map<String, dynamic>> keyDates;

  /// Cost estimate lines; each map: category, description, amount, currency.
  final List<Map<String, dynamic>> costEstimates;

  /// Action items / outstanding requests.
  final List<String> actionItems;

  /// Pre-incident case background narrative to append.
  final String? backgroundText;

  /// Case header refs to apply: claim_reference, technical_file_no,
  /// vessel_name, instruction_date.
  final Map<String, dynamic> caseRefs;

  bool get hasHardData => hardFields.isNotEmpty;
  bool get hasFindings => contextFindings.isNotEmpty;
  bool get hasIncidents => detectedIncidents.isNotEmpty;
  bool get hasMachinery => detectedMachinery.isNotEmpty;
  bool get hasClassConditions => detectedClassConditions.isNotEmpty;
  bool get hasContacts => detectedContacts.isNotEmpty;
  bool get hasVesselData => vesselFields.isNotEmpty;
  bool get hasKeyDates => keyDates.isNotEmpty;
  bool get hasCosts => costEstimates.isNotEmpty;
  bool get hasActionItems => actionItems.isNotEmpty;
  bool get hasBackground => (backgroundText ?? '').trim().isNotEmpty;
  bool get hasCaseRefs => caseRefs.values.any((v) => (v?.toString() ?? '').isNotEmpty);
  bool get hasAny =>
      hasHardData ||
      hasFindings ||
      hasIncidents ||
      hasMachinery ||
      hasVesselData ||
      hasClassConditions ||
      hasContacts ||
      hasKeyDates ||
      hasCosts ||
      hasActionItems ||
      hasBackground ||
      hasCaseRefs;

  /// Build the shared extraction result from a correspondence extraction JSON
  /// (ClaudeApi.extractCorrespondence*), so correspondence uses the same review
  /// sheet + apply as documents. [sourceId] is the correspondence id.
  factory DocExtractionResult.fromCorrespondence(
      String sourceId, Map<String, dynamic> raw) {
    List<Map<String, dynamic>> maps(dynamic v) => v is List
        ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : const [];
    List<String> strs(dynamic v) => v is List
        ? v
            .map((e) => e?.toString() ?? '')
            .where((s) => s.trim().isNotEmpty)
            .toList()
        : const [];
    String? s(dynamic v) {
      final t = v?.toString().trim() ?? '';
      return (t.isEmpty || t.toLowerCase() == 'null') ? null : t;
    }

    final findings = maps(raw['context_findings'])
        .where((f) => (s(f['text']) ?? '').isNotEmpty)
        .toList();
    return DocExtractionResult(
      docId: sourceId,
      documentType: 'Correspondence',
      hardFields: const {},
      contextFindings: [for (final f in findings) s(f['text'])!],
      findingCategories: [
        for (final f in findings) s(f['note_category']) ?? 'observation'
      ],
      findingCaseSections: [for (final f in findings) s(f['case_section'])],
      detectedIncidents: maps(raw['detected_incidents']),
      detectedMachinery: maps(raw['detected_machinery']),
      detectedClassConditions: maps(raw['detected_class_conditions']),
      detectedContacts: maps(raw['parties']),
      keyDates: maps(raw['key_dates']),
      costEstimates: maps(raw['cost_estimates']),
      actionItems: strs(raw['action_items']),
      backgroundText: s(raw['background_text']),
      caseRefs: {
        'technical_file_no': s(raw['technical_file_no']),
        'claim_reference': s(raw['claim_reference']),
        'vessel_name': s(raw['vessel_name']),
        'instruction_date': s(raw['instruction_date']),
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'docId': docId,
        'documentType': documentType,
        'hardFields': hardFields,
        'contextFindings': contextFindings,
        'findingCategories': findingCategories,
        'findingCaseSections': findingCaseSections,
        'detectedIncidents': detectedIncidents,
        'detectedMachinery': detectedMachinery,
        'detectedClassConditions': detectedClassConditions,
        'detectedContacts': detectedContacts,
        'vesselFields': vesselFields,
        'keyDates': keyDates,
        'costEstimates': costEstimates,
        'actionItems': actionItems,
        'backgroundText': backgroundText,
        'caseRefs': caseRefs,
      };

  factory DocExtractionResult.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> maps(dynamic v) => v is List
        ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : const [];
    return DocExtractionResult(
      docId: j['docId']?.toString() ?? '',
      documentType: j['documentType'] as String?,
      hardFields: (j['hardFields'] as Map?)?.cast<String, dynamic>() ?? const {},
      contextFindings:
          (j['contextFindings'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      findingCategories:
          (j['findingCategories'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      findingCaseSections:
          (j['findingCaseSections'] as List?)?.map((e) => e as String?).toList() ??
              const [],
      detectedIncidents: maps(j['detectedIncidents']),
      detectedMachinery: maps(j['detectedMachinery']),
      detectedClassConditions: maps(j['detectedClassConditions']),
      detectedContacts: maps(j['detectedContacts']),
      vesselFields:
          (j['vesselFields'] as Map?)?.cast<String, dynamic>() ?? const {},
      keyDates: maps(j['keyDates']),
      costEstimates: maps(j['costEstimates']),
      actionItems:
          (j['actionItems'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      backgroundText: j['backgroundText'] as String?,
      caseRefs: (j['caseRefs'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
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
    String? sourceCorrespondenceId,
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
          'included_in_report': true,
          'received_date': DateTime.now().toIso8601String().split('T').first,
          'ai_extracted': false,
          'extraction_status': willExtract ? 'pending' : 'not_applicable',
          if (sourceCorrespondenceId != null)
            'source_correspondence_id': sourceCorrespondenceId,
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

    // §4.1: event-driven — importing a document fires extraction straight
    // away instead of leaving it for a manual "Extract" tap. Fire-and-forget
    // so uploadAndCreate() returns immediately and the import sheet closes
    // normally; extract() persists pending_extraction/status itself, so the
    // Document Vault tile and Production Manager pick this up reactively
    // whether or not the surveyor is still watching this screen.
    if (willExtract) unawaited(_autoExtract(doc.docId));

    return doc;
  }

  /// Wraps [extract] for fire-and-forget callers (upload auto-fire). extract()
  /// already records failure in `extraction_status`/local state and rethrows
  /// for callers that are awaiting it directly (the manual "Extract" button,
  /// which shows its own SnackBar) — here there's no one awaiting, so the
  /// failure is swallowed rather than becoming an unhandled async error.
  Future<void> _autoExtract(String docId) async {
    try {
      await extract(docId);
    } catch (_) {
      // Already recorded as extraction_status: 'failed' — surfaced via the
      // document's own tile (retry action) and the Production Manager view.
    }
  }

  /// Run AI extraction on a document already in the vault. Persists the raw
  /// result to `pending_extraction` + `extraction_status: 'ready_for_review'`
  /// so a background/auto-fired run (see [uploadAndCreate]) survives the
  /// surveyor navigating away, then also returns the parsed
  /// [DocExtractionResult] so a caller watching synchronously (the manual
  /// "Extract" button) can open the review sheet immediately without a
  /// second round trip. Does NOT write extracted data to case fields —
  /// call [saveExtracted] to confirm; that's the only step that ever does.
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
        'pdf' => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        _ => 'application/pdf',
      };

      final raw = await ref.read(aiTasksProvider.notifier).run(
            label: 'Extracting "${doc.title}"',
            caseId: arg,
            estimate: const Duration(seconds: 20),
            action: () => ClaudeApi.extractDocument(
              base64Content: base64Encode(bytes),
              mediaType: mediaType,
              categoryHint: doc.docCategory?.label ?? 'marine document',
            ),
          );

      // ClaudeApi._parseJson() falls back to {'error': ..., 'raw': ...} when
      // the model's response isn't valid JSON (e.g. it replied with prose
      // instead — seen live with a French-language maintenance record).
      // Previously this silently persisted as a "successful" extraction
      // with zero hard_fields/context_findings — the surveyor just saw an
      // empty review sheet with no indication anything had gone wrong
      // (14 July 2026 walkthrough, §10). Treat it as the real failure it
      // is so the existing catch-block/failed-status/retry-action path
      // handles it like any other extraction error.
      if (raw.containsKey('error')) {
        throw Exception('Extraction response could not be parsed: ${raw['error']}');
      }

      await SupabaseService.client.from('documents').update({
        'pending_extraction': raw,
        'extraction_status': 'ready_for_review',
      }).eq('doc_id', docId);
      final afterPersist = state.value ?? [];
      state = AsyncData(afterPersist.map((d) {
        if (d.docId != docId) return d;
        return d.copyWith(
            extractionStatus: 'ready_for_review', pendingExtraction: raw);
      }).toList());

      return _parseRaw(docId, raw);
    } catch (e) {
      _patchStatus(docId, 'failed');
      await SupabaseService.client
          .from('documents')
          .update({'extraction_status': 'failed'}).eq('doc_id', docId);
      debugPrint('[DocumentProvider] extraction failed for $docId: $e');
      rethrow;
    }
  }

  /// Re-parses an already-persisted `pending_extraction` payload — the path
  /// used to open the review sheet for an extraction that ran in the
  /// background (auto-fired on upload, or the surveyor navigated away
  /// after tapping "Extract"), rather than re-calling Claude.
  DocExtractionResult? parsePending(String docId) {
    final doc = (state.value ?? []).firstWhere((d) => d.docId == docId,
        orElse: () => throw StateError('Unknown document: $docId'));
    final raw = doc.pendingExtraction;
    if (raw == null) return null;
    return _parseRaw(docId, raw);
  }

  DocExtractionResult _parseRaw(String docId, Map<String, dynamic> raw) {
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
    final findingSections = <String?>[];
    final findingOrigins = <String?>[];
    final findingPages = <int?>[];
    for (final f in raw['context_findings'] as List? ?? []) {
      if (f is Map) {
        final text = f['text']?.toString() ?? '';
        if (text.isNotEmpty) {
          findings.add(text);
          findingCats.add(f['note_category']?.toString() ?? 'observation');
          findingSections.add(f['case_section']?.toString());
          findingOrigins.add(f['origin']?.toString());
          findingPages.add(int.tryParse(f['page']?.toString() ?? ''));
        }
      } else {
        final text = f.toString();
        if (text.isNotEmpty) {
          findings.add(text);
          findingCats.add('observation');
          findingSections.add(null);
          findingOrigins.add(null);
          findingPages.add(null);
        }
      }
    }

    // Safety net: enforce document order by page even if the model didn't
    // fully comply with the "list in document order" instruction — a
    // stable sort keyed on (page, original index) so same-page/unknown-page
    // findings keep their original relative order.
    final order = List<int>.generate(findings.length, (i) => i)
      ..sort((a, b) {
        final pa = findingPages[a] ?? (1 << 30);
        final pb = findingPages[b] ?? (1 << 30);
        if (pa != pb) return pa.compareTo(pb);
        return a.compareTo(b);
      });
    final orderedFindings = [for (final i in order) findings[i]];
    final orderedCats = [for (final i in order) findingCats[i]];
    final orderedSections = [for (final i in order) findingSections[i]];
    final orderedOrigins = [for (final i in order) findingOrigins[i]];
    final orderedPages = [for (final i in order) findingPages[i]];

    final incidents = (raw['detected_incidents'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final machinery = (raw['detected_machinery'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final classConditions = (raw['detected_class_conditions'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) =>
            e['description'] != null && e['description'].toString().isNotEmpty)
        .toList();

    final contacts = (raw['detected_contacts'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => (e['name']?.toString().trim() ?? '').isNotEmpty)
        .toList();

    // Vessel particulars from intelligence documents (Equasis, Lloyd's, etc.)
    final vesselFields = <String, dynamic>{};
    final rawVessel = raw['vessel_data'];
    debugPrint(
        '[EXTRACT] vessel_data raw type: ${rawVessel.runtimeType}, value: $rawVessel');
    if (rawVessel is Map) {
      for (final e in rawVessel.entries) {
        if (e.value != null && e.value != '') {
          vesselFields[e.key as String] = e.value;
        }
      }
    }
    debugPrint(
        '[EXTRACT] vesselFields parsed (${vesselFields.length} keys): $vesselFields');
    debugPrint(
        '[EXTRACT] machinery: ${machinery.length}, classConditions: ${classConditions.length}');

    return DocExtractionResult(
      docId: docId,
      hardFields: hardFields,
      contextFindings: orderedFindings,
      findingCategories: orderedCats,
      findingCaseSections: orderedSections,
      findingOrigins: orderedOrigins,
      findingPages: orderedPages,
      detectedIncidents: incidents,
      detectedMachinery: machinery,
      detectedClassConditions: classConditions,
      detectedContacts: contacts,
      vesselFields: vesselFields,
      suggestedCategory: raw['suggested_category'] as String?,
      documentType: raw['document_type'] as String?,
    );
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
    List<Map<String, dynamic>> detectedClassConditions = const [],
    int findingsApplied = 0,
    int incidentsApplied = 0,
    int machineryApplied = 0,
    int conditionsApplied = 0,
  }) async {
    final storedData = <String, dynamic>{
      if (selectedHardFields.isNotEmpty) 'hard_fields': selectedHardFields,
      if (vesselData?.isNotEmpty == true) 'vessel_data': vesselData,
      if (unmappedFields?.isNotEmpty == true) 'unmapped_fields': unmappedFields,
      if (contextFindings.isNotEmpty) 'context_findings': contextFindings,
      if (detectedIncidents.isNotEmpty) 'detected_incidents': detectedIncidents,
      if (detectedMachinery.isNotEmpty) 'detected_machinery': detectedMachinery,
      if (detectedClassConditions.isNotEmpty)
        'detected_class_conditions': detectedClassConditions,
      'meta': {
        'findings_applied': findingsApplied,
        'incidents_applied': incidentsApplied,
        'machinery_applied': machineryApplied,
        'conditions_applied': conditionsApplied,
        'findings_total': contextFindings.length,
        'incidents_total': detectedIncidents.length,
        'machinery_total': detectedMachinery.length,
        'conditions_total': detectedClassConditions.length,
      },
    };

    // The document's own content date — not the import/created_at timestamp
    // — was extracted into hard_fields.document_date but never written back
    // onto the document record itself (docDate stayed permanently null).
    // Timeline's Full Log needs this to be a real queryable field, not
    // something buried in extracted_data jsonb (14 July 2026 walkthrough).
    final docDateRaw = selectedHardFields['document_date']?.toString();
    final docDate =
        docDateRaw != null ? DateTime.tryParse(docDateRaw) : null;

    await SupabaseService.client.from('documents').update({
      'extracted_data': storedData,
      'pending_extraction': null,
      'ai_extracted': true,
      'extraction_status': 'completed',
      if (docDate != null)
        'doc_date': docDate.toIso8601String().split('T').first,
    }).eq('doc_id', docId);

    final current = state.value ?? [];
    state = AsyncData(current.map((d) {
      if (d.docId != docId) return d;
      return d.copyWith(
        extractedData: storedData,
        pendingExtraction: null,
        aiExtracted: true,
        extractionStatus: 'completed',
        docDate: docDate ?? d.docDate,
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
    DateTime? requestedDate,
  }) async {
    final effectiveRequestedDate = availability == DocAvailability.requested
        ? (requestedDate ?? DateTime.now())
        : requestedDate;
    final data = await SupabaseService.client
        .from('documents')
        .insert({
          'case_id': caseId,
          'title': title,
          'doc_category': category?.value,
          'availability': availability.value,
          if (notes != null) 'notes': notes,
          if (effectiveRequestedDate != null)
            'requested_date':
                effectiveRequestedDate.toIso8601String().split('T').first,
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
          .update({'source_doc_id': null}).eq('source_doc_id', doc.docId);
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
    Object? annexureAssignment = _sentinel,
    bool? surveyorConfirmed,
    bool? isCoverPhoto,
    DocAvailability? availability,
    bool? includedInReport,
  }) async {
    final updates = <String, dynamic>{
      if (title != null) 'title': title,
      if (category != null) 'doc_category': category.value,
      if (!identical(annexureAssignment, _sentinel))
        'annexure_assignment': annexureAssignment as String?,
      if (surveyorConfirmed != null) 'surveyor_confirmed': surveyorConfirmed,
      if (isCoverPhoto != null) 'is_cover_photo': isCoverPhoto,
      if (availability != null) 'availability': availability.value,
      if (includedInReport != null) 'included_in_report': includedInReport,
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
        annexureAssignment: annexureAssignment,
        surveyorConfirmed: surveyorConfirmed,
        isCoverPhoto: isCoverPhoto,
        availability: availability,
        includedInReport: includedInReport,
      );
    }).toList());
  }

  /// Sets this document as the sole cover photo for the case.
  /// Clears the flag on every other doc first (DB + local state).
  Future<void> setCoverPhoto(String docId) async {
    // Clear the flag on any previously designated cover photo
    await SupabaseService.client
        .from('documents')
        .update({'is_cover_photo': false})
        .eq('case_id', arg)
        .neq('doc_id', docId);
    // Set on the chosen doc
    await SupabaseService.client
        .from('documents')
        .update({'is_cover_photo': true}).eq('doc_id', docId);
    final current = state.value ?? [];
    state = AsyncData(current.map((d) {
      return d.copyWith(isCoverPhoto: d.docId == docId);
    }).toList());
  }

  /// Clears the cover photo flag on all docs for this case.
  Future<void> clearCoverPhoto() async {
    await SupabaseService.client
        .from('documents')
        .update({'is_cover_photo': false}).eq('case_id', arg);
    final current = state.value ?? [];
    state =
        AsyncData(current.map((d) => d.copyWith(isCoverPhoto: false)).toList());
  }

  Future<void> renameDocument(String docId, String newTitle) async {
    await SupabaseService.client
        .from('documents')
        .update({'title': newTitle}).eq('doc_id', docId);
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
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'á': 'a',
    'ã': 'a',
    'å': 'a',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'í': 'i',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'ó': 'o',
    'õ': 'o',
    'ø': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ú': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'ç': 'c',
    'ñ': 'n',
    'ß': 'ss',
    'À': 'A',
    'Â': 'A',
    'Ä': 'A',
    'Á': 'A',
    'Ã': 'A',
    'Å': 'A',
    'È': 'E',
    'É': 'E',
    'Ê': 'E',
    'Ë': 'E',
    'Ì': 'I',
    'Î': 'I',
    'Ï': 'I',
    'Í': 'I',
    'Ò': 'O',
    'Ô': 'O',
    'Ö': 'O',
    'Ó': 'O',
    'Õ': 'O',
    'Ø': 'O',
    'Ù': 'U',
    'Û': 'U',
    'Ü': 'U',
    'Ú': 'U',
    'Ç': 'C',
    'Ñ': 'N',
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
