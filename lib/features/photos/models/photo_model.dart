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

enum PhotoAllocation {
  coverPage('cover_page', 'Cover Page'),
  logbook('logbook', 'Logbook'),
  maintenanceRecord('maintenance_record', 'Maintenance Record'),
  certificate('certificate', 'Certificate'),
  damageEvidence('damage_evidence', 'Damage Evidence'),
  namePlate('name_plate', 'Name Plate');

  const PhotoAllocation(this.value, this.label);
  final String value;
  final String label;

  static PhotoAllocation? fromValue(String? v) {
    if (v == null) return null;
    return values.firstWhere((e) => e.value == v,
        orElse: () => PhotoAllocation.damageEvidence);
  }
}

/// Where a photo renders in the exported report (spec §7 "Visual Evidence").
enum PlacementMode {
  inline('inline', 'Inline'),
  sectionGallery('section_gallery', 'Section Gallery'),
  annexure('annexure', 'Annexure');

  const PlacementMode(this.value, this.label);
  final String value;
  final String label;

  static PlacementMode? fromValue(String? v) {
    if (v == null) return null;
    return values.firstWhere((e) => e.value == v,
        orElse: () => PlacementMode.annexure);
  }
}

/// Who provided the photo — drives the auto-inserted attribution sentence
/// for non-surveyor sources (spec §7).
enum PhotoSource {
  takenBySurveyor('taken_by_surveyor', 'Taken by Undersigned Surveyor'),
  providedByOwner('provided_by_owner', 'Provided by Owner/Operator'),
  providedByContractor('provided_by_contractor', 'Provided by Contractor'),
  thirdPartyReport('third_party_report', 'Third-Party Inspection Report');

  const PhotoSource(this.value, this.label);
  final String value;
  final String label;

  static PhotoSource? fromValue(String? v) {
    if (v == null) return null;
    return values.firstWhere((e) => e.value == v,
        orElse: () => PhotoSource.takenBySurveyor);
  }
}

@immutable
class PhotoModel {
  const PhotoModel({
    required this.id,
    required this.caseId,
    required this.localPath,
    this.thumbnailPath,
    this.caption,
    this.allocation,
    this.linkedToType,
    this.linkedToId,
    this.attendanceId,
    required this.takenAt,
    this.syncStatus = PhotoSyncStatus.localOnly,
    this.remotePath,
    this.fileSizeKb,
    this.placementMode,
    this.photoSource,
  });

  final String id;
  final String caseId;
  final String localPath;
  final String? thumbnailPath;
  final String? caption;
  final PhotoAllocation? allocation;
  final String? linkedToType; // 'damage_item' | 'occurrence' | 'case'
  final String? linkedToId;
  final String? attendanceId;
  final DateTime takenAt;
  final PhotoSyncStatus syncStatus;
  final String? remotePath;
  final double? fileSizeKb;
  final PlacementMode? placementMode;
  final PhotoSource? photoSource;

  /// Resolved placement mode — explicit value if set, else the spec's
  /// default: Inline for damage-item photos, Annexure otherwise.
  PlacementMode get effectivePlacementMode =>
      placementMode ??
      (linkedToType == 'damage_item'
          ? PlacementMode.inline
          : PlacementMode.annexure);

  factory PhotoModel.fromMap(Map<String, dynamic> m) => PhotoModel(
        id: m['id'] as String,
        caseId: m['case_id'] as String,
        localPath: m['local_path'] as String,
        thumbnailPath: m['thumbnail_path'] as String?,
        caption: m['caption'] as String?,
        allocation: PhotoAllocation.fromValue(m['photo_allocation'] as String?),
        linkedToType: m['linked_to_type'] as String?,
        linkedToId: m['linked_to_id'] as String?,
        attendanceId: m['attendance_id'] as String?,
        takenAt: DateTime.parse(m['taken_at'] as String),
        syncStatus: PhotoSyncStatus.fromValue(
            m['sync_status'] as String? ?? 'local_only'),
        remotePath: m['remote_path'] as String?,
        fileSizeKb: (m['file_size_kb'] as num?)?.toDouble(),
        placementMode: PlacementMode.fromValue(m['placement_mode'] as String?),
        photoSource: PhotoSource.fromValue(m['photo_source'] as String?),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'case_id': caseId,
        'local_path': localPath,
        if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
        if (caption != null) 'caption': caption,
        if (allocation != null) 'photo_allocation': allocation!.value,
        if (linkedToType != null) 'linked_to_type': linkedToType,
        if (linkedToId != null) 'linked_to_id': linkedToId,
        if (attendanceId != null) 'attendance_id': attendanceId,
        'taken_at': takenAt.toIso8601String(),
        'sync_status': syncStatus.value,
        if (remotePath != null) 'remote_path': remotePath,
        if (fileSizeKb != null) 'file_size_kb': fileSizeKb,
        if (placementMode != null) 'placement_mode': placementMode!.value,
        if (photoSource != null) 'photo_source': photoSource!.value,
      };

  // Sentinel for nullable copyWith fields.
  static const _unset = Object();

  PhotoModel copyWith({
    String? caption,
    Object? allocation = _unset,
    String? linkedToType,
    String? linkedToId,
    String? attendanceId,
    PhotoSyncStatus? syncStatus,
    String? remotePath,
    String? thumbnailPath,
    Object? placementMode = _unset,
    Object? photoSource = _unset,
  }) =>
      PhotoModel(
        id: id,
        caseId: caseId,
        localPath: localPath,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        caption: caption ?? this.caption,
        allocation: allocation == _unset
            ? this.allocation
            : allocation as PhotoAllocation?,
        linkedToType: linkedToType ?? this.linkedToType,
        linkedToId: linkedToId ?? this.linkedToId,
        attendanceId: attendanceId ?? this.attendanceId,
        takenAt: takenAt,
        syncStatus: syncStatus ?? this.syncStatus,
        remotePath: remotePath ?? this.remotePath,
        fileSizeKb: fileSizeKb,
        placementMode: placementMode == _unset
            ? this.placementMode
            : placementMode as PlacementMode?,
        photoSource: photoSource == _unset
            ? this.photoSource
            : photoSource as PhotoSource?,
      );
}
