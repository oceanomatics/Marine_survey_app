// lib/features/photos/screens/photo_gallery_screen.dart

import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/photo_model.dart';
import '../providers/photo_provider.dart';
import '../widgets/photo_detail_sheet.dart';
import '../../attendances/providers/attendances_provider.dart';
import '../../attendances/models/attendance_model.dart';
import '../../survey/providers/damage_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/photo_picker_sheet.dart';

const _kColor   = AppColors.purple;
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
  bool _importing  = false;
  int  _importDone = 0;
  int  _importTotal = 0;

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

    final bytesList = await PhotoPickerSheet.resolveBytes(source, context: context);
    if (bytesList.isEmpty || !mounted) return;

    await _importBytes(
      bytesList,
      attendanceId: attendanceId,
      linkedToType: linkedToType,
      linkedToId: linkedToId,
    );
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
      _importing   = true;
      _importDone  = 0;
      _importTotal = files.length;
    });

    const batchSize = 3;
    for (var i = 0; i < files.length; i += batchSize) {
      if (!mounted) break;
      final batch = files.sublist(i, min(i + batchSize, files.length));
      await Future.wait(batch.map((file) async {
        await ref.read(photosProvider(widget.caseId).notifier).addPhotoFromFile(
          caseId:       widget.caseId,
          file:         file,
          attendanceId: attendanceId,
          linkedToType: linkedToType,
          linkedToId:   linkedToId,
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
      _importing   = true;
      _importDone  = 0;
      _importTotal = bytesList.length;
    });

    const batchSize = 3;
    for (var i = 0; i < bytesList.length; i += batchSize) {
      if (!mounted) break;
      final batch = bytesList.sublist(i, min(i + batchSize, bytesList.length));
      await Future.wait(batch.map((bytes) async {
        await ref.read(photosProvider(widget.caseId).notifier).addPhoto(
          caseId:       widget.caseId,
          bytes:        bytes,
          attendanceId: attendanceId,
          linkedToType: linkedToType,
          linkedToId:   linkedToId,
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
            caseId:    widget.caseId,
            photos:    photos,
            onAddPhotos: _addPhotos,
            onDelete: (id) =>
                ref.read(photosProvider(widget.caseId).notifier).deletePhoto(id),
          ),
          _ByInspectionTab(
            caseId:  widget.caseId,
            photos:  photos,
            onAddPhotos: _addPhotos,
            onDelete: (id) =>
                ref.read(photosProvider(widget.caseId).notifier).deletePhoto(id),
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
        width: 18, height: 18,
        child: CircularProgressIndicator(
            color: Colors.white, strokeWidth: 2),
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
  final Future<void> Function({String? attendanceId, String? linkedToType, String? linkedToId}) onAddPhotos;
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
  final Future<void> Function({String? attendanceId, String? linkedToType, String? linkedToId}) onAddPhotos;
  final void Function(String) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final damageAsync = ref.watch(damageProvider(caseId));
    final occurrences = damageAsync.value?.occurrences ?? [];
    final damageItems = damageAsync.value?.damageItems ?? [];

    final general = photos.where((p) =>
        p.linkedToType == null ||
        p.linkedToType == 'case').toList();

    if (photos.isEmpty) {
      return _EmptyState(onAdd: () => onAddPhotos());
    }

    return CustomScrollView(
      slivers: [
        for (final occ in occurrences) ...[
          _OccurrenceSectionHeader(occurrence: occ),

          () {
            final occPhotos = photos.where((p) =>
                p.linkedToType == 'occurrence' &&
                p.linkedToId == occ.occurrenceId).toList();
            if (occPhotos.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
            return _PhotoSliverGrid(
                caseId: caseId, photos: occPhotos, allPhotos: photos, onDelete: onDelete);
          }(),

          for (final item in damageItems.where(
              (d) => d.occurrenceId == occ.occurrenceId)) ...[
            _DamageItemSubHeader(item: item),
            () {
              final itemPhotos = photos.where((p) =>
                  p.linkedToType == 'damage_item' &&
                  p.linkedToId == item.damageId).toList();
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
                  caseId: caseId, photos: itemPhotos, allPhotos: photos, onDelete: onDelete);
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
        AttendanceType.initial       => const Color(0xFFBF7E3A),
        AttendanceType.followUp      => AppColors.midBlue,
        AttendanceType.finalInspection => AppColors.teal,
        AttendanceType.remoteReview  => AppColors.purple,
      };

  @override
  Widget build(BuildContext context) {
    final color  = _typeColor(attendance.attendanceType);
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
    if (photos.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

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
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showOptions(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            // Use cached thumbnail for fast grid rendering; fall back to full-res.
            child: Image.file(
              File(photo.thumbnailPath ?? photo.localPath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.file(
                File(photo.localPath),
                fit: BoxFit.cover,
                cacheWidth: 200,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.surface,
                  child: const Icon(Icons.broken_image_outlined,
                      color: AppColors.textTertiary),
                ),
              ),
            ),
          ),
          // Damage/occurrence link badge
          if (photo.linkedToType == 'damage_item')
            const _Badge('DMG', AppColors.coral),
          if (photo.linkedToType == 'occurrence')
            const _Badge('OCC', AppColors.amber),
          // Allocation badge (bottom-left)
          if (alloc != null)
            Positioned(
              bottom: 4, left: 4,
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
          // Sync status
          if (photo.syncStatus == PhotoSyncStatus.localOnly)
            Positioned(
              bottom: 4, right: 4,
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
      builder: (_) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _kColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_outlined,
                      color: _kColor, size: 18),
                ),
                title: const Text('Edit details',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  photo.caption?.isNotEmpty == true
                      ? photo.caption!
                      : photo.allocation != null
                          ? photo.allocation!.label
                          : 'Add caption or allocation',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => PhotoDetailSheet(
                        caseId: caseId,
                        photo: photo,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: AppColors.error, size: 18),
                ),
                title: const Text('Delete photo',
                    style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _allocShortLabel(PhotoAllocation a) => switch (a) {
      PhotoAllocation.coverPage        => 'COVER',
      PhotoAllocation.logbook          => 'LOG',
      PhotoAllocation.maintenanceRecord => 'MAINT',
      PhotoAllocation.certificate      => 'CERT',
      PhotoAllocation.damageEvidence   => 'DMG',
      PhotoAllocation.namePlate        => 'PLATE',
    };

Color _allocColor(PhotoAllocation a) => switch (a) {
      PhotoAllocation.coverPage        => AppColors.purple,
      PhotoAllocation.logbook          => AppColors.midBlue,
      PhotoAllocation.maintenanceRecord => AppColors.teal,
      PhotoAllocation.certificate      => AppColors.amber,
      PhotoAllocation.damageEvidence   => AppColors.coral,
      PhotoAllocation.namePlate        => AppColors.textSecondary,
    };

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 4, left: 4,
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

// ── Full-screen viewer ──────────────────────────────────────────────────────

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
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current    = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch live so caption/allocation updates are reflected immediately.
    final photos = ref.watch(photosProvider(widget.caseId)).value ?? widget.photos;
    // Find current photo by id to survive list reorder.
    final currentId = widget.photos[_current].id;
    final ph = photos.firstWhere(
      (p) => p.id == currentId,
      orElse: () => widget.photos[_current],
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            ph.caption?.isNotEmpty == true
                ? ph.caption!
                : '${_current + 1} / ${widget.photos.length}',
            style: const TextStyle(fontSize: 14),
          ),
          if (ph.allocation != null)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _allocColor(ph.allocation!).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                ph.allocation!.label,
                style: TextStyle(
                    fontSize: 10,
                    color: _allocColor(ph.allocation!),
                    fontWeight: FontWeight.w600),
              ),
            )
          else if (ph.linkedToType != null)
            Text(
              switch (ph.linkedToType) {
                'damage_item' => 'Linked to damage item',
                'occurrence'  => 'Linked to occurrence',
                _             => '',
              },
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit details',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => PhotoDetailSheet(
                  caseId: widget.caseId,
                  photo: ph,
                ),
              ),
            ),
          ),
        ],
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
            width: 64, height: 64,
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
