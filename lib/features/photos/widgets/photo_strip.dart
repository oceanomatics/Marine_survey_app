// lib/features/photos/widgets/photo_strip.dart
//
// Horizontal thumbnail strip shown inside a damage item card.
// Tapping a thumb opens the full-screen viewer; the "+" button triggers capture.

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../models/photo_model.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/drive_photo_image.dart';
import '../../../shared/widgets/back_app_bar.dart';

const _kThumbSize = 72.0;
const _kColor = AppColors.purple;

class PhotoStrip extends StatelessWidget {
  const PhotoStrip({
    super.key,
    required this.photos,
    required this.onAddPhoto,
    this.onDeletePhoto,
  });

  final List<PhotoModel> photos;
  final VoidCallback onAddPhoto;
  final void Function(String photoId)? onDeletePhoto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kThumbSize,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Add button always first
          _AddButton(onTap: onAddPhoto),
          const SizedBox(width: 6),
          ...photos.map((ph) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _Thumbnail(
                  photo: ph,
                  onTap: () => _openViewer(
                      context, photos, photos.indexWhere((p) => p.id == ph.id)),
                  onDelete: onDeletePhoto != null
                      ? () => onDeletePhoto!(ph.id)
                      : null,
                ),
              )),
        ],
      ),
    );
  }

  void _openViewer(BuildContext context, List<PhotoModel> photos, int initial) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoViewer(photos: photos, initialIndex: initial),
      ),
    );
  }
}

// ── Add button ─────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _kThumbSize,
        height: _kThumbSize,
        decoration: BoxDecoration(
          color: _kColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: _kColor.withValues(alpha: 0.3), style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: _kColor, size: 22),
            SizedBox(height: 3),
            Text('Photo',
                style: TextStyle(
                    fontSize: 10, color: _kColor, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Thumbnail ──────────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.photo,
    required this.onTap,
    this.onDelete,
  });

  final PhotoModel photo;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          SizedBox(
            width: _kThumbSize,
            height: _kThumbSize,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DrivePhotoImage(
                photo: photo,
                fit: BoxFit.cover,
                noSourceBuilder: (_) => Container(
                  color: AppColors.surface,
                  child: const Icon(Icons.cloud_download_outlined,
                      color: AppColors.textTertiary, size: 24),
                ),
                errorBuilder: (_) => Container(
                  color: AppColors.surface,
                  child: const Icon(Icons.broken_image_outlined,
                      color: AppColors.textTertiary, size: 24),
                ),
              ),
            ),
          ),
          // Sync badge
          if (photo.syncStatus == PhotoSyncStatus.localOnly)
            Positioned(
              bottom: 3,
              right: 3,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.cloud_off_outlined,
                    size: 10, color: Colors.white),
              ),
            ),
          // Delete button
          if (onDelete != null)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Full-screen viewer ─────────────────────────────────────────────────────

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photos, required this.initialIndex});
  final List<PhotoModel> photos;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_current];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: BackAppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          photo.caption?.isNotEmpty == true
              ? photo.caption!
              : '${_current + 1} / ${widget.photos.length}',
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: PhotoViewGallery.builder(
        itemCount: widget.photos.length,
        pageController: PageController(initialPage: widget.initialIndex),
        onPageChanged: (i) => setState(() => _current = i),
        builder: (_, i) => PhotoViewGalleryPageOptions.customChild(
          child: DrivePhotoImage(
            photo: widget.photos[i],
            preferThumbnail: false,
            fit: BoxFit.contain,
            noSourceBuilder: (_) => const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: Colors.white38, size: 64),
            ),
            errorBuilder: (_) => const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: Colors.white38, size: 64),
            ),
          ),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
        ),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}
