import 'package:marine_survey_app/features/accounts/models/accounts_models.dart';
import 'package:marine_survey_app/features/accounts/providers/accounts_provider.dart';

class FakeRepairDocumentsNotifier extends RepairDocumentsNotifier {
  FakeRepairDocumentsNotifier(this._docs);
  final List<RepairDocumentModel> _docs;

  @override
  Future<List<RepairDocumentModel>> build(String caseId) async => _docs;
}
