// lib/features/capture/widgets/web_audio_recorder.dart
//
// Web-compatible audio recording using the browser's MediaRecorder API.
// On web, dart:html gives us access to MediaRecorder directly.
// On native (Android/iOS/tablet), the record package is used instead.
// This file handles the WEB path only.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';

class WebAudioRecorder {
  html.MediaRecorder? _recorder;
  html.MediaStream? _stream;
  final List<html.Blob> _chunks = [];
  bool _isRecording = false;
  StreamController<Uint8List>? _onStopController;

  bool get isRecording => _isRecording;

  /// Request microphone permission and start recording
  Future<void> start() async {
    try {
      _chunks.clear();
      _stream = await html.window.navigator.mediaDevices!
          .getUserMedia({'audio': true, 'video': false});

      _recorder = html.MediaRecorder(_stream!, {'mimeType': 'audio/webm'});

      _recorder!.addEventListener('dataavailable', (event) {
        final blobEvent = event as html.BlobEvent;
        if (blobEvent.data != null && blobEvent.data!.size > 0) {
          _chunks.add(blobEvent.data!);
        }
      });

      _onStopController = StreamController<Uint8List>();

      _recorder!.addEventListener('stop', (_) async {
        final blob = html.Blob(_chunks, 'audio/webm');
        final bytes = await _blobToBytes(blob);
        _onStopController?.add(bytes);
        _onStopController?.close();
      });

      _recorder!.start(250); // collect chunks every 250ms
      _isRecording = true;
    } catch (e) {
      throw Exception('Microphone access denied: $e');
    }
  }

  /// Stop recording and return audio bytes
  Future<Uint8List> stop() async {
    if (_recorder == null || !_isRecording) {
      throw Exception('No active recording');
    }

    _isRecording = false;
    _recorder!.stop();

    // Stop microphone stream tracks
    _stream?.getTracks().forEach((track) => track.stop());

    // Wait for the stop event to fire and return bytes
    final bytes = await _onStopController!.stream.first;
    return bytes;
  }

  void dispose() {
    _stream?.getTracks().forEach((track) => track.stop());
    _recorder = null;
    _stream = null;
    _onStopController?.close();
  }

  Future<Uint8List> _blobToBytes(html.Blob blob) async {
    final reader = html.FileReader();
    final completer = Completer<Uint8List>();

    reader.onLoadEnd.listen((_) {
      final result = reader.result as dynamic;
      if (result is Uint8List) {
        completer.complete(result);
      } else {
        // result is a JS ArrayBuffer — convert
        completer.complete(Uint8List.view(result as dynamic));
      }
    });

    reader.onError.listen((e) {
      completer.completeError('FileReader error: $e');
    });

    reader.readAsArrayBuffer(blob);
    return completer.future;
  }
}
