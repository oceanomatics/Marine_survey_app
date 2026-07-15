// test/features/timeline/models/timeline_aggregation_test.dart
//
// Pure-logic tests for the Full Event Log aggregation and the single
// chronology-inclusion rule (TODO.md §3.16). No Flutter/Riverpod harness.

import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/attendances/models/attendance_model.dart';
import 'package:marine_survey_app/features/survey/providers/damage_provider.dart';
import 'package:marine_survey_app/features/timeline/models/timeline_aggregation.dart';
import 'package:marine_survey_app/features/timeline/models/timeline_entry.dart';
import 'package:marine_survey_app/features/timeline/models/timeline_event_model.dart';
import 'package:marine_survey_app/features/timeline/models/timeline_event_rating.dart';

TimelineEventRating _rating(
  String key, {
  EventRelevance relevance = EventRelevance.normal,
  bool included = false,
  bool pending = false,
}) =>
    TimelineEventRating(
      id: 'r-$key',
      caseId: 'c1',
      eventKey: key,
      relevance: relevance,
      includedInChronology: included,
      pendingReview: pending,
    );

DamageState _damage({
  List<OccurrenceModel> occ = const [],
  List<RepairModel> rep = const [],
}) =>
    DamageState(occurrences: occ, damageItems: const [], repairs: rep);

void main() {
  group('aggregateTimelineEntries', () {
    test('merges all sources, sorts by date, undated last, keys correctly', () {
      final entries = aggregateTimelineEntries(
        manualEvents: [
          TimelineEventModel(
            eventId: 'm1',
            caseId: 'c1',
            eventType: TimelineEventType.drydockEntry,
            eventDate: DateTime(2026, 3, 5),
            title: 'Drydock entry',
          ),
          const TimelineEventModel(
            eventId: 'm2',
            caseId: 'c1',
            eventType: TimelineEventType.custom,
            title: 'No date event',
          ),
        ],
        attendances: [
          SurveyAttendanceModel(
            attendanceId: 'a1',
            caseId: 'c1',
            attendanceType: AttendanceType.initial,
            attendanceDate: DateTime(2026, 2, 1),
            location: 'Singapore',
          ),
        ],
        damage: _damage(
          occ: [
            OccurrenceModel(
              occurrenceId: 'o1',
              caseId: 'c1',
              occurrenceNo: 1,
              dateTime: DateTime(2026, 1, 10),
              title: 'Grounding',
              briefDescription: 'Vessel grounded',
            ),
          ],
          rep: [
            RepairModel(
              repairId: 'rp1',
              occurrenceId: 'o1',
              caseId: 'c1',
              repairType: RepairType.permanent,
              repairStatus: RepairStatus.completed,
              completionDate: DateTime(2026, 4, 20),
            ),
            // Incomplete repair (no completion date) is excluded.
            const RepairModel(
              repairId: 'rp2',
              occurrenceId: 'o1',
              caseId: 'c1',
              repairType: RepairType.temporary,
              repairStatus: RepairStatus.inProgress,
            ),
          ],
        ),
      );

      expect(entries.map((e) => e.eventKey), [
        'occurrence:o1', // 10 Jan
        'attendance:a1', // 1 Feb
        'manual:m1', // 5 Mar
        'repair:rp1', // 20 Apr
        'manual:m2', // undated → last
      ]);
    });

    test('joins ratings and promoted flag by event key', () {
      final entries = aggregateTimelineEntries(
        manualEvents: const [],
        damage: _damage(occ: [
          OccurrenceModel(
            occurrenceId: 'o1',
            caseId: 'c1',
            occurrenceNo: 1,
            dateTime: DateTime(2026, 1, 1),
            title: 'Fire',
          ),
        ]),
        ratingsByKey: {
          'occurrence:o1':
              _rating('occurrence:o1', relevance: EventRelevance.important),
        },
        promotedSourceKeys: {'occurrence:o1'},
      );

      final e = entries.single;
      expect(e.relevance, EventRelevance.important);
      expect(e.promoted, isTrue);
      expect(e.includedInChronology, isTrue); // promoted ⇒ in chronology
    });
  });

  group('chronologyIncludeForRating', () {
    test('manual defaults to included, aggregated defaults to excluded', () {
      expect(
        chronologyIncludeForRating(
            sourceType: TimelineSourceType.manual, rating: null),
        isTrue,
      );
      expect(
        chronologyIncludeForRating(
            sourceType: TimelineSourceType.occurrence, rating: null),
        isFalse,
      );
    });

    test('ignore always excludes, even when explicitly included', () {
      expect(
        chronologyIncludeForRating(
          sourceType: TimelineSourceType.manual,
          rating: _rating('manual:m1',
              relevance: EventRelevance.ignore, included: true),
        ),
        isFalse,
      );
    });

    // 14 July 2026 walkthrough simplification: rating *is* the chronology-
    // inclusion mechanism now — Important includes, Ignore excludes,
    // Normal doesn't (except manual events, which default included). The
    // standalone `includedInChronology`/`promoted` flags no longer
    // independently drive inclusion (the underlying `timeline_events` row
    // for an aggregated Important entry is now created/removed
    // automatically to follow the relevance decision instead — see
    // TimelineScreen._rate — so `promoted` here is just a mirror of that,
    // not an alternate inclusion path).
    test('important relevance on an aggregated event includes it', () {
      expect(
        chronologyIncludeForRating(
          sourceType: TimelineSourceType.attendance,
          rating: _rating('attendance:a1', relevance: EventRelevance.important),
        ),
        isTrue,
      );
    });

    test('normal relevance on an aggregated event does not include it', () {
      expect(
        chronologyIncludeForRating(
          sourceType: TimelineSourceType.repair,
          rating: _rating('repair:rp1', relevance: EventRelevance.normal),
        ),
        isFalse,
      );
    });

    test('ignore relevance on a manual event removes it from chronology', () {
      expect(
        chronologyIncludeForRating(
          sourceType: TimelineSourceType.manual,
          rating: _rating('manual:m1', relevance: EventRelevance.ignore),
        ),
        isFalse,
      );
    });

    test('normal relevance on a manual event still defaults to included', () {
      expect(
        chronologyIncludeForRating(
          sourceType: TimelineSourceType.manual,
          rating: _rating('manual:m1', relevance: EventRelevance.normal),
        ),
        isTrue,
      );
    });
  });

  group('TimelineEntry derived getters', () {
    test('chronologyText prefers description, falls back to title', () {
      const withDesc = TimelineEntry(
        sourceType: TimelineSourceType.manual,
        sourceId: 'm1',
        title: 'Title',
        description: 'A full description',
      );
      const noDesc = TimelineEntry(
        sourceType: TimelineSourceType.manual,
        sourceId: 'm2',
        title: 'Just a title',
      );
      expect(withDesc.chronologyText, 'A full description');
      expect(noDesc.chronologyText, 'Just a title');
    });

    test('pendingReview and aiReason flow from the rating', () {
      final e = const TimelineEntry(
        sourceType: TimelineSourceType.occurrence,
        sourceId: 'o1',
        title: 'x',
      ).copyWith(
        rating: _rating('occurrence:o1', pending: true)
            .copyWith(aiReason: 'pivotal casualty'),
      );
      expect(e.pendingReview, isTrue);
      expect(e.aiReason, 'pivotal casualty');
    });
  });
}
