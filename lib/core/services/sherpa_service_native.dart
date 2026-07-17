// lib/core/services/sherpa_service_native.dart
//
// Native (Android/iOS/desktop) implementation — uses sherpa-onnx via FFI.
// Exported conditionally from sherpa_service.dart.

import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'model_manager.dart';
import '../../features/settings/providers/speech_settings_provider.dart';

// ── Public types ──────────────────────────────────────────────────────────────

class SherpaResult {
  const SherpaResult({required this.text, required this.isFinal});

  /// Current recognised text (partial while recording, final at endpoint).
  final String text;

  /// True when sherpa detected an endpoint (sentence boundary).
  /// The recogniser resets automatically so the next event starts fresh.
  final bool isFinal;
}

// ── Service ───────────────────────────────────────────────────────────────────

class SherpaService {
  static final SherpaService instance = SherpaService._();
  SherpaService._();

  static const int _sampleRate = 16000;

  sherpa.OnlineRecognizer? _recognizer;

  // KILL-SWITCH (17 July 2026): the streaming-zipformer models this app
  // downloads are incompatible with sherpa_onnx ^1.13.3 — the native
  // OnlineRecognizer constructor aborts ("'attention_dims' does not exist in
  // the metadata"), a C++ abort() that bypasses Dart try/catch and crashes the
  // whole app the moment the Case Analyst / Interview screens initialise STT.
  // Until a compatible model+library pairing is shipped, refuse to initialise
  // with a *catchable* Dart error so callers degrade to text-only instead of
  // the process dying. Flip this to true once STT is fixed.
  static const bool _sttEnabled = false;
  sherpa.OnlineStream?     _stream;
  AudioRecorder?           _recorder;
  StreamController<SherpaResult>? _resultCtrl;
  StreamSubscription<Uint8List>?  _audioSub;

  // Raw PCM buffered from the same chunk stream already driving STT below
  // (14 July 2026 walkthrough — "fully functional recorder with audio
  // save", the raw audio was previously discarded entirely once
  // transcribed). Deliberately *not* a second concurrent `AudioRecorder`
  // — that would mean two exclusive-mic sessions racing each other; this
  // just keeps a copy of the bytes already flowing through here.
  final BytesBuilder _rawPcm = BytesBuilder(copy: false);

  bool get isInitialized => _recognizer != null;
  bool get isStreaming    => _audioSub != null;

  // ── Initialisation ─────────────────────────────────────────────────────────

  /// Load model files and create the recogniser.  Safe to call multiple times.
  /// Pass [settings] to apply the user's chosen decoding method and endpoint
  /// sensitivity; omit to use sensible defaults.
  Future<void> initialize(ModelPaths paths, [SpeechSettings? settings]) async {
    if (!_sttEnabled) {
      // Catchable — never reaches the aborting native constructor below.
      throw StateError('On-device speech-to-text is temporarily unavailable '
          '(model/library update pending).');
    }
    _stopInternal();
    _recognizer?.free();
    _recognizer = null;

    sherpa.initBindings();

    final cfg = settings ?? const SpeechSettings();
    final (rule1, rule2) = cfg.endpointSensitivity.thresholds;

    final modelConfig = sherpa.OnlineModelConfig(
      transducer: sherpa.OnlineTransducerModelConfig(
        encoder: paths.encoder,
        decoder: paths.decoder,
        joiner:  paths.joiner,
      ),
      tokens:     paths.tokens,
      numThreads: 2,
      provider:   'cpu',
      debug:      false,
      modelType:  'zipformer',
    );

    final config = sherpa.OnlineRecognizerConfig(
      feat:  const sherpa.FeatureConfig(sampleRate: _sampleRate, featureDim: 80),
      model: modelConfig,
      decodingMethod:          cfg.decodingMethod,
      maxActivePaths:          4,
      enableEndpoint:          true,
      rule1MinTrailingSilence: rule1,
      rule2MinTrailingSilence: rule2,
      rule3MinUtteranceLength: 30.0,
    );

    _recognizer = sherpa.OnlineRecognizer(config);
  }

  // ── Streaming ──────────────────────────────────────────────────────────────

  /// Start recording + recognition.  Returns a broadcast stream of results.
  /// Throws [StateError] if not initialised.
  Stream<SherpaResult> startStreaming() {
    if (_recognizer == null) {
      throw StateError(
          'SherpaService not initialised — call initialize() first');
    }
    _stopInternal();

    _stream     = _recognizer!.createStream();
    _recorder   = AudioRecorder();
    _resultCtrl = StreamController<SherpaResult>.broadcast();
    _rawPcm.clear();

    _recorder!
        .startStream(const RecordConfig(
          encoder:     AudioEncoder.pcm16bits,
          sampleRate:  _sampleRate,
          numChannels: 1,
        ))
        .then((audioStream) {
          _audioSub = audioStream.listen(
            _onAudioChunk,
            onError: (Object e) => _resultCtrl?.addError(e),
            onDone:  _onAudioDone,
          );
        });

    return _resultCtrl!.stream;
  }

  void _onAudioChunk(Uint8List bytes) {
    if (_recognizer == null || _stream == null) return;

    _rawPcm.add(bytes);

    final samples = _pcm16ToFloat32(bytes);
    _stream!.acceptWaveform(samples: samples, sampleRate: _sampleRate);

    while (_recognizer!.isReady(_stream!)) {
      _recognizer!.decode(_stream!);
    }

    final text = _recognizer!.getResult(_stream!).text.trim();

    if (_recognizer!.isEndpoint(_stream!)) {
      if (text.isNotEmpty) {
        _resultCtrl?.add(SherpaResult(text: text, isFinal: true));
      }
      _recognizer!.reset(_stream!);
    } else if (text.isNotEmpty) {
      _resultCtrl?.add(SherpaResult(text: text, isFinal: false));
    }
  }

  void _onAudioDone() {
    if (_recognizer != null && _stream != null) {
      _stream!.inputFinished();
      while (_recognizer!.isReady(_stream!)) {
        _recognizer!.decode(_stream!);
      }
      final text = _recognizer!.getResult(_stream!).text.trim();
      if (text.isNotEmpty) {
        _resultCtrl?.add(SherpaResult(text: text, isFinal: true));
      }
    }
    _resultCtrl?.close();
    _resultCtrl = null;
  }

  /// Stop recording and flush any remaining partial text.
  Future<String> stop() async {
    String last = '';
    if (_recognizer != null && _stream != null) {
      last = _recognizer!.getResult(_stream!).text.trim();
    }
    await _recorder?.stop();
    _stopInternal();
    return last;
  }

  void _stopInternal() {
    _audioSub?.cancel();
    _audioSub = null;
    _recorder?.dispose();
    _recorder = null;
    _stream?.free();
    _stream = null;
    if (_resultCtrl != null && !_resultCtrl!.isClosed) {
      _resultCtrl!.close();
    }
    _resultCtrl = null;
  }

  void dispose() {
    _stopInternal();
    _recognizer?.free();
    _recognizer = null;
  }

  /// The raw audio recorded since the last [startStreaming], as a standard
  /// 16-bit PCM mono WAV file — playable/uploadable as-is. Call after
  /// [stop]; returns null if nothing was recorded. Does not clear the
  /// buffer itself (call [clearRawAudio] once the caller has taken it).
  Uint8List? takeRawAudioWav() {
    final pcm = _rawPcm.toBytes();
    if (pcm.isEmpty) return null;
    return _wrapPcmAsWav(pcm, sampleRate: _sampleRate);
  }

  void clearRawAudio() => _rawPcm.clear();

  // ── Audio helpers ──────────────────────────────────────────────────────────

  /// Convert little-endian PCM-16 bytes → Float32List in [-1, 1].
  static Float32List _pcm16ToFloat32(Uint8List bytes) {
    final count   = bytes.length ~/ 2;
    final samples = Float32List(count);
    final data    = ByteData.sublistView(bytes);
    for (int i = 0; i < count; i++) {
      samples[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }

  /// Prepends a standard 44-byte RIFF/WAVE header to raw PCM-16 mono data
  /// so it's a normal playable .wav file, not a headerless blob.
  static Uint8List _wrapPcmAsWav(Uint8List pcm,
      {required int sampleRate, int numChannels = 1, int bitsPerSample = 16}) {
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;
    final header = ByteData(44);
    void s(int offset, String v) {
      for (var i = 0; i < v.length; i++) {
        header.setUint8(offset + i, v.codeUnitAt(i));
      }
    }

    s(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    s(8, 'WAVE');
    s(12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // fmt chunk size
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    s(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);

    final out = BytesBuilder();
    out.add(header.buffer.asUint8List());
    out.add(pcm);
    return out.toBytes();
  }
}
