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

  // Feature 1 (professional title capture): extraction hands the deduced
  // job title/function to StakeholderGroup.fromRole to file the person.
  group('StakeholderGroup.fromRole — professional titles', () {
    test('vessel-crew engineer ranks are owner-side (insured), not contractors',
        () {
      expect(StakeholderGroup.fromRole('Chief Engineer'),
          StakeholderGroup.insured);
      expect(StakeholderGroup.fromRole('Second Engineer'),
          StakeholderGroup.insured);
      expect(StakeholderGroup.fromRole('2nd Engineer'),
          StakeholderGroup.insured);
      expect(StakeholderGroup.fromRole('ETO'), StakeholderGroup.insured);
    });

    test('deck ranks and superintendents are insured', () {
      expect(StakeholderGroup.fromRole('Master'), StakeholderGroup.insured);
      expect(StakeholderGroup.fromRole('Chief Officer'),
          StakeholderGroup.insured);
      expect(StakeholderGroup.fromRole('First Mate'),
          StakeholderGroup.insured);
      expect(StakeholderGroup.fromRole('Superintendent'),
          StakeholderGroup.insured);
      expect(StakeholderGroup.fromRole("Owner's Representative"),
          StakeholderGroup.insured);
    });

    test('outside technical roles still classify as technical contractors', () {
      expect(StakeholderGroup.fromRole('Service Engineer'),
          StakeholderGroup.technicalContractor);
      expect(StakeholderGroup.fromRole('Average Adjuster'),
          StakeholderGroup.technicalContractor);
    });

    test('surveyors, brokers and underwriters classify correctly', () {
      expect(StakeholderGroup.fromRole('Class Surveyor'),
          StakeholderGroup.surveyor);
      expect(StakeholderGroup.fromRole('Broker'), StakeholderGroup.broker);
      expect(StakeholderGroup.fromRole('Underwriter'),
          StakeholderGroup.underwriter);
    });
  });
}
