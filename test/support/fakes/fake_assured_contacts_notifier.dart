import 'package:marine_survey_app/features/parties/models/party_model.dart';
import 'package:marine_survey_app/features/parties/providers/parties_provider.dart';

// AddAttendeeSheet's _PartyPickerRow (docs/TODO.md §3.13 row 48, Parties
// cross-link) watches assuredContactsProvider to offer "pick an existing
// Parties contact" — needed by any test that pumps AddAttendeeSheet, not
// just Parties-feature tests themselves.
class FakeAssuredContactsNotifier extends AssuredContactsNotifier {
  FakeAssuredContactsNotifier([this._seed = const []]);
  final List<AssuredContactModel> _seed;

  @override
  Future<List<AssuredContactModel>> build(String caseId) async => _seed;
}
