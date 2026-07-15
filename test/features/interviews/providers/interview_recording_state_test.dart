// test/features/interviews/providers/interview_recording_state_test.dart
//
// InterviewRecordingNotifier itself is not unit-tested here — it hardcodes
// `SherpaService.instance` (a real singleton wrapping native audio/model
// state) with no injection point, and `startForCase()` throws StateError
// immediately against an uninitialised recognizer in a plain `flutter test`
// run. Making that testable needs a small DI-style refactor of production
// code (an injectable service seam), which wasn't made unilaterally here —
// flagging it rather than guessing at the right shape. What IS covered:
// the pure InterviewRecordingState data class the notifier's transitions
// are built from.

import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/interviews/providers/interview_recording_provider.dart';

void main() {
  group('InterviewRecordingState', () {
    test('default state has no active session', () {
      const state = InterviewRecordingState();
      expect(state.hasActiveSession, isFalse);
      expect(state.isRecording, isFalse);
      expect(state.seconds, 0);
      expect(state.liveWords, '');
      expect(state.transcript, '');
    });

    test('hasActiveSession is true once a caseId is set', () {
      const state = InterviewRecordingState(caseId: 'case1');
      expect(state.hasActiveSession, isTrue);
    });

    test('copyWith only changes the given fields', () {
      const original = InterviewRecordingState(
        caseId: 'case1',
        isRecording: true,
        seconds: 12,
        liveWords: 'partial',
        transcript: 'committed text',
      );

      final updated = original.copyWith(seconds: 13);

      expect(updated.caseId, 'case1');
      expect(updated.isRecording, isTrue);
      expect(updated.seconds, 13);
      expect(updated.liveWords, 'partial');
      expect(updated.transcript, 'committed text');
    });

    test('copyWith(isRecording: false) stops the session but keeps transcript', () {
      const original = InterviewRecordingState(
        caseId: 'case1',
        isRecording: true,
        transcript: 'so far so good',
      );

      final stopped = original.copyWith(isRecording: false);

      expect(stopped.isRecording, isFalse);
      expect(stopped.transcript, 'so far so good');
      expect(stopped.caseId, 'case1');
    });
  });
}
