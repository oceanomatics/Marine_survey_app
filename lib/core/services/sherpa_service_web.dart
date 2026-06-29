// lib/core/services/sherpa_service_web.dart
//
// Web stub — sherpa-onnx is FFI-based and cannot run in a browser.
// Exported conditionally from sherpa_service.dart when dart.library.io is absent.

import 'dart:async';
import 'model_manager.dart';
import '../../features/settings/providers/speech_settings_provider.dart';

class SherpaResult {
  const SherpaResult({required this.text, required this.isFinal});
  final String text;
  final bool   isFinal;
}

class SherpaService {
  static final SherpaService instance = SherpaService._();
  SherpaService._();

  bool get isInitialized => false;
  bool get isStreaming    => false;

  Future<void> initialize(ModelPaths paths, [SpeechSettings? settings]) async {}

  Stream<SherpaResult> startStreaming() => const Stream.empty();

  Future<String> stop() async => '';

  void dispose() {}
}
