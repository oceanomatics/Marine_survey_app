// lib/features/reports/services/report_delivery_native.dart
//
// Native delivery: saves to the app documents directory.
// Share/open is left to the OS file manager for now.

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';

Future<void> deliverDocx(Uint8List bytes, String filename) async {
  final dir  = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  debugPrint('Saved report: ${file.path}');
}
