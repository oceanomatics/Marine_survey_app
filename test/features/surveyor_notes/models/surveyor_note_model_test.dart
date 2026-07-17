// Occurrence Narrative cue forking (docs/occurrence_narrative_spec.md) —
// pins the new OccurrencePhase enum and the SurveyorNote.occurrencePhase
// serialization contract (only emitted for cues that carry a phase, so cues
// without one keep their pre-feature save shape).
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/surveyor_notes/models/surveyor_note_model.dart';

void main() {
  group('OccurrencePhase', () {
    test('round-trips through value', () {
      for (final p in OccurrencePhase.values) {
        expect(OccurrencePhase.fromValue(p.value), p);
      }
    });

    test('fromValue is null for unknown / null', () {
      expect(OccurrencePhase.fromValue(null), isNull);
      expect(OccurrencePhase.fromValue('somewhere_else'), isNull);
    });

    test('ordered is before -> incident -> aftermath', () {
      expect(OccurrencePhase.ordered, [
        OccurrencePhase.before,
        OccurrencePhase.incident,
        OccurrencePhase.aftermath,
      ]);
    });
  });

  group('SurveyorNote occurrence_phase serialization', () {
    SurveyorNote base({OccurrencePhase? phase}) => SurveyorNote(
          id: 'n1',
          caseId: 'c1',
          content: 'A cue',
          caseSection: CaseSection.occurrence,
          occurrencePhase: phase,
          createdAt: DateTime(2026, 7, 17),
          updatedAt: DateTime(2026, 7, 17),
        );

    test('a phased cue writes occurrence_phase and reads it back', () {
      final map = base(phase: OccurrencePhase.incident).toMap();
      expect(map['occurrence_phase'], 'incident');
      expect(SurveyorNote.fromMap(map).occurrencePhase, OccurrencePhase.incident);
    });

    test('an unphased cue omits occurrence_phase entirely', () {
      final map = base().toMap();
      expect(map.containsKey('occurrence_phase'), isFalse);
      expect(SurveyorNote.fromMap(map).occurrencePhase, isNull);
    });

    test('copyWith can set a phase and preserves it otherwise', () {
      final sorted = base().copyWith(occurrencePhase: OccurrencePhase.aftermath);
      expect(sorted.occurrencePhase, OccurrencePhase.aftermath);
      // A copyWith that doesn't mention the phase keeps it.
      expect(sorted.copyWith(content: 'edited').occurrencePhase,
          OccurrencePhase.aftermath);
    });
  });
}
