// lib/features/photos/services/google_drive_service.dart
//
// Thin wrapper around Google Drive v3 REST API.
// Authentication is handled by GoogleAuthService (shared across Drive/Gmail/
// Photos — see lib/core/services/google_auth_service.dart for OAuth setup).

import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../core/services/google_auth_service.dart';

// ── Data model ───────────────────────────────────────────────────────────────

class DriveItem {
  const DriveItem({
    required this.id,
    required this.name,
    required this.isFolder,
    this.mimeType,
    this.sizeBytes,
  });

  final String id;
  final String name;
  final bool isFolder;
  final String? mimeType;
  final int? sizeBytes;
}

// Re-exported so existing callers importing DriveSignInCancelled keep working.
typedef DriveSignInCancelled = GoogleSignInCancelled;

// ── Service ──────────────────────────────────────────────────────────────────

class GoogleDriveService {
  GoogleDriveService._();

  static const _folderMime = 'application/vnd.google-apps.folder';

  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://www.googleapis.com/drive/v3/',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 3),
  ));

  static final _uploadDio = Dio(BaseOptions(
    baseUrl: 'https://www.googleapis.com/upload/drive/v3/',
    connectTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(minutes: 5),
  ));

  static Future<Options> _authHeaders() async => Options(headers: {
        'Authorization': 'Bearer ${await GoogleAuthService.accessToken()}'
      });

  /// Lists folders and image files directly inside [folderId].
  /// Pass 'root' for My Drive root.
  /// Returns folders first (sorted by name), then images (sorted by name).
  static Future<List<DriveItem>> listFolder(String folderId) async {
    final all = <DriveItem>[];
    String? pageToken;

    do {
      final resp = await _dio.get<Map<String, dynamic>>(
        'files',
        queryParameters: {
          'q': "'$folderId' in parents and trashed = false",
          'fields': 'nextPageToken,files(id,name,mimeType,size)',
          'orderBy': 'folder,name',
          'pageSize': 200,
          if (pageToken != null) 'pageToken': pageToken,
        },
        options: await _authHeaders(),
      );

      for (final f in (resp.data!['files'] as List)) {
        final mime = (f['mimeType'] as String? ?? '');
        final isFolder = mime == _folderMime;
        if (!isFolder && !mime.startsWith('image/')) continue;
        all.add(DriveItem(
          id: f['id'] as String,
          name: f['name'] as String,
          isFolder: isFolder,
          mimeType: mime,
          sizeBytes: int.tryParse(f['size']?.toString() ?? ''),
        ));
      }

      pageToken = resp.data!['nextPageToken'] as String?;
    } while (pageToken != null);

    return all;
  }

  /// Downloads a file and returns its raw bytes.
  static Future<Uint8List> downloadFile(String fileId) async {
    final options = await _authHeaders();
    final resp = await _dio.get<List<int>>(
      'files/$fileId',
      queryParameters: {'alt': 'media'},
      options: options.copyWith(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(resp.data!);
  }

  /// Finds a folder named [name] directly under [parentId] ('root' for My
  /// Drive), creating it if it doesn't exist yet. Only searches/creates
  /// within files this app owns (drive.file scope) — won't see or clash
  /// with folders created by other apps or manually in a way this app can't
  /// then write into.
  static Future<String> findOrCreateFolder(String name,
      {String parentId = 'root'}) async {
    final escaped = name.replaceAll("'", r"\'");
    final resp = await _dio.get<Map<String, dynamic>>(
      'files',
      queryParameters: {
        'q': "name = '$escaped' and '$parentId' in parents and "
            "mimeType = '$_folderMime' and trashed = false",
        'fields': 'files(id,name)',
        'pageSize': 1,
      },
      options: await _authHeaders(),
    );
    final existing = (resp.data!['files'] as List);
    if (existing.isNotEmpty) return existing.first['id'] as String;

    final created = await _dio.post<Map<String, dynamic>>(
      'files',
      data: {
        'name': name,
        'mimeType': _folderMime,
        'parents': [parentId],
      },
      options: await _authHeaders(),
    );
    return created.data!['id'] as String;
  }

  /// Uploads [bytes] as a new file named [filename] inside [parentId].
  /// Uses multipart upload (metadata + content in one request) — fine for
  /// the report/photo/invoice file sizes this app deals with.
  static Future<String> uploadFile({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required String parentId,
  }) async {
    final metadata = jsonEncode({
      'name': filename,
      'parents': [parentId],
    });
    const boundary = '-------drive-upload-boundary';
    final body = BytesBuilder()
      ..add(utf8.encode('--$boundary\r\n'))
      ..add(
          utf8.encode('Content-Type: application/json; charset=UTF-8\r\n\r\n'))
      ..add(utf8.encode('$metadata\r\n'))
      ..add(utf8.encode('--$boundary\r\n'))
      ..add(utf8.encode('Content-Type: $mimeType\r\n\r\n'))
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--'));

    final token = await GoogleAuthService.accessToken();
    final resp = await _uploadDio.post<Map<String, dynamic>>(
      'files',
      queryParameters: {'uploadType': 'multipart'},
      data: body.toBytes(),
      options: Options(headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/related; boundary=$boundary',
      }),
    );
    return resp.data!['id'] as String;
  }
}
