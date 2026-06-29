// lib/features/reports/services/report_delivery_web.dart
//
// Web delivery: triggers a browser download via dart:html.

import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

const String _docxMime =
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

Future<void> deliverDocx(Uint8List bytes, String filename) async {
  final blob = html.Blob([bytes], _docxMime);
  final url  = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
