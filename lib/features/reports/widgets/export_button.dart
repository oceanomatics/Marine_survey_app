// lib/features/reports/widgets/export_button.dart
//
// The export button shown in the report builder.
// Handles pre-export validation, shows progress, triggers download.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/report_provider.dart';
import '../services/docx_export_service.dart';
import '../../../features/photos/models/photo_model.dart';
import '../../../features/photos/providers/photo_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/error_handler.dart';

class ExportButton extends ConsumerStatefulWidget {
  const ExportButton({
    super.key,
    required this.output,
    required this.assembled,
    required this.sections,
  });

  final ReportOutput output;
  final AssembledReportData assembled;
  final Map<SectionType, ReportSection> sections;

  @override
  ConsumerState<ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends ConsumerState<ExportButton> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final allApproved = widget.sections.values.every((s) => s.approved);
    final canExport   = widget.output.status != ReportStatus.locked;
    final isFinal     = widget.output.outputType == OutputType.final_;
    final caseData    = widget.assembled.caseData;
    final signedOffAttending = caseData['signed_off_attending'] as bool? ?? false;
    final signedOffReviewing = caseData['signed_off_reviewing'] as bool? ?? false;
    final signOffBlocked = isFinal && !(signedOffAttending && signedOffReviewing);

    return ElevatedButton.icon(
      onPressed: (!canExport || _exporting || signOffBlocked)
          ? null
          : () => _export(context, allApproved),
      icon: _exporting
          ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.download_outlined, size: 18),
      label: Text(
        _exporting
            ? 'Generating...'
            : signOffBlocked
                ? 'Sign-off required'
                : 'Export .docx',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: (canExport && !signOffBlocked)
            ? AppColors.navy
            : AppColors.textTertiary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
            horizontal: 18, vertical: 12),
      ),
    );
  }

  Future<void> _export(BuildContext context, bool allApproved) async {
    // Warn if not all sections approved
    if (!allApproved) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Not all sections approved'),
          content: const Text(
            'Some sections have not been approved yet. '
            'The exported document will include unapproved content.\n\n'
            'Do you want to export anyway?',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Export anyway')),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _exporting = true);

    try {
      // Resolve cover photo — prefer the output's override, fall back to the
      // case's cover-allocated photo from vessel particulars.
      Uint8List? coverPhotoBytes;
      String coverPhotoExt = 'jpg';
      if (!kIsWeb) {
        final photos = ref.read(photosProvider(widget.output.caseId)).value ?? [];
        final overrideId = widget.output.coverPhotoId;
        PhotoModel? findPhoto(bool Function(PhotoModel) test) {
          try { return photos.firstWhere(test); } catch (_) { return null; }
        }
        final photo = overrideId != null
            ? findPhoto((p) => p.id == overrideId)
            : findPhoto((p) => p.allocation == PhotoAllocation.coverPage);
        if (photo != null && photo.localPath.isNotEmpty) {
          try {
            coverPhotoBytes = await File(photo.localPath).readAsBytes();
          } catch (_) {}
        }
      }

      final filename = await DocxExportService.export(
        output:          widget.output,
        assembled:       widget.assembled,
        sections:        widget.sections,
        coverPhotoBytes: coverPhotoBytes,
        coverPhotoExt:   coverPhotoExt,
      );

      if (!context.mounted) return;
      _showSuccess(context, filename);
    } catch (e, st) {
      if (!context.mounted) return;
      showError(context, 'Export failed: $e', error: e, stack: st, tag: 'App');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showSuccess(BuildContext context, String filename) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.check_circle,
              color: AppColors.success, size: 22),
          SizedBox(width: 10),
          Text('Report exported',
              style: TextStyle(fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your report has been downloaded:',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                const Icon(Icons.description_outlined,
                    size: 16, color: AppColors.navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(filename,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500)),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            const Text(
              'The file is saved in your downloads folder. '
              'Open it in Microsoft Word or any compatible application.',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
