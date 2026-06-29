import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:uuid/uuid.dart';
import '../models/accounts_models.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/api/claude_api.dart';
import '../../surveyor_notes/models/surveyor_note_model.dart';
import '../../surveyor_notes/providers/surveyor_notes_provider.dart';

const _uuid = Uuid();

// ── Providers ──────────────────────────────────────────────────────────────

final repairDocumentsProvider = AsyncNotifierProviderFamily<
    RepairDocumentsNotifier, List<RepairDocumentModel>, String>(
  RepairDocumentsNotifier.new,
);

// ── Notifier ───────────────────────────────────────────────────────────────

class RepairDocumentsNotifier
    extends FamilyAsyncNotifier<List<RepairDocumentModel>, String> {
  String get _caseId => arg;

  @override
  Future<List<RepairDocumentModel>> build(String caseId) => _fetch();

  Future<List<RepairDocumentModel>> _fetch() async {
    final docs = await SupabaseService.client
        .from('repair_documents')
        .select()
        .eq('case_id', _caseId)
        .order('created_at', ascending: false);

    final lines = await SupabaseService.client
        .from('account_lines')
        .select()
        .eq('case_id', _caseId)
        .order('line_order');

    final linesByDoc = <String, List<AccountLineModel>>{};
    for (final j in lines as List) {
      final m = AccountLineModel.fromJson(j as Map<String, dynamic>);
      linesByDoc.putIfAbsent(m.documentId, () => []).add(m);
    }

    return (docs as List)
        .map((j) => RepairDocumentModel.fromJson(
              j as Map<String, dynamic>,
              accountLines: linesByDoc[j['id'] as String] ?? [],
            ))
        .toList();
  }

  /// Upload a file and create a bare document record — no AI extraction yet.
  ///
  /// [thumbnailBytes] – optional pre-built PNG thumbnail (e.g. from
  ///   perspective correction). When provided, skips PDF rendering and uses
  ///   these bytes directly.
  /// [displayName] – optional human-readable name; falls back to [filename].
  Future<RepairDocumentModel> importPdf({
    required List<int> bytes,
    required String filename,
    required String mimeType,
    Uint8List? thumbnailBytes,
    String? displayName,
  }) async {
    debugPrint('[AccountsProvider] importPdf — caseId: $_caseId  file: $filename  size: ${bytes.length}');
    final storagePath =
        '$_caseId/accounts/${DateTime.now().millisecondsSinceEpoch}_$filename';
    debugPrint('[AccountsProvider] uploading to: $storagePath');
    await SupabaseService.uploadFile(
      bucket: 'documents',
      path: storagePath,
      bytes: bytes,
      mimeType: mimeType,
    );
    debugPrint('[AccountsProvider] upload done, inserting DB row…');

    final docData = await SupabaseService.client
        .from('repair_documents')
        .insert({
          'case_id':           _caseId,
          'display_name':      displayName ?? filename,
          'surveyor_status':   'pending_review',
          'source_pdf_path':   storagePath,
          'without_prejudice': true,
          'mixed_nature_flag': false,
          'submitted_to_insurance': true,
        })
        .select()
        .single();

    debugPrint('[AccountsProvider] DB insert OK — id: ${docData['id']}');
    final doc = RepairDocumentModel.fromJson(docData);
    final current = state.value ?? [];
    state = AsyncData([doc, ...current]);

    if (thumbnailBytes != null) {
      unawaited(_saveThumbnail(thumbnailBytes, doc.id));
    } else {
      unawaited(_generateAndSaveThumbnail(bytes, doc.id));
    }
    return doc;
  }

  /// Upload pre-built PNG thumbnail bytes and update the DB record.
  Future<void> _saveThumbnail(Uint8List pngBytes, String docId) async {
    try {
      final thumbPath = '$_caseId/accounts/thumbs/$docId.png';
      await SupabaseService.uploadFile(
        bucket: 'documents',
        path: thumbPath,
        bytes: pngBytes,
        mimeType: 'image/png',
      );
      await SupabaseService.client
          .from('repair_documents')
          .update({'thumbnail_path': thumbPath})
          .eq('id', docId);

      if (state.value != null) {
        state = AsyncData(
          state.value!.map((d) {
            if (d.id != docId) return d;
            return RepairDocumentModel.fromJson(
                {..._docToJson(d), 'thumbnail_path': thumbPath});
          }).toList(),
        );
      }
      debugPrint('[AccountsProvider] thumbnail saved: $thumbPath');
    } catch (e) {
      debugPrint('[AccountsProvider] thumbnail save failed: $e');
    }
  }

  /// Render page 1 of a PDF and save it as a PNG thumbnail to Supabase.
  Future<void> _generateAndSaveThumbnail(List<int> bytes, String docId) async {
    try {
      final pdfDoc = await PdfDocument.openData(Uint8List.fromList(bytes));
      if (pdfDoc.pages.isEmpty) { await pdfDoc.dispose(); return; }
      final page = pdfDoc.pages.first;
      const thumbW = 300.0;
      final thumbH = thumbW * page.height / page.width;
      final pdfImage = await page.render(fullWidth: thumbW, fullHeight: thumbH);
      await pdfDoc.dispose();
      if (pdfImage == null) return;

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pdfImage.pixels, pdfImage.width, pdfImage.height,
        ui.PixelFormat.rgba8888, completer.complete,
      );
      final uiImage = await completer.future;
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      uiImage.dispose();
      if (byteData == null) return;

      await _saveThumbnail(byteData.buffer.asUint8List(), docId);
    } catch (e) {
      debugPrint('[AccountsProvider] thumbnail generation failed: $e');
    }
  }

  /// Run AI extraction on an already-imported document.
  /// Downloads the PDF from storage, calls Claude, updates the record and
  /// replaces all account lines.
  Future<void> extractWithAI(String docId) async {
    final doc = (state.value ?? []).firstWhere((d) => d.id == docId);
    if (doc.sourcePdfPath == null) throw Exception('No PDF on record');

    // Download from Supabase storage
    final signedUrl = await SupabaseService.getSignedUrl(
        'documents', doc.sourcePdfPath!);
    final response = await Dio().get<List<int>>(
      signedUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data!;

    // Detect mime type from path
    final ext = doc.sourcePdfPath!.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png'           => 'image/png',
      _               => 'application/pdf',
    };

    final base64Content = base64Encode(bytes);
    final extracted = await ClaudeApi.extractInvoiceData(
      base64Content: base64Content,
      mediaType: mimeType,
    );

    // Parse and build auto display name
    final docNumber = extracted['document_number'] as String?;
    final supplier  = extracted['supplier_name'] as String?;
    final rawDate   = extracted['document_date'] as String?;
    final docDate   = rawDate != null ? DateTime.tryParse(rawDate) : null;
    final autoName = [
      docNumber?.isNotEmpty == true ? docNumber : null,
      supplier?.isNotEmpty == true  ? supplier  : null,
      docDate != null
          ? '${docDate.day.toString().padLeft(2, '0')}/'
            '${docDate.month.toString().padLeft(2, '0')}/'
            '${docDate.year}'
          : null,
    ].where((s) => s != null).join(' — ');

    // Update document row
    await SupabaseService.client.from('repair_documents').update({
      'display_name':          autoName.isNotEmpty ? autoName : doc.displayName,
      'document_type':         extracted['document_type'] ?? 'invoice',
      'document_number':       docNumber,
      'document_date':         rawDate,
      'contract_ref':          extracted['contract_ref'],
      'supplier_name':         supplier,
      'supplier_category':     extracted['supplier_category'] ?? 'other',
      'currency':              extracted['currency'] ?? 'AUD',
      'subtotal_ex_tax':       extracted['subtotal_ex_tax'],
      'tax_total':             extracted['tax_total'],
      'total_inc_tax':         extracted['total_inc_tax'],
      'mixed_nature_flag':     extracted['mixed_nature_flag'] ?? false,
      'ai_presentation_draft': extracted['ai_presentation_draft'],
      'ai_extracted_at':       DateTime.now().toIso8601String(),
      'ai_confidence':         extracted['confidence'],
      'raw_lines_json':        jsonEncode(extracted['raw_lines'] ?? []),
    }).eq('id', docId);

    // Replace account lines: delete existing, insert new
    await SupabaseService.client
        .from('account_lines')
        .delete()
        .eq('document_id', docId);

    final rawLines =
        (extracted['account_lines'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    for (var i = 0; i < rawLines.length; i++) {
      final rl = rawLines[i];
      await SupabaseService.client.from('account_lines').insert({
        'document_id':           docId,
        'case_id':               _caseId,
        'line_order':            i,
        'item_number':           (rl['item_number'] as num?)?.toInt() ?? (i + 1),
        'description':           rl['description'],
        'cost_nature':           rl['cost_nature'] ?? 'service_technician',
        'gross_amount':          (rl['gross_amount'] as num?)?.toDouble() ?? 0.0,
        'surveyor_status':       'pending_review',
        'ai_presentation_draft': rl['owners_note'],
        if (rl['repair_period_id'] != null)
          'repair_period_id': rl['repair_period_id'],
        if (rl['occurrence_id'] != null)
          'occurrence_id': rl['occurrence_id'],
      });
    }

    // Refresh state
    state = AsyncData(await _fetch());
  }

  /// Downloads the source document, asks Claude to extract non-accounting
  /// observations (timesheets, hours, scope notes, etc.) and saves each one
  /// as a SurveyorNote linked back to this document.
  /// Returns the number of cues created.
  Future<int> extractContextCues(String docId) async {
    final doc = (state.value ?? []).firstWhere((d) => d.id == docId);
    if (doc.sourcePdfPath == null) throw Exception('No source document on record');

    final signedUrl = await SupabaseService.getSignedUrl(
        'documents', doc.sourcePdfPath!);
    final response = await Dio().get<List<int>>(
      signedUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data!;

    final ext = doc.sourcePdfPath!.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png'           => 'image/png',
      _               => 'application/pdf',
    };

    final cues = await ClaudeApi.extractInvoiceContextCues(
      base64Content: base64Encode(bytes),
      mediaType: mimeType,
    );

    final notesNotifier =
        ref.read(surveyorNotesProvider(doc.caseId).notifier);
    for (final cue in cues) {
      final priority = (cue['priority'] as String?) == 'important'
          ? CuePriority.important
          : CuePriority.normal;
      await notesNotifier.add(
        caseId:      doc.caseId,
        content:     cue['content'] as String,
        category:    NoteCategory.invoicing,
        priority:    priority,
        linkedToType: 'repair_document',
        linkedToId:   docId,
        source:       doc.effectiveName,
      );
    }
    return cues.length;
  }

  /// Update document-level fields (status, presentation statement, notes, etc.)
  Future<void> updateDocument(String docId, Map<String, dynamic> fields) async {
    await SupabaseService.client
        .from('repair_documents')
        .update(fields)
        .eq('id', docId);
    state = AsyncData(await _fetch());
  }

  Future<void> deleteDocument(String docId) async {
    await SupabaseService.client
        .from('repair_documents')
        .delete()
        .eq('id', docId);
    final current = state.value ?? [];
    state = AsyncData(current.where((d) => d.id != docId).toList());
  }

  Future<void> addAccountLine(AccountLineModel line) async {
    final data = await SupabaseService.client
        .from('account_lines')
        .insert(line.toInsertJson())
        .select()
        .single();
    final newLine = AccountLineModel.fromJson(data);
    state = AsyncData(
      (state.value ?? []).map((doc) {
        if (doc.id != line.documentId) return doc;
        return RepairDocumentModel.fromJson(
          _docToJson(doc),
          accountLines: [...doc.accountLines, newLine],
        );
      }).toList(),
    );
  }

  Future<void> updateAccountLine(AccountLineModel line) async {
    await SupabaseService.client
        .from('account_lines')
        .update({
          'description':            line.description,
          'cost_nature':            line.costNature.value,
          'gross_amount':           line.grossAmount,
          'owners_portion':         line.ownersPortion,
          'underwriters_portion':   line.underwritersPortion,
          'betterment_deduction':   line.bettermentDeduction,
          'apportionment_notes':    line.apportionmentNotes,
          'apportionment_type':     line.apportionmentType,
          'apportionment_value':    line.apportionmentValue,
          'surveyor_status':        line.status.value,
          'presentation_statement': line.presentationStatement,
          'repair_period_id':       line.repairPeriodId,
          'occurrence_id':          line.occurrenceId,
        })
        .eq('id', line.id);
    state = AsyncData(
      (state.value ?? []).map((doc) {
        if (doc.id != line.documentId) return doc;
        return RepairDocumentModel.fromJson(
          _docToJson(doc),
          accountLines: doc.accountLines
              .map((l) => l.id == line.id ? line : l)
              .toList(),
        );
      }).toList(),
    );
  }

  Future<void> deleteAccountLine(String lineId, String docId) async {
    await SupabaseService.client
        .from('account_lines')
        .delete()
        .eq('id', lineId);
    state = AsyncData(
      (state.value ?? []).map((doc) {
        if (doc.id != docId) return doc;
        return RepairDocumentModel.fromJson(
          _docToJson(doc),
          accountLines: doc.accountLines.where((l) => l.id != lineId).toList(),
        );
      }).toList(),
    );
  }

  /// Create records for each confirmed segment from a batch PDF analysis.
  /// [storagePath] is the already-uploaded full PDF path.
  Future<List<RepairDocumentModel>> importBatchSegments({
    required String storagePath,
    required List<BatchInvoiceSegment> segments,
  }) async {
    final created = <RepairDocumentModel>[];
    for (final seg in segments) {
      final parts = [seg.invoiceNumber, seg.supplierName]
          .where((s) => s != null && s!.isNotEmpty)
          .join(' — ');
      final autoName = parts.isNotEmpty ? parts : 'Document ${seg.index + 1}';

      final docData = await SupabaseService.client
          .from('repair_documents')
          .insert({
            'case_id':               _caseId,
            'display_name':          autoName,
            'document_number':       seg.invoiceNumber,
            'document_date':         seg.date,
            'supplier_name':         seg.supplierName,
            'currency':              seg.currency ?? 'AUD',
            'total_inc_tax':         seg.totalAmount,
            'surveyor_status':       'pending_review',
            'source_pdf_path':       storagePath,
            'page_start':            seg.pageStart,
            'page_end':              seg.pageEnd,
            'submitted_to_insurance':seg.submittedToInsurance,
            'without_prejudice':     true,
            'mixed_nature_flag':     false,
          })
          .select()
          .single();

      created.add(RepairDocumentModel.fromJson(docData));
    }

    final current = state.value ?? [];
    state = AsyncData([...created, ...current]);
    return created;
  }

  // Serialize a document back to a minimal map for in-memory reconstruction.
  static Map<String, dynamic> _docToJson(RepairDocumentModel d) => {
        'id':                    d.id,
        'case_id':               d.caseId,
        'display_name':          d.displayName,
        'document_type':         d.documentType.value,
        'document_number':       d.documentNumber,
        'document_date':         d.documentDate?.toIso8601String(),
        'contract_ref':          d.contractRef,
        'supplier_name':         d.supplierName,
        'supplier_category':     d.supplierCategory.value,
        'currency':              d.currency,
        'subtotal_ex_tax':       d.subtotalExTax,
        'tax_total':             d.taxTotal,
        'total_inc_tax':         d.totalIncTax,
        'mixed_nature_flag':     d.mixedNatureFlag,
        'without_prejudice':     d.withoutPrejudice,
        'ai_presentation_draft': d.aiPresentationDraft,
        'presentation_statement':d.presentationStatement,
        'surveyor_status':       d.status.value,
        'surveyor_notes':        d.surveyorNotes,
        'source_pdf_path':       d.sourcePdfPath,
        'ai_extracted_at':       d.aiExtractedAt?.toIso8601String(),
        'ai_confidence':         d.aiConfidence,
        'page_start':            d.pageStart,
        'page_end':              d.pageEnd,
        'submitted_to_insurance':d.submittedToInsurance,
        'rejection_reason':      d.rejectionReason,
        'thumbnail_path':        d.thumbnailPath,
        'created_at':            d.createdAt?.toIso8601String(),
      };
}

