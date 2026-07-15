import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/cases/models/case_model.dart';
import 'package:marine_survey_app/features/cases/providers/cases_provider.dart';

class FakeCaseNotifier extends CaseNotifier {
  FakeCaseNotifier(this._model);
  final CaseModel _model;

  @override
  Future<CaseModel> build(String caseId) async => _model;

  @override
  Future<void> updateOtherMattersClauses(List<String> clauseIds) async {
    state = AsyncData(
        (state.value ?? _model).copyWith(otherMattersClauseIds: clauseIds));
  }

  @override
  Future<void> updateOtherMattersNotes(String notes) async {
    state = AsyncData(
        (state.value ?? _model).copyWith(otherMattersNotes: notes));
  }
}
