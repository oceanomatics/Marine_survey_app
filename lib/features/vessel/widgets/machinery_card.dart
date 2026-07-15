// lib/features/vessel/widgets/machinery_card.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vessel_provider.dart';
import 'add_component_sheet.dart';
import '../../photos/models/photo_model.dart';
import '../../photos/providers/photo_provider.dart';
import '../../../core/api/claude_api.dart';
import '../../ai_tasks/providers/ai_tasks_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/case_photo_picker_sheet.dart';
import '../../../shared/widgets/drive_photo_image.dart';

class MachineryCard extends ConsumerStatefulWidget {
  const MachineryCard({
    super.key,
    required this.machinery,
    required this.caseId,
    required this.onEdit,
    required this.onDelete,
  });

  final MachineryModel machinery;
  final String caseId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  ConsumerState<MachineryCard> createState() => _MachineryCardState();
}

class _MachineryCardState extends ConsumerState<MachineryCard> {
  bool _expanded = false;
  bool _scanningPlate = false;

  // ── Machinery nameplate scan ───────────────────────────────────────────────

  Future<void> _scanMachineryNameplate() async {
    final picked = await showModalBottomSheet<List<dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CasePhotoPickerSheet(
        caseId: widget.caseId,
        title: 'Select Nameplate Photo',
        accentColor: AppColors.teal,
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    setState(() => _scanningPlate = true);
    try {
      final PhotoModel photo = picked.first;
      final resolved = photo.hasLocalFile
          ? photo
          : await ref
                  .read(photosProvider(widget.caseId).notifier)
                  .ensureLocalFile(photo.id) ??
              photo;
      if (!resolved.hasLocalFile) {
        throw Exception('Photo file not available');
      }
      final bytes = await File(resolved.localPath!).readAsBytes();
      final b64 = base64Encode(bytes);
      const mime = 'image/jpeg';
      final result = await ref.read(aiTasksProvider.notifier).run(
            label: 'Scanning nameplate photo',
            caseId: widget.caseId,
            estimate: const Duration(seconds: 12),
            action: () =>
                ClaudeApi.extractNameplate(base64Image: b64, mediaType: mime),
          );
      if (!mounted) return;

      // Build an updated MachineryModel from the extracted data
      final make = result['manufacturer'] as String? ?? '';
      final model = result['model'] as String? ?? '';
      final serial = result['serial_number'] as String? ?? '';
      final powerKw = (result['rated_power_kw'] as num?)?.toDouble();
      final rpm = (result['rated_rpm'] as num?)?.toDouble();
      final addl = result['additional_info'] as String? ?? '';

      final updated = widget.machinery.copyWith(
        make: make.isNotEmpty ? make : null,
        model: model.isNotEmpty ? model : null,
        serialNumber: serial.isNotEmpty ? serial : null,
        mcrKw: powerKw,
        mcrRpm: rpm,
      );

      // Show confirmation before writing
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nameplate extracted'),
          content: _NameplatePreview(
            make: make,
            model: model,
            serial: serial,
            powerKw: powerKw,
            rpm: rpm,
            addl: addl,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apply'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      // Pin this photo as the nameplate reference for the card thumbnail —
      // done before updateMachinery below, not after: updateMachinery
      // triggers a Machinery-list rebuild, and doing the link first keeps
      // it outside that risk window (14 July 2026 walkthrough — this path
      // wasn't reliably showing the thumbnail; the Edit-menu path, which
      // runs inside its own modal sheet decoupled from this list, did).
      await ref.read(photosProvider(widget.caseId).notifier).attachLink(
          photo.id, 'machinery_nameplate', widget.machinery.machineryId);

      await ref
          .read(machineryProvider(widget.machinery.vesselId).notifier)
          .updateMachinery(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Machinery updated from nameplate'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _scanningPlate = false);
    }
  }

  void _viewNameplateFullSize(BuildContext context, PhotoModel photo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: DrivePhotoImage(
                photo: photo,
                preferThumbnail: false,
                fit: BoxFit.contain,
                errorBuilder: (_) => const SizedBox(
                  height: 200,
                  child: Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.white54, size: 40),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sub-component actions ──────────────────────────────────────────────────

  void _openAddComponent(List<VesselComponentModel> existing) {
    final nextSeq = existing.isEmpty
        ? 1
        : existing.map((c) => c.sequenceNo).reduce((a, b) => a > b ? a : b) + 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => AddComponentSheet(
        machineryId: widget.machinery.machineryId,
        vesselId: widget.machinery.vesselId,
        caseId: widget.caseId,
        nextSeqNo: nextSeq,
        onSave: (comp) {
          return ref
              .read(vesselComponentsProvider(widget.machinery.machineryId)
                  .notifier)
              .addComponent(comp);
        },
      ),
    );
  }

  void _openEditComponent(VesselComponentModel comp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => AddComponentSheet(
        machineryId: widget.machinery.machineryId,
        vesselId: widget.machinery.vesselId,
        caseId: widget.caseId,
        existing: comp,
        onSave: (updated) async {
          await ref
              .read(vesselComponentsProvider(widget.machinery.machineryId)
                  .notifier)
              .deleteComponent(comp.componentId);
          return ref
              .read(vesselComponentsProvider(widget.machinery.machineryId)
                  .notifier)
              .addComponent(updated);
        },
      ),
    );
  }

  Future<void> _deleteComponent(VesselComponentModel comp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove sub-component?'),
        content:
            Text('Remove "${comp.name}" from ${widget.machinery.displayName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref
          .read(vesselComponentsProvider(widget.machinery.machineryId).notifier)
          .deleteComponent(comp.componentId);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final componentsAsync =
        ref.watch(vesselComponentsProvider(widget.machinery.machineryId));
    final components = componentsAsync.value ?? [];
    final photos = ref.watch(photosProvider(widget.caseId)).value ?? [];

    // Find the nameplate photo for this machinery item.
    final nameplateMatches = photos.where((p) =>
        p.linkedToType == 'machinery_nameplate' &&
        p.linkedToId == widget.machinery.machineryId);
    final nameplatePhoto =
        nameplateMatches.isEmpty ? null : nameplateMatches.first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ─────────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      _roleColor(widget.machinery.role).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.machinery.roleLabel,
                  style: TextStyle(
                    color: _roleColor(widget.machinery.role),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.machinery.unitNumber != null) ...[
                const SizedBox(width: 6),
                Text(
                  'No. ${widget.machinery.unitNumber}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const Spacer(),
              // Nameplate scan
              _scanningPlate
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.teal))
                  : IconButton(
                      icon: const Icon(Icons.document_scanner_outlined,
                          size: 18, color: AppColors.teal),
                      onPressed: _scanMachineryNameplate,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Scan nameplate',
                    ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.textSecondary),
                onPressed: widget.onEdit,
                visualDensity: VisualDensity.compact,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.error),
                onPressed: widget.onDelete,
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete',
              ),
            ]),

            const SizedBox(height: 8),

            // ── Display name + nameplate thumbnail ─────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.machinery.displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // ── Spec chips ─────────────────────────────
                      Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          if (widget.machinery.mcrKw != null)
                            _Spec('MCR',
                                '${widget.machinery.mcrKw!.toStringAsFixed(0)} kW'),
                          if (widget.machinery.mcrRpm != null)
                            _Spec('RPM',
                                widget.machinery.mcrRpm!.toStringAsFixed(0)),
                          if (widget.machinery.fuelType != null)
                            _Spec('Fuel', widget.machinery.fuelType!),
                          if (widget.machinery.cylinderCount != null)
                            _Spec('Cyl.',
                                widget.machinery.cylinderCount.toString()),
                          if (widget.machinery.serialNumber != null)
                            _Spec('S/N', widget.machinery.serialNumber!),
                          if (widget.machinery.runHrsNew != null)
                            _Spec('Hrs (new)',
                                widget.machinery.runHrsNew!.toStringAsFixed(0)),
                          if (widget.machinery.runHrsOverhaul != null)
                            _Spec(
                                'Hrs (O/H)',
                                widget.machinery.runHrsOverhaul!
                                    .toStringAsFixed(0)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Nameplate photo thumbnail — tap to view full-size
                // (readable text), small overlay button to re-scan
                // (§2.17 finding #13: a 64px thumbnail whose only tap
                // action re-opened the photo picker wasn't actually
                // "readable" as a nameplate reference).
                if (nameplatePhoto != null) ...[
                  const SizedBox(width: 10),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            _viewNameplateFullSize(context, nameplatePhoto),
                        child: SizedBox(
                          width: 88,
                          height: 88,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: DrivePhotoImage(
                              photo: nameplatePhoto,
                              preferThumbnail: false,
                              fit: BoxFit.cover,
                              noSourceBuilder: (_) => Container(
                                color: AppColors.surface,
                                child: const Icon(
                                    Icons.cloud_download_outlined,
                                    size: 20,
                                    color: AppColors.textTertiary),
                              ),
                              errorBuilder: (_) => Container(
                                color: AppColors.surface,
                                child: const Icon(Icons.broken_image_outlined,
                                    size: 20, color: AppColors.textTertiary),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -6,
                        bottom: -6,
                        child: GestureDetector(
                          onTap: _scanMachineryNameplate,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.teal,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.document_scanner_outlined,
                                size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),

            // ── Sub-components toggle ──────────────────────────────
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    components.isEmpty
                        ? 'Sub-components'
                        : 'Sub-components (${components.length})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (componentsAsync.isLoading) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: AppColors.textTertiary),
                    ),
                  ],
                ]),
              ),
            ),

            // ── Expanded sub-components list ───────────────────────
            if (_expanded) ...[
              const SizedBox(height: 6),
              const Divider(height: 1),
              const SizedBox(height: 4),
              if (components.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'No sub-components yet — add turbochargers, pumps, sensors…',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ...components.map((comp) {
                  final subtitle = [
                    if (comp.manufacturer != null) comp.manufacturer!,
                    if (comp.model != null) comp.model!,
                    if (comp.serialNumber != null) 'S/N ${comp.serialNumber}',
                  ].join(' · ');

                  // Find nameplate photo for this sub-component.
                  final compPhotoMatches = photos.where((p) =>
                      p.linkedToType == 'component_nameplate' &&
                      p.linkedToId == comp.componentId);
                  final compPhoto =
                      compPhotoMatches.isEmpty ? null : compPhotoMatches.first;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.subdirectory_arrow_right,
                            size: 14, color: AppColors.textTertiary),
                        const SizedBox(width: 6),
                        // Component nameplate thumbnail
                        if (compPhoto != null) ...[
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: DrivePhotoImage(
                                photo: compPhoto,
                                fit: BoxFit.cover,
                                noSourceBuilder: (_) => const SizedBox(),
                                errorBuilder: (_) => const SizedBox(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(comp.name,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500)),
                              if (subtitle.isNotEmpty)
                                Text(subtitle,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textTertiary)),
                            ],
                          ),
                        ),
                        // Edit button
                        InkWell(
                          onTap: () => _openEditComponent(comp),
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.edit_outlined,
                                size: 13, color: AppColors.textSecondary),
                          ),
                        ),
                        // Delete button
                        InkWell(
                          onTap: () => _deleteComponent(comp),
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close,
                                size: 13, color: AppColors.textTertiary),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _openAddComponent(components),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add, size: 14, color: AppColors.teal),
                  const SizedBox(width: 4),
                  Text(
                    components.isEmpty
                        ? 'Add sub-component'
                        : 'Add another sub-component',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _roleColor(String? role) => switch (role) {
        'main_engine' => AppColors.navy,
        'diesel_generator' => AppColors.teal,
        'emergency_generator' => AppColors.amber,
        'thruster' => AppColors.midBlue,
        'gearbox' => AppColors.purple,
        _ => AppColors.textSecondary,
      };
}

// ── Nameplate preview widget (confirmation dialog content) ─────────────────

class _NameplatePreview extends StatelessWidget {
  const _NameplatePreview({
    required this.make,
    required this.model,
    required this.serial,
    required this.powerKw,
    required this.rpm,
    required this.addl,
  });

  final String make, model, serial, addl;
  final double? powerKw, rpm;

  @override
  Widget build(BuildContext context) {
    final rows = <_PreviewRow>[
      if (make.isNotEmpty) _PreviewRow('Manufacturer', make),
      if (model.isNotEmpty) _PreviewRow('Model', model),
      if (serial.isNotEmpty) _PreviewRow('Serial No.', serial),
      if (powerKw != null)
        _PreviewRow('Power', '${powerKw!.toStringAsFixed(0)} kW'),
      if (rpm != null) _PreviewRow('RPM', rpm!.toStringAsFixed(0)),
      if (addl.isNotEmpty) _PreviewRow('Additional', addl),
    ];

    if (rows.isEmpty) {
      return const Text('No data could be extracted from the nameplate.');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('The following data will be applied to this machinery:',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(r.label,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: Text(r.value,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textPrimary)),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _PreviewRow {
  const _PreviewRow(this.label, this.value);
  final String label;
  final String value;
}

class _Spec extends StatelessWidget {
  const _Spec(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style:
                const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        Text(value,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
