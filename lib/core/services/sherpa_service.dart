// lib/core/services/sherpa_service.dart
//
// Platform-conditional export: native build gets the real FFI-backed service,
// web build gets a no-op stub (sherpa-onnx requires dart:ffi, not available on web).

export 'sherpa_service_web.dart'
    if (dart.library.io) 'sherpa_service_native.dart';
