import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/cases/utils/case_title.dart';

void main() {
  group('buildCaseTitle', () {
    test('joins all four components with en-dash', () {
      expect(
        buildCaseTitle(
          jobNo: 'ABL-1001',
          vesselName: 'MV Neptune',
          caseTypeLabel: 'Damage Survey',
          occurrenceTitle: 'Grounding off Fremantle',
        ),
        'ABL-1001 – MV Neptune – Damage Survey – Grounding off Fremantle',
      );
    });

    test('re-appends occurrence brief when the vessel name is re-cased '
        '(regression: brief must NOT be dropped on a component change)', () {
      // Original title built with lowercase vessel name…
      final before = buildCaseTitle(
        jobNo: 'ABL-1001',
        vesselName: 'mv neptune',
        caseTypeLabel: 'Damage Survey',
        occurrenceTitle: 'Grounding off Fremantle',
      );
      // …then the surveyor re-cases the vessel name and the title rebuilds.
      final after = buildCaseTitle(
        jobNo: 'ABL-1001',
        vesselName: 'MV Neptune',
        caseTypeLabel: 'Damage Survey',
        occurrenceTitle: 'Grounding off Fremantle',
      );

      expect(before.endsWith('Grounding off Fremantle'), isTrue);
      expect(after.endsWith('Grounding off Fremantle'), isTrue,
          reason: 'occurrence brief must survive a vessel-name edit');
      expect(after, 'ABL-1001 – MV Neptune – Damage Survey – Grounding off Fremantle');
    });

    test('omits blank / whitespace-only components', () {
      expect(
        buildCaseTitle(
          jobNo: '',
          vesselName: 'MV Neptune',
          caseTypeLabel: '   ',
          occurrenceTitle: 'Fire in engine room',
        ),
        'MV Neptune – Fire in engine room',
      );
    });

    test('trims each component', () {
      expect(
        buildCaseTitle(
          jobNo: '  ABL-1001  ',
          vesselName: ' MV Neptune ',
          caseTypeLabel: 'Damage Survey',
          occurrenceTitle: ' Collision ',
        ),
        'ABL-1001 – MV Neptune – Damage Survey – Collision',
      );
    });

    test('returns empty string when every component is blank', () {
      expect(buildCaseTitle(), '');
    });

    test('handles a missing occurrence brief gracefully', () {
      expect(
        buildCaseTitle(
          jobNo: 'ABL-1001',
          vesselName: 'MV Neptune',
          caseTypeLabel: 'Condition Survey',
        ),
        'ABL-1001 – MV Neptune – Condition Survey',
      );
    });
  });
}
