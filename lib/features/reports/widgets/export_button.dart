// lib/features/reports/widgets/export_button.dart
//
// The export button shown in the report builder.
// Handles pre-export validation, shows progress, triggers download.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/report_provider.dart';
import '../services/docx_export_service.dart';
import '../utils/export_validation.dart';
import 'export_validation_sheet.dart';
import '../../../features/cases/providers/cases_provider.dart';
import '../../../features/photos/models/photo_model.dart';
import '../../../features/photos/providers/photo_provider.dart';
import '../../../features/photos/services/google_drive_service.dart';
import '../../../core/services/google_auth_service.dart';
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
    final canExport = widget.output.status != ReportStatus.locked;
    final isFinal = widget.output.outputType == OutputType.final_;
    final caseData = widget.assembled.caseData;
    final signedOffAttending =
        caseData['signed_off_attending'] as bool? ?? false;
    final signedOffReviewing =
        caseData['signed_off_reviewing'] as bool? ?? false;
    final signOffBlocked =
        isFinal && !(signedOffAttending && signedOffReviewing);

    // GPN-AI: hard-block if any AI-drafted section has no surveyor review
    final aiUnreviewedCount = widget.sections.values
        .where((s) => s.aiDrafted && s.surveyorReview == null)
        .length;
    final aiReviewBlocked = aiUnreviewedCount > 0;

    final blocked =
        !canExport || _exporting || signOffBlocked || aiReviewBlocked;

    return ElevatedButton.icon(
      onPressed: blocked ? null : () => _export(context),
      icon: _exporting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.download_outlined, size: 18),
      label: Text(
        _exporting
            ? 'Generating...'
            : signOffBlocked
                ? 'Sign-off required'
                : aiReviewBlocked
                    ? 'AI review required ($aiUnreviewedCount)'
                    : 'Export .docx',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: !blocked ? AppColors.navy : AppColors.textTertiary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    // Consolidated pre-export checklist (TODO.md §1.7) — soft warnings only;
    // the hard blocks (sign-off, AI review) already disable the button and
    // never reach this dialog.
    final warnings =
        buildExportWarnings(widget.output, widget.sections, widget.assembled);
    if (warnings.isNotEmpty) {
      final proceed = await showExportValidationSheet(context, warnings);
      if (!proceed) return;
    }

    setState(() => _exporting = true);

    try {
      // Resolve cover photo — the single case-wide cover-allocated photo,
      // shared with the Photo Gallery and Vessel Particulars.
      Uint8List? coverPhotoBytes;
      String coverPhotoExt = 'jpg';
      // Inline damage-item photos (spec §7 placement mode) — resolved here,
      // same convention as the cover photo, so the export service itself
      // has no filesystem dependency.
      final damagePhotosByItemId = <String, List<ResolvedPhoto>>{};
      // Machinery nameplate photos (TODO.md §1.8 S4) — same resolution
      // convention, keyed by machinery_id via the 'machinery_nameplate'
      // link type already used for the in-app thumbnail (machinery_card.dart).
      final machineryPhotosByItemId = <String, List<ResolvedPhoto>>{};
      if (!kIsWeb) {
        final photoNotifier =
            ref.read(photosProvider(widget.output.caseId).notifier);
        final photos =
            ref.read(photosProvider(widget.output.caseId)).value ?? [];
        final photo = photos.coverPhoto;
        if (photo != null) {
          try {
            final resolved = photo.hasLocalFile
                ? photo
                : await photoNotifier.ensureLocalFile(photo.id) ?? photo;
            if (resolved.hasLocalFile) {
              coverPhotoBytes = await File(resolved.localPath!).readAsBytes();
            }
          } catch (_) {}
        }

        for (final p in photos) {
          if (p.linkedToType != 'damage_item' ||
              p.linkedToId == null ||
              p.effectivePlacementMode != PlacementMode.inline) {
            continue;
          }
          try {
            final resolved = p.hasLocalFile
                ? p
                : await photoNotifier.ensureLocalFile(p.id) ?? p;
            if (!resolved.hasLocalFile) continue;
            final localPath = resolved.localPath!;
            final bytes = await File(localPath).readAsBytes();
            final ext =
                localPath.contains('.') ? localPath.split('.').last : 'jpg';
            damagePhotosByItemId
                .putIfAbsent(p.linkedToId!, () => [])
                .add((bytes: bytes, ext: ext));
          } catch (_) {}
        }

        for (final p in photos) {
          if (p.linkedToType != 'machinery_nameplate' || p.linkedToId == null) {
            continue;
          }
          try {
            final resolved = p.hasLocalFile
                ? p
                : await photoNotifier.ensureLocalFile(p.id) ?? p;
            if (!resolved.hasLocalFile) continue;
            final localPath = resolved.localPath!;
            final bytes = await File(localPath).readAsBytes();
            final ext =
                localPath.contains('.') ? localPath.split('.').last : 'jpg';
            machineryPhotosByItemId
                .putIfAbsent(p.linkedToId!, () => [])
                .add((bytes: bytes, ext: ext));
          } catch (_) {}
        }
      }

      final filename = await DocxExportService.export(
        output: widget.output,
        assembled: widget.assembled,
        sections: widget.sections,
        coverPhotoBytes: coverPhotoBytes,
        coverPhotoExt: coverPhotoExt,
        damagePhotosByItemId: damagePhotosByItemId,
        machineryPhotosByItemId: machineryPhotosByItemId,
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

  // ── Send to Google Drive ─────────────────────────────────────────────────
  // Reads the just-saved local copy back off disk (deliverDocx already wrote
  // it to ApplicationDocumentsDirectory) rather than threading bytes through
  // DocxExportService's return value — keeps the export service itself free
  // of any Drive dependency.
  bool _sendingToDrive = false;

  Future<void> _sendToDrive(BuildContext context, String filename) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final bytes = await File('${dir.path}/$filename').readAsBytes();

      final caseModel = ref.read(caseProvider(widget.output.caseId)).value;
      final rootId =
          await GoogleDriveService.findOrCreateFolder('Marine Survey Reports');
      final caseFolderId = await GoogleDriveService.findOrCreateFolder(
        caseModel?.title ?? widget.output.caseId,
        parentId: rootId,
      );
      await GoogleDriveService.uploadFile(
        bytes: bytes,
        filename: filename,
        mimeType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        parentId: caseFolderId,
      );

      messenger.showSnackBar(
        const SnackBar(content: Text('Report uploaded to Google Drive')),
      );
    } on GoogleSignInCancelled {
      // User cancelled sign-in — nothing to do.
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
            content: Text('Drive upload failed: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccess(BuildContext context, String filename) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 22),
            SizedBox(width: 10),
            Text('Report exported', style: TextStyle(fontSize: 16)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your report has been downloaded:',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: _sendingToDrive
                  ? null
                  : () async {
                      setDialogState(() => _sendingToDrive = true);
                      await _sendToDrive(ctx, filename);
                      setDialogState(() => _sendingToDrive = false);
                    },
              icon: _sendingToDrive
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5))
                  : const Icon(Icons.add_to_drive_outlined, size: 16),
              label: const Text('Send to Drive'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
