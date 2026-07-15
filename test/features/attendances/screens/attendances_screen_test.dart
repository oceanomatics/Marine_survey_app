// test/features/attendances/screens/attendances_screen_test.dart
//
// Closes TEST_SHEET.md row 46 ("Create attendance record") — distinct from
// attendee CRUD (rows 42-45, attendees_screen_test.dart): this is the visit/
// survey-attendance event itself, on AttendancesScreen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/attendances/screens/attendances_screen.dart';
import 'package:marine_survey_app/features/attendances/models/attendance_model.dart';
import 'package:marine_survey_app/features/attendances/providers/attendances_provider.dart';
import 'package:marine_survey_app/features/survey/providers/attendees_provider.dart';
import 'package:marine_survey_app/features/cases/models/case_model.dart';
import 'package:marine_survey_app/features/cases/providers/cases_provider.dart';

import '../../../support/fakes/fake_attendances_notifier.dart';
import '../../../support/fakes/fake_attendees_notifier.dart';
import '../../../support/fakes/fake_case_notifier.dart';

const _caseId = 'case-1';

Future<FakeAttendancesNotifier> _pump(
  WidgetTester tester, {
  List<SurveyAttendanceModel> attendances = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final fake = FakeAttendancesNotifier(attendances);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        attendancesProvider.overrideWith(() => fake),
        attendeesProvider.overrideWith(() => FakeAttendeesNotifier(const [])),
        caseProvider.overrideWith(() => FakeCaseNotifier(const CaseModel(
              caseId: _caseId,
              technicalFileNo: 'AU-M53-056789',
              caseType: CaseType.hm,
              status: CaseStatus.open,
            ))),
      ],
      child: const MaterialApp(home: AttendancesScreen(caseId: _caseId)),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('empty state shows an Add prompt', (tester) async {
    await _pump(tester);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('creating an attendance record via the FAB adds it with the selected type',
      (tester) async {
    final fake = await _pump(tester);

    await tester.tap(find.text('Add Attendance'));
    await tester.pumpAndSettle();

    // Defaults (type=Initial Attendance, no date/location required) are
    // enough to save — no validation blocks an empty-ish record.
    await tester.tap(find.text('Final Inspection'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Attendance'));
    await tester.pumpAndSettle();

    expect(fake.state.value, hasLength(1));
    expect(fake.state.value!.single.attendanceType, AttendanceType.finalInspection);
  });

  testWidgets('an existing attendance shows in the list with its type label',
      (tester) async {
    await _pump(tester, attendances: [
      SurveyAttendanceModel(
        attendanceId: 'a1',
        caseId: _caseId,
        attendanceType: AttendanceType.initial,
        attendanceDate: DateTime(2026, 6, 1),
      ),
    ]);

    expect(find.text('Initial Attendance'), findsOneWidget);
  });
}
