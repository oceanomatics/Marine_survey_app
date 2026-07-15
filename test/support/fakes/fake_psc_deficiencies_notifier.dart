// Widget-test double for PscDeficienciesNotifier — skips SupabaseService.client.
import 'package:marine_survey_app/features/vessel/models/psc_deficiency_model.dart';
import 'package:marine_survey_app/features/vessel/providers/psc_deficiencies_provider.dart';

class FakePscDeficienciesNotifier extends PscDeficienciesNotifier {
  FakePscDeficienciesNotifier([this._seed = const []]);
  final List<PscDeficiencyModel> _seed;

  @override
  Future<List<PscDeficiencyModel>> build(String vesselId) async => _seed;
}
