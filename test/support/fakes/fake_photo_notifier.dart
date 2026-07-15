import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/photos/models/photo_model.dart';
import 'package:marine_survey_app/features/photos/providers/photo_provider.dart';

class FakePhotoNotifier extends PhotoNotifier {
  FakePhotoNotifier(this._photos);
  final List<PhotoModel> _photos;

  @override
  Future<List<PhotoModel>> build(String caseId) async => _photos;

  @override
  Future<void> deletePhoto(String photoId) async {
    final current = state.value ?? [];
    state = AsyncData(current.where((p) => p.id != photoId).toList());
  }

  @override
  Future<int> autoAssignUnassignedPhotos() async => 0;
}
