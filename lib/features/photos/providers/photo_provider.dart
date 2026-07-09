// lib/features/photos/providers/photo_provider.dart
//
// Drive-backed unified storage (2026-07-05): Supabase is the authoritative
// metadata store (same offline-cache/write-queue pattern as
// surveyor_notes_provider.dart), the full-resolution original is uploaded to
// Google Drive (DriveStorageService) as the canonical cross-platform file,
// and native platforms additionally keep a local file cache for fast
// offline access (local_path/thumbnail_path — per-device, never synced).

import 'dart:io';
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/supabase_client.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/drive_storage_service.dart';
import '../../../core/utils/drive_filename.dart';
import '../../attendances/models/attendance_model.dart';
import '../../cases/models/case_model.dart';
import '../../cases/providers/cases_provider.dart';
import '../models/photo_model.dart';

const _uuid = Uuid();
const _table = 'photos';

final photosProvider =
    AsyncNotifierProviderFamily<PhotoNotifier, List<PhotoModel>, String>(
  PhotoNotifier.new,
);

class PhotoNotifier extends FamilyAsyncNotifier<List<PhotoModel>, String> {
  String get _caseId => arg;

  // See CorrespondenceNotifier._mutationGeneration (same offline-cache
  // pattern, same race): a _refresh() already in flight when a photo is
  // added/deleted can finish afterwards using a stale pre-mutation Supabase
  // snapshot, and its merge step then deletes/resurrects rows based on that
  // stale snapshot — wiping a just-added photo from the list until the case
  // is reopened. Bumped on addPhoto()/deletePhoto(); _refresh() bails out if
  // it changes mid-run instead of applying a stale result.
  int _mutationGeneration = 0;

  @override
  Future<List<PhotoModel>> build(String caseId) async {
    ref.listen<AsyncValue<bool>>(connectivityProvider, (_, next) {
      if (next.value == true) _refresh();
    });
    if (kIsWeb) {
      // No sqflite/dart:io on web — Supabase is fetched directly, no
      // offline cache/write-queue (matches surveyor_notes_provider).
      return _fetchSupabase(caseId);
    }
    // Return the local cache immediately, then refresh from Supabase.
    _refresh();
    return _fetchOffline(caseId);
  }

  // ── Supabase (canonical metadata) ─────────────────────────────────────────

  Future<List<PhotoModel>> _fetchSupabase(String caseId) async {
    final rows = await SupabaseService.client
        .from(_table)
        .select()
        .eq('case_id', caseId)
        .order('taken_at', ascending: false);
    return (rows as List)
        .map((r) => PhotoModel.fromSupabaseMap(r as Map<String, dynamic>))
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
        return;
      }
      await _syncPending();
      final remote = await _fetchSupabase(_caseId);
      if (_mutationGeneration != startGeneration) return;
      await _mergeIntoLocalCache(remote);
      final offline = await _fetchOffline(_caseId);
      if (_mutationGeneration != startGeneration) return;
      state = AsyncData(offline);
    } catch (e, st) {
      debugPrint('PhotoNotifier._refresh error: $e\n$st');
      // Keep whatever state is already shown.
    } finally {
      _refreshing = false;
    }
  }

  /// Writes remote rows into the local cache, preserving each row's
  /// per-device local_path/thumbnail_path and not clobbering an edit still
  /// queued for upload (local_sync_status == pending_upsert).
  Future<void> _mergeIntoLocalCache(List<PhotoModel> remoteRows) async {
    final db = await AppDatabase.instance.database;
    for (final remote in remoteRows) {
      final existingRows =
          await db.query(_table, where: 'id = ?', whereArgs: [remote.id]);
      if (existingRows.isEmpty) {
        await db.insert(_table, {
          ...remote.toMap(),
          'local_sync_status': 'synced',
        });
        continue;
      }
      final existingRow = existingRows.first;
      if (existingRow['local_sync_status'] == 'pending_upsert') continue;
      final existing = PhotoModel.fromMap(existingRow);
      final merged = remote.copyWith(
        localPath: existing.localPath,
        thumbnailPath: existing.thumbnailPath,
        syncStatus: existing.syncStatus, // preserve Google Photos state too
        remotePath: existing.remotePath,
      );
      await db.update(
          _table, {...merged.toMap(), 'local_sync_status': 'synced'},
          where: 'id = ?', whereArgs: [remote.id]);
    }

    // A photo synced elsewhere and since removed remotely — drop the local
    // cache row for it, unless it's a not-yet-uploaded local edit.
    final remoteIds = remoteRows.map((r) => r.id).toSet();
    final localRows =
        await db.query(_table, where: 'case_id = ?', whereArgs: [_caseId]);
    for (final row in localRows) {
      final id = row['id'] as String;
      if (!remoteIds.contains(id) && row['local_sync_status'] == 'synced') {
        await db.delete(_table, where: 'id = ?', whereArgs: [id]);
      }
    }
  }

  Future<void> _syncPending() async {
    final db = await AppDatabase.instance.database;

    final toUpsert = await db.query(_table,
        where: 'case_id = ? AND local_sync_status = ?',
        whereArgs: [_caseId, 'pending_upsert']);
    for (final row in toUpsert) {
      try {
        final photo = PhotoModel.fromMap(row);
        await SupabaseService.client
            .from(_table)
            .upsert(photo.toSupabaseMap(), onConflict: 'id');
        await db.update(_table, {'local_sync_status': 'synced'},
            where: 'id = ?', whereArgs: [photo.id]);
      } catch (_) {
        return; // Still offline — stop and retry later
      }
    }

    final toDelete = await db.query(_table,
        where: 'case_id = ? AND local_sync_status = ?',
        whereArgs: [_caseId, 'pending_delete']);
    for (final row in toDelete) {
      final id = row['id'] as String;
      try {
        await SupabaseService.client.from(_table).delete().eq('id', id);
        await db.delete(_table, where: 'id = ?', whereArgs: [id]);
      } catch (_) {
        return; // Still offline
      }
    }
  }

  // ── Local cache read + orphan recovery ────────────────────────────────────

  Future<List<PhotoModel>> _fetchOffline(String caseId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      _table,
      where: 'case_id = ?',
      whereArgs: [caseId],
      orderBy: 'taken_at DESC',
    );
    final fromDb = rows.map(PhotoModel.fromMap).toList();
    final recovered = await _recoverOrphanedFiles(caseId, fromDb, db);
    if (recovered.isEmpty) return fromDb;
    return [...recovered, ...fromDb]
      ..sort((a, b) => b.takenAt.compareTo(a.takenAt));
  }

  /// Scans the on-disk photos directory for .jpg files whose UUID is not in
  /// [existing]. Inserts a bare record for each so they reappear in the grid.
  /// This re-attaches photos that survived a DB schema wipe (version bump).
  Future<List<PhotoModel>> _recoverOrphanedFiles(
    String caseId,
    List<PhotoModel> existing,
    Database db,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(dir.path, 'cases', caseId, 'photos'));
    if (!photosDir.existsSync()) return [];

    final knownIds = existing.map((ph) => ph.id).toSet();
    final recovered = <PhotoModel>[];

    for (final entity in photosDir.listSync()) {
      if (entity is! File) continue;
      final name = p.basenameWithoutExtension(entity.path);
      if (!name.contains('-') || knownIds.contains(name)) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (ext != '.jpg' && ext != '.jpeg') continue;

      final thumbPath =
          p.join(dir.path, 'cases', caseId, 'thumbnails', '$name.jpg');
      final fileBytes = await entity.readAsBytes();
      final takenAt = await _exifDate(fileBytes) ?? entity.statSync().modified;

      final photo = PhotoModel(
        id: name,
        caseId: caseId,
        localPath: entity.path,
        thumbnailPath: File(thumbPath).existsSync() ? thumbPath : null,
        takenAt: takenAt,
      );
      try {
        await db.insert(
            _table, {...photo.toMap(), 'local_sync_status': 'pending_upsert'});
        recovered.add(photo);
      } catch (_) {
        // Already inserted by a concurrent call — skip.
      }
    }
    return recovered;
  }

  /// Extract DateTimeOriginal (or fallback fields) from EXIF.
  /// Returns null if no valid EXIF date is present.
  static Future<DateTime?> _exifDate(Uint8List bytes) async {
    try {
      final tags = await readExifFromBytes(bytes);
      for (final key in [
        'EXIF DateTimeOriginal',
        'Image DateTime',
        'EXIF DateTimeDigitized',
      ]) {
        final raw = tags[key]?.printable.trim();
        if (raw == null || raw.isEmpty) continue;
        // EXIF format: "2024:06:15 14:23:45"
        final parts = raw.split(' ');
        if (parts.length < 2) continue;
        final iso = '${parts[0].replaceAll(':', '-')} ${parts[1]}';
        final dt = DateTime.tryParse(iso);
        if (dt != null) return dt;
      }
    } catch (_) {}
    return null;
  }

  /// TODO.md §3.2 — matches [takenAt] against the case's survey attendances
  /// by same calendar day. Returns the attendance id only when exactly one
  /// attendance falls on that day; ambiguous (multiple attendances same
  /// day) or no match both resolve to null, leaving the photo unassigned
  /// for manual review via the existing photo-viewer picker
  /// (`photo_detail_sheet.dart`) or the "NOT YET ASSIGNED TO A VISIT"
  /// section in the gallery — no separate flagging mechanism needed.
  Future<String?> _autoMatchAttendance(String caseId, DateTime takenAt) async {
    final dateStr =
        '${takenAt.year}-${takenAt.month.toString().padLeft(2, '0')}-'
        '${takenAt.day.toString().padLeft(2, '0')}';
    try {
      final rows = await SupabaseService.client
          .from('survey_attendances')
          .select('attendance_id')
          .eq('case_id', caseId)
          .eq('attendance_date', dateStr);
      final matches = rows as List;
      if (matches.length == 1) {
        return matches.first['attendance_id'] as String;
      }
    } catch (_) {
      // Offline or lookup failed — leave unassigned, same as no match.
    }
    return null;
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

  /// Resolves a human-readable "{date} – {attendance type}" label for the
  /// Photos/{label}/ Drive subfolder, or null if [attendanceId] is null or
  /// the lookup fails (photo still uploads, just directly into Photos/).
  Future<String?> _attendanceFolderLabel(String? attendanceId) async {
    if (attendanceId == null) return null;
    try {
      final row = await SupabaseService.client
          .from('survey_attendances')
          .select('attendance_type, attendance_date')
          .eq('attendance_id', attendanceId)
          .maybeSingle();
      if (row == null) return null;
      final type =
          AttendanceType.fromValue(row['attendance_type'] as String? ?? 'initial');
      final date = row['attendance_date'] as String?;
      return [if (date != null) date, type.label].join(' – ');
    } catch (_) {
      return null;
    }
  }

  // ── Public mutations ──────────────────────────────────────────────────────

  /// Compresses [bytes], caches locally (native only), uploads the
  /// full-resolution copy to Drive (best-effort — offline/misconfigured
  /// Drive doesn't block saving the photo, just leaves driveFileId null for
  /// now), and records metadata in Supabase + the local cache.
  Future<PhotoModel> addPhoto({
    required String caseId,
    required Uint8List bytes,
    String? caption,
    String? linkedToType,
    String? linkedToId,
    String? attendanceId,
    PhotoAllocation? allocation,
  }) async {
    _mutationGeneration++;
    final id = _uuid.v4();

    // Read EXIF date from original bytes before compression strips metadata.
    final takenAt = await _exifDate(bytes) ?? DateTime.now();

    // TODO.md §3.2 — an explicit attendanceId from the caller (e.g. adding
    // photos from within a specific attendance's gallery view) always wins;
    // otherwise try to auto-assign by matching the EXIF date.
    final resolvedAttendanceId =
        attendanceId ?? await _autoMatchAttendance(caseId, takenAt);

    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1920,
      minHeight: 1920,
      quality: 82,
      format: CompressFormat.jpeg,
    );
    final thumbBytes = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 240,
      minHeight: 240,
      quality: 72,
      format: CompressFormat.jpeg,
    );

    String? filePath;
    String? thumbPath;
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(dir.path, 'cases', caseId, 'photos'));
      await photosDir.create(recursive: true);
      filePath = p.join(photosDir.path, '$id.jpg');
      await File(filePath).writeAsBytes(compressed);

      final thumbDir =
          Directory(p.join(dir.path, 'cases', caseId, 'thumbnails'));
      await thumbDir.create(recursive: true);
      thumbPath = p.join(thumbDir.path, '$id.jpg');
      await File(thumbPath).writeAsBytes(thumbBytes);
    }

    String? driveFileId;
    String? thumbDriveFileId;
    try {
      final caseModel = await _fetchCaseModel(caseId);
      final attendanceLabel = await _attendanceFolderLabel(resolvedAttendanceId);
      final subFolders = attendanceLabel != null ? [attendanceLabel] : const <String>[];
      final dateStr = '${takenAt.year}-${takenAt.month.toString().padLeft(2, '0')}-'
          '${takenAt.day.toString().padLeft(2, '0')} '
          '${takenAt.hour.toString().padLeft(2, '0')}${takenAt.minute.toString().padLeft(2, '0')}';
      final namePart = (caption?.trim().isNotEmpty ?? false)
          ? caption!.trim()
          : allocation?.label ?? 'Photo';
      // Short id suffix guarantees uniqueness (same caption/minute is common
      // when several photos are taken in quick succession).
      final shortId = id.substring(0, 8);
      // TODO.md §3.15: title convention now includes the attendance/event
      // label as its own part (previously only used to pick the Drive
      // subfolder, not reflected in the filename itself) — {date} -
      // {attendance/event label} - {description} - {id}. Only reflects
      // whatever attendanceId is known at upload time, same limitation
      // already accepted for caption (a caption/allocation added later via
      // the photo viewer doesn't retroactively rename the Drive file).
      final baseName = buildDriveFilename(
          [dateStr, attendanceLabel, namePart, shortId], 'jpg');
      driveFileId = await DriveStorageService.uploadCaseFile(
        caseModel: caseModel,
        category: CaseFileCategory.photos,
        subFolders: subFolders,
        bytes: compressed,
        filename: baseName,
        mimeType: 'image/jpeg',
      );
      thumbDriveFileId = await DriveStorageService.uploadCaseFile(
        caseModel: caseModel,
        category: CaseFileCategory.photos,
        subFolders: subFolders,
        bytes: thumbBytes,
        filename: buildDriveFilename(
            [dateStr, attendanceLabel, namePart, shortId, 'thumb'], 'jpg'),
        mimeType: 'image/jpeg',
      );
    } catch (e) {
      debugPrint('Drive photo upload skipped (offline or not configured): $e');
    }

    final photo = PhotoModel(
      id: id,
      caseId: caseId,
      localPath: filePath,
      thumbnailPath: thumbPath,
      caption: caption,
      allocation: allocation,
      linkedToType: linkedToType,
      linkedToId: linkedToId,
      attendanceId: resolvedAttendanceId,
      takenAt: takenAt,
      fileSizeKb: compressed.length / 1024,
      driveFileId: driveFileId,
      thumbnailDriveFileId: thumbDriveFileId,
    );

    var localSyncStatus = 'pending_upsert';
    try {
      await SupabaseService.client.from(_table).insert(photo.toSupabaseMap());
      localSyncStatus = 'synced';
    } catch (_) {
      // Offline — queued for _syncPending to pick up later.
    }

    if (!kIsWeb) {
      final db = await AppDatabase.instance.database;
      await db.insert(
          _table, {...photo.toMap(), 'local_sync_status': localSyncStatus});
    }

    final current = state.value ?? [];
    state = AsyncData([photo, ...current]);
    return photo;
  }

  /// Convenience wrapper — reads [file] bytes then calls [addPhoto].
  /// Use this from folder import to avoid buffering all files in memory first.
  Future<PhotoModel> addPhotoFromFile({
    required String caseId,
    required File file,
    String? attendanceId,
    String? linkedToType,
    String? linkedToId,
  }) async {
    final bytes = await file.readAsBytes();
    return addPhoto(
      caseId: caseId,
      bytes: bytes,
      attendanceId: attendanceId,
      linkedToType: linkedToType,
      linkedToId: linkedToId,
    );
  }

  /// Downloads the full-resolution original from Drive and caches it
  /// locally — for viewing a photo that was synced from another device (or
  /// on a fresh install) and has no local file yet. No-op on web (no local
  /// cache to write) or if there's no Drive copy to fetch.
  Future<PhotoModel?> ensureLocalFile(String photoId) async {
    if (kIsWeb) return null;
    final current = state.value ?? [];
    final photo = current.firstWhere((ph) => ph.id == photoId);
    if (photo.hasLocalFile || photo.driveFileId == null) return photo;

    final bytes = await DriveStorageService.downloadFile(photo.driveFileId!);
    final dir = await getApplicationDocumentsDirectory();
    final photosDir =
        Directory(p.join(dir.path, 'cases', photo.caseId, 'photos'));
    await photosDir.create(recursive: true);
    final filePath = p.join(photosDir.path, '$photoId.jpg');
    await File(filePath).writeAsBytes(bytes);

    String? thumbPath;
    if (photo.thumbnailDriveFileId != null) {
      final thumbBytes =
          await DriveStorageService.downloadFile(photo.thumbnailDriveFileId!);
      final thumbDir =
          Directory(p.join(dir.path, 'cases', photo.caseId, 'thumbnails'));
      await thumbDir.create(recursive: true);
      thumbPath = p.join(thumbDir.path, '$photoId.jpg');
      await File(thumbPath).writeAsBytes(thumbBytes);
    }

    final updated =
        photo.copyWith(localPath: filePath, thumbnailPath: thumbPath);
    final db = await AppDatabase.instance.database;
    await db
        .update(_table, updated.toMap(), where: 'id = ?', whereArgs: [photoId]);
    _updateState((ph) => ph.id == photoId ? updated : ph);
    return updated;
  }

  Future<void> attachToDamageItem(String photoId, String damageItemId) async {
    await _updateLink(photoId, 'damage_item', damageItemId);
  }

  Future<void> attachToOccurrence(String photoId, String occurrenceId) async {
    await _updateLink(photoId, 'occurrence', occurrenceId);
  }

  /// General-purpose link: stores [type] + [id] on the photo so callers can
  /// filter by (linkedToType, linkedToId) without needing named methods for
  /// every entity type (e.g. 'machinery_nameplate', 'vessel_general_view').
  Future<void> attachLink(String photoId, String type, String id) =>
      _updateLink(photoId, type, id);

  Future<void> _updateLink(String photoId, String type, String linkedId) =>
      _applyUpdate(photoId,
          (ph) => ph.copyWith(linkedToType: type, linkedToId: linkedId));

  Future<void> updateCaption(String photoId, String caption) async {
    final trimmed = caption.trim();
    await _applyUpdate(photoId,
        (ph) => ph.copyWith(caption: trimmed.isEmpty ? null : trimmed));
  }

  Future<void> updatePlacementMode(
          String photoId, PlacementMode? placementMode) =>
      _applyUpdate(photoId, (ph) => ph.copyWith(placementMode: placementMode));

  Future<void> updatePhotoSource(String photoId, PhotoSource? photoSource) =>
      _applyUpdate(photoId, (ph) => ph.copyWith(photoSource: photoSource));

  /// TODO.md §3.15 (8 July 2026) — allocate a photo to an attendance/event
  /// from the photo viewer.
  Future<void> updateAttendanceId(String photoId, String? attendanceId) =>
      _applyUpdate(photoId, (ph) => ph.copyWith(attendanceId: attendanceId));

  /// TODO.md §3.2 bulk re-run — re-attempts EXIF-date matching for every
  /// photo in this case that has no attendance yet (e.g. after a new
  /// attendance is logged retroactively, covering photos already
  /// imported). Returns how many photos were newly assigned.
  Future<int> autoAssignUnassignedPhotos() async {
    final current = state.value ?? [];
    var assignedCount = 0;
    for (final photo in current.where((ph) => ph.attendanceId == null)) {
      final match = await _autoMatchAttendance(_caseId, photo.takenAt);
      if (match == null) continue;
      await _applyUpdate(photo.id, (ph) => ph.copyWith(attendanceId: match));
      assignedCount++;
    }
    return assignedCount;
  }

  Future<void> updateAllocation(
      String photoId, PhotoAllocation? allocation) async {
    final current = state.value ?? [];

    // Only one photo per case may hold the Cover Page allocation — shared
    // as the single cover photo across the Photo Gallery, Vessel
    // Particulars, and Report Builder. Clear it from any other photo in
    // this case before assigning it here.
    if (allocation == PhotoAllocation.coverPage) {
      final caseId = current.firstWhere((ph) => ph.id == photoId).caseId;
      final others = current.where((ph) =>
          ph.caseId == caseId &&
          ph.id != photoId &&
          ph.allocation == PhotoAllocation.coverPage);
      for (final other in others) {
        await _applyUpdate(other.id, (ph) => ph.copyWith(allocation: null));
      }
    }

    await _applyUpdate(photoId, (ph) => ph.copyWith(allocation: allocation));
  }

  /// Marks a photo as synced to an external store (Google Photos) and
  /// records where — [remotePath] here is the shared album's URL, since
  /// individual media-item baseUrls expire and aren't stable references.
  Future<void> markSynced(String photoId, String? remotePath) => _applyUpdate(
      photoId,
      (ph) => ph.copyWith(
          syncStatus: PhotoSyncStatus.synced, remotePath: remotePath));

  /// Applies [transform] to the in-memory photo, then pushes it to
  /// Supabase (falling back to a queued local pending_upsert if offline)
  /// and the local cache, then updates state.
  Future<void> _applyUpdate(
      String photoId, PhotoModel Function(PhotoModel) transform) async {
    final current = state.value ?? [];
    final existing = current.firstWhere((ph) => ph.id == photoId);
    final updated = transform(existing);

    var localSyncStatus = 'pending_upsert';
    try {
      await SupabaseService.client
          .from(_table)
          .update(updated.toSupabaseMap())
          .eq('id', photoId);
      localSyncStatus = 'synced';
    } catch (_) {
      // Offline
    }

    if (!kIsWeb) {
      final db = await AppDatabase.instance.database;
      await db.update(
          _table, {...updated.toMap(), 'local_sync_status': localSyncStatus},
          where: 'id = ?', whereArgs: [photoId]);
    }

    _updateState((ph) => ph.id == photoId ? updated : ph);
  }

  Future<void> deletePhoto(String photoId) async {
    _mutationGeneration++;
    final current = state.value ?? [];
    final photo = current.firstWhere((ph) => ph.id == photoId);
    if (photo.localPath != null) {
      try {
        await File(photo.localPath!).delete();
      } catch (_) {}
    }
    if (photo.thumbnailPath != null) {
      try {
        await File(photo.thumbnailPath!).delete();
      } catch (_) {}
    }

    var deleted = false;
    try {
      await SupabaseService.client.from(_table).delete().eq('id', photoId);
      deleted = true;
    } catch (_) {
      // Offline
    }

    if (!kIsWeb) {
      final db = await AppDatabase.instance.database;
      if (deleted) {
        await db.delete(_table, where: 'id = ?', whereArgs: [photoId]);
      } else {
        await db.update(_table, {'local_sync_status': 'pending_delete'},
            where: 'id = ?', whereArgs: [photoId]);
      }
    }

    state = AsyncData(current.where((ph) => ph.id != photoId).toList());
  }

  void _updateState(PhotoModel Function(PhotoModel) transform) {
    final current = state.value ?? [];
    state = AsyncData(current.map(transform).toList());
  }
}

// Convenience: filter photos for a specific damage item from existing state.
extension PhotoListX on List<PhotoModel> {
  List<PhotoModel> forDamageItem(String damageId) => where(
          (ph) => ph.linkedToType == 'damage_item' && ph.linkedToId == damageId)
      .toList();

  List<PhotoModel> get allocated =>
      where((ph) => ph.allocation != null).toList();

  /// The single case-wide cover photo (Clause/UI: shared identically by the
  /// Photo Gallery, Vessel Particulars, and Report Builder — there is only
  /// ever one photo with the Cover Page allocation per case).
  PhotoModel? get coverPhoto {
    try {
      return firstWhere((p) => p.allocation == PhotoAllocation.coverPage);
    } catch (_) {
      return null;
    }
  }
}
