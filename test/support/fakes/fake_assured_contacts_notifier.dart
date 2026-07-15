import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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

  @override
  Future<void> add({
    required String caseId,
    required String fullName,
    String? company,
    String? roleTitle,
    StakeholderGroup? stakeholderGroup,
    String? phone,
    String? email,
    String? notes,
  }) async {
    final current = state.value ?? [];
    final created = AssuredContactModel(
      contactId: const Uuid().v4(),
      caseId: caseId,
      fullName: fullName,
      company: company,
      roleTitle: roleTitle,
      stakeholderGroup: stakeholderGroup,
      phone: phone,
      email: email,
      notes: notes,
    );
    state = AsyncData([...current, created]);
  }

  @override
  Future<void> editContact(AssuredContactModel contact) async {
    final current = state.value ?? [];
    state = AsyncData(current
        .map((c) => c.contactId == contact.contactId ? contact : c)
        .toList());
  }

  @override
  Future<void> delete(String contactId) async {
    final current = state.value ?? [];
    state =
        AsyncData(current.where((c) => c.contactId != contactId).toList());
  }
}
