// lib/features/reports/services/report_delivery.dart
//
// Platform-conditional export: web build uses dart:html for browser download,
// native build saves to the documents directory.

export 'report_delivery_web.dart'
    if (dart.library.io) 'report_delivery_native.dart';
