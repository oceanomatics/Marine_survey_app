// lib/features/photos/widgets/photo_detail_sheet.dart
//
// Bottom sheet for editing a photo's caption and document allocation.
// Push as a fullscreenDialog route so the keyboard doesn't cover the sheet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/chip_row.dart';
import '../../../shared/widgets/drive_photo_image.dart';
import '../models/photo_model.dart';
import '../providers/photo_provider.dart';
import '../../attendances/models/attendance_model.dart';
import '../../attendances/providers/attendances_provider.dart';
import '../../../shared/widgets/back_app_bar.dart';
import '../../../shared/widgets/app_feedback.dart';

class PhotoDetailSheet extends ConsumerStatefulWidget {
  const PhotoDetailSheet({
    super.key,
    required this.caseId,
    required this.photo,
  });

  final String caseId;
  final PhotoModel photo;

  @override
  ConsumerState<PhotoDetailSheet> createState() => _PhotoDetailSheetState();
}

class _PhotoDetailSheetState extends ConsumerState<PhotoDetailSheet> {
  late final TextEditingController _captionCtrl;
  PhotoAllocation? _allocation;
  PlacementMode? _placementMode;
  PhotoSource? _photoSource;
  String? _attendanceId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _captionCtrl = TextEditingController(text: widget.photo.caption ?? '');
    _allocation = widget.photo.allocation;
    _placementMode = widget.photo.placementMode;
    _photoSource = widget.photo.photoSource;
    _attendanceId = widget.photo.attendanceId;
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final notifier = ref.read(photosProvider(widget.caseId).notifier);
    await notifier.updateCaption(widget.photo.id, _captionCtrl.text);
    await notifier.updateAllocation(widget.photo.id, _allocation);
    await notifier.updatePlacementMode(widget.photo.id, _placementMode);
    await notifier.updatePhotoSource(widget.photo.id, _photoSource);
    await notifier.updateAttendanceId(widget.photo.id, _attendanceId);
    if (mounted) {
      showSavedToast(context);
      Navigator.pop(context);
    }
  }

  // TODO.md §3.15 (8 July 2026): quick-create a lightweight event (not a
  // formal survey attendance — AttendanceType.event, excluded from the
  // Attendances screen's register) right from the photo viewer, date
  // pre-filled from this photo's EXIF-derived taken_at.
  Future<void> _createEvent() async {
    final labelCtrl = TextEditingController();
    var date = widget.photo.takenAt;
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Event'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: labelCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'e.g. Diver\'s Inspection, Crew Photo'),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setDialogState(() => date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date'),
                  child: Text('${date.day.toString().padLeft(2, '0')}/'
                      '${date.month.toString().padLeft(2, '0')}/${date.year}'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: labelCtrl.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: const Text('Create')),
          ],
        ),
      ),
    );
    if (created != true || labelCtrl.text.trim().isEmpty || !mounted) return;
    final event = await ref
        .read(attendancesProvider(widget.caseId).notifier)
        .add(
          caseId: widget.caseId,
          type: AttendanceType.event,
          date: date,
          summary: labelCtrl.text.trim(),
        );
    if (mounted) setState(() => _attendanceId = event.attendanceId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(
        title: const Text('Photo Details', style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Save',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo preview
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: DrivePhotoImage(
                  photo: widget.photo,
                  preferThumbnail: false,
                  fit: BoxFit.cover,
                  noSourceBuilder: (_) => Container(
                    color: AppColors.surface,
                    child: const Icon(Icons.cloud_download_outlined,
                        size: 48, color: AppColors.textTertiary),
                  ),
                  errorBuilder: (_) => Container(
                    color: AppColors.surface,
                    child: const Icon(Icons.broken_image_outlined,
                        size: 48, color: AppColors.textTertiary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Caption
            const _Label('Caption'),
            const SizedBox(height: 6),
            TextField(
              controller: _captionCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Describe this photo…',
                hintStyle: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.purple, width: 1.5)),
              ),
            ),
            const SizedBox(height: 20),

            // Allocation
            const Row(children: [
              _Label('Allocate to Document Type'),
              SizedBox(width: 6),
              Tooltip(
                message: 'Allocated photos appear in the Document Vault '
                    'for AI interpretation.',
                child: Icon(Icons.info_outline,
                    size: 14, color: AppColors.textTertiary),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // "None" chip
                _AllocationChip(
                  label: 'None',
                  icon: Icons.block_outlined,
                  selected: _allocation == null,
                  color: AppColors.textSecondary,
                  onTap: () => setState(() => _allocation = null),
                ),
                for (final alloc in PhotoAllocation.values)
                  _AllocationChip(
                    label: alloc.label,
                    icon: _allocIcon(alloc),
                    selected: _allocation == alloc,
                    color: _allocColor(alloc),
                    onTap: () => setState(() => _allocation = alloc),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Placement mode (spec §7: where the photo renders in the
            // exported report — Inline defaults for damage-item photos).
            // Section Gallery is deliberately not offered here (2026-07-13
            // review): no export path renders it inline within a section —
            // docx_export_service.dart only ever places a non-inline photo
            // in Annexure E — so selecting it silently did the same thing
            // as Annexure with a misleading label. Revisit once section-
            // scoped inline rendering actually exists.
            const _Label('Placement in Report'),
            const SizedBox(height: 8),
            ChipRow<PlacementMode>(
              values: PlacementMode.values
                  .where((m) => m != PlacementMode.sectionGallery)
                  .toList(),
              selected: _placementMode ?? widget.photo.effectivePlacementMode,
              label: (m) => m.label,
              onChanged: (v) => setState(() => _placementMode = v),
            ),
            const SizedBox(height: 20),

            // Photo source — drives the auto-inserted attribution sentence
            // for non-surveyor sources.
            const _Label('Photo Source'),
            const SizedBox(height: 8),
            ChipRow<PhotoSource>(
              values: PhotoSource.values,
              selected: _photoSource,
              label: (s) => s.label,
              onChanged: (v) => setState(() => _photoSource = v),
            ),
            const SizedBox(height: 20),

            // TODO.md §3.15 (8 July 2026): allocate this photo to an
            // existing attendance/event, or quick-create a new one.
            const _Label('Link to Attendance / Event'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AllocationChip(
                  label: 'None',
                  icon: Icons.block_outlined,
                  selected: _attendanceId == null,
                  color: AppColors.textSecondary,
                  onTap: () => setState(() => _attendanceId = null),
                ),
                for (final a
                    in ref.watch(attendancesProvider(widget.caseId)).value ??
                        const <SurveyAttendanceModel>[])
                  _AllocationChip(
                    label: a.summary ?? a.attendanceType.label,
                    icon: Icons.event_outlined,
                    selected: _attendanceId == a.attendanceId,
                    color: AppColors.purple,
                    onTap: () =>
                        setState(() => _attendanceId = a.attendanceId),
                  ),
                _AllocationChip(
                  label: '+ New Event',
                  icon: Icons.add,
                  selected: false,
                  color: AppColors.purple,
                  onTap: _createEvent,
                ),
              ],
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Save',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllocationChip extends StatelessWidget {
  const _AllocationChip({
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.3),
      );
}

IconData _allocIcon(PhotoAllocation a) => switch (a) {
      PhotoAllocation.coverPage => Icons.home_outlined,
      PhotoAllocation.logbook => Icons.menu_book_outlined,
      PhotoAllocation.maintenanceRecord => Icons.build_outlined,
      PhotoAllocation.certificate => Icons.verified_outlined,
      PhotoAllocation.damageEvidence => Icons.warning_amber_outlined,
      PhotoAllocation.namePlate => Icons.label_outlined,
    };

Color _allocColor(PhotoAllocation a) => switch (a) {
      PhotoAllocation.coverPage => AppColors.purple,
      PhotoAllocation.logbook => AppColors.midBlue,
      PhotoAllocation.maintenanceRecord => AppColors.teal,
      PhotoAllocation.certificate => AppColors.amber,
      PhotoAllocation.damageEvidence => AppColors.coral,
      PhotoAllocation.namePlate => AppColors.textSecondary,
    };
