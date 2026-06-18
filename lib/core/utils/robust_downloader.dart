// lib/core/utils/robust_downloader.dart
//
// Downloads a file from a URL with chunked range requests and per-chunk
// exponential-backoff retry. Falls back to a single-shot retry loop when the
// server does not advertise Accept-Ranges.

import 'dart:typed_data';
import 'package:dio/dio.dart';

class RobustDownloader {
  static const _maxAttempts = 5;
  static const _chunkSize = 1024 * 1024; // 1 MB per chunk

  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 90),
  ));

  /// Downloads the file at [url].
  /// [onProgress] is called with (bytesReceived, totalBytes).
  /// totalBytes is 0 when the server did not return Content-Length.
  static Future<Uint8List> download(
    String url, {
    void Function(int received, int total)? onProgress,
  }) async {
    int? totalBytes;
    bool acceptsRanges = false;

    try {
      final head = await _dio.head(url,
          options: Options(receiveTimeout: const Duration(seconds: 15)));
      final cl = head.headers.value('content-length');
      if (cl != null) totalBytes = int.tryParse(cl);
      acceptsRanges =
          head.headers.value('accept-ranges')?.toLowerCase() == 'bytes';
    } catch (_) {
      // HEAD unsupported or network glitch — fall through to simple download.
    }

    if (totalBytes != null && totalBytes > 0 && acceptsRanges) {
      return _chunkedDownload(url, totalBytes, onProgress: onProgress);
    }
    return _simpleDownload(url, onProgress: onProgress);
  }

  // ── Chunked path ─────────────────────────────────────────────────────────

  static Future<Uint8List> _chunkedDownload(
    String url,
    int totalBytes, {
    void Function(int received, int total)? onProgress,
  }) async {
    final buffer = Uint8List(totalBytes);
    int received = 0;

    while (received < totalBytes) {
      final rangeEnd = (received + _chunkSize - 1).clamp(0, totalBytes - 1);
      final chunk = await _fetchRange(url, received, rangeEnd);
      buffer.setAll(received, chunk);
      received += chunk.length;
      onProgress?.call(received, totalBytes);
    }

    return buffer;
  }

  static Future<Uint8List> _fetchRange(
      String url, int start, int end) async {
    DioException? lastErr;
    for (int attempt = 0; attempt < _maxAttempts; attempt++) {
      try {
        final resp = await _dio.get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {'Range': 'bytes=$start-$end'},
            receiveTimeout: const Duration(seconds: 90),
          ),
        );
        if (resp.data == null || resp.data!.isEmpty) {
          throw Exception('Empty chunk from server');
        }
        return Uint8List.fromList(resp.data!);
      } on DioException catch (e) {
        lastErr = e;
        if (_isFatal(e)) rethrow;
        await Future.delayed(_backoff(attempt));
      }
    }
    throw lastErr!;
  }

  // ── Simple path (no range support) ───────────────────────────────────────

  static Future<Uint8List> _simpleDownload(
    String url, {
    void Function(int received, int total)? onProgress,
  }) async {
    DioException? lastErr;
    for (int attempt = 0; attempt < _maxAttempts; attempt++) {
      try {
        final resp = await _dio.get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 120),
          ),
          onReceiveProgress: onProgress != null
              ? (r, t) => onProgress(r, t < 0 ? 0 : t)
              : null,
        );
        if (resp.data == null || resp.data!.isEmpty) {
          throw Exception('Empty response from server');
        }
        return Uint8List.fromList(resp.data!);
      } on DioException catch (e) {
        lastErr = e;
        if (_isFatal(e)) rethrow;
        await Future.delayed(_backoff(attempt));
      }
    }
    throw lastErr!;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  // Don't retry genuine client errors (404, 403, etc.).
  // Do retry 408 (request timeout), 429 (rate limit), 5xx (server errors).
  static bool _isFatal(DioException e) {
    final code = e.response?.statusCode;
    if (code == null) return false;
    if (code >= 400 && code < 500) {
      return code != 408 && code != 429;
    }
    return false;
  }

  // Exponential backoff: 1 s, 2 s, 4 s, 8 s, capped at 16 s.
  static Duration _backoff(int attempt) =>
      Duration(seconds: (1 << attempt).clamp(1, 16));
}
