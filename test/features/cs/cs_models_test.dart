import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/cs/models/cs_models.dart';

void main() {
  group('deriveSectionRating (PLC rollup)', () {
    test('no gradable items → GOOD', () {
      expect(deriveSectionRating([]), CsSectionRating.good);
      expect(deriveSectionRating([null, CsGrade.na]), CsSectionRating.good);
    });

    test('all satisfactory/good → GOOD', () {
      expect(
        deriveSectionRating([CsGrade.satisfactory, CsGrade.good, CsGrade.satisfactory]),
        CsSectionRating.good,
      );
    });

    test('a minority unsatisfactory → SATISFACTORY_WITH_ISSUES', () {
      // 1 of 5 failing
      expect(
        deriveSectionRating([
          CsGrade.unsatisfactory,
          CsGrade.satisfactory,
          CsGrade.satisfactory,
          CsGrade.satisfactory,
          CsGrade.good,
        ]),
        CsSectionRating.satisfactoryWithIssues,
      );
    });

    test('half-or-more unsatisfactory → UNSATISFACTORY', () {
      // 2 of 4 failing (exactly half)
      expect(
        deriveSectionRating([
          CsGrade.unsatisfactory,
          CsGrade.unsatisfactory,
          CsGrade.satisfactory,
          CsGrade.good,
        ]),
        CsSectionRating.unsatisfactory,
      );
      // 3 of 4 failing
      expect(
        deriveSectionRating([
          CsGrade.unsatisfactory,
          CsGrade.unsatisfactory,
          CsGrade.unsatisfactory,
          CsGrade.satisfactory,
        ]),
        CsSectionRating.unsatisfactory,
      );
    });

    test('N/A items are ignored in the tally', () {
      // 1 unsatisfactory + 1 satisfactory among gradable (na dropped) → half → UNSATISFACTORY
      expect(
        deriveSectionRating([
          CsGrade.unsatisfactory,
          CsGrade.satisfactory,
          CsGrade.na,
          CsGrade.na,
        ]),
        CsSectionRating.unsatisfactory,
      );
    });
  });

  group('enum round-trips', () {
    test('CsGrade.fromValue', () {
      expect(CsGrade.fromValue('UNSATISFACTORY'), CsGrade.unsatisfactory);
      expect(CsGrade.fromValue('N_A'), CsGrade.na);
      expect(CsGrade.fromValue(null), isNull);
      expect(CsGrade.fromValue('bogus'), isNull);
    });

    test('CsSectionRating.fromValue', () {
      expect(CsSectionRating.fromValue('SATISFACTORY_WITH_ISSUES'),
          CsSectionRating.satisfactoryWithIssues);
      expect(CsSectionRating.fromValue(null), isNull);
    });

    test('CsRecommendationStatus.fromValue defaults to open', () {
      expect(CsRecommendationStatus.fromValue('closed'),
          CsRecommendationStatus.closed);
      expect(CsRecommendationStatus.fromValue(null),
          CsRecommendationStatus.open);
    });
  });

  group('model fromJson', () {
    test('CsInspectionItemModel parses grade + is_na', () {
      final m = CsInspectionItemModel.fromJson({
        'id': 'i1',
        'case_id': 'c1',
        'grade': 'GOOD',
        'is_na': false,
        'sort_order': 3,
      });
      expect(m.grade, CsGrade.good);
      expect(m.isNa, false);
      expect(m.sortOrder, 3);
    });
  });
}
