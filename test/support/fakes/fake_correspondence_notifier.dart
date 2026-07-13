import 'package:marine_survey_app/features/correspondence/models/correspondence_model.dart';
import 'package:marine_survey_app/features/correspondence/providers/correspondence_provider.dart';

/// Widget-test double — just returns [seed], skipping the real notifier's
/// offline-cache/Drive-upload/connectivity-retry machinery entirely.
class FakeCorrespondenceNotifier extends CorrespondenceNotifier {
  FakeCorrespondenceNotifier([this._seed = const []]);
  final List<CorrespondenceModel> _seed;

  @override
  Future<List<CorrespondenceModel>> build(String caseId) async => _seed;
}
