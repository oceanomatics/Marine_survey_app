// lib/core/services/model_manager.dart
//
// Platform-conditional export: native build gets the dart:io implementation,
// web build gets a no-op stub.

export 'model_manager_web.dart'
    if (dart.library.io) 'model_manager_native.dart';
