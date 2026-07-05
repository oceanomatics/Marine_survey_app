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
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/case_photo_picker_sheet.dart';

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
      final result =
          await ClaudeApi.extractNameplate(base64Image: b64, mediaType: mime);
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

      await ref
          .read(machineryProvider(widget.machinery.vesselId).notifier)
          .updateMachinery(updated);

      // Pin this photo as the nameplate reference for the card thumbnail.
      await ref.read(photosProvider(widget.caseId).notifier).attachLink(
          photo.id, 'machinery_nameplate', widget.machinery.machineryId);

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
                // Nameplate photo thumbnail
                if (nameplatePhoto != null) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _scanMachineryNameplate,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: !nameplatePhoto.hasLocalFile
                          ? Container(
                              width: 64,
                              height: 64,
                              color: AppColors.surface,
                              child: const Icon(Icons.cloud_download_outlined,
                                  size: 20, color: AppColors.textTertiary),
                            )
                          : Image.file(
                              File(nameplatePhoto.thumbnailPath ??
                                  nameplatePhoto.localPath!),
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 64,
                                height: 64,
                                color: AppColors.surface,
                                child: const Icon(Icons.broken_image_outlined,
                                    size: 20, color: AppColors.textTertiary),
                              ),
                            ),
                    ),
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
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: !compPhoto.hasLocalFile
                                ? const SizedBox(width: 36, height: 36)
                                : Image.file(
                                    File(compPhoto.thumbnailPath ??
                                        compPhoto.localPath!),
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox(width: 36, height: 36),
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
