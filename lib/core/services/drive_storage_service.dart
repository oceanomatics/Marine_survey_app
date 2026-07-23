// lib/core/services/drive_storage_service.dart
//
// Resolves the unified Google Drive folder structure used across every
// feature that stores files there (photos, correspondence, reports,
// documents), per case:
//
//   {AppConfig.driveBaseFolder ?? "My Drive root"}/
//     Cases/
//       {case.driveFolderName}/
//         Admin/
//         Collected Documents/
//           Certificates/
//           Class Report/
//           Service Reports/
//           Logs/
//           Other/
//         Claim Invoices/
//         Reports/
//         HSE/
//         Photos/
//           {attendance label}/        (created lazily, only when known)
//         Correspondence/
//
// The case-level folder id is persisted to cases.storage_folder_path the
// first time it's resolved, so later calls reuse + rename that same folder
// (via GoogleDriveService.renameFile) instead of creating a duplicate when
// case.driveFolderName changes (e.g. placeholder file no. becomes real,
// vessel name gets set). Folder ids below that are cached in-memory only —
// findOrCreateFolder is idempotent (searches by name before creating), so
// that cache is purely a latency optimisation.

import 'dart:typed_data';

import '../api/supabase_client.dart';
import '../config/app_config.dart';
import '../../features/cases/models/case_model.dart';
import '../../features/photos/services/google_drive_service.dart';

enum CaseFileCategory {
  admin('Admin'),
  collectedDocuments('Collected Documents'),
  claimInvoices('Claim Invoices'),
  reports('Reports'),
  hse('HSE'),
  photos('Photos'),
  correspondence('Correspondence');

  const CaseFileCategory(this.folderName);
  final String folderName;
}

enum CollectedDocBucket {
  certificates('Certificates'),
  classReport('Class Report'),
  serviceReports('Service Reports'),
  logs('Logs'),
  other('Other');

  const CollectedDocBucket(this.folderName);
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

  /// Resolves (creating if needed) the case-level Drive folder, persisting
  /// its id to cases.storage_folder_path so later resolutions reuse + rename
  /// the same folder instead of duplicating it under a new name.
  static Future<String> _caseFolderId(CaseModel caseModel) {
    return _cached('case:${caseModel.caseId}', () async {
      final desiredName = caseModel.driveFolderName;
      final existingId = caseModel.storageFolderPath;
      if (existingId != null && existingId.isNotEmpty) {
        try {
          await GoogleDriveService.renameFile(existingId, desiredName);
        } catch (e) {
          // Best-effort — stale name in Drive is cosmetic, not fatal.
        }
        return existingId;
      }
      final casesRoot = await _casesRootId();
      final newId = await GoogleDriveService.findOrCreateFolder(desiredName,
          parentId: casesRoot);
      await SupabaseService.client
          .from('cases')
          .update({'storage_folder_path': newId})
          .eq('case_id', caseModel.caseId);
      return newId;
    });
  }

  /// Walks/creates a chain of subfolders under [parentId], caching each
  /// level under [baseKey] + the path walked so far.
  static Future<String> _nested(
      String baseKey, String parentId, List<String> names) async {
    var currentId = parentId;
    var key = baseKey;
    for (final name in names) {
      key = '$key/$name';
      currentId = await _cached(
          key, () => GoogleDriveService.findOrCreateFolder(name, parentId: currentId));
    }
    return currentId;
  }

  /// Resolves (creating if needed) the Drive folder for [category] within
  /// the given case.
  static Future<String> caseFolderId({
    required CaseModel caseModel,
    required CaseFileCategory category,
  }) async {
    final caseFolder = await _caseFolderId(caseModel);
    return _cached(
        'case:${caseModel.caseId}:${category.name}',
        () => GoogleDriveService.findOrCreateFolder(category.folderName,
            parentId: caseFolder));
  }

  /// Proactively re-resolves (and, if the id already exists, renames) the
  /// case's Drive folder — call this after case details that feed
  /// [CaseModel.driveFolderName] change (technical file no., vessel name).
  ///
  /// The case-folder id is memoised in [_folderIdCache], so the very first
  /// resolution wins and every later call short-circuits to the cached id —
  /// which skips the rename branch inside [_caseFolderId]. Drop that one
  /// entry first so the rename actually runs. (Child category folders keep
  /// their ids when the parent is renamed, so their cache stays valid.)
  static Future<void> syncCaseFolderName(CaseModel caseModel) {
    _folderIdCache.remove('case:${caseModel.caseId}');
    return _caseFolderId(caseModel);
  }

  /// Uploads [bytes] as [filename] into the given case's [category] folder,
  /// optionally nested under [subFolders] (e.g. a Collected Documents bucket
  /// or a Photos attendance folder), returning the created Drive file id.
  static Future<String> uploadCaseFile({
    required CaseModel caseModel,
    required CaseFileCategory category,
    List<String> subFolders = const [],
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final categoryFolderId =
        await caseFolderId(caseModel: caseModel, category: category);
    final targetFolderId = subFolders.isEmpty
        ? categoryFolderId
        : await _nested('case:${caseModel.caseId}:${category.name}',
            categoryFolderId, subFolders);
    return GoogleDriveService.uploadFile(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      parentId: targetFolderId,
    );
  }

  /// Downloads a previously-uploaded file by its Drive file id.
  static Future<Uint8List> downloadFile(String fileId) =>
      GoogleDriveService.downloadFile(fileId);

  /// Ensures every top-level case folder (and the Collected Documents
  /// sub-buckets) exists — called once when a case is created so the
  /// structure is visible in the user's Drive immediately, not only after
  /// the first upload to each.
  static Future<void> ensureCaseFoldersExist(CaseModel caseModel) async {
    for (final category in CaseFileCategory.values) {
      final folderId = await caseFolderId(caseModel: caseModel, category: category);
      if (category == CaseFileCategory.collectedDocuments) {
        for (final bucket in CollectedDocBucket.values) {
          await _nested('case:${caseModel.caseId}:${category.name}', folderId,
              [bucket.folderName]);
        }
      }
    }
  }
}
