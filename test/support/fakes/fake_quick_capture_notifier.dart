// Widget/provider-test double for QuickCaptureNotifier — skips
// SupabaseService.client entirely but replays the exact same routing logic
// as the real notifier (including calling the real, shared
// sectionForRoutedTo() so the cue-routing mapping can never drift between
// the fake and the production code). Mirrors the pattern in
// fake_surveyor_notes_notifier.dart etc.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/capture/providers/quick_capture_provider.dart';
import 'package:marine_survey_app/features/surveyor_notes/providers/surveyor_notes_provider.dart';

class FakeQuickCaptureNotifier extends QuickCaptureNotifier {
  FakeQuickCaptureNotifier([this._seed = const []]);
  final List<QuickCaptureModel> _seed;

  @override
  Future<QuickCaptureState> build(String caseId) async =>
      QuickCaptureState(items: _seed);

  @override
  Future<void> routeCapture({
    required String captureId,
    required RoutedTo destination,
    String? linkedId,
  }) async {
    final current0 = state.value!;
    final capture = current0.items.firstWhere((i) => i.captureId == captureId);

    if (destination != RoutedTo.discarded) {
      await ref.read(surveyorNotesProvider(capture.caseId).notifier).add(
            caseId: capture.caseId,
            content: capture.content,
            caseSection: sectionForRoutedTo(destination),
            source: 'Quick Capture',
          );
    }

    final current = state.value!;
    state = AsyncData(QuickCaptureState(
      items: current.items.map((i) {
        if (i.captureId != captureId) return i;
        return QuickCaptureModel(
          captureId:   i.captureId,
          caseId:      i.caseId,
          content:     i.content,
          status:      CaptureStatus.routed,
          capturedAt:  i.capturedAt,
          captureType: i.captureType,
          routedTo:    destination,
          linkedId:    linkedId,
        );
      }).toList(),
    ));
  }
}
