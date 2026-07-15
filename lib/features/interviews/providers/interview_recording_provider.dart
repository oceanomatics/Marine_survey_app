// lib/features/interviews/providers/interview_recording_provider.dart
//
// Recording session state lifted out of RecordInterviewScreen's local
// State and into a Riverpod provider (14 July 2026 walkthrough — "recording
// should keep running as something like a persistent overlay/floating
// indicator across screens, not require staying on the Interview screen").
// A Riverpod provider naturally survives navigation within the same
// ProviderScope (the whole app, here) — the screen becomes a thin UI over
// this, and a global overlay (see interview_recording_overlay.dart) can
// show/control the same session from anywhere.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sherpa_service.dart';

@immutable
class InterviewRecordingState {
  const InterviewRecordingState({
    this.caseId,
    this.isRecording = false,
    this.seconds = 0,
    this.liveWords = '',
    this.transcript = '',
  });

  /// Which case is being recorded for — the overlay uses this to route back
  /// to the right screen when tapped from elsewhere in the app.
  final String? caseId;
  final bool isRecording;
  final int seconds;
  final String liveWords;
  final String transcript;

  bool get hasActiveSession => caseId != null;

  InterviewRecordingState copyWith({
    String? caseId,
    bool? isRecording,
    int? seconds,
    String? liveWords,
    String? transcript,
  }) =>
      InterviewRecordingState(
        caseId: caseId ?? this.caseId,
        isRecording: isRecording ?? this.isRecording,
        seconds: seconds ?? this.seconds,
        liveWords: liveWords ?? this.liveWords,
        transcript: transcript ?? this.transcript,
      );
}

final interviewRecordingProvider = NotifierProvider<InterviewRecordingNotifier,
    InterviewRecordingState>(InterviewRecordingNotifier.new);

class InterviewRecordingNotifier extends Notifier<InterviewRecordingState> {
  final _sherpa = SherpaService.instance;
  Timer? _timer;
  StreamSubscription<SherpaResult>? _sub;

  @override
  InterviewRecordingState build() => const InterviewRecordingState();

  void startForCase(String caseId, {String seedTranscript = ''}) {
    state = InterviewRecordingState(
        caseId: caseId, transcript: seedTranscript, isRecording: true);
    final stream = _sherpa.startStreaming();
    _sub?.cancel();
    _sub = stream.listen(_onResult);
    _timer?.cancel();
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) => state = state.copyWith(seconds: state.seconds + 1));
  }

  void _onResult(SherpaResult result) {
    if (result.isFinal) {
      final existing = state.transcript.trimRight();
      final sep = existing.isEmpty ? '' : ' ';
      state = state.copyWith(
          transcript: '$existing$sep${result.text}', liveWords: '');
    } else {
      state = state.copyWith(liveWords: result.text);
    }
  }

  /// Stops the recorder and returns the final transcript + raw audio WAV
  /// (may be null if nothing was captured) — the caller (the screen, if
  /// still open, or a later reopen of it) is responsible for the save UI.
  /// Session state (caseId/transcript) is deliberately *not* cleared here
  /// — [clearSession] is a separate explicit step, so the transcript
  /// remains recoverable if the screen wasn't open when recording stopped.
  Future<({String transcript, Uint8List? audioWav})> stop() async {
    _timer?.cancel();
    _timer = null;
    await _sub?.cancel();
    _sub = null;

    final trailing = await _sherpa.stop();
    var transcript = state.transcript;
    if (trailing.isNotEmpty) {
      final existing = transcript.trimRight();
      final sep = existing.isEmpty ? '' : ' ';
      transcript = '$existing$sep$trailing';
    }
    final audio = _sherpa.takeRawAudioWav();
    state = state.copyWith(isRecording: false, transcript: transcript, liveWords: '');
    return (transcript: transcript, audioWav: audio);
  }

  void clearSession() {
    _sherpa.clearRawAudio();
    state = const InterviewRecordingState();
  }
}
