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

  /// Launches the native scanner (live outline + auto-capture + dewarp) and
  /// returns the first scanned page's bytes as a flat, upright image — or null
  /// if the platform is unsupported or the user cancelled. The caller then
  /// runs the result through the normal Doc Vault import + extraction flow.
  static Future<Uint8List?> scanSinglePage() async {
    if (!isSupported) return null;
    final paths = await CunningDocumentScanner.getPictures(noOfPages: 1);
    if (paths == null || paths.isEmpty) return null;
    return XFile(paths.first).readAsBytes();
  }
}
