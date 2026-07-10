// Widget-test double for SectionDraftNotifier. The real buildSections()
// generates ~1000 lines of default section text and reads/writes
// `report_sections` via SupabaseService.client — this fake skips all of that
// and just seeds the state directly, since widget tests only need to prove
// the screen renders/reacts to section state correctly, not that the AI
// drafting or persistence pipeline works (that's Manual/Integ — see
// TEST_SHEET.md).
import 'package:marine_survey_app/features/reports/providers/report_provider.dart';

class FakeSectionDraftNotifier extends SectionDraftNotifier {
  FakeSectionDraftNotifier(super.caseId, super.outputId, this._seed);
  final Map<SectionType, ReportSection> _seed;

  @override
  Future<void> buildSections(
    AssembledReportData data, {
    required ReportOutput output,
    bool aiDraft = false,
  }) async {
    state = _seed;
  }

  @override
  void updateContent(SectionType type, String content) {
    final existing = state[type];
    if (existing != null) {
      state = {...state, type: existing.copyWith(content: content)};
    }
  }

  @override
  void updateRemarks(SectionType type, String remarks) {
    final existing = state[type];
    if (existing != null) {
      state = {...state, type: existing.copyWith(remarks: remarks)};
    }
  }

  @override
  void setSurveyorReview(SectionType type, SurveyorReview review) {
    final existing = state[type];
    if (existing != null) {
      state = {...state, type: existing.copyWith(surveyorReview: review)};
    }
  }
}
