// Widget tests for the Full Event Log rework (TODO.md §3.16): the three tabs,
// the aggregated log, chronology promotion, and the ignore ⇄ restore round-trip.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/attendances/models/attendance_model.dart';
import 'package:marine_survey_app/features/attendances/providers/attendances_provider.dart';
import 'package:marine_survey_app/features/correspondence/providers/correspondence_provider.dart';
import 'package:marine_survey_app/features/documents/providers/document_provider.dart';
import 'package:marine_survey_app/features/reports/providers/report_provider.dart';
import 'package:marine_survey_app/features/survey/providers/damage_provider.dart';
import 'package:marine_survey_app/features/surveyor_notes/providers/surveyor_notes_provider.dart';
import 'package:marine_survey_app/features/timeline/models/timeline_event_model.dart';
import 'package:marine_survey_app/features/timeline/providers/timeline_provider.dart';
import 'package:marine_survey_app/features/timeline/providers/timeline_ratings_provider.dart';
import 'package:marine_survey_app/features/timeline/screens/timeline_screen.dart';

import '../../../support/fakes/fake_timeline_notifier.dart';
import '../../../support/fakes/fake_timeline_deps.dart';
import '../../../support/fakes/fake_correspondence_notifier.dart';
import '../../../support/fakes/fake_document_notifier.dart';
import '../../../support/fakes/fake_report_outputs_notifier.dart';

const _caseId = 'case-1';

DamageState _damage({List<OccurrenceModel> occ = const []}) =>
    DamageState(occurrences: occ, damageItems: const []);

OccurrenceModel _occ(String id, String title, DateTime when) => OccurrenceModel(
      occurrenceId: id,
      caseId: _caseId,
      occurrenceNo: 1,
      dateTime: when,
      title: title,
      briefDescription: 'brief for $title',
    );

TimelineEventModel _manual(String id, String title, DateTime when) =>
    TimelineEventModel(
      eventId: id,
      caseId: _caseId,
      eventType: TimelineEventType.drydockEntry,
      eventDate: when,
      title: title,
    );

Future<void> _pump(
  WidgetTester tester, {
  List<TimelineEventModel> manual = const [],
  List<SurveyAttendanceModel> attendances = const [],
  DamageState? damage,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        timelineProvider.overrideWith(() => FakeTimelineNotifier(manual)),
        timelineRatingsProvider
            .overrideWith(() => FakeTimelineRatingsNotifier()),
        attendancesProvider
            .overrideWith(() => FakeAttendancesNotifier(attendances)),
        damageProvider
            .overrideWith(() => FakeDamageNotifier(damage ?? _damage())),
        surveyorNotesProvider
            .overrideWith(() => FakeSurveyorNotesNotifier()),
        correspondenceProvider
            .overrideWith(() => FakeCorrespondenceNotifier()),
        documentProvider.overrideWith(() => FakeDocumentNotifier(const [])),
        reportOutputsProvider
            .overrideWith(() => FakeReportOutputsNotifier(const [])),
      ],
      child: const MaterialApp(home: TimelineScreen(caseId: _caseId)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('TimelineScreen §3.16', () {
    testWidgets('renders Timeline / Full Log / Ignored tabs', (tester) async {
      await _pump(tester, manual: [_manual('m1', 'Drydock entry', DateTime(2026, 3, 1))]);
      expect(find.text('Timeline'), findsWidgets);
      expect(find.textContaining('Full Log'), findsWidgets);
      expect(find.textContaining('Ignored'), findsWidgets);
    });

    testWidgets('Full Log aggregates occurrences, attendances and manual events',
        (tester) async {
      await _pump(
        tester,
        manual: [_manual('m1', 'Drydock entry', DateTime(2026, 3, 1))],
        attendances: [
          SurveyAttendanceModel(
            attendanceId: 'a1',
            caseId: _caseId,
            attendanceType: AttendanceType.initial,
            attendanceDate: DateTime(2026, 2, 1),
            location: 'Singapore',
          ),
        ],
        damage: _damage(occ: [_occ('o1', 'Grounding', DateTime(2026, 1, 10))]),
      );

      await tester.tap(find.textContaining('Full Log').first);
      await tester.pumpAndSettle();

      // Cards are collapsed by default (14 July 2026 walkthrough — compact
      // 2-line cards, full detail only on tap) — titles are still visible
      // in the collapsed header.
      expect(find.text('Grounding'), findsOneWidget);
      expect(find.text('Initial Attendance'), findsOneWidget);
      expect(find.text('Drydock entry'), findsOneWidget);

      // Expand the manual event's card to see its chronology status — it
      // defaults into the chronology (no rating needed); aggregated ones
      // don't. Rating IS the chronology mechanism now — there's no longer
      // a separate "Add to Chronology" button to find.
      await tester.tap(find.text('Drydock entry'));
      await tester.pumpAndSettle();
      expect(find.text('In Chronology'), findsOneWidget);
      expect(find.text('Add to Chronology'), findsNothing);
    });

    testWidgets('rating an aggregated event Important adds it to the chronology',
        (tester) async {
      await _pump(
        tester,
        damage: _damage(occ: [_occ('o1', 'Grounding', DateTime(2026, 1, 10))]),
      );

      await tester.tap(find.byType(Tab).at(1)); // Full Log
      await tester.pumpAndSettle();

      // Expand the card to reach the relevance menu.
      await tester.tap(find.text('Grounding'));
      await tester.pumpAndSettle();
      expect(find.text('In Chronology'), findsNothing);

      // Rate it Important via the relevance menu (shows 'Normal' by default).
      await tester.tap(find.text('Normal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Important').last);
      await tester.pumpAndSettle();

      // No separate "add" step — Important alone puts it in the chronology.
      expect(find.text('In Chronology'), findsOneWidget);
    });

    testWidgets('ignore moves an event to the Ignored tab, restore brings it back',
        (tester) async {
      await _pump(
        tester,
        manual: [_manual('m1', 'Sea trial', DateTime(2026, 3, 1))],
      );

      // The three main tabs are the first three Tab widgets in the tree.
      await tester.tap(find.byType(Tab).at(1)); // Full Log
      await tester.pumpAndSettle();
      expect(find.text('Sea trial'), findsOneWidget);

      // Expand the card to reach the relevance menu, then open it (its
      // trigger shows the current 'Normal').
      await tester.tap(find.text('Sea trial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Normal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ignore').last);
      await tester.pumpAndSettle();

      // Ignored ⇒ the tab now carries a count, and the event is reviewable
      // from the dedicated Ignored tab.
      expect(find.textContaining('Ignored  1'), findsWidgets);
      await tester.tap(find.byType(Tab).at(2)); // Ignored
      await tester.pumpAndSettle();
      expect(find.text('Sea trial'), findsOneWidget);
      // Expand the card (collapsed by default) to reach Restore.
      await tester.tap(find.text('Sea trial'));
      await tester.pumpAndSettle();
      expect(find.text('Restore'), findsOneWidget);

      // Restore from the Ignored tab ⇒ the list empties to its empty state —
      // nothing is silently lost.
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing ignored'), findsOneWidget);
    });
  });
}
