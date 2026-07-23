// lib/features/correspondence/providers/correspondence_provider.dart
//
// Drive-backed unified storage (2026-07-05): Supabase is the authoritative
// metadata store (same offline-cache/write-queue pattern as
// surveyor_notes_provider.dart / photo_provider.dart), the file itself
// (.eml or .pdf) is uploaded to Google Drive (DriveStorageService) as the
// canonical cross-platform copy, and native platforms additionally keep a
// local file cache for fast offline access (local_path — per-device, never
// synced).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/supabase_client.dart';
import '../../../core/api/claude_api.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/drive_storage_service.dart';
import '../../../core/utils/drive_filename.dart';
import '../../../core/utils/eml_parser.dart';
import '../../cases/models/case_model.dart';
import '../../cases/providers/cases_provider.dart';
import '../../ai_tasks/providers/ai_tasks_provider.dart';
// Correspondence extraction now produces the SHARED extraction result and
// opens the SAME review sheet + apply as documents (ExtractionReviewSheet).
import '../../documents/providers/document_provider.dart';
import '../models/correspondence_model.dart';

const _uuid = Uuid();
const _table = 'correspondence';

final correspondenceProvider = AsyncNotifierProviderFamily<
    CorrespondenceNotifier, List<CorrespondenceModel>, String>(
  CorrespondenceNotifier.new,
);

class CorrespondenceNotifier
    extends FamilyAsyncNotifier<List<CorrespondenceModel>, String> {
  String get _caseId => arg;

  // Bumped on every direct _insert()/delete() (single/bulk import, PDF add,
  // deleting an item). _refresh() captures this at the start of its
  // (slow — network fetch + local merge) run and skips applying its result
  // if it changed in the meantime, i.e. a manual mutation landed while the
  // refresh was in flight. Without this, a _refresh() that was already
  // running (kicked off in build(), or by a connectivity event) can finish
  // *after* a bulk Gmail import, using a Supabase snapshot taken *before*
  // the import — its merge step then deletes the freshly-inserted (already
  // 'synced') local rows because they're absent from that stale snapshot,
  // wiping them from the list until the next screen open triggers a fresh,
  // up-to-date refresh. The same race can resurrect a just-deleted item.
  int _mutationGeneration = 0;

  // Ids already run through the auto-extraction sweep this session, so a
  // rebuild / refresh / connectivity event doesn't re-fire a (paid) Claude
  // call on an item that already had one queued. See [autoExtractPending].
  final Set<String> _autoExtractHandled = {};

  @override
  Future<List<CorrespondenceModel>> build(String caseId) async {
    ref.listen<AsyncValue<bool>>(connectivityProvider, (_, next) {
      if (next.value == true) _refresh();
    });
    if (kIsWeb) {
      final rows = await _fetchSupabase(caseId);
      // state isn't set yet inside build(); sweep after it lands.
      Future.microtask(autoExtractPending);
      return rows;
    }
    _refresh();
    final rows = await _fetchOffline(caseId);
    Future.microtask(autoExtractPending);
    return rows;
  }

  // ── Supabase (canonical metadata) ─────────────────────────────────────────

  Future<List<CorrespondenceModel>> _fetchSupabase(String caseId) async {
    final rows = await SupabaseService.client
        .from(_table)
        .select()
        .eq('case_id', caseId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) =>
            CorrespondenceModel.fromSupabaseMap(r as Map<String, dynamic>))
        .toList();
  }

  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    final startGeneration = _mutationGeneration;
    try {
      if (kIsWeb) {
        final fetched = await _fetchSupabase(_caseId);
        if (_mutationGeneration != startGeneration) return;
        state = AsyncData(fetched);
        unawaited(autoExtractPending());
        return;
      }
      await _syncPending();
      final remote = await _fetchSupabase(_caseId);
      if (_mutationGeneration != startGeneration) return;
      await _mergeIntoLocalCache(remote);
      final offline = await _fetchOffline(_caseId);
      if (_mutationGeneration != startGeneration) return;
      state = AsyncData(offline);
      unawaited(autoExtractPending());
    } catch (e, st) {
      debugPrint('CorrespondenceNotifier._refresh error: $e\n$st');
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _mergeIntoLocalCache(
      List<CorrespondenceModel> remoteRows) async {
    final db = await AppDatabase.instance.database;
    for (final remote in remoteRows) {
      final existingRows =
          await db.query(_table, where: 'id = ?', whereArgs: [remote.id]);
      if (existingRows.isEmpty) {
        await db.insert(_table, {...remote.toMap(), 'sync_status': 'synced'});
        continue;
      }
      final existingRow = existingRows.first;
      if (existingRow['sync_status'] == 'pending_upsert') continue;
      final existing = CorrespondenceModel.fromMap(existingRow);
      final merged = remote.copyWith(localPath: existing.localPath);
      await db.update(_table, {...merged.toMap(), 'sync_status': 'synced'},
          where: 'id = ?', whereArgs: [remote.id]);
    }

    final remoteIds = remoteRows.map((r) => r.id).toSet();
    final localRows =
        await db.query(_table, where: 'case_id = ?', whereArgs: [_caseId]);
    for (final row in localRows) {
      final id = row['id'] as String;
      if (!remoteIds.contains(id) && row['sync_status'] == 'synced') {
        await db.delete(_table, where: 'id = ?', whereArgs: [id]);
      }
    }
  }

  Future<void> _syncPending() async {
    final db = await AppDatabase.instance.database;

    final toUpsert = await db.query(_table,
        where: 'case_id = ? AND sync_status = ?',
        whereArgs: [_caseId, 'pending_upsert']);
    for (final row in toUpsert) {
      try {
        final corr = CorrespondenceModel.fromMap(row);
        await SupabaseService.client
            .from(_table)
            .upsert(corr.toSupabaseMap(), onConflict: 'id');
        await db.update(_table, {'sync_status': 'synced'},
            where: 'id = ?', whereArgs: [corr.id]);
      } catch (_) {
        return;
      }
    }

    final toDelete = await db.query(_table,
        where: 'case_id = ? AND sync_status = ?',
        whereArgs: [_caseId, 'pending_delete']);
    for (final row in toDelete) {
      final id = row['id'] as String;
      try {
        await SupabaseService.client.from(_table).delete().eq('id', id);
        await db.delete(_table, where: 'id = ?', whereArgs: [id]);
      } catch (_) {
        return;
      }
    }
  }

  Future<List<CorrespondenceModel>> _fetchOffline(String caseId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      _table,
      where: 'case_id = ?',
      whereArgs: [caseId],
      orderBy: 'created_at DESC',
    );
    return rows.map(CorrespondenceModel.fromMap).toList();
  }

  Future<CaseModel> _fetchCaseModel(String caseId) async {
    final cached = ref.read(caseProvider(caseId)).value;
    if (cached != null) return cached;
    final row = await SupabaseService.client
        .from('cases')
        .select('*, vessels(name)')
        .eq('case_id', caseId)
        .single();
    final vessel = row['vessels'] as Map<String, dynamic>?;
    return CaseModel.fromJson({...row, 'vessel_name': vessel?['name']});
  }

  // ── Public mutations ──────────────────────────────────────────────────────

  /// Copy a PDF from [bytes] into local storage (native) + Drive (unified
  /// storage), and create a Supabase + local cache record.
  Future<CorrespondenceModel> addFromBytes({
    required String caseId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final id = _uuid.v4();
    final ext =
        filename.contains('.') ? filename.split('.').last.toLowerCase() : 'pdf';

    String? localPath;
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      final corrDir =
          Directory(p.join(dir.path, 'cases', caseId, 'correspondence'));
      await corrDir.create(recursive: true);
      localPath = p.join(corrDir.path, '$id.$ext');
      await File(localPath).writeAsBytes(bytes);
    }

    String? driveFileId;
    try {
      final caseModel = await _fetchCaseModel(caseId);
      driveFileId = await DriveStorageService.uploadCaseFile(
        caseModel: caseModel,
        category: CaseFileCategory.correspondence,
        bytes: bytes,
        filename: filename,
        mimeType: ext == 'pdf' ? 'application/pdf' : 'application/octet-stream',
      );
    } catch (e) {
      debugPrint('Drive correspondence upload skipped: $e');
    }

    final corr = CorrespondenceModel(
      id: id,
      caseId: caseId,
      title: filename,
      localPath: localPath,
      fileType: ext,
      fileSizeKb: bytes.length / 1024,
      driveFileId: driveFileId,
      createdAt: DateTime.now(),
    );

    await _insert(corr);
    return corr;
  }

  /// Parse an EML file, save it locally (native) + Drive, and create a
  /// Supabase + local cache record. Returns the record plus the list of
  /// attachments found in the email.
  Future<(CorrespondenceModel, List<EmlAttachment>)> importEml({
    required String caseId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final msg = EmlParser.parse(bytes);
    final id = _uuid.v4();

    String? localPath;
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      final corrDir =
          Directory(p.join(dir.path, 'cases', caseId, 'correspondence'));
      await corrDir.create(recursive: true);
      localPath = p.join(corrDir.path, '$id.eml');
      await File(localPath).writeAsBytes(bytes);
    }

    String? driveFileId;
    try {
      final caseModel = await _fetchCaseModel(caseId);
      final dateStr = msg.date != null
          ? '${msg.date!.year}-${msg.date!.month.toString().padLeft(2, '0')}-${msg.date!.day.toString().padLeft(2, '0')}'
          : null;
      driveFileId = await DriveStorageService.uploadCaseFile(
        caseModel: caseModel,
        category: CaseFileCategory.correspondence,
        bytes: bytes,
        filename: buildDriveFilename([dateStr, msg.from, msg.subject], 'eml'),
        mimeType: 'message/rfc822',
      );
    } catch (e) {
      debugPrint('Drive correspondence upload skipped: $e');
    }

    final corr = CorrespondenceModel(
      id: id,
      caseId: caseId,
      title: msg.subject,
      sender: msg.from.isNotEmpty ? msg.from : null,
      recipient: msg.to.isNotEmpty ? msg.to : null,
      corrDate: msg.date,
      localPath: localPath,
      fileType: 'eml',
      bodyText: msg.plainBody.isNotEmpty ? msg.plainBody : null,
      fileSizeKb: bytes.length / 1024,
      driveFileId: driveFileId,
      createdAt: DateTime.now(),
    );

    await _insert(corr);
    return (corr, msg.attachments);
  }

  Future<void> _insert(CorrespondenceModel corr) async {
    _mutationGeneration++;
    var syncStatus = 'pending_upsert';
    try {
      await SupabaseService.client.from(_table).insert(corr.toSupabaseMap());
      syncStatus = 'synced';
    } catch (_) {
      // Offline — queued for _syncPending to pick up later.
    }

    if (!kIsWeb) {
      final db = await AppDatabase.instance.database;
      await db.insert(_table, {...corr.toMap(), 'sync_status': syncStatus});
    }

    final current = state.value ?? [];
    state = AsyncData([corr, ...current]);

    // Auto-queue AI extraction for the freshly imported item so the surveyor
    // only reviews the result rather than tapping Extract on each (16 July
    // 2026 reports). Fire-and-forget through the shared aiTasks queue.
    unawaited(autoExtractPending());
  }

  /// Auto-queues AI extraction for every still-"Not extracted" imported item
  /// so the surveyor only reviews results instead of tapping Extract on each
  /// (16 July 2026 reports). Runs each pending item through the same [extract]
  /// path — and therefore the shared aiTasksProvider queue — once per session
  /// per item, sequentially so a batch import doesn't fire a dozen parallel
  /// Claude calls. Best-effort: a failure just leaves that item marked failed
  /// (extract() already does that) and the sweep moves on.
  Future<void> autoExtractPending() async {
    final items = List<CorrespondenceModel>.from(state.value ?? const []);
    for (final c in items) {
      if (c.status != CorrStatus.pending) continue;
      if (_autoExtractHandled.contains(c.id)) continue;
      // Only extract what we can actually read here: an EML with body text
      // works via the text path (incl. web); PDFs need a local/Drive file and
      // only extract off-web (web has no local cache to stream from).
      final eligible = (c.isEml && (c.bodyText?.isNotEmpty ?? false)) ||
          (!kIsWeb && (c.hasLocalFile || c.driveFileId != null));
      if (!eligible) continue;
      _autoExtractHandled.add(c.id);
      // Skip if it's already been picked up (e.g. a manual Extract in flight).
      final live = (state.value ?? const [])
          .firstWhere((x) => x.id == c.id, orElse: () => c);
      if (live.status != CorrStatus.pending) continue;
      try {
        await extract(c.id);
      } catch (_) {
        // extract() already set status=failed and logged; keep sweeping.
      }
    }
  }

  /// Downloads the file from Drive and caches it locally — for viewing a
  /// correspondence synced from another device (or a fresh install) with no
  /// local file yet. No-op on web or if there's no Drive copy to fetch.
  Future<CorrespondenceModel?> ensureLocalFile(String corrId) async {
    if (kIsWeb) return null;
    final current = state.value ?? [];
    final corr = current.firstWhere((c) => c.id == corrId);
    if (corr.hasLocalFile || corr.driveFileId == null) return corr;

    final bytes = await DriveStorageService.downloadFile(corr.driveFileId!);
    final dir = await getApplicationDocumentsDirectory();
    final corrDir =
        Directory(p.join(dir.path, 'cases', corr.caseId, 'correspondence'));
    await corrDir.create(recursive: true);
    final localPath = p.join(corrDir.path, '$corrId.${corr.fileType}');
    await File(localPath).writeAsBytes(bytes);

    final updated = corr.copyWith(localPath: localPath);
    final db = await AppDatabase.instance.database;
    await db
        .update(_table, updated.toMap(), where: 'id = ?', whereArgs: [corrId]);
    _updateState((c) => c.id == corrId ? updated : c);
    return updated;
  }

  /// Run Claude extraction on an uploaded PDF or imported EML, mapping it into
  /// the SHARED extraction shape (DocExtractionResult) so the caller opens the
  /// same ExtractionReviewSheet as documents. Also persists it to
  /// correspondence.pending_extraction for the review-later path.
  Future<DocExtractionResult?> extract(String corrId) async {
    _setStatus(corrId, CorrStatus.processing);
    try {
      var current = state.value ?? [];
      var corr = current.firstWhere((c) => c.id == corrId);
      if (!corr.hasLocalFile) {
        corr = await ensureLocalFile(corrId) ?? corr;
      }

      Map<String, dynamic> result;
      if (corr.isEml && corr.bodyText != null) {
        result = await ref.read(aiTasksProvider.notifier).run(
              label: 'Extracting "${corr.title}"',
              caseId: corr.caseId,
              estimate: const Duration(seconds: 15),
              action: () => ClaudeApi.extractCorrespondenceFromText(
                subject: corr.title,
                bodyText: corr.bodyText!,
                from: corr.sender,
                to: corr.recipient,
              ),
            );
      } else {
        if (!corr.hasLocalFile) {
          throw Exception('Correspondence file not available');
        }
        final bytes = await File(corr.localPath!).readAsBytes();
        final base64Pdf = base64Encode(bytes);
        result = await ref.read(aiTasksProvider.notifier).run(
              label: 'Extracting "${corr.title}"',
              caseId: corr.caseId,
              estimate: const Duration(seconds: 20),
              action: () => ClaudeApi.extractCorrespondence(
                base64Pdf: base64Pdf,
                filename: corr.title,
              ),
            );
      }

      final extraction = DocExtractionResult.fromCorrespondence(corrId, result);

      // Cache a few display fields on the correspondence row (card + summary).
      final parties = (result['parties'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ExtractedParty.fromMap(e.cast<String, dynamic>()))
          .toList();
      final keyDatesDisplay = (result['key_dates'] as List? ?? [])
          .map((e) => e is Map
              ? [e['date'], e['description']]
                  .map((x) => x?.toString())
                  .whereType<String>()
                  .where((s) => s.trim().isNotEmpty)
                  .join(' — ')
              : e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
      final corrDate = (result['corr_date'] is String)
          ? DateTime.tryParse(result['corr_date'] as String)
          : null;

      current = state.value ?? [];
      corr = current.firstWhere((c) => c.id == corrId);
      final updated = corr.copyWith(
        summary: result['summary'] as String?,
        sender: result['sender'] as String?,
        recipient: result['recipient'] as String?,
        corrDate: corrDate,
        parties: parties,
        actions: (result['action_items'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
        keyDates: keyDatesDisplay,
        status: CorrStatus.completed,
      );
      await _persist(updated);

      await _persistPendingExtraction(corrId, extraction);

      return extraction.hasAny ? extraction : null;
    } catch (e) {
      _setStatus(corrId, CorrStatus.failed);
      debugPrint('[CorrespondenceProvider] extraction failed for $corrId: $e');
      rethrow;
    }
  }

  Future<void> delete(String corrId) async {
    _mutationGeneration++;
    final current = state.value ?? [];
    final corr = current.firstWhere((c) => c.id == corrId);
    if (corr.localPath != null) {
      try {
        await File(corr.localPath!).delete();
      } catch (_) {}
    }

    var deleted = false;
    try {
      await SupabaseService.client.from(_table).delete().eq('id', corrId);
      deleted = true;
    } catch (_) {
      // Offline
    }

    if (!kIsWeb) {
      final db = await AppDatabase.instance.database;
      if (deleted) {
        await db.delete(_table, where: 'id = ?', whereArgs: [corrId]);
      } else {
        await db.update(_table, {'sync_status': 'pending_delete'},
            where: 'id = ?', whereArgs: [corrId]);
      }
    }

    state = AsyncData(current.where((c) => c.id != corrId).toList());
  }

  void _setStatus(String corrId, CorrStatus status) {
    _updateState((c) => c.id == corrId ? c.copyWith(status: status) : c);
    unawaited(_persistStatusOnly(corrId, status));
  }

  Future<void> _persistStatusOnly(String corrId, CorrStatus status) async {
    try {
      await SupabaseService.client
          .from(_table)
          .update({'status': status.value}).eq('id', corrId);
    } catch (_) {
      // Offline — the full _persist() call after extraction completes will
      // still queue a pending_upsert with the final status.
    }
    if (!kIsWeb) {
      final db = await AppDatabase.instance.database;
      await db.update(_table, {'status': status.value},
          where: 'id = ?', whereArgs: [corrId]);
    }
  }


  Future<void> _persistPendingExtraction(
      String corrId, DocExtractionResult r) async {
    try {
      await SupabaseService.client
          .from(_table)
          .update({'pending_extraction': r.toJson()}).eq('id', corrId);
    } catch (e) {
      debugPrint('[CorrespondenceProvider] persist pending_extraction failed: $e');
    }
  }

  Future<void> clearPendingExtraction(String corrId) async {
    try {
      await SupabaseService.client
          .from(_table)
          .update({'pending_extraction': null}).eq('id', corrId);
    } catch (_) {}
  }

  /// Load a previously-persisted extraction (review-later path).
  Future<DocExtractionResult?> pendingExtractionFor(String corrId) async {
    try {
      final row = await SupabaseService.client
          .from(_table)
          .select('pending_extraction')
          .eq('id', corrId)
          .maybeSingle();
      final raw = row?['pending_extraction'];
      if (raw is Map) {
        return DocExtractionResult.fromJson(raw.cast<String, dynamic>());
      }
    } catch (e) {
      debugPrint('[CorrespondenceProvider] load pending_extraction failed: $e');
    }
    return null;
  }

  Future<void> _persist(CorrespondenceModel corr) async {
    var syncStatus = 'pending_upsert';
    try {
      await SupabaseService.client
          .from(_table)
          .update(corr.toSupabaseMap())
          .eq('id', corr.id);
      syncStatus = 'synced';
    } catch (_) {
      // Offline
    }

    if (!kIsWeb) {
      final db = await AppDatabase.instance.database;
      await db.update(_table, {...corr.toMap(), 'sync_status': syncStatus},
          where: 'id = ?', whereArgs: [corr.id]);
    }

    _updateState((c) => c.id == corr.id ? corr : c);
  }

  void _updateState(
      CorrespondenceModel Function(CorrespondenceModel) transform) {
    final current = state.value ?? [];
    state = AsyncData(current.map(transform).toList());
  }
}
