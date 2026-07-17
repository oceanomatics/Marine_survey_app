import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/reports/utils/waiver_narrative.dart';

void main() {
  group('composeWaiverNarrative', () {
    test('base clause only when no ticks are set', () {
      final text = composeWaiverNarrative(
          const WaiverInputs(baseText: 'Base limitation clause.'));
      expect(text, 'Base limitation clause.');
    });

    test('no formal allegation appends the built-in without-prejudice line', () {
      final text = composeWaiverNarrative(const WaiverInputs(
        baseText: 'Base.',
        noFormalAllegation: true,
      ));
      expect(text, contains('Without Prejudice to Underwriters\' liability'));
      expect(text.split('\n\n').first, 'Base.');
    });

    test('no formal allegation prefers the supplied clause_library E-2 text', () {
      final text = composeWaiverNarrative(const WaiverInputs(
        baseText: 'Base.',
        noFormalAllegation: true,
        withoutPrejudiceClause: 'Verbatim E-2 clause text.',
      ));
      expect(text, contains('Verbatim E-2 clause text.'));
      expect(text, isNot(contains('Accordingly, the damage now found')));
    });

    test('preliminary report adds the supplement-and-amend sentence', () {
      final text = composeWaiverNarrative(const WaiverInputs(
        baseText: 'Base.',
        isPreliminary: true,
      ));
      expect(text, contains('issued on a preliminary basis'));
    });

    test('certs not sighted adds the certificate limitation sentence', () {
      final text = composeWaiverNarrative(const WaiverInputs(
        baseText: 'Base.',
        certificatesNotSighted: true,
      ));
      expect(text, contains('statutory certificates were not made available'));
    });

    test('all ticks compose in a fixed order, joined by blank lines', () {
      final text = composeWaiverNarrative(const WaiverInputs(
        baseText: 'Base.',
        noFormalAllegation: true,
        isPreliminary: true,
        certificatesNotSighted: true,
        costsSubjectToAdjustment: true,
      ));
      final parts = text.split('\n\n');
      expect(parts.length, 5);
      expect(parts[0], 'Base.');
      expect(parts[1], contains('Without Prejudice'));
      expect(parts[2], contains('preliminary basis'));
      expect(parts[3], contains('certificates were not made available'));
      expect(parts[4], contains('subject to'));
    });

    test('empty base text is dropped rather than producing a leading blank', () {
      final text = composeWaiverNarrative(const WaiverInputs(
        baseText: '   ',
        isPreliminary: true,
      ));
      expect(text.startsWith('This report is issued'), isTrue);
    });
  });
}
