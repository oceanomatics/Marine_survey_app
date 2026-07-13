// Widget-test double for BackgroundNotifier — skips SupabaseService.client,
// used wherever caseCompletenessProvider (case_completeness_provider.dart)
// needs a background signal without a real case_background fetch.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/background/models/background_model.dart';
import 'package:marine_survey_app/features/background/providers/background_provider.dart';

class FakeBackgroundNotifier extends BackgroundNotifier {
  FakeBackgroundNotifier([this._content = '']);
  final String _content;

  @override
  Future<CaseBackground> build(String caseId) async => CaseBackground(
        caseId: caseId,
        content: _content,
        updatedAt: DateTime(2026, 1, 1),
      );

  @override
  Future<void> save(String content) async {
    state = AsyncData((state.value!).copyWith(content: content));
  }
}
