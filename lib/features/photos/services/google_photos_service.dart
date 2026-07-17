// lib/features/photos/services/google_photos_service.dart
//
// Google Photos **Picker API** client — the sanctioned post-March-2025 path
// for importing photos the user explicitly selects from their own Google
// Photos library. Authentication is shared with Drive/Gmail via
// GoogleAuthService. Scope: photospicker.mediaitems.readonly.
//
// The old Photos Library shared-album EXPORT (findOrCreateAlbum / shareAlbum /
// addPhotoToAlbum, appendonly + sharing scopes) was removed on 17 Jul 2026 —
// nobody asked for it and the deprecated sharing scope caused a 403 saga.
//
// Flow:
//   1. createSession()          → POST /v1/sessions   (returns pickerUri)
//   2. user opens pickerUri, selects photos in Google's own picker UI
//   3. pollSession(id)          → GET  /v1/sessions/{id}  until mediaItemsSet
//   4. listPickedMediaItems(id) → GET  /v1/mediaItems?sessionId=…
//   5. downloadMediaItem(item)  → GET  baseUrl=d-... (bytes)
//   6. deleteSession(id)        → DELETE /v1/sessions/{id}  (cleanup)

import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/services/google_auth_service.dart';

/// A picking session returned by the Photos Picker API.
class PhotosPickerSession {
  const PhotosPickerSession({
    required this.id,
    required this.pickerUri,
    required this.mediaItemsSet,
    required this.pollIntervalSeconds,
    required this.timeoutSeconds,
  });

  final String id;

  /// URL to open in a browser/webview so the user can pick photos.
  final String pickerUri;

  /// True once the user has finished selecting and the selection is available.
  final bool mediaItemsSet;

  /// Recommended polling cadence + overall timeout from pollingConfig.
  final int pollIntervalSeconds;
  final int timeoutSeconds;

  factory PhotosPickerSession.fromJson(Map<String, dynamic> j) {
    int parseDuration(String? s, int fallback) {
      // Durations come back like "3s" / "1800s".
      if (s == null) return fallback;
      final m = RegExp(r'([0-9.]+)s?').firstMatch(s);
      final v = m != null ? double.tryParse(m.group(1)!) : null;
      return v != null ? v.ceil() : fallback;
    }

    final polling = j['pollingConfig'] as Map<String, dynamic>?;
    return PhotosPickerSession(
      id: j['id'] as String,
      pickerUri: j['pickerUri'] as String? ?? '',
      mediaItemsSet: j['mediaItemsSet'] as bool? ?? false,
      pollIntervalSeconds: parseDuration(polling?['pollInterval'] as String?, 3),
      timeoutSeconds: parseDuration(polling?['timeoutIn'] as String?, 1800),
    );
  }
}

/// A single photo the user picked.
class PickedMediaItem {
  const PickedMediaItem({
    required this.id,
    required this.baseUrl,
    required this.mimeType,
    required this.filename,
    this.createTime,
  });

  final String id;

  /// Base URL for the bytes — append `=d` to download the full-resolution
  /// original (per Picker API docs).
  final String baseUrl;
  final String mimeType;
  final String filename;
  final DateTime? createTime;

  factory PickedMediaItem.fromJson(Map<String, dynamic> j) {
    final mediaFile = j['mediaFile'] as Map<String, dynamic>? ?? const {};
    return PickedMediaItem(
      id: j['id'] as String? ?? '',
      baseUrl: mediaFile['baseUrl'] as String? ?? '',
      mimeType: mediaFile['mimeType'] as String? ?? 'image/jpeg',
      filename: mediaFile['filename'] as String? ?? 'photo.jpg',
      createTime: DateTime.tryParse(j['createTime'] as String? ?? ''),
    );
  }

  bool get isPhoto => mimeType.startsWith('image/');
}

class GooglePhotosService {
  GooglePhotosService._();

  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://photospicker.googleapis.com/v1/',
    connectTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 2),
  ));

  static Future<Options> _authHeaders() async => Options(headers: {
        'Authorization': 'Bearer ${await GoogleAuthService.accessToken()}'
      });

  /// Creates a new picking session. Open [PhotosPickerSession.pickerUri] in a
  /// browser so the user can select photos, then poll [pollSession].
  static Future<PhotosPickerSession> createSession() async {
    final resp = await _dio.post<Map<String, dynamic>>(
      'sessions',
      data: <String, dynamic>{},
      options: await _authHeaders(),
    );
    return PhotosPickerSession.fromJson(resp.data!);
  }

  /// Fetches the current state of session [sessionId] — poll this until
  /// [PhotosPickerSession.mediaItemsSet] is true (or the timeout elapses).
  static Future<PhotosPickerSession> pollSession(String sessionId) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      'sessions/$sessionId',
      options: await _authHeaders(),
    );
    return PhotosPickerSession.fromJson(resp.data!);
  }

  /// Lists every media item the user selected in [sessionId], paging through
  /// results. Only call once the session reports mediaItemsSet == true.
  static Future<List<PickedMediaItem>> listPickedMediaItems(
      String sessionId) async {
    final items = <PickedMediaItem>[];
    String? pageToken;
    do {
      final resp = await _dio.get<Map<String, dynamic>>(
        'mediaItems',
        queryParameters: {
          'sessionId': sessionId,
          'pageSize': 100,
          if (pageToken != null) 'pageToken': pageToken,
        },
        options: await _authHeaders(),
      );
      final raw = (resp.data!['mediaItems'] as List? ?? []);
      for (final m in raw) {
        items.add(PickedMediaItem.fromJson(m as Map<String, dynamic>));
      }
      pageToken = resp.data!['nextPageToken'] as String?;
    } while (pageToken != null);
    return items;
  }

  /// Downloads the full-resolution bytes of a picked [item] (appends `=d` to
  /// its baseUrl, which the Picker API requires and which returns the original).
  static Future<Uint8List> downloadMediaItem(PickedMediaItem item) async {
    final token = await GoogleAuthService.accessToken();
    final resp = await Dio().get<List<int>>(
      '${item.baseUrl}=d',
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    return Uint8List.fromList(resp.data!);
  }

  /// Best-effort cleanup — deletes the picking session once import is done.
  static Future<void> deleteSession(String sessionId) async {
    try {
      await _dio.delete<void>('sessions/$sessionId',
          options: await _authHeaders());
    } catch (_) {
      // Session auto-expires anyway; a failed delete is harmless.
    }
  }
}
