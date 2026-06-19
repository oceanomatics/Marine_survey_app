// lib/features/photos/screens/photo_gallery_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/photo_model.dart';
import '../providers/photo_provider.dart';
import '../../attendances/providers/attendances_provider.dart';
import '../../attendances/models/attendance_model.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';

const _kColor = AppColors.purple;
const _kThumbSize = 110.0;
const _kSpacing = 3.0;

class PhotoGalleryScreen extends ConsumerWidget {
  const PhotoGalleryScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(photosProvider(caseId)).value ?? [];
    final attendances = ref.watch(attendancesProvider(caseId)).value ?? [];

    // Sort attendances most-recent-first
    final sorted = [...attendances]..sort((a, b) {
        if (a.attendanceDate == null) return 1;
        if (b.attendanceDate == null) return -1;
        return b.attendanceDate!.compareTo(a.attendanceDate!);
      });

    final unassigned =
        photos.where((p) => p.attendanceId == null).toList();
    final totalCount = photos.length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          totalCount == 0 ? 'Photos' : 'Photos  ($totalCount)',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPhoto(context, ref, attendanceId: null),
        backgroundColor: _kColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_outlined),
        label:
            const Text('Add Photo', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: photos.isEmpty && attendances.isEmpty
          ? _EmptyState(onAdd: () => _addPhoto(context, ref, attendanceId: null))
          : CustomScrollView(
              slivers: [
                // ── One section per attendance ─────────────────────────
                for (final att in sorted) ...[
                  _AttendanceSectionHeader(
                    attendance: att,
                    photoCount: photos
                        .where((p) => p.attendanceId == att.attendanceId)
                        .length,
                    onAddPhoto: () =>
                        _addPhoto(context, ref, attendanceId: att.attendanceId),
                  ),
                  _PhotoSliverGrid(
                    photos: photos
                        .where((p) => p.attendanceId == att.attendanceId)
                        .toList(),
                    allPhotos: photos,
                    onDelete: (id) =>
                        ref.read(photosProvider(caseId).notifier).deletePhoto(id),
                  ),
                ],

                // ── Unassigned section ────────────────────────────────
                if (unassigned.isNotEmpty) ...[
                  const _UnassignedHeader(),
                  _PhotoSliverGrid(
                    photos: unassigned,
                    allPhotos: photos,
                    onDelete: (id) =>
                        ref.read(photosProvider(caseId).notifier).deletePhoto(id),
                  ),
                ],

                // Space for FAB
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  Future<void> _addPhoto(
    BuildContext context,
    WidgetRef ref, {
    required String? attendanceId,
  }) async {
    final source = await _pickSource(context);
    if (source == null || !context.mounted) return;
    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 90);
    if (picked == null || !context.mounted) return;
    final bytes = await picked.readAsBytes();
    await ref.read(photosProvider(caseId).notifier).addPhoto(
          caseId: caseId,
          bytes: bytes,
          attendanceId: attendanceId,
        );
  }

  Future<ImageSource?> _pickSource(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SourcePicker(),
    );
  }
}

// ── Source picker sheet ────────────────────────────────────────────────────

class _SourcePicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _kColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.camera_alt_outlined, color: _kColor),
            ),
            title: const Text('Camera',
                style:
                    TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _kColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.photo_library_outlined, color: _kColor),
            ),
            title: const Text('Photo Library',
                style:
                    TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );
  }
}

// ── Attendance section header ──────────────────────────────────────────────

class _AttendanceSectionHeader extends StatelessWidget {
  const _AttendanceSectionHeader({
    required this.attendance,
    required this.photoCount,
    required this.onAddPhoto,
  });

  final SurveyAttendanceModel attendance;
  final int photoCount;
  final VoidCallback onAddPhoto;

  Color _typeColor(AttendanceType t) => switch (t) {
        AttendanceType.initial => const Color(0xFFBF7E3A),
        AttendanceType.followUp => AppColors.midBlue,
        AttendanceType.finalInspection => AppColors.teal,
        AttendanceType.remoteReview => AppColors.purple,
      };

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(attendance.attendanceType);
    final dateStr = attendance.attendanceDate != null
        ? DateFormat('dd MMM yyyy').format(attendance.attendanceDate!)
        : 'Date TBC';

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 14, 12, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                attendance.attendanceType.label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateStr,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  if (attendance.location != null)
                    Text(attendance.location!,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                ],
              ),
            ),
            // Photo count badge
            if (photoCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$photoCount',
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            // Add button
            GestureDetector(
              onTap: onAddPhoto,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add_a_photo_outlined,
                    color: color, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Unassigned header ──────────────────────────────────────────────────────

class _UnassignedHeader extends StatelessWidget {
  const _UnassignedHeader();

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Text(
          'UNASSIGNED',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

// ── Photo sliver grid ──────────────────────────────────────────────────────

class _PhotoSliverGrid extends StatelessWidget {
  const _PhotoSliverGrid({
    required this.photos,
    required this.allPhotos,
    required this.onDelete,
  });

  final List<PhotoModel> photos;
  final List<PhotoModel> allPhotos;
  final void Function(String) onDelete;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'No photos for this attendance yet.',
            style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: _kSpacing,
          mainAxisSpacing: _kSpacing,
          childAspectRatio: 1,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => _PhotoTile(
            photo: photos[i],
            onTap: () => _openViewer(context, i),
            onDelete: () => onDelete(photos[i].id),
          ),
          childCount: photos.length,
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, int initial) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _PhotoViewer(photos: photos, initialIndex: initial),
      ),
    );
  }
}

// ── Photo tile ─────────────────────────────────────────────────────────────

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.onTap,
    required this.onDelete,
  });

  final PhotoModel photo;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showOptions(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              File(photo.localPath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surface,
                child: const Icon(Icons.broken_image_outlined,
                    color: AppColors.textTertiary),
              ),
            ),
          ),
          // Damage link badge
          if (photo.linkedToType == 'damage_item')
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.coral.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('DMG',
                    style: TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          // Cloud sync badge
          if (photo.syncStatus == PhotoSyncStatus.localOnly)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.cloud_off_outlined,
                    size: 9, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete photo',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Full-screen viewer ─────────────────────────────────────────────────────

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer(
      {required this.photos, required this.initialIndex});
  final List<PhotoModel> photos;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ph = widget.photos[_current];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ph.caption?.isNotEmpty == true
                  ? ph.caption!
                  : '${_current + 1} / ${widget.photos.length}',
              style: const TextStyle(fontSize: 14),
            ),
            if (ph.linkedToType == 'damage_item')
              const Text('Linked to damage item',
                  style: TextStyle(
                      fontSize: 10, color: Colors.white54)),
          ],
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Center(
            child: Image.file(
              File(widget.photos[i].localPath),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _kColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.photo_library_outlined,
                color: _kColor, size: 30),
          ),
          const SizedBox(height: 16),
          const Text('No photos yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Photos are grouped by attendance visit',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add First Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
