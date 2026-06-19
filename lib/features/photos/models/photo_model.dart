// lib/features/photos/models/photo_model.dart

import 'package:flutter/foundation.dart';

enum PhotoSyncStatus {
  localOnly,
  uploading,
  synced;

  static PhotoSyncStatus fromValue(String v) => switch (v) {
        'uploading' => uploading,
        'synced' => synced,
        _ => localOnly,
      };

  String get value => switch (this) {
        localOnly => 'local_only',
        uploading => 'uploading',
        synced => 'synced',
      };
}

@immutable
class PhotoModel {
  const PhotoModel({
    required this.id,
    required this.caseId,
    required this.localPath,
    this.caption,
    this.linkedToType,
    this.linkedToId,
    this.attendanceId,
    required this.takenAt,
    this.syncStatus = PhotoSyncStatus.localOnly,
    this.remotePath,
    this.fileSizeKb,
  });

  final String id;
  final String caseId;
  final String localPath;
  final String? caption;
  final String? linkedToType; // 'damage_item' | 'occurrence' | 'case'
  final String? linkedToId;
  final String? attendanceId;
  final DateTime takenAt;
  final PhotoSyncStatus syncStatus;
  final String? remotePath;
  final double? fileSizeKb;

  factory PhotoModel.fromMap(Map<String, dynamic> m) => PhotoModel(
        id: m['id'] as String,
        caseId: m['case_id'] as String,
        localPath: m['local_path'] as String,
        caption: m['caption'] as String?,
        linkedToType: m['linked_to_type'] as String?,
        linkedToId: m['linked_to_id'] as String?,
        attendanceId: m['attendance_id'] as String?,
        takenAt: DateTime.parse(m['taken_at'] as String),
        syncStatus: PhotoSyncStatus.fromValue(
            m['sync_status'] as String? ?? 'local_only'),
        remotePath: m['remote_path'] as String?,
        fileSizeKb: (m['file_size_kb'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'case_id': caseId,
        'local_path': localPath,
        if (caption != null) 'caption': caption,
        if (linkedToType != null) 'linked_to_type': linkedToType,
        if (linkedToId != null) 'linked_to_id': linkedToId,
        if (attendanceId != null) 'attendance_id': attendanceId,
        'taken_at': takenAt.toIso8601String(),
        'sync_status': syncStatus.value,
        if (remotePath != null) 'remote_path': remotePath,
        if (fileSizeKb != null) 'file_size_kb': fileSizeKb,
      };

  PhotoModel copyWith({
    String? caption,
    String? linkedToType,
    String? linkedToId,
    String? attendanceId,
    PhotoSyncStatus? syncStatus,
    String? remotePath,
  }) =>
      PhotoModel(
        id: id,
        caseId: caseId,
        localPath: localPath,
        caption: caption ?? this.caption,
        linkedToType: linkedToType ?? this.linkedToType,
        linkedToId: linkedToId ?? this.linkedToId,
        attendanceId: attendanceId ?? this.attendanceId,
        takenAt: takenAt,
        syncStatus: syncStatus ?? this.syncStatus,
        remotePath: remotePath ?? this.remotePath,
        fileSizeKb: fileSizeKb,
      );
}
