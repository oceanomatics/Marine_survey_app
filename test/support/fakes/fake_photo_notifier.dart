import 'package:marine_survey_app/features/photos/models/photo_model.dart';
import 'package:marine_survey_app/features/photos/providers/photo_provider.dart';

class FakePhotoNotifier extends PhotoNotifier {
  FakePhotoNotifier(this._photos);
  final List<PhotoModel> _photos;

  @override
  Future<List<PhotoModel>> build(String caseId) async => _photos;
}
