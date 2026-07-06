// lib/shared/widgets/drive_photo_image.dart
//
// Renders a PhotoModel's image regardless of platform: uses the local file
// cache when available (fast path, native only — see
// PhotoNotifier.ensureLocalFile), and falls back to downloading the bytes
// straight from Drive when there's no local copy — which is *always* the
// case on web (no dart:io there) and can also happen on native before a
// photo has synced to this device. Falls back to a placeholder if neither
// a local file nor a Drive copy exists (e.g. a photo captured before the
// Drive-backed upload migration, which never got a drive_file_id at all).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/services/drive_storage_service.dart';
import '../../features/photos/models/photo_model.dart';
import '../theme/app_theme.dart';

/// Dedupes/caches in-flight Drive downloads for photo bytes so the same
/// file id isn't re-fetched on every rebuild/scroll.
class DrivePhotoBytesCache {
  DrivePhotoBytesCache._();
  static final Map<String, Future<Uint8List>> _cache = {};
  static Future<Uint8List> fetch(String fileId) =>
      _cache.putIfAbsent(fileId, () => DriveStorageService.downloadFile(fileId));
}

class DrivePhotoImage extends StatelessWidget {
  const DrivePhotoImage({
    super.key,
    required this.photo,
    this.preferThumbnail = true,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.errorBuilder,
    this.loadingBuilder,
    this.noSourceBuilder,
  });

  final PhotoModel photo;

  /// true: prefer the (smaller/faster) thumbnail Drive copy, falling back to
  /// the full-res one. false: always use the full-res copy — for a large
  /// single-photo view (report cover, vessel hero shot) where a thumbnail
  /// would look soft.
  final bool preferThumbnail;
  final BoxFit fit;
  final int? cacheWidth;
  final WidgetBuilder? errorBuilder;
  final WidgetBuilder? loadingBuilder;

  /// Shown when the photo has neither a local file nor any Drive copy at
  /// all (e.g. captured before the Drive-backed upload migration) —
  /// distinct from [errorBuilder], which is for an actual fetch failure.
  /// Defaults to [errorBuilder]'s widget if not given.
  final WidgetBuilder? noSourceBuilder;

  String? get _driveFileId => preferThumbnail
      ? (photo.thumbnailDriveFileId ?? photo.driveFileId)
      : (photo.driveFileId ?? photo.thumbnailDriveFileId);

  @override
  Widget build(BuildContext context) {
    if (photo.hasLocalFile) {
      final primaryPath =
          preferThumbnail ? (photo.thumbnailPath ?? photo.localPath!) : photo.localPath!;
      return Image.file(
        File(primaryPath),
        fit: fit,
        cacheWidth: cacheWidth,
        errorBuilder: (_, __, ___) => primaryPath != photo.localPath
            ? Image.file(
                File(photo.localPath!),
                fit: fit,
                cacheWidth: cacheWidth,
                errorBuilder: (_, __, ___) => _fallback(context),
              )
            : _fallback(context),
      );
    }

    final driveFileId = _driveFileId;
    if (driveFileId == null) {
      return (noSourceBuilder ?? errorBuilder)?.call(context) ?? _fallback(context);
    }

    return FutureBuilder<Uint8List>(
      future: DrivePhotoBytesCache.fetch(driveFileId),
      builder: (ctx, snap) {
        if (snap.hasData) {
          return Image.memory(snap.data!, fit: fit, cacheWidth: cacheWidth);
        }
        if (snap.hasError) return _fallback(ctx);
        return loadingBuilder?.call(ctx) ??
            Container(
              color: AppColors.surface,
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
      },
    );
  }

  Widget _fallback(BuildContext context) =>
      errorBuilder?.call(context) ??
      Container(
        color: AppColors.surface,
        child: const Icon(Icons.broken_image_outlined, color: AppColors.textTertiary),
      );
}
