// lib/core/utils/document_scan.dart
//
// Reusable "scan a document" helper — camera/image bytes in, a flat, upright,
// perspective-corrected PNG out. Generalised (17 Jul 2026) from the invoice
// import flow (import_invoice_sheet._perspectiveCorrect) so any feature that
// wants a one-click scan (the Document Vault, Accounts, etc.) shares the same
// corner-detection + dewarp pipeline instead of duplicating it.
//
// Pipeline: Claude detects the four document corners → DocumentWarp applies a
// GPU perspective warp → PNG bytes. Corner detection runs through the global
// AI task queue (aiTasksProvider) so it shows in the task explorer like every
// other AI call.

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/claude_api.dart';
import '../../features/ai_tasks/providers/ai_tasks_provider.dart';
import 'document_warp.dart';

class DocumentScanner {
  DocumentScanner._();

  /// Detects the four corners of a document in [bytes] (a JPEG/PNG image) and
  /// perspective-corrects it to a flat, upright rectangle, returned as PNG
  /// bytes. Returns null when no document is detected or the warp fails — the
  /// caller should then fall back to the original image.
  ///
  /// [onProgress] surfaces the current step (corner detection / warp) for a
  /// busy label. Corner detection is dispatched through [aiTasksProvider] so it
  /// appears in the AI task explorer.
  static Future<Uint8List?> flatten({
    required WidgetRef ref,
    required String caseId,
    required Uint8List bytes,
    required String mimeType,
    void Function(String label)? onProgress,
  }) async {
    try {
      final b64 = base64Encode(bytes);
      onProgress?.call('Detecting document corners…');

      final rawCorners = await ref.read(aiTasksProvider.notifier).run(
            label: 'Detecting document corners',
            caseId: caseId,
            estimate: const Duration(seconds: 10),
            action: () => ClaudeApi.detectDocumentCorners(
              base64Image: b64,
              mediaType: mimeType,
            ),
          );
      if (rawCorners == null || rawCorners.length != 4) return null;

      onProgress?.call('Applying perspective correction…');

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;
      codec.dispose();

      final corners = rawCorners
          .map((xy) => ui.Offset(
                xy[0] * srcImage.width,
                xy[1] * srcImage.height,
              ))
          .toList();

      final result = await DocumentWarp.warp(
        srcImage: srcImage,
        srcCorners: corners,
      );
      srcImage.dispose();
      return result;
    } catch (e) {
      debugPrint('[DocumentScanner] flatten failed (will use original): $e');
      return null;
    }
  }
}
