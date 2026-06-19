// lib/features/photos/providers/photo_provider.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'photos',
      where: 'case_id = ?',
      whereArgs: [caseId],
      orderBy: 'taken_at DESC',
    );
    return rows.map(PhotoModel.fromMap).toList();
  }

  /// Save bytes as a compressed JPEG locally and record metadata in SQLite.
  Future<PhotoModel> addPhoto({
    required String caseId,
    required Uint8List bytes,
    String? caption,
    String? linkedToType,
    String? linkedToId,
    String? attendanceId,
  }) async {
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1920,
      minHeight: 1920,
      quality: 82,
      format: CompressFormat.jpeg,
    );

    final dir = await getApplicationDocumentsDirectory();
    final photosDir =
        Directory(p.join(dir.path, 'cases', caseId, 'photos'));
    await photosDir.create(recursive: true);

    final id = _uuid.v4();
    final filePath = p.join(photosDir.path, '$id.jpg');
    await File(filePath).writeAsBytes(compressed);

    final photo = PhotoModel(
      id: id,
      caseId: caseId,
      localPath: filePath,
      caption: caption,
      linkedToType: linkedToType,
      linkedToId: linkedToId,
      attendanceId: attendanceId,
      takenAt: DateTime.now(),
      fileSizeKb: compressed.length / 1024,
    );

    final db = await AppDatabase.instance.database;
    await db.insert('photos', photo.toMap());

    final current = state.value ?? [];
    state = AsyncData([photo, ...current]);
    return photo;
  }

  Future<void> attachToDamageItem(
      String photoId, String damageItemId) async {
    await _updateLink(photoId, 'damage_item', damageItemId);
  }

  Future<void> attachToOccurrence(
      String photoId, String occurrenceId) async {
    await _updateLink(photoId, 'occurrence', occurrenceId);
  }

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
    final db = await AppDatabase.instance.database;
    await db.update('photos', {'caption': caption},
        where: 'id = ?', whereArgs: [photoId]);
    _updateState(
        (ph) => ph.id == photoId ? ph.copyWith(caption: caption) : ph);
  }

  Future<void> deletePhoto(String photoId) async {
    final current = state.value ?? [];
    final photo = current.firstWhere((ph) => ph.id == photoId);
    try {
      await File(photo.localPath).delete();
    } catch (_) {}
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
}
