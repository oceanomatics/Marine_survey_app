// lib/features/photos/models/photo_model.dart

import 'package:flutter/foundation.dart';

enum PhotoSyncStatus {
  localOnly,
  uploading,
  synced,
  // Upload to Google Photos was attempted and failed — kept distinct from
  // localOnly so the gallery can flag it and the next sync run retries it.
  syncFailed;

  static PhotoSyncStatus fromValue(String v) => switch (v) {
        'uploading' => uploading,
        'synced' => synced,
        'sync_failed' => syncFailed,
        _ => localOnly,
      };

  String get value => switch (this) {
        localOnly => 'local_only',
        uploading => 'uploading',
        synced => 'synced',
        syncFailed => 'sync_failed',
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
    this.localPath,
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
    this.driveFileId,
    this.thumbnailDriveFileId,
    this.locationComponent,
    this.directionContext,
    this.significanceToClaim,
  });

  final String id;
  final String caseId;

  /// Per-device local cache path — null if this photo hasn't been
  /// downloaded/cached on this device yet (e.g. synced from another device,
  /// or viewed on web where there's no local cache at all).
  final String? localPath;
  final String? thumbnailPath;
  final String? caption;
  final PhotoAllocation? allocation;
  final String? linkedToType; // 'damage_item' | 'occurrence' | 'case'
  final String? linkedToId;
  final String? attendanceId;
  final DateTime takenAt;
  final PhotoSyncStatus syncStatus;

  /// Google Photos shared-album URL, if synced via the "Sync to Google
  /// Photos" feature — distinct from [driveFileId], which is the canonical
  /// Drive-backed unified-storage copy.
  final String? remotePath;
  final double? fileSizeKb;
  final PlacementMode? placementMode;
  final PhotoSource? photoSource;

  /// Drive file id of the full-resolution original — the canonical,
  /// cross-platform copy (unified storage). Null until the background
  /// upload completes.
  final String? driveFileId;
  final String? thumbnailDriveFileId;

  /// §2.4 (13 July 2026): Annexure E photo register fields (spec §4.8 —
  /// Photo No. | Location/Component | Direction/Context | Date |
  /// Significance; Date comes from [takenAt], Photo No. is the register's
  /// row position, not stored). [caption] is a separate free-text field
  /// some existing photos already carry — kept as a caption fallback when
  /// these are unset, not replaced by them.
  final String? locationComponent;
  final String? directionContext;
  final String? significanceToClaim;

  bool get hasLocalFile => localPath != null && localPath!.isNotEmpty;

  /// True if there's any usable image source at all — a local file cache
  /// (native) or a Drive copy (any platform). False only for photos that
  /// predate the Drive-backed upload migration and were never synced.
  bool get hasUsablePhoto =>
      hasLocalFile || driveFileId != null || thumbnailDriveFileId != null;

  /// Resolved placement mode — explicit value if set, else the spec's
  /// default: Inline for damage-item photos, Annexure otherwise.
  PlacementMode get effectivePlacementMode =>
      placementMode ??
      (linkedToType == 'damage_item'
          ? PlacementMode.inline
          : PlacementMode.annexure);

  /// Parses a row from the local SQLite cache (per-device fields present).
  factory PhotoModel.fromMap(Map<String, dynamic> m) => PhotoModel(
        id: m['id'] as String,
        caseId: m['case_id'] as String,
        localPath: (m['local_path'] as String?)?.isEmpty == true
            ? null
            : m['local_path'] as String?,
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
        driveFileId: m['drive_file_id'] as String?,
        thumbnailDriveFileId: m['thumbnail_drive_file_id'] as String?,
        locationComponent: m['location_component'] as String?,
        directionContext: m['direction_context'] as String?,
        significanceToClaim: m['significance_to_claim'] as String?,
      );

  /// Parses a row from Supabase (canonical metadata; no per-device fields —
  /// [localPath]/[thumbnailPath] are null until this device caches the file).
  factory PhotoModel.fromSupabaseMap(Map<String, dynamic> m) => PhotoModel(
        id: m['id'] as String,
        caseId: m['case_id'] as String,
        caption: m['caption'] as String?,
        allocation: PhotoAllocation.fromValue(m['photo_allocation'] as String?),
        linkedToType: m['linked_to_type'] as String?,
        linkedToId: m['linked_to_id'] as String?,
        attendanceId: m['attendance_id'] as String?,
        takenAt: DateTime.parse(m['taken_at'] as String).toLocal(),
        syncStatus: PhotoSyncStatus.synced,
        fileSizeKb: (m['file_size_kb'] as num?)?.toDouble(),
        placementMode: PlacementMode.fromValue(m['placement_mode'] as String?),
        photoSource: PhotoSource.fromValue(m['photo_source'] as String?),
        driveFileId: m['drive_file_id'] as String?,
        thumbnailDriveFileId: m['thumbnail_drive_file_id'] as String?,
        locationComponent: m['location_component'] as String?,
        directionContext: m['direction_context'] as String?,
        significanceToClaim: m['significance_to_claim'] as String?,
      );

  /// Serializes for the local SQLite cache — includes per-device fields.
  Map<String, dynamic> toMap() => {
        'id': id,
        'case_id': caseId,
        'local_path': localPath ?? '',
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
        if (driveFileId != null) 'drive_file_id': driveFileId,
        if (thumbnailDriveFileId != null)
          'thumbnail_drive_file_id': thumbnailDriveFileId,
        if (locationComponent != null) 'location_component': locationComponent,
        if (directionContext != null) 'direction_context': directionContext,
        if (significanceToClaim != null)
          'significance_to_claim': significanceToClaim,
      };

  /// Serializes for the Supabase `photos` table — canonical metadata only,
  /// no per-device local paths.
  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'case_id': caseId,
        if (caption != null) 'caption': caption,
        if (allocation != null) 'photo_allocation': allocation!.value,
        if (linkedToType != null) 'linked_to_type': linkedToType,
        if (linkedToId != null) 'linked_to_id': linkedToId,
        if (attendanceId != null) 'attendance_id': attendanceId,
        'taken_at': takenAt.toUtc().toIso8601String(),
        if (fileSizeKb != null) 'file_size_kb': fileSizeKb,
        if (placementMode != null) 'placement_mode': placementMode!.value,
        if (photoSource != null) 'photo_source': photoSource!.value,
        if (driveFileId != null) 'drive_file_id': driveFileId,
        if (thumbnailDriveFileId != null)
          'thumbnail_drive_file_id': thumbnailDriveFileId,
        if (locationComponent != null) 'location_component': locationComponent,
        if (directionContext != null) 'direction_context': directionContext,
        if (significanceToClaim != null)
          'significance_to_claim': significanceToClaim,
      };

  // Sentinel for nullable copyWith fields.
  static const _unset = Object();

  PhotoModel copyWith({
    String? caption,
    Object? allocation = _unset,
    String? linkedToType,
    String? linkedToId,
    Object? attendanceId = _unset,
    PhotoSyncStatus? syncStatus,
    String? remotePath,
    String? localPath,
    String? thumbnailPath,
    Object? placementMode = _unset,
    Object? photoSource = _unset,
    String? driveFileId,
    String? thumbnailDriveFileId,
    Object? locationComponent = _unset,
    Object? directionContext = _unset,
    Object? significanceToClaim = _unset,
  }) =>
      PhotoModel(
        id: id,
        caseId: caseId,
        localPath: localPath ?? this.localPath,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        caption: caption ?? this.caption,
        allocation: allocation == _unset
            ? this.allocation
            : allocation as PhotoAllocation?,
        linkedToType: linkedToType ?? this.linkedToType,
        linkedToId: linkedToId ?? this.linkedToId,
        attendanceId: attendanceId == _unset
            ? this.attendanceId
            : attendanceId as String?,
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
        driveFileId: driveFileId ?? this.driveFileId,
        thumbnailDriveFileId: thumbnailDriveFileId ?? this.thumbnailDriveFileId,
        locationComponent: locationComponent == _unset
            ? this.locationComponent
            : locationComponent as String?,
        directionContext: directionContext == _unset
            ? this.directionContext
            : directionContext as String?,
        significanceToClaim: significanceToClaim == _unset
            ? this.significanceToClaim
            : significanceToClaim as String?,
      );
}
