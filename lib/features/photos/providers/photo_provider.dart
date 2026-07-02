// lib/features/photos/providers/photo_provider.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../models/photo_model.dart';

const _uuid = Uuid();

final photosProvider =
    AsyncNotifierProviderFamily<PhotoNotifier, List<PhotoModel>, String>(
  PhotoNotifier.new,
);

class PhotoNotifier extends FamilyAsyncNotifier<List<PhotoModel>, String> {
  @override
  Future<List<PhotoModel>> build(String caseId) => _fetch(caseId);

  Future<List<PhotoModel>> _fetch(String caseId) async {
    if (kIsWeb) {
      // Photos are stored as local files (dart:io) with no web backend —
      // photo capture/upload is not supported on web (see
      // project_platform_target_desktop_cloud memory: future plan is
      // cloud storage + standalone desktop apps, not browser support).
      // Returning an empty list here only prevents screens that read the
      // photo list (e.g. the Report Builder cover photo picker) from
      // crash-looping the whole screen on web.
      return [];
    }
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'photos',
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

      final thumbPath = p.join(dir.path, 'cases', caseId, 'thumbnails', '$name.jpg');
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
        await db.insert('photos', photo.toMap());
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

  /// Save bytes as a compressed JPEG locally, generate a thumbnail, and
  /// record metadata in SQLite.
  Future<PhotoModel> addPhoto({
    required String caseId,
    required Uint8List bytes,
    String? caption,
    String? linkedToType,
    String? linkedToId,
    String? attendanceId,
    PhotoAllocation? allocation,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final id = _uuid.v4();

    // Read EXIF date from originals bytes before compression strips metadata.
    final takenAt = await _exifDate(bytes) ?? DateTime.now();

    // Compress full-res JPEG.
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1920,
      minHeight: 1920,
      quality: 82,
      format: CompressFormat.jpeg,
    );
    final photosDir = Directory(p.join(dir.path, 'cases', caseId, 'photos'));
    await photosDir.create(recursive: true);
    final filePath = p.join(photosDir.path, '$id.jpg');
    await File(filePath).writeAsBytes(compressed);

    // Generate small thumbnail for fast grid display.
    final thumbBytes = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 240,
      minHeight: 240,
      quality: 72,
      format: CompressFormat.jpeg,
    );
    final thumbDir =
        Directory(p.join(dir.path, 'cases', caseId, 'thumbnails'));
    await thumbDir.create(recursive: true);
    final thumbPath = p.join(thumbDir.path, '$id.jpg');
    await File(thumbPath).writeAsBytes(thumbBytes);

    final photo = PhotoModel(
      id: id,
      caseId: caseId,
      localPath: filePath,
      thumbnailPath: thumbPath,
      caption: caption,
      allocation: allocation,
      linkedToType: linkedToType,
      linkedToId: linkedToId,
      attendanceId: attendanceId,
      takenAt: takenAt,
      fileSizeKb: compressed.length / 1024,
    );

    final db = await AppDatabase.instance.database;
    await db.insert('photos', photo.toMap());

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

  Future<void> attachToDamageItem(
      String photoId, String damageItemId) async {
    await _updateLink(photoId, 'damage_item', damageItemId);
  }

  Future<void> attachToOccurrence(
      String photoId, String occurrenceId) async {
    await _updateLink(photoId, 'occurrence', occurrenceId);
  }

  /// General-purpose link: stores [type] + [id] on the photo so callers can
  /// filter by (linkedToType, linkedToId) without needing named methods for
  /// every entity type (e.g. 'machinery_nameplate', 'vessel_general_view').
  Future<void> attachLink(String photoId, String type, String id) =>
      _updateLink(photoId, type, id);

  Future<void> _updateLink(
      String photoId, String type, String linkedId) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'photos',
      {'linked_to_type': type, 'linked_to_id': linkedId},
      where: 'id = ?',
      whereArgs: [photoId],
    );
    _updateState((ph) => ph.id == photoId
        ? ph.copyWith(linkedToType: type, linkedToId: linkedId)
        : ph);
  }

  Future<void> updateCaption(String photoId, String caption) async {
    final trimmed = caption.trim();
    final db = await AppDatabase.instance.database;
    await db.update(
      'photos',
      {'caption': trimmed.isEmpty ? null : trimmed},
      where: 'id = ?',
      whereArgs: [photoId],
    );
    _updateState((ph) => ph.id == photoId
        ? ph.copyWith(caption: trimmed.isEmpty ? null : trimmed)
        : ph);
  }

  Future<void> updatePlacementMode(
      String photoId, PlacementMode? placementMode) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'photos',
      {'placement_mode': placementMode?.value},
      where: 'id = ?',
      whereArgs: [photoId],
    );
    _updateState((ph) =>
        ph.id == photoId ? ph.copyWith(placementMode: placementMode) : ph);
  }

  Future<void> updatePhotoSource(String photoId, PhotoSource? photoSource) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'photos',
      {'photo_source': photoSource?.value},
      where: 'id = ?',
      whereArgs: [photoId],
    );
    _updateState(
        (ph) => ph.id == photoId ? ph.copyWith(photoSource: photoSource) : ph);
  }

  Future<void> updateAllocation(
      String photoId, PhotoAllocation? allocation) async {
    final db = await AppDatabase.instance.database;
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
        await db.update(
          'photos',
          {'photo_allocation': null},
          where: 'id = ?',
          whereArgs: [other.id],
        );
      }
    }

    await db.update(
      'photos',
      {'photo_allocation': allocation?.value},
      where: 'id = ?',
      whereArgs: [photoId],
    );

    state = AsyncData(current.map((ph) {
      if (ph.id == photoId) return ph.copyWith(allocation: allocation);
      if (allocation == PhotoAllocation.coverPage &&
          ph.allocation == PhotoAllocation.coverPage) {
        return ph.copyWith(allocation: null);
      }
      return ph;
    }).toList());
  }

  Future<void> deletePhoto(String photoId) async {
    final current = state.value ?? [];
    final photo = current.firstWhere((ph) => ph.id == photoId);
    try { await File(photo.localPath).delete(); } catch (_) {}
    if (photo.thumbnailPath != null) {
      try { await File(photo.thumbnailPath!).delete(); } catch (_) {}
    }
    final db = await AppDatabase.instance.database;
    await db.delete('photos', where: 'id = ?', whereArgs: [photoId]);
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
