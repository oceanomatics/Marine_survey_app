import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/parties/models/party_model.dart';

AssuredContactModel _contact({
  String? company,
  String? roleTitle,
  StakeholderGroup? group,
}) =>
    AssuredContactModel(
      contactId: 'c1',
      caseId: 'case1',
      fullName: 'Jane Doe',
      company: company,
      roleTitle: roleTitle,
      stakeholderGroup: group,
    );

void main() {
  group('displayCompany', () {
    test('returns the trimmed company', () {
      expect(_contact(company: '  Neptune Shipping  ').displayCompany,
          'Neptune Shipping');
    });

    test('returns null for a null company', () {
      expect(_contact(company: null).displayCompany, isNull);
    });

    test('returns null for an empty / whitespace company '
        '(so it renders consistently, not as a blank line)', () {
      expect(_contact(company: '').displayCompany, isNull);
      expect(_contact(company: '   ').displayCompany, isNull);
    });
  });

  group('roleRestatesGroup', () {
    test('true when an "Assured" role sits under the Insured group', () {
      expect(
        _contact(roleTitle: 'Assured', group: StakeholderGroup.insured)
            .roleRestatesGroup,
        isTrue,
      );
    });

    test('true when the role equals the group label (case-insensitive)', () {
      expect(
        _contact(roleTitle: 'underwriter', group: StakeholderGroup.underwriter)
            .roleRestatesGroup,
        isTrue,
      );
    });

    test('false for a distinct, informative role in the Insured group', () {
      expect(
        _contact(roleTitle: 'Master', group: StakeholderGroup.insured)
            .roleRestatesGroup,
        isFalse,
      );
    });

    test('false when no role or no group', () {
      expect(_contact(roleTitle: null, group: StakeholderGroup.insured)
          .roleRestatesGroup, isFalse);
      expect(_contact(roleTitle: 'Assured', group: null).roleRestatesGroup,
          isFalse);
    });
  });
}
