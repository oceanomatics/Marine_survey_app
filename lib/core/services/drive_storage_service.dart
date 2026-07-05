// lib/core/services/drive_storage_service.dart
//
// Resolves the unified Google Drive folder structure used across every
// feature that stores files there (photos, correspondence, reports,
// documents), and admin-level folders unrelated to a specific case:
//
//   {AppConfig.driveBaseFolder ?? "My Drive root"}/
//     Cases/
//       {case title}/
//         Documents/
//         Photos/
//         Reports/
//         Correspondence/
//     Admin/
//       Freelancer Contracts/
//       Invoices/
//       HSE/
//
// Folder IDs are cached in-memory for the session — findOrCreateFolder
// itself is idempotent (searches by name before creating), so the cache is
// purely a latency optimisation, not a correctness requirement.

import 'dart:typed_data';

import '../config/app_config.dart';
import '../../features/photos/services/google_drive_service.dart';

enum CaseFileCategory {
  documents('Documents'),
  photos('Photos'),
  reports('Reports'),
  correspondence('Correspondence');

  const CaseFileCategory(this.folderName);
  final String folderName;
}

enum AdminFileCategory {
  freelancerContracts('Freelancer Contracts'),
  invoices('Invoices'),
  hse('HSE');

  const AdminFileCategory(this.folderName);
  final String folderName;
}

class DriveStorageService {
  DriveStorageService._();

  static final Map<String, String> _folderIdCache = {};

  static Future<String> _cached(
      String key, Future<String> Function() resolve) async {
    final existing = _folderIdCache[key];
    if (existing != null) return existing;
    final id = await resolve();
    _folderIdCache[key] = id;
    return id;
  }

  static Future<String> _baseFolderId() async {
    final base = AppConfig.driveBaseFolder;
    if (base == null || base.isEmpty) return 'root';
    return _cached(
        'base:$base', () => GoogleDriveService.findOrCreateFolder(base));
  }

  static Future<String> _casesRootId() async {
    final baseId = await _baseFolderId();
    return _cached('cases-root:$baseId',
        () => GoogleDriveService.findOrCreateFolder('Cases', parentId: baseId));
  }

  static Future<String> _adminRootId() async {
    final baseId = await _baseFolderId();
    return _cached('admin-root:$baseId',
        () => GoogleDriveService.findOrCreateFolder('Admin', parentId: baseId));
  }

  /// Resolves (creating if needed) the Drive folder for [category] within
  /// the given case, named [caseTitle] — e.g. ".../Cases/SI-M53-055873 –
  /// MINRES ODIN – .../Photos".
  static Future<String> caseFolderId({
    required String caseId,
    required String caseTitle,
    required CaseFileCategory category,
  }) async {
    final casesRoot = await _casesRootId();
    final caseFolderId = await _cached(
        'case:$caseId',
        () => GoogleDriveService.findOrCreateFolder(caseTitle,
            parentId: casesRoot));
    return _cached(
        'case:$caseId:${category.name}',
        () => GoogleDriveService.findOrCreateFolder(category.folderName,
            parentId: caseFolderId));
  }

  /// Resolves (creating if needed) an admin-level folder unrelated to any
  /// specific case (e.g. freelancer contracts, invoices, HSE records).
  static Future<String> adminFolderId(AdminFileCategory category) async {
    final adminRoot = await _adminRootId();
    return _cached(
        'admin:${category.name}',
        () => GoogleDriveService.findOrCreateFolder(category.folderName,
            parentId: adminRoot));
  }

  /// Uploads [bytes] as [filename] into the given case's [category] folder,
  /// returning the created Drive file id.
  static Future<String> uploadCaseFile({
    required String caseId,
    required String caseTitle,
    required CaseFileCategory category,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final folderId = await caseFolderId(
        caseId: caseId, caseTitle: caseTitle, category: category);
    return GoogleDriveService.uploadFile(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      parentId: folderId,
    );
  }

  /// Uploads [bytes] as [filename] into the given admin-level folder,
  /// returning the created Drive file id.
  static Future<String> uploadAdminFile({
    required AdminFileCategory category,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final folderId = await adminFolderId(category);
    return GoogleDriveService.uploadFile(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      parentId: folderId,
    );
  }

  /// Downloads a previously-uploaded file by its Drive file id.
  static Future<Uint8List> downloadFile(String fileId) =>
      GoogleDriveService.downloadFile(fileId);

  /// Ensures every Admin sub-folder exists — called once from Drive setup
  /// so they're visible in the user's Drive immediately, not only after the
  /// first upload to each.
  static Future<void> ensureAdminFoldersExist() async {
    for (final category in AdminFileCategory.values) {
      await adminFolderId(category);
    }
  }
}
