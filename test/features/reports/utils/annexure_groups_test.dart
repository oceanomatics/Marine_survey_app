import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/reports/utils/annexure_groups.dart';

void main() {
  group('buildAnnexureGroups', () {
    test('groups documents by annexure_assignment letter', () {
      final docs = [
        {'annexure_assignment': 'B', 'title': 'Doc 1'},
        {'annexure_assignment': 'A', 'title': 'Doc 2'},
        {'annexure_assignment': 'A', 'title': 'Doc 3'},
      ];
      final groups = buildAnnexureGroups(docs);
      expect(groups.map((e) => e.key), ['A', 'B']);
      expect(groups.first.value.length, 2);
      expect(groups.last.value.length, 1);
    });

    test('sorts letters A to Z regardless of input order', () {
      final docs = [
        {'annexure_assignment': 'D'},
        {'annexure_assignment': 'A'},
        {'annexure_assignment': 'C'},
      ];
      final groups = buildAnnexureGroups(docs);
      expect(groups.map((e) => e.key), ['A', 'C', 'D']);
    });

    test('excludes documents with a null or empty annexure_assignment', () {
      final docs = [
        {'annexure_assignment': null},
        {'annexure_assignment': ''},
        {'annexure_assignment': 'A'},
      ];
      final groups = buildAnnexureGroups(docs);
      expect(groups.map((e) => e.key), ['A']);
    });

    test('excludes letter I, reserved for the AI Generation Record', () {
      final docs = [
        {'annexure_assignment': 'I'},
        {'annexure_assignment': 'H'},
      ];
      final groups = buildAnnexureGroups(docs);
      expect(groups.map((e) => e.key), ['H']);
    });

    test('normalises letter case and surrounding whitespace', () {
      final docs = [
        {'annexure_assignment': ' a '},
        {'annexure_assignment': 'A'},
      ];
      final groups = buildAnnexureGroups(docs);
      expect(groups.length, 1);
      expect(groups.first.key, 'A');
      expect(groups.first.value.length, 2);
    });

    test('empty input returns empty output', () {
      expect(buildAnnexureGroups(const []), isEmpty);
    });
  });
}
