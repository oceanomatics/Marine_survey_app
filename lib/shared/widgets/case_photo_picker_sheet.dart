// lib/shared/widgets/case_photo_picker_sheet.dart
//
// Modal bottom sheet that shows the case's stored photos as a grid.
// Single-select: tapping a photo closes immediately and returns [photo].
// Multi-select:  tapping toggles selection; a "Select (n)" button confirms.
//
// Usage:
//   final picked = await showModalBottomSheet<List<PhotoModel>>(
//     context: context,
//     backgroundColor: Colors.transparent,
//     isScrollControlled: true,
//     builder: (_) => CasePhotoPickerSheet(caseId: caseId),
//   );
//   if (picked == null || picked.isEmpty) return;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/photos/models/photo_model.dart';
import '../../features/photos/providers/photo_provider.dart';
import '../theme/app_theme.dart';

class CasePhotoPickerSheet extends ConsumerStatefulWidget {
  const CasePhotoPickerSheet({
    super.key,
    required this.caseId,
    this.multiSelect = false,
    this.title = 'Select Photo',
    this.accentColor = AppColors.purple,
  });

  final String caseId;
  final bool multiSelect;
  final String title;
  final Color accentColor;

  @override
  ConsumerState<CasePhotoPickerSheet> createState() =>
      _CasePhotoPickerSheetState();
}

class _CasePhotoPickerSheetState extends ConsumerState<CasePhotoPickerSheet> {
  final Set<String> _selected = {};

  void _tap(PhotoModel photo, List<PhotoModel> allPhotos) {
    if (!widget.multiSelect) {
      Navigator.pop(context, [photo]);
      return;
    }
    setState(() {
      if (_selected.contains(photo.id)) {
        _selected.remove(photo.id);
      } else {
        _selected.add(photo.id);
      }
    });
  }

  void _confirm(List<PhotoModel> allPhotos) {
    Navigator.pop(
      context,
      allPhotos.where((p) => _selected.contains(p.id)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(photosProvider(widget.caseId)).value ?? [];

    return Material(
      color: AppColors.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
            child: Row(children: [
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const Spacer(),
              if (widget.multiSelect && _selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton(
                    onPressed: () => _confirm(photos),
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.accentColor,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Select (${_selected.length})',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.close,
                    size: 20, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context, <PhotoModel>[]),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),

          if (photos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.photo_library_outlined,
                    size: 48, color: AppColors.textTertiary),
                SizedBox(height: 10),
                Text('No photos in this case yet',
                    style: TextStyle(
                        color: AppColors.textTertiary, fontSize: 13)),
              ]),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: photos.length,
                itemBuilder: (_, i) {
                  final photo = photos[i];
                  final sel = _selected.contains(photo.id);
                  return GestureDetector(
                    onTap: () => _tap(photo, photos),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(photo.thumbnailPath ?? photo.localPath),
                            fit: BoxFit.cover,
                            cacheWidth: 200,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.surface,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                size: 24,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                        // Date label at bottom
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Colors.black54, Colors.transparent],
                              ),
                              borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(6)),
                            ),
                            child: Text(
                              DateFormat('dd/MM').format(photo.takenAt),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        // Selection overlay (multi-select only)
                        if (sel)
                          Container(
                            decoration: BoxDecoration(
                              color: widget.accentColor.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: widget.accentColor, width: 2.5),
                            ),
                            child: Center(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: widget.accentColor,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(3),
                                child: const Icon(Icons.check,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
