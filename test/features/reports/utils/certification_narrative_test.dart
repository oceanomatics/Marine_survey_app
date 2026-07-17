import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/reports/utils/certification_narrative.dart';

Map<String, dynamic> _cert({required String status, String? name}) =>
    {'cert_name': name, 'status': status};

Map<String, dynamic> _condition({required bool related}) =>
    {'occurrence_related': related};

void main() {
  group('composeStatutoryCertificatesNarrative', () {
    test('empty list returns empty string', () {
      expect(composeStatutoryCertificatesNarrative(const []), isEmpty);
    });

    test('all valid — single clean sentence', () {
      final text = composeStatutoryCertificatesNarrative([
        _cert(status: 'valid', name: 'Load Line Certificate'),
        _cert(status: 'valid', name: 'Safety Equipment Certificate'),
      ]);
      expect(text,
          'All statutory certificates were found to be current and valid at the time of the casualty.');
    });

    test('single expired certificate uses singular grammar', () {
      final text = composeStatutoryCertificatesNarrative([
        _cert(status: 'expired', name: 'Load Line Certificate'),
      ]);
      expect(
          text,
          'The following statutory certificate was noted as expired at the '
          'time of the casualty: Load Line Certificate.');
    });

    test('multiple expired certificates uses plural grammar and joins names', () {
      final text = composeStatutoryCertificatesNarrative([
        _cert(status: 'expired', name: 'Load Line Certificate'),
        _cert(status: 'expired', name: 'Safety Equipment Certificate'),
      ]);
      expect(
          text,
          'The following statutory certificates were noted as expired at the '
          'time of the casualty: Load Line Certificate, Safety Equipment '
          'Certificate.');
    });

    test('not sighted', () {
      final text = composeStatutoryCertificatesNarrative([
        _cert(status: 'not_sighted', name: 'DOC'),
      ]);
      expect(
          text,
          'Copies of the following statutory certificate was not made '
          'available to the Undersigned for review: DOC.');
    });

    test(
        'mix of suspended + otherwise-valid certs is fully narrated — the gap '
        'the old mutually-exclusive 3-way pick silently dropped', () {
      final text = composeStatutoryCertificatesNarrative([
        _cert(status: 'suspended', name: 'ISM DOC'),
        _cert(status: 'valid', name: 'Load Line Certificate'),
      ]);
      expect(
          text,
          'The following statutory certificate was noted as suspended: ISM '
          'DOC. The remaining statutory certificate — Load Line Certificate '
          '— was confirmed current and valid.');
    });

    test('every bucket populated composes all five sentences in order', () {
      final text = composeStatutoryCertificatesNarrative([
        _cert(status: 'not_sighted', name: 'A'),
        _cert(status: 'expired', name: 'B'),
        _cert(status: 'suspended', name: 'C'),
        _cert(status: 'tbc', name: 'D'),
        _cert(status: 'valid', name: 'E'),
      ]);
      expect(text, contains('not made available to the Undersigned'));
      expect(text, contains('noted as expired'));
      expect(text, contains('noted as suspended'));
      expect(text, contains('had not been confirmed at the time of writing'));
      expect(text, contains('confirmed current and valid'));
      // Order: not sighted, expired, suspended, tbc, valid.
      expect(
          text.indexOf('not made available') <
              text.indexOf('noted as expired') &&
          text.indexOf('noted as expired') < text.indexOf('noted as suspended') &&
          text.indexOf('noted as suspended') <
              text.indexOf('had not been confirmed') &&
          text.indexOf('had not been confirmed') <
              text.indexOf('confirmed current and valid'),
          isTrue);
    });

    test('falls back to cert_type when cert_name is missing', () {
      final text = composeStatutoryCertificatesNarrative([
        {'cert_type': 'doc', 'status': 'expired'},
      ]);
      expect(text, contains('doc'));
    });
  });

  group('composeConditionOfClassNarrative', () {
    test('no conditions', () {
      expect(
          composeConditionOfClassNarrative(const []),
          'No condition of class has been issued against the vessel at the '
          'time of this survey.');
    });

    test('single condition, related to the casualty', () {
      final text =
          composeConditionOfClassNarrative([_condition(related: true)]);
      expect(
          text,
          '1 condition of class has been issued against the vessel, which is '
          'considered related to the casualty under review. Details are set '
          'out below.');
    });

    test('single condition, not related', () {
      final text =
          composeConditionOfClassNarrative([_condition(related: false)]);
      expect(
          text,
          '1 condition of class has been issued against the vessel, which is '
          'not considered related to the casualty under review. Details are '
          'set out below.');
    });

    test('multiple conditions, all related', () {
      final text = composeConditionOfClassNarrative(
          [_condition(related: true), _condition(related: true)]);
      expect(
          text,
          '2 conditions of class have been issued against the vessel, all of '
          'which are considered related to the casualty under review. '
          'Details are set out below.');
    });

    test('multiple conditions, none related', () {
      final text = composeConditionOfClassNarrative(
          [_condition(related: false), _condition(related: false)]);
      expect(
          text,
          '2 conditions of class have been issued against the vessel, none '
          'of which are considered related to the casualty under review. '
          'Details are set out below.');
    });

    test('multiple conditions, some related — the case the old 3-way pick '
        'could not represent at all', () {
      final text = composeConditionOfClassNarrative([
        _condition(related: true),
        _condition(related: false),
        _condition(related: false),
      ]);
      expect(
          text,
          '3 conditions of class have been issued against the vessel, of '
          'which 1 is considered related to the casualty under review and 2 '
          'are not. Details are set out below.');
    });
  });

  group('composeDetentionsNarrative', () {
    test('empty list states no detention recorded', () {
      expect(composeDetentionsNarrative(const []),
          'No Port State Control detention has been recorded against the '
          'subject vessel.');
    });

    test('single released detention', () {
      final text = composeDetentionsNarrative([
        {'resolved': true},
      ]);
      expect(
          text,
          'One Port State Control detention has been recorded against the '
          'subject vessel, since released. Details are set out below.');
    });

    test('single outstanding detention', () {
      final text = composeDetentionsNarrative([
        {'resolved': false},
      ]);
      expect(
          text,
          'One Port State Control detention has been recorded against the '
          'subject vessel, not yet recorded as released. Details are set '
          'out below.');
    });

    test('multiple detentions, some still outstanding', () {
      final text = composeDetentionsNarrative([
        {'resolved': true},
        {'resolved': false},
        {'resolved': false},
      ]);
      expect(
          text,
          '3 Port State Control detentions have been recorded against the '
          'subject vessel, of which 2 remain not yet recorded as released. '
          'Details are set out below.');
    });

    test('all detentions released', () {
      final text = composeDetentionsNarrative([
        {'resolved': true},
        {'resolved': true},
      ]);
      expect(
          text,
          '2 Port State Control detentions have been recorded against the '
          'subject vessel, all of which have been released. Details are set '
          'out below.');
    });
  });

  group('composeIsmStatusNarrative', () {
    test('compliant', () {
      expect(composeIsmStatusNarrative('compliant'), contains('hold valid ISM'));
    });
    test('non_compliant', () {
      expect(composeIsmStatusNarrative('non_compliant'),
          contains('not to have been in compliance with the ISM Code'));
    });
    test('tbc and null both report not confirmed', () {
      const expected =
          'The ISM compliance status of the subject vessel had not been '
          'confirmed at the time of this report.';
      expect(composeIsmStatusNarrative('tbc'), expected);
      expect(composeIsmStatusNarrative(null), expected);
    });
  });

  group('composeIspsStatusNarrative', () {
    test('compliant', () {
      expect(composeIspsStatusNarrative('compliant'),
          contains('International Ship Security Certificate'));
    });
    test('non_compliant', () {
      expect(composeIspsStatusNarrative('non_compliant'),
          contains('not to have been in compliance with the ISPS Code'));
    });
    test('null reports not confirmed', () {
      expect(composeIspsStatusNarrative(null),
          'The ISPS compliance status of the subject vessel had not been '
          'confirmed at the time of this report.');
    });
  });
}
