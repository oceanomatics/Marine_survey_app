import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/reports/providers/report_provider.dart';
import 'package:marine_survey_app/features/reports/utils/writing_style_lint.dart';

void main() {
  group('lintProhibitedLanguage', () {
    test('flags a prohibited phrase with its rulebook reason', () {
      final flags = lintProhibitedLanguage('The hull was apparently damaged.');
      expect(flags, hasLength(1));
      expect(flags.first.phrase, 'apparently');
      expect(flags.first.reason, contains('Unquantified qualifier'));
    });

    test('is case-insensitive', () {
      final flags = lintProhibitedLanguage('OBVIOUSLY the shaft was bent.');
      expect(flags, hasLength(1));
      expect(flags.first.phrase, 'OBVIOUSLY');
    });

    test('matches whole words only, not substrings', () {
      // "clearly" should not match inside "nuclearly" (contrived but proves
      // the \b word-boundary regex, not a naive .contains()).
      final flags = lintProhibitedLanguage('The reading was nuclearly stable.');
      expect(flags, isEmpty);
    });

    test('deduplicates repeated occurrences of the same phrase', () {
      final flags = lintProhibitedLanguage(
          'Clearly the plate was clearly cracked, clearly beyond repair.');
      expect(flags, hasLength(1));
    });

    test('flags multi-word phrases like "good condition"', () {
      final flags = lintProhibitedLanguage('The engine was in good condition.');
      expect(flags.map((f) => f.phrase), contains('good condition'));
    });

    test('flags first-person phrasing', () {
      final flags = lintProhibitedLanguage('I inspected the tank and I visited the engine room.');
      expect(flags.map((f) => f.phrase), containsAll(['I inspected', 'I visited']));
    });

    test('clean text produces no flags', () {
      expect(lintProhibitedLanguage('The vessel was inspected on 5 July 2026.'), isEmpty);
    });
  });

  group('hasAttributionMarker', () {
    test('true when a recognised attribution phrase is present', () {
      expect(hasAttributionMarker('The Master reportedly heard a loud bang.'), isTrue);
    });

    test('true and case-insensitive', () {
      expect(hasAttributionMarker('ACCORDING TO the Chief Engineer, the pump failed.'), isTrue);
    });

    test('false when no attribution phrase is present', () {
      expect(hasAttributionMarker('The pump failed at 0300 hours.'), isFalse);
    });
  });

  group('lintSection', () {
    test('empty text returns no flags regardless of section type', () {
      expect(lintSection(SectionType.background, ''), isEmpty);
      expect(lintSection(SectionType.background, '   '), isEmpty);
    });

    test('flags missing attribution for attribution-required section types', () {
      final flags = lintSection(SectionType.background, 'The vessel departed port on schedule.');
      expect(flags.any((f) => f.phrase == 'No attribution phrase found'), isTrue);
    });

    test('does not flag missing attribution when a marker is present', () {
      final flags = lintSection(
          SectionType.occurrence, 'It was reported that the anchor dragged.');
      expect(flags.any((f) => f.phrase == 'No attribution phrase found'), isFalse);
    });

    test('does not require attribution for section types outside the required set', () {
      final flags = lintSection(SectionType.repairs, 'The repairs were completed on time.');
      expect(flags, isEmpty);
    });

    test('combines prohibited-language and missing-attribution flags', () {
      final flags = lintSection(SectionType.background, 'The hull was apparently in good condition.');
      expect(flags.length, 3);
      expect(flags.any((f) => f.phrase == 'apparently'), isTrue);
      expect(flags.any((f) => f.phrase == 'good condition'), isTrue);
      expect(flags.any((f) => f.phrase == 'No attribution phrase found'), isTrue);
    });
  });
}
