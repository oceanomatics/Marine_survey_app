// Widget-test double for InterviewsNotifier — skips SupabaseService.client
// and Storage entirely but replays the same state-update shape as the real
// notifier. Mirrors fake_surveyor_notes_notifier.dart etc.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/interviews/models/interview_model.dart';
import 'package:marine_survey_app/features/interviews/providers/interview_provider.dart';

class FakeInterviewsNotifier extends InterviewsNotifier {
  FakeInterviewsNotifier([this._seed = const []]);
  final List<InterviewModel> _seed;
  final List<InterviewModel> updateCalls = [];
  final List<String> deleteCalls = [];

  @override
  Future<List<InterviewModel>> build(String caseId) async => _seed;

  @override
  Future<void> updateInterview(InterviewModel model) async {
    updateCalls.add(model);
    final current = state.value ?? [];
    state = AsyncData([
      for (final m in current)
        if (m.interviewId == model.interviewId) model else m,
    ]);
  }

  @override
  Future<void> delete(String interviewId) async {
    deleteCalls.add(interviewId);
    final current = state.value ?? [];
    state =
        AsyncData(current.where((m) => m.interviewId != interviewId).toList());
  }
}
