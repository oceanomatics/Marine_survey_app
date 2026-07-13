import 'package:marine_survey_app/features/documents/providers/document_provider.dart';

class FakeDocumentNotifier extends DocumentNotifier {
  FakeDocumentNotifier(this._docs);
  final List<DocumentModel> _docs;

  @override
  Future<List<DocumentModel>> build(String caseId) async => _docs;
}
