// Stub for non-web platforms. The real implementation is in web_audio_recorder.dart.
import 'dart:typed_data';

class WebAudioRecorder {
  bool get isRecording => false;
  Future<void> start() async => throw UnsupportedError('Web only');
  Future<Uint8List> stop() async => throw UnsupportedError('Web only');
  void dispose() {}
}
