// lib/core/utils/native_document_scan.dart
//
// Native real-time document scanner (surveyor request, 21 Jul 2026): a live
// edge-detection + auto-capture + perspective-dewarp scan, backed by the
// platform document scanner — Google ML Kit Document Scanner on Android and
// VisionKit on iOS (via the cunning_document_scanner plugin).
//
// This is the "ideal" real-time path. It supersedes the AI corner-detect
// scan (DocumentScanner.flatten) on mobile; web/desktop, where no native
// scanner exists, fall back to that AI path — see DocumentVaultScreen.
// _scanDocument. Either way the scanned page flows into the same save-to-vault
// + AI-extraction pipeline.

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;

class NativeDocumentScan {
  NativeDocumentScan._();

  /// Whether the native real-time scanner exists on this platform.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Launches the native scanner for ONE document and returns it as a single
  /// (possibly multi-page) PDF's bytes — the scanner's "add page" builds up the
  /// pages of this one document, exactly what the surveyor expects (not one
  /// vault doc per page). Returns null when unsupported or cancelled (cancel is
  /// how the caller's scan loop knows to stop and return to the vault).
  ///
  /// Uses [AndroidScannerMode.base] — the lean mode: no image
  /// filter/enhance/clean tools at capture time (the surveyor flagged those as
  /// unnecessary here; the crop/rotate review is inherent to ML Kit).
  static Future<Uint8List?> scanOneDocument({int maxPages = 24}) async {
    if (!isSupported) return null;
    final paths = await CunningDocumentScanner.getPictures(
      noOfPages: maxPages,
      asPdf: true,
      androidScannerMode: AndroidScannerMode.base,
    );
    if (paths == null || paths.isEmpty) return null;
    // asPdf returns the PDF path (defensively pick the .pdf entry if the
    // platform also returns page images alongside it).
    final pdf = paths.firstWhere(
      (p) => p.toLowerCase().endsWith('.pdf'),
      orElse: () => paths.first,
    );
    return XFile(pdf).readAsBytes();
  }
}
