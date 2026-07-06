import 'package:marine_survey_app/features/cases/models/case_model.dart';
import 'package:marine_survey_app/features/cases/providers/cases_provider.dart';

class FakeCaseNotifier extends CaseNotifier {
  FakeCaseNotifier(this._model);
  final CaseModel _model;

  @override
  Future<CaseModel> build(String caseId) async => _model;
}
