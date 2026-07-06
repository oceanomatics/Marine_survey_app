// lib/features/photos/screens/photo_gallery_screen.dart

import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';

import 'package:image_picker/image_picker.dart';

import '../models/photo_model.dart';
import '../providers/photo_provider.dart';
import '../services/google_photos_service.dart';
import '../../attendances/providers/attendances_provider.dart';
import '../../attendances/models/attendance_model.dart';
import '../../cases/providers/cases_provider.dart';
import '../../survey/providers/damage_provider.dart';
import '../../../core/services/google_auth_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/drive_photo_image.dart';
import '../../../shared/widgets/photo_picker_sheet.dart';

const _kColor = AppColors.purple;
const _kSpacing = 3.0;

// ── Screen ─────────────────────────────────────────────────────────────────

class PhotoGalleryScreen extends ConsumerStatefulWidget {
  const PhotoGalleryScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends ConsumerState<PhotoGalleryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _importing = false;
  int _importDone = 0;
  int _importTotal = 0;
  bool _syncing = false;
  int _syncDone = 0;
  int _syncTotal = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Google Photos sync ──────────────────────────────────────────────────

  Future<void> _syncToGooglePhotos() async {
    final all = ref.read(photosProvider(widget.caseId)).value ?? [];
    final unsynced =
        all.where((p) => p.syncStatus != PhotoSyncStatus.synced).toList();
    if (unsynced.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All photos already synced')),
      );
      return;
    }

    setState(() {
      _syncing = true;
      _syncDone = 0;
      _syncTotal = unsynced.length;
    });

    try {
      final caseModel = ref.read(caseProvider(widget.caseId)).value;
      final albumTitle = '${caseModel?.title ?? widget.caseId} — Survey Photos';
      final albumId = await GooglePhotosService.findOrCreateAlbum(albumTitle);
      final shareUrl = await GooglePhotosService.shareAlbum(albumId);
      final notifier = ref.read(photosProvider(widget.caseId).notifier);

      for (final photo in unsynced) {
        if (!mounted) return;
        try {
          final resolved = photo.hasLocalFile
              ? photo
              : await notifier.ensureLocalFile(photo.id);
          if (resolved == null || !resolved.hasLocalFile) continue;
          final bytes = await File(resolved.localPath!).readAsBytes();
          await GooglePhotosService.addPhotoToAlbum(
            albumId: albumId,
            bytes: bytes,
            filename: '${photo.id}.jpg',
            description: photo.caption,
          );
          await notifier.markSynced(photo.id, shareUrl);
        } catch (_) {
          // Skip this photo, continue with the rest — rough-edge MVP.
        }
        if (mounted) setState(() => _syncDone++);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Synced $_syncDone / $_syncTotal photos to Google Photos')),
        );
      }
    } on GoogleSignInCancelled {
      // User cancelled sign-in — nothing to do.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Sync failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  // ── Photo import pipeline ──────────────────────────────────────────────

  Future<void> _addPhotos({
    String? attendanceId,
    String? linkedToType,
    String? linkedToId,
  }) async {
    final source = await showModalBottomSheet<PhotoPickSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const PhotoPickerSheet(accentColor: _kColor),
    );
    if (source == null || !mounted) return;

    // Folder import: process files one-by-one to avoid buffering all bytes
    // in memory before showing progress.
    if (source == PhotoPickSource.localFolder) {
      await _addPhotosFromLocalFolder(
        attendanceId: attendanceId,
        linkedToType: linkedToType,
        linkedToId: linkedToId,
      );
      return;
    }

    // Gallery: handle separately to avoid buffering all bytes before progress shows.
    if (source == PhotoPickSource.gallery) {
      await _addPhotosFromGallery(
        attendanceId: attendanceId,
        linkedToType: linkedToType,
        linkedToId: linkedToId,
      );
      return;
    }

    final bytesList =
        await PhotoPickerSheet.resolveBytes(source, context: context);
    if (bytesList.isEmpty || !mounted) return;

    await _importBytes(
      bytesList,
      attendanceId: attendanceId,
      linkedToType: linkedToType,
      linkedToId: linkedToId,
    );
  }

  /// Gallery import: picks files first (no native compression), shows the
  /// progress indicator immediately, then compresses each photo in Dart.
  ///
  /// Why no imageQuality on pickMultiImage: that parameter triggers native
  /// re-encoding of ALL selected photos before the Future completes, causing
  /// a multi-second freeze between the user confirming the selection and the
  /// progress bar appearing. Moving compression to Dart lets the picker return
  /// immediately so _importing = true renders on the very next frame.
  Future<void> _addPhotosFromGallery({
    String? attendanceId,
    String? linkedToType,
    String? linkedToId,
  }) async {
    final xFiles = await ImagePicker()
        .pickMultiImage(); // no imageQuality — see note above
    if (xFiles.isEmpty || !mounted) return;

    setState(() {
      _importing = true;
      _importDone = 0;
      _importTotal = xFiles.length;
    });

    // Let the progress-bar frame actually paint before starting heavy work.
    await SchedulerBinding.instance.endOfFrame;

    // Serial (batchSize 1): original full-res photos can be 10–20 MB each.
    // Processing one at a time keeps peak RSS to one raw photo + one compressed
    // copy rather than spiking with multiple concurrent reads.
    for (var i = 0; i < xFiles.length; i++) {
      if (!mounted) break;
      var bytes = await xFiles[i].readAsBytes();
      // Dart-side compression — equivalent quality to the removed imageQuality: 90
      // but applied per-photo so processing overlaps with UI rendering.
      try {
        bytes = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 2048,
          minHeight: 2048,
          quality: 85,
          format: CompressFormat.jpeg,
        );
      } catch (_) {
        // If compression fails (e.g. unsupported format) keep original bytes.
      }
      await ref.read(photosProvider(widget.caseId).notifier).addPhoto(
            caseId: widget.caseId,
            bytes: bytes,
            attendanceId: attendanceId,
            linkedToType: linkedToType,
            linkedToId: linkedToId,
          );
      if (mounted) setState(() => _importDone++);
    }

    if (mounted) setState(() => _importing = false);
  }

  /// Folder import: resolves files then imports progressively (no up-front
  /// memory spike from reading all files at once).
  Future<void> _addPhotosFromLocalFolder({
    String? attendanceId,
    String? linkedToType,
    String? linkedToId,
  }) async {
    final files = await PhotoPickerSheet.resolveFiles(context: context);
    if (files == null || files.isEmpty || !mounted) return;

    setState(() {
      _importing = true;
      _importDone = 0;
      _importTotal = files.length;
    });

    const batchSize = 3;
    for (var i = 0; i < files.length; i += batchSize) {
      if (!mounted) break;
      final batch = files.sublist(i, min(i + batchSize, files.length));
      await Future.wait(batch.map((file) async {
        await ref.read(photosProvider(widget.caseId).notifier).addPhotoFromFile(
              caseId: widget.caseId,
              file: file,
              attendanceId: attendanceId,
              linkedToType: linkedToType,
              linkedToId: linkedToId,
            );
        if (mounted) setState(() => _importDone++);
      }));
    }

    if (mounted) setState(() => _importing = false);
  }

  /// Bytes-based import (camera / gallery / files) — parallel batches of 3.
  Future<void> _importBytes(
    List<Uint8List> bytesList, {
    String? attendanceId,
    String? linkedToType,
    String? linkedToId,
  }) async {
    setState(() {
      _importing = true;
      _importDone = 0;
      _importTotal = bytesList.length;
    });

    const batchSize = 3;
    for (var i = 0; i < bytesList.length; i += batchSize) {
      if (!mounted) break;
      final batch = bytesList.sublist(i, min(i + batchSize, bytesList.length));
      await Future.wait(batch.map((bytes) async {
        await ref.read(photosProvider(widget.caseId).notifier).addPhoto(
              caseId: widget.caseId,
              bytes: bytes,
              attendanceId: attendanceId,
              linkedToType: linkedToType,
              linkedToId: linkedToId,
            );
        if (mounted) setState(() => _importDone++);
      }));
    }

    if (mounted) setState(() => _importing = false);
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(photosProvider(widget.caseId)).value ?? [];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          photos.isEmpty ? 'Photos' : 'Photos  (${photos.length})',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (photos.isNotEmpty)
            IconButton(
              icon: _syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cloud_sync_outlined, color: Colors.white),
              tooltip: 'Sync to Google Photos',
              onPressed: _syncing ? null : _syncToGooglePhotos,
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
          tabs: const [
            Tab(text: 'By Visit'),
            Tab(text: 'By Inspection'),
          ],
        ),
      ),

      // Import progress overlay
      floatingActionButton: _importing
          ? _ImportProgress(done: _importDone, total: _importTotal)
          : FloatingActionButton.extended(
              onPressed: () => _addPhotos(),
              backgroundColor: _kColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add Photos',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),

      body: TabBarView(
        controller: _tab,
        children: [
          _ByVisitTab(
            caseId: widget.caseId,
            photos: photos,
            onAddPhotos: _addPhotos,
            onDelete: (id) => ref
                .read(photosProvider(widget.caseId).notifier)
                .deletePhoto(id),
          ),
          _ByInspectionTab(
            caseId: widget.caseId,
            photos: photos,
            onAddPhotos: _addPhotos,
            onDelete: (id) => ref
                .read(photosProvider(widget.caseId).notifier)
                .deletePhoto(id),
          ),
        ],
      ),
    );
  }
}

// ── Import progress FAB replacement ────────────────────────────────────────

class _ImportProgress extends StatelessWidget {
  const _ImportProgress({required this.done, required this.total});
  final int done, total;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: null,
      backgroundColor: _kColor,
      foregroundColor: Colors.white,
      icon: const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      ),
      label: Text('Importing $done / $total…',
          style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

// ── Tab 1: By Visit ─────────────────────────────────────────────────────────

class _ByVisitTab extends ConsumerWidget {
  const _ByVisitTab({
    required this.caseId,
    required this.photos,
    required this.onAddPhotos,
    required this.onDelete,
  });

  final String caseId;
  final List<PhotoModel> photos;
  final Future<void> Function(
      {String? attendanceId,
      String? linkedToType,
      String? linkedToId}) onAddPhotos;
  final void Function(String) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendances = ref.watch(attendancesProvider(caseId)).value ?? [];
    final sorted = [...attendances]..sort((a, b) {
        if (a.attendanceDate == null) return 1;
        if (b.attendanceDate == null) return -1;
        return b.attendanceDate!.compareTo(a.attendanceDate!);
      });

    final unassigned = photos.where((p) => p.attendanceId == null).toList();

    if (photos.isEmpty && attendances.isEmpty) {
      return _EmptyState(onAdd: () => onAddPhotos());
    }

    return CustomScrollView(
      slivers: [
        for (final att in sorted) ...[
          _AttendanceSectionHeader(
            attendance: att,
            photoCount:
                photos.where((p) => p.attendanceId == att.attendanceId).length,
            onAddPhoto: () => onAddPhotos(attendanceId: att.attendanceId),
          ),
          _PhotoSliverGrid(
            caseId: caseId,
            photos: photos
                .where((p) => p.attendanceId == att.attendanceId)
                .toList(),
            allPhotos: photos,
            onDelete: onDelete,
          ),
        ],
        if (unassigned.isNotEmpty) ...[
          const _SectionLabel('NOT YET ASSIGNED TO A VISIT'),
          _PhotoSliverGrid(
            caseId: caseId,
            photos: unassigned,
            allPhotos: photos,
            onDelete: onDelete,
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ── Tab 2: By Inspection ────────────────────────────────────────────────────

class _ByInspectionTab extends ConsumerWidget {
  const _ByInspectionTab({
    required this.caseId,
    required this.photos,
    required this.onAddPhotos,
    required this.onDelete,
  });

  final String caseId;
  final List<PhotoModel> photos;
  final Future<void> Function(
      {String? attendanceId,
      String? linkedToType,
      String? linkedToId}) onAddPhotos;
  final void Function(String) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final damageAsync = ref.watch(damageProvider(caseId));
    final occurrences = damageAsync.value?.occurrences ?? [];
    final damageItems = damageAsync.value?.damageItems ?? [];

    final general = photos
        .where((p) => p.linkedToType == null || p.linkedToType == 'case')
        .toList();

    if (photos.isEmpty) {
      return _EmptyState(onAdd: () => onAddPhotos());
    }

    return CustomScrollView(
      slivers: [
        for (final occ in occurrences) ...[
          _OccurrenceSectionHeader(occurrence: occ),
          () {
            final occPhotos = photos
                .where((p) =>
                    p.linkedToType == 'occurrence' &&
                    p.linkedToId == occ.occurrenceId)
                .toList();
            if (occPhotos.isEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }
            return _PhotoSliverGrid(
                caseId: caseId,
                photos: occPhotos,
                allPhotos: photos,
                onDelete: onDelete);
          }(),
          for (final item in damageItems
              .where((d) => d.occurrenceId == occ.occurrenceId)) ...[
            _DamageItemSubHeader(item: item),
            () {
              final itemPhotos = photos
                  .where((p) =>
                      p.linkedToType == 'damage_item' &&
                      p.linkedToId == item.damageId)
                  .toList();
              if (itemPhotos.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 16, 6),
                    child: Text('No photos for this item yet.',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                            fontStyle: FontStyle.italic)),
                  ),
                );
              }
              return _PhotoSliverGrid(
                  caseId: caseId,
                  photos: itemPhotos,
                  allPhotos: photos,
                  onDelete: onDelete);
            }(),
          ],
        ],
        if (general.isNotEmpty) ...[
          const _SectionLabel('GENERAL / UNLINKED PHOTOS'),
          _PhotoSliverGrid(
            caseId: caseId,
            photos: general,
            allPhotos: photos,
            onDelete: onDelete,
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ── Section header widgets ──────────────────────────────────────────────────

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
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              attendance.attendanceType.label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dateStr,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              if (attendance.location != null)
                Text(attendance.location!,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
            ]),
          ),
          if (photoCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$photoCount',
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          GestureDetector(
            onTap: onAddPhoto,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add_a_photo_outlined, color: color, size: 18),
            ),
          ),
        ]),
      ),
    );
  }
}

class _OccurrenceSectionHeader extends StatelessWidget {
  const _OccurrenceSectionHeader({required this.occurrence});
  final OccurrenceModel occurrence;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 14, 12, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.coral.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.coral.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Occurrence ${occurrence.occurrenceNo}',
              style: const TextStyle(
                  color: AppColors.coral,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              occurrence.title ?? 'Unnamed occurrence',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DamageItemSubHeader extends StatelessWidget {
  const _DamageItemSubHeader({required this.item});
  final DamageItemModel item;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 16, 4),
        child: Row(children: [
          const Icon(Icons.chevron_right,
              size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              item.componentName,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.lightAmber,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.damageCategory.label,
              style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.amber,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 0.8),
        ),
      ),
    );
  }
}

// ── Photo sliver grid ───────────────────────────────────────────────────────

class _PhotoSliverGrid extends StatelessWidget {
  const _PhotoSliverGrid({
    required this.caseId,
    required this.photos,
    required this.allPhotos,
    required this.onDelete,
  });

  final String caseId;
  final List<PhotoModel> photos;
  final List<PhotoModel> allPhotos;
  final void Function(String) onDelete;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
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
            caseId: caseId,
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
        builder: (_) => _PhotoViewer(
          caseId: caseId,
          photos: photos,
          initialIndex: initial,
        ),
      ),
    );
  }
}

// ── Photo tile ──────────────────────────────────────────────────────────────

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.caseId,
    required this.photo,
    required this.onTap,
    required this.onDelete,
  });

  final String caseId;
  final PhotoModel photo;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final alloc = photo.allocation;
    final unclassified =
        (photo.caption == null || photo.caption!.isEmpty) && alloc == null;
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _confirmDelete(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: DrivePhotoImage(
              photo: photo,
              fit: BoxFit.cover,
              cacheWidth: 300,
              noSourceBuilder: (_) => Container(
                color: AppColors.surface,
                child: const Icon(Icons.cloud_download_outlined,
                    color: AppColors.textTertiary),
              ),
            ),
          ),
          // Damage/occurrence link badge (top-left)
          if (photo.linkedToType == 'damage_item')
            const _Badge('DMG', AppColors.coral),
          if (photo.linkedToType == 'occurrence')
            const _Badge('OCC', AppColors.amber),
          // Date badge (top-right) — amber when photo has no caption/allocation
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: unclassified
                    ? AppColors.amber.withValues(alpha: 0.9)
                    : Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                DateFormat('d MMM').format(photo.takenAt),
                style: const TextStyle(
                    fontSize: 8,
                    color: Colors.white,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
          // Allocation badge (bottom-left)
          if (alloc != null)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: _allocColor(alloc).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _allocShortLabel(alloc),
                  style: const TextStyle(
                      fontSize: 8,
                      color: Colors.white,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          // Sync status (bottom-right)
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

  void _confirmDelete(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) onDelete();
    });
  }
}

String _allocShortLabel(PhotoAllocation a) => switch (a) {
      PhotoAllocation.coverPage => 'COVER',
      PhotoAllocation.logbook => 'LOG',
      PhotoAllocation.maintenanceRecord => 'MAINT',
      PhotoAllocation.certificate => 'CERT',
      PhotoAllocation.damageEvidence => 'DMG',
      PhotoAllocation.namePlate => 'PLATE',
    };

Color _allocColor(PhotoAllocation a) => switch (a) {
      PhotoAllocation.coverPage => AppColors.purple,
      PhotoAllocation.logbook => AppColors.midBlue,
      PhotoAllocation.maintenanceRecord => AppColors.teal,
      PhotoAllocation.certificate => AppColors.amber,
      PhotoAllocation.damageEvidence => AppColors.coral,
      PhotoAllocation.namePlate => AppColors.textSecondary,
    };

IconData _allocIconFor(PhotoAllocation a) => switch (a) {
      PhotoAllocation.coverPage => Icons.home_outlined,
      PhotoAllocation.logbook => Icons.menu_book_outlined,
      PhotoAllocation.maintenanceRecord => Icons.build_outlined,
      PhotoAllocation.certificate => Icons.verified_outlined,
      PhotoAllocation.damageEvidence => Icons.warning_amber_outlined,
      PhotoAllocation.namePlate => Icons.label_outlined,
    };

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 4,
      left: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Full-screen viewer with inline editing ──────────────────────────────────

class _PhotoViewer extends ConsumerStatefulWidget {
  const _PhotoViewer({
    required this.caseId,
    required this.photos,
    required this.initialIndex,
  });
  final String caseId;
  final List<PhotoModel> photos;
  final int initialIndex;

  @override
  ConsumerState<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<_PhotoViewer> {
  late final TextEditingController _captionCtrl;
  // Explicit controller so pan/zoom state can be reset before handing off
  // to the native crop screen — without this, PhotoView owns its own
  // internal controller that can't be cleared, and a pan/zoom gesture left
  // mid-flight when the native crop activity takes over can resurface as
  // an unwanted pan once control returns to Flutter.
  late final PhotoViewController _photoViewController;
  int _current = 0;
  PhotoAllocation? _allocation;
  bool _saving = false;
  bool _busy = false;
  // Incremented per photo after rotate/crop so PhotoViewGallery reloads the file.
  final Map<String, int> _imgVersion = {};

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    final ph = widget.photos[widget.initialIndex];
    _captionCtrl = TextEditingController(text: ph.caption ?? '');
    _allocation = ph.allocation;
    _photoViewController = PhotoViewController();
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _photoViewController.dispose();
    super.dispose();
  }

  PhotoModel _livePhoto([int? index]) {
    final i = index ?? _current;
    final photos =
        ref.read(photosProvider(widget.caseId)).value ?? widget.photos;
    final id = widget.photos[i].id;
    return photos.firstWhere((p) => p.id == id, orElse: () => widget.photos[i]);
  }

  void _navigateTo(int i) {
    FocusManager.instance.primaryFocus?.unfocus();
    final ph = _livePhoto(i);
    setState(() {
      _current = i;
      _captionCtrl.text = ph.caption ?? '';
      _allocation = ph.allocation;
    });
  }

  void _prevPhoto() {
    if (_current > 0) _navigateTo(_current - 1);
  }

  void _nextPhoto() {
    if (_current < widget.photos.length - 1) _navigateTo(_current + 1);
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    final ph = _livePhoto();
    final notifier = ref.read(photosProvider(widget.caseId).notifier);
    await notifier.updateCaption(ph.id, _captionCtrl.text);
    await notifier.updateAllocation(ph.id, _allocation);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Saved'),
      duration: Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _rotate() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      var ph = _livePhoto();
      if (!ph.hasLocalFile) {
        ph = await ref
                .read(photosProvider(widget.caseId).notifier)
                .ensureLocalFile(ph.id) ??
            ph;
      }
      if (!ph.hasLocalFile) {
        debugPrint('[rotate] no local or Drive copy available, skipping');
        if (mounted) setState(() => _busy = false);
        return;
      }
      final f = File(ph.localPath!);
      debugPrint(
          '[rotate] start — exists=${f.existsSync()} path=${ph.localPath}');
      final bytes = await f.readAsBytes();
      debugPrint('[rotate] read ${bytes.length} bytes, compressing...');
      final rotated = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 4096,
        minHeight: 4096,
        quality: 92,
        rotate: 90,
        format: CompressFormat.jpeg,
      );
      debugPrint('[rotate] compressed to ${rotated.length} bytes, writing...');
      await f.writeAsBytes(rotated);
      debugPrint('[rotate] file written');
      if (ph.thumbnailPath != null) {
        final thumb = await FlutterImageCompress.compressWithList(
          rotated,
          minWidth: 240,
          minHeight: 240,
          quality: 72,
          format: CompressFormat.jpeg,
        );
        await File(ph.thumbnailPath!).writeAsBytes(thumb);
        debugPrint('[rotate] thumbnail updated');
      }
      // Evict old decoded image from Flutter cache so FileImage reloads from disk.
      imageCache.evict(FileImage(f));
      if (ph.thumbnailPath != null) {
        imageCache.evict(FileImage(File(ph.thumbnailPath!)));
      }
      _imgVersion[ph.id] = (_imgVersion[ph.id] ?? 0) + 1;
      debugPrint('[rotate] done, version=${_imgVersion[ph.id]}');
    } catch (e, st) {
      debugPrint('[rotate] ERROR: $e\n$st');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _crop() async {
    if (_busy) return;
    var ph = _livePhoto();
    if (!ph.hasLocalFile) {
      ph = await ref
              .read(photosProvider(widget.caseId).notifier)
              .ensureLocalFile(ph.id) ??
          ph;
    }
    if (!ph.hasLocalFile) {
      debugPrint('[crop] no local or Drive copy available, skipping');
      return;
    }
    debugPrint(
        '[crop] start — exists=${File(ph.localPath!).existsSync()} path=${ph.localPath}');
    setState(() => _busy = true);
    // Clear any in-flight pan/zoom before handing off to the native crop
    // screen — otherwise a gesture left mid-drag when the native activity
    // takes over can resurface as an unwanted pan once it returns.
    _photoViewController.reset();
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: ph.localPath!,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop',
            toolbarColor: Colors.black87,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: CropAspectRatioPreset.values
                .map((p) => _CapitalizedAspectRatioPreset(p))
                .toList(),
          ),
          IOSUiSettings(title: 'Crop'),
        ],
      );
      debugPrint('[crop] result=${cropped?.path}');
      if (cropped != null) {
        final croppedBytes = await File(cropped.path).readAsBytes();
        debugPrint(
            '[crop] read ${croppedBytes.length} bytes from cropped file');
        await File(ph.localPath!).writeAsBytes(croppedBytes);
        debugPrint('[crop] overwrote original');
        if (ph.thumbnailPath != null) {
          final thumb = await FlutterImageCompress.compressWithList(
            croppedBytes,
            minWidth: 240,
            minHeight: 240,
            quality: 72,
            format: CompressFormat.jpeg,
          );
          await File(ph.thumbnailPath!).writeAsBytes(thumb);
        }
        imageCache.evict(FileImage(File(ph.localPath!)));
        if (ph.thumbnailPath != null) {
          imageCache.evict(FileImage(File(ph.thumbnailPath!)));
        }
        _imgVersion[ph.id] = (_imgVersion[ph.id] ?? 0) + 1;
        debugPrint('[crop] done, version=${_imgVersion[ph.id]}');
      }
    } catch (e, st) {
      debugPrint('[crop] ERROR: $e\n$st');
    }
    _photoViewController.reset();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _deleteCurrentPhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(photosProvider(widget.caseId).notifier)
        .deletePhoto(_livePhoto().id);
    if (mounted) Navigator.pop(context);
  }

  void _showAllocationPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllocationPickerSheet(
        current: _allocation,
        onSelected: (a) {
          setState(() => _allocation = a);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final livePhotos =
        ref.watch(photosProvider(widget.caseId)).value ?? widget.photos;
    final currentPhoto = livePhotos.firstWhere(
      (ph) => ph.id == widget.photos[_current].id,
      orElse: () => widget.photos[_current],
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_current + 1} / ${widget.photos.length}',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                DateFormat('dd MMM yyyy')
                    .format(widget.photos[_current].takenAt),
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
        ),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 22),
              tooltip: 'Delete photo',
              onPressed: _deleteCurrentPhoto,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Photo (pinch-to-zoom via PhotoView, prev/next via arrows) ──
          Expanded(
            child: Stack(
              children: [
                if (!currentPhoto.hasLocalFile && !kIsWeb)
                  FutureBuilder<PhotoModel?>(
                    key: ValueKey('download-${currentPhoto.id}'),
                    future: ref
                        .read(photosProvider(widget.caseId).notifier)
                        .ensureLocalFile(currentPhoto.id),
                    builder: (_, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }
                      final resolved = snapshot.data;
                      if (resolved == null || !resolved.hasLocalFile) {
                        return const Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: Colors.white38, size: 64),
                        );
                      }
                      return PhotoView(
                        key: ValueKey(
                            '${resolved.id}-${_imgVersion[resolved.id] ?? 0}'),
                        controller: _photoViewController,
                        imageProvider: FileImage(File(resolved.localPath!)),
                        initialScale: PhotoViewComputedScale.contained,
                        minScale: PhotoViewComputedScale.contained * 0.8,
                        maxScale: PhotoViewComputedScale.covered * 4.0,
                        backgroundDecoration:
                            const BoxDecoration(color: Colors.black),
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: Colors.white38, size: 64),
                        ),
                      );
                    },
                  )
                else if (!currentPhoto.hasLocalFile && currentPhoto.driveFileId != null)
                  FutureBuilder<Uint8List>(
                    key: ValueKey('web-download-${currentPhoto.id}'),
                    future: DrivePhotoBytesCache.fetch(currentPhoto.driveFileId!),
                    builder: (_, snap) {
                      if (!snap.hasData) {
                        if (snap.hasError) {
                          return const Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: Colors.white38, size: 64),
                          );
                        }
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }
                      return PhotoView(
                        key: ValueKey(
                            '${currentPhoto.id}-${_imgVersion[currentPhoto.id] ?? 0}'),
                        controller: _photoViewController,
                        imageProvider: MemoryImage(snap.data!),
                        initialScale: PhotoViewComputedScale.contained,
                        minScale: PhotoViewComputedScale.contained * 0.8,
                        maxScale: PhotoViewComputedScale.covered * 4.0,
                        backgroundDecoration:
                            const BoxDecoration(color: Colors.black),
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: Colors.white38, size: 64),
                        ),
                      );
                    },
                  )
                else if (!currentPhoto.hasLocalFile)
                  const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.white38, size: 64),
                  )
                else
                  PhotoView(
                    key: ValueKey(
                        '${currentPhoto.id}-${_imgVersion[currentPhoto.id] ?? 0}'),
                    controller: _photoViewController,
                    imageProvider: FileImage(File(currentPhoto.localPath!)),
                    initialScale: PhotoViewComputedScale.contained,
                    minScale: PhotoViewComputedScale.contained * 0.8,
                    maxScale: PhotoViewComputedScale.covered * 4.0,
                    backgroundDecoration:
                        const BoxDecoration(color: Colors.black),
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white38, size: 64),
                    ),
                  ),
                if (_current > 0) _NavArrow(isLeft: true, onTap: _prevPhoto),
                if (_current < widget.photos.length - 1)
                  _NavArrow(isLeft: false, onTap: _nextPhoto),
              ],
            ),
          ),

          // ── Inline edit panel ─────────────────────────────────────────
          // Collapse to single row when keyboard is open to maximise photo space.
          Builder(builder: (ctx) {
            final kbOpen = MediaQuery.of(ctx).viewInsets.bottom > 100;
            final decoration = InputDecoration(
              hintText: 'Caption…',
              hintStyle:
                  const TextStyle(color: AppColors.textTertiary, fontSize: 14),
              isDense: true,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kColor, width: 1.5),
              ),
            );
            final saveBtn = FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _kColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            );

            return Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: kbOpen
                  // ── Compact: caption + save only ─────────────────────
                  ? Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _captionCtrl,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 14),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _save(),
                          decoration: decoration,
                        ),
                      ),
                      const SizedBox(width: 10),
                      saveBtn,
                    ])
                  // ── Full: caption + tools + allocation ───────────────
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _captionCtrl,
                                maxLines: 2,
                                minLines: 1,
                                style: const TextStyle(fontSize: 14),
                                textInputAction: TextInputAction.done,
                                decoration: decoration,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _ToolBtn(
                              icon: Icons.rotate_90_degrees_cw_outlined,
                              tooltip: 'Rotate 90°',
                              enabled: !_busy,
                              onTap: _rotate,
                            ),
                            const SizedBox(width: 6),
                            _ToolBtn(
                              icon: Icons.crop_outlined,
                              tooltip: 'Crop',
                              enabled: !_busy,
                              onTap: _crop,
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(children: [
                          GestureDetector(
                            onTap: _showAllocationPicker,
                            child: _AllocationBadge(allocation: _allocation),
                          ),
                          const Spacer(),
                          saveBtn,
                        ]),
                      ],
                    ),
            );
          }),
        ],
      ),
    );
  }
}

// Wraps CropAspectRatioPreset to fix the plugin's lowercase 'original' label
// shown as a tab in the native crop UI.
class _CapitalizedAspectRatioPreset implements CropAspectRatioPresetData {
  const _CapitalizedAspectRatioPreset(this.preset);

  final CropAspectRatioPreset preset;

  @override
  String get name =>
      preset == CropAspectRatioPreset.original ? 'Original' : preset.name;

  @override
  (int ratioX, int ratioY)? get data => preset.data;
}

// ── Empty state ─────────────────────────────────────────────────────────────

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
          const Text(
            'Add from camera, gallery, or cloud drive.\nPhotos are sorted by visit or by inspection.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
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

// ── Viewer helper widgets ────────────────────────────────────────────────────

class _ToolBtn extends StatelessWidget {
  const _ToolBtn({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppColors.textSecondary : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _AllocationBadge extends StatelessWidget {
  const _AllocationBadge({this.allocation});
  final PhotoAllocation? allocation;

  @override
  Widget build(BuildContext context) {
    final color =
        allocation != null ? _allocColor(allocation!) : AppColors.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: allocation != null
              ? color.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            allocation != null
                ? _allocIconFor(allocation!)
                : Icons.label_outline,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            allocation?.label ?? 'No allocation',
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more, size: 14, color: color),
        ],
      ),
    );
  }
}

class _AllocationPickerSheet extends StatelessWidget {
  const _AllocationPickerSheet({
    required this.current,
    required this.onSelected,
  });
  final PhotoAllocation? current;
  final void Function(PhotoAllocation?) onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Allocate to Document',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AllocChip(
                  label: 'None',
                  icon: Icons.block_outlined,
                  selected: current == null,
                  color: AppColors.textSecondary,
                  onTap: () => onSelected(null),
                ),
                for (final a in PhotoAllocation.values)
                  _AllocChip(
                    label: a.label,
                    icon: _allocIconFor(a),
                    selected: current == a,
                    color: _allocColor(a),
                    onTap: () => onSelected(a),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _AllocChip extends StatelessWidget {
  const _AllocChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: selected ? color : AppColors.textTertiary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.isLeft, required this.onTap});
  final bool isLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: isLeft ? 8 : null,
      right: isLeft ? null : 8,
      top: 0,
      bottom: 0,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLeft ? Icons.chevron_left : Icons.chevron_right,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}
