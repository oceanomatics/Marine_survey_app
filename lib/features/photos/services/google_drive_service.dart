// lib/features/photos/services/google_drive_service.dart
//
// Thin wrapper around Google Drive v3 REST API.
// Authentication is handled by google_sign_in (silent re-auth on every call).
//
// SETUP REQUIRED — Google Cloud Console:
//   1. Create a project, enable "Google Drive API"
//   2. OAuth 2.0 → create an Android credential (package name + SHA-1 fingerprint)
//   3. OAuth 2.0 → create an iOS credential (bundle ID)
//   4. Download google-services.json → android/app/
//      Download GoogleService-Info.plist → ios/Runner/  (add via Xcode)
//   5. iOS: add CFBundleURLSchemes entry in Info.plist (the REVERSED_CLIENT_ID
//      from GoogleService-Info.plist)

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

// Internal sentinel — thrown when the user cancels the Google sign-in dialog.
class DriveSignInCancelled implements Exception {
  const DriveSignInCancelled();
}

// ── Service ──────────────────────────────────────────────────────────────────

class GoogleDriveService {
  GoogleDriveService._();

  static final _signIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.readonly'],
  );

  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://www.googleapis.com/drive/v3/',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 3),
  ));

  static GoogleSignInAccount? get currentAccount => _signIn.currentUser;

  /// Signs in silently if possible, otherwise shows the account picker.
  /// Returns null only if the user explicitly cancels.
  static Future<GoogleSignInAccount?> ensureSignedIn() async {
    return _signIn.currentUser ??
        await _signIn.signInSilently() ??
        await _signIn.signIn();
  }

  static Future<void> signOut() => _signIn.signOut();

  static Future<String> _accessToken() async {
    final account = await ensureSignedIn();
    if (account == null) throw const DriveSignInCancelled();
    final auth = await account.authentication;
    final token = auth.accessToken;
    if (token == null) throw Exception('Could not obtain Drive access token');
    return token;
  }

  /// Lists folders and image files directly inside [folderId].
  /// Pass 'root' for My Drive root.
  /// Returns folders first (sorted by name), then images (sorted by name).
  static Future<List<DriveItem>> listFolder(String folderId) async {
    final token = await _accessToken();
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
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      for (final f in (resp.data!['files'] as List)) {
        final mime = (f['mimeType'] as String? ?? '');
        final isFolder = mime == 'application/vnd.google-apps.folder';
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
    final token = await _accessToken();
    final resp = await _dio.get<List<int>>(
      'files/$fileId',
      queryParameters: {'alt': 'media'},
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(resp.data!);
  }
}
