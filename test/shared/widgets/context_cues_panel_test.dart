// §3.10 (13 July 2026): cueMatchesScope was extracted from
// ContextCuesPanel's private _matchesScope so RepairPeriodScopedCuesScreen
// can compute the Unassigned bucket's cue count *before* the panel builds
// (to decide whether it starts collapsed) without duplicating the matching
// rules — this pins the shared logic itself.
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/surveyor_notes/models/surveyor_note_model.dart';
import 'package:marine_survey_app/shared/widgets/context_cues_panel.dart';

SurveyorNote _note({
  CaseSection section = CaseSection.notAverage,
  String? linkedToType,
  String? linkedToId,
}) {
  final now = DateTime(2026, 7, 13);
  return SurveyorNote(
    id: 'n-${linkedToType ?? 'none'}-${linkedToId ?? 'none'}',
    caseId: 'case-1',
    content: 'A cue',
    caseSection: section,
    linkedToType: linkedToType,
    linkedToId: linkedToId,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('cueMatchesScope', () {
    test('wrong section never matches, regardless of scope', () {
      final n = _note(section: CaseSection.damage);
      expect(
        cueMatchesScope(n, CaseSection.notAverage,
            periodScope: const RepairPeriodScope.unassigned()),
        isFalse,
      );
    });

    test('unassigned bucket matches a cue with no repair_period link', () {
      final n = _note(); // no linkedToType/linkedToId
      expect(
        cueMatchesScope(n, CaseSection.notAverage,
            periodScope: const RepairPeriodScope.unassigned()),
        isTrue,
      );
    });

    test('unassigned bucket matches a cue linked to something else '
        'entirely (e.g. an occurrence)', () {
      final n = _note(linkedToType: 'occurrence', linkedToId: 'occ-1');
      expect(
        cueMatchesScope(n, CaseSection.notAverage,
            periodScope: const RepairPeriodScope.unassigned()),
        isTrue,
      );
    });

    test('unassigned bucket excludes a cue linked to a specific period', () {
      final n = _note(linkedToType: repairPeriodLinkType, linkedToId: 'p-1');
      expect(
        cueMatchesScope(n, CaseSection.notAverage,
            periodScope: const RepairPeriodScope.unassigned()),
        isFalse,
      );
    });

    test('period scope matches only that exact period id', () {
      final matching =
          _note(linkedToType: repairPeriodLinkType, linkedToId: 'p-1');
      final other =
          _note(linkedToType: repairPeriodLinkType, linkedToId: 'p-2');
      const scope = RepairPeriodScope.forPeriod('p-1');
      expect(
          cueMatchesScope(matching, CaseSection.notAverage,
              periodScope: scope),
          isTrue);
      expect(
          cueMatchesScope(other, CaseSection.notAverage, periodScope: scope),
          isFalse);
    });

    test('item scope matches type+id pair exactly', () {
      final n = _note(linkedToType: 'occurrence', linkedToId: 'occ-1');
      expect(
        cueMatchesScope(n, CaseSection.notAverage,
            itemScope: const CueItemScope(
                linkedToType: 'occurrence', linkedToId: 'occ-1')),
        isTrue,
      );
      expect(
        cueMatchesScope(n, CaseSection.notAverage,
            itemScope: const CueItemScope(
                linkedToType: 'occurrence', linkedToId: 'occ-2')),
        isFalse,
      );
    });

    test('no scope at all matches any cue in the section', () {
      final n = _note(linkedToType: 'anything', linkedToId: 'x');
      expect(cueMatchesScope(n, CaseSection.notAverage), isTrue);
    });
  });
}
