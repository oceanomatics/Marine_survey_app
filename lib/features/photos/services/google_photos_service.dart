// lib/features/photos/services/google_photos_service.dart
//
// Thin wrapper around the Google Photos Library API v1. Authentication is
// shared with Drive/Gmail via GoogleAuthService.
//
// Scope used is photoslibrary.appendonly — write-only, app-created-content
// access (no ability to read/list the user's existing library), plus
// photoslibrary.sharing to make an album shareable. That's the minimal
// scope pairing for "sync survey photos to a shared album per case."

import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../core/services/google_auth_service.dart';

class GooglePhotosService {
  GooglePhotosService._();

  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://photoslibrary.googleapis.com/v1/',
    connectTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(minutes: 5),
    receiveTimeout: const Duration(minutes: 2),
  ));

  static Future<Options> _authHeaders() async => Options(headers: {
        'Authorization': 'Bearer ${await GoogleAuthService.accessToken()}'
      });

  /// Finds an app-created album titled [title], creating it if absent.
  /// appendonly scope only lists/creates albums this app itself created.
  static Future<String> findOrCreateAlbum(String title) async {
    String? pageToken;
    do {
      final resp = await _dio.get<Map<String, dynamic>>(
        'albums',
        queryParameters: {
          'pageSize': 50,
          if (pageToken != null) 'pageToken': pageToken,
        },
        options: await _authHeaders(),
      );
      final albums = (resp.data!['albums'] as List? ?? []);
      for (final a in albums) {
        if (a['title'] == title) return a['id'] as String;
      }
      pageToken = resp.data!['nextPageToken'] as String?;
    } while (pageToken != null);

    final created = await _dio.post<Map<String, dynamic>>(
      'albums',
      data: {
        'album': {'title': title}
      },
      options: await _authHeaders(),
    );
    return created.data!['id'] as String;
  }

  /// Makes [albumId] shareable and returns its share URL. Safe to call
  /// repeatedly — Google Photos returns the existing share info if the
  /// album is already shared.
  static Future<String?> shareAlbum(String albumId) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        'albums/$albumId:share',
        data: <String, dynamic>{},
        options: await _authHeaders(),
      );
      return resp.data?['shareInfo']?['shareableUrl'] as String?;
    } on DioException catch (e) {
      // Already shared — fetch the existing link instead of failing.
      if (e.response?.statusCode == 400) {
        final resp = await _dio.get<Map<String, dynamic>>(
          'albums/$albumId',
          options: await _authHeaders(),
        );
        return resp.data?['shareInfo']?['shareableUrl'] as String?;
      }
      rethrow;
    }
  }

  /// Uploads raw image bytes and returns an upload token — good for one
  /// subsequent mediaItems.batchCreate call, per Google's docs.
  static Future<String> _uploadBytes(Uint8List bytes, String filename) async {
    final token = await GoogleAuthService.accessToken();
    final resp = await _dio.post<String>(
      'uploads',
      data: bytes,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/octet-stream',
          'X-Goog-Upload-Content-Type': 'image/jpeg',
          'X-Goog-Upload-Protocol': 'raw',
          'X-Goog-Upload-File-Name': filename,
        },
      ),
    );
    return resp.data!;
  }

  /// Uploads [bytes] and adds it to [albumId] in one step. Returns the
  /// created media item's id.
  static Future<String> addPhotoToAlbum({
    required String albumId,
    required Uint8List bytes,
    required String filename,
    String? description,
  }) async {
    final uploadToken = await _uploadBytes(bytes, filename);
    final resp = await _dio.post<Map<String, dynamic>>(
      'mediaItems:batchCreate',
      data: {
        'albumId': albumId,
        'newMediaItems': [
          {
            if (description != null) 'description': description,
            'simpleMediaItem': {'uploadToken': uploadToken},
          }
        ],
      },
      options: await _authHeaders(),
    );
    final results = resp.data!['newMediaItemResults'] as List;
    final result = results.first as Map<String, dynamic>;
    final status = result['status'] as Map<String, dynamic>?;
    final code = status?['code'] as int?;
    if (code != null && code != 0) {
      throw Exception('Photos upload failed: ${status?['message']}');
    }
    return result['mediaItem']['id'] as String;
  }
}
