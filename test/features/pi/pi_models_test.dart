import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/pi/models/pi_models.dart';

void main() {
  group('PiOpinionModel', () {
    test('fromJson parses qualifiers + source_refs', () {
      final m = PiOpinionModel.fromJson(const {
        'id': 'o1',
        'case_id': 'c1',
        'opinion_text': 'The failure was pre-existing.',
        'heading': 'Root cause',
        'basis': 'Assumes the log is accurate.',
        'outside_expertise': false,
        'not_concluded': true,
        'source_refs': ['d1', 'd2'],
        'sort_order': 2,
      });
      expect(m.opinionText, 'The failure was pre-existing.');
      expect(m.heading, 'Root cause');
      expect(m.notConcluded, true);
      expect(m.outsideExpertise, false);
      expect(m.sourceRefs, ['d1', 'd2']);
      expect(m.sortOrder, 2);
    });

    test('hasQualifier reflects any qualifier being set', () {
      const base = PiOpinionModel(id: 'o', caseId: 'c', opinionText: 'x');
      expect(base.hasQualifier, false);
      expect(base.copyWith(notConcluded: true).hasQualifier, true);
      expect(base.copyWith(outsideExpertise: true).hasQualifier, true);
      expect(base.copyWith(qualifierNote: 'limited scope').hasQualifier, true);
      expect(base.copyWith(qualifierNote: '   ').hasQualifier, false);
    });

    test('copyWith preserves identity fields', () {
      const base = PiOpinionModel(
          id: 'o', caseId: 'c', opinionText: 'x', sortOrder: 5);
      final edited = base.copyWith(opinionText: 'y');
      expect(edited.id, 'o');
      expect(edited.caseId, 'c');
      expect(edited.sortOrder, 5);
      expect(edited.opinionText, 'y');
    });
  });
}
