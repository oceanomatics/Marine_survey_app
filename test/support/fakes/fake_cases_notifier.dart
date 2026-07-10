import 'package:marine_survey_app/features/cases/models/case_model.dart';
import 'package:marine_survey_app/features/cases/providers/cases_provider.dart';

/// Overrides the case-list provider with a fixed set of cases for widget
/// tests (e.g. the Inbox triage case picker).
class FakeCasesNotifier extends CasesNotifier {
  FakeCasesNotifier(this._cases);
  final List<CaseModel> _cases;

  @override
  Future<List<CaseModel>> build() async => _cases;
}
