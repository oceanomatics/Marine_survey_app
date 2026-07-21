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

  /// Launches the native scanner (live outline + auto-capture + dewarp) for a
  /// whole batch: the surveyor captures many documents in ONE session (the
  /// scanner's "add page" between each), and this returns every scanned page's
  /// flat, upright bytes in order. Empty when unsupported or cancelled. Each
  /// page is then imported to the Doc Vault + queued for extraction without a
  /// per-document confirmation (surveyor: confirming each is too slow when
  /// scanning a stack).
  static Future<List<Uint8List>> scanPages({int maxPages = 24}) async {
    if (!isSupported) return const [];
    final paths = await CunningDocumentScanner.getPictures(noOfPages: maxPages);
    if (paths == null || paths.isEmpty) return const [];
    final out = <Uint8List>[];
    for (final path in paths) {
      out.add(await XFile(path).readAsBytes());
    }
    return out;
  }
}
