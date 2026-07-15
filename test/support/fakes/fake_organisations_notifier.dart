// Widget-test double for OrganisationsNotifier — skips SupabaseService.client
// entirely. Mirrors the pattern in fake_account_notifier.dart etc.
import 'package:marine_survey_app/features/settings/models/organisation_model.dart';
import 'package:marine_survey_app/features/settings/providers/organisations_provider.dart';

class FakeOrganisationsNotifier extends OrganisationsNotifier {
  FakeOrganisationsNotifier([this._seed = const []]);
  final List<OrganisationModel> _seed;

  @override
  Future<List<OrganisationModel>> build() async => _seed;
}
