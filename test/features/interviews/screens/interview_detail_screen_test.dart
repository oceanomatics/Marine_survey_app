// test/features/interviews/screens/interview_detail_screen_test.dart
//
// Deliberately never taps "Generate summary & cues" (real ClaudeApi network
// call) or "Delete" through to completion (delete navigates via
// context.go(), which needs a real GoRouter not present in this plain
// MaterialApp harness) — both are exercised only up to the point that stays
// safe and hermetic.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/interviews/screens/interview_detail_screen.dart';
import 'package:marine_survey_app/features/interviews/models/interview_model.dart';
import 'package:marine_survey_app/features/interviews/providers/interview_provider.dart';
import 'package:marine_survey_app/features/surveyor_notes/providers/surveyor_notes_provider.dart';

import '../../../support/fakes/fake_interviews_notifier.dart';
import '../../../support/fakes/fake_surveyor_notes_notifier.dart';

const _caseId = 'case-1';
const _interviewId = 'iv-1';

Future<FakeInterviewsNotifier> _pump(
  WidgetTester tester, {
  required InterviewModel interview,
}) async {
  final fake = FakeInterviewsNotifier([interview]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        interviewsProvider.overrideWith(() => fake),
        surveyorNotesProvider.overrideWith(() => FakeSurveyorNotesNotifier()),
      ],
      child: const MaterialApp(
        home: InterviewDetailScreen(caseId: _caseId, interviewId: _interviewId),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('no audio bar when the interview has no audioPath',
      (tester) async {
    await _pump(
      tester,
      interview: InterviewModel(
        interviewId: _interviewId,
        caseId: _caseId,
        createdAt: DateTime(2026, 7, 10),
        participants: const [],
        transcript: 'The master described the sequence of events.',
      ),
    );

    expect(find.text('Original recording'), findsNothing);
    expect(find.text('The master described the sequence of events.'), findsOneWidget);
  });

  testWidgets('shows participant chips with role titles', (tester) async {
    await _pump(
      tester,
      interview: InterviewModel(
        interviewId: _interviewId,
        caseId: _caseId,
        createdAt: DateTime(2026, 7, 10),
        participants: const [
          InterviewParticipant(contactId: 'p1', fullName: 'John Samuel', roleTitle: 'Superintendent'),
        ],
        transcript: 'Some transcript',
      ),
    );

    expect(find.text('John Samuel · Superintendent'), findsOneWidget);
  });

  testWidgets('shows "Generate summary" when no summary exists yet, "Regenerate" once one does',
      (tester) async {
    await _pump(
      tester,
      interview: InterviewModel(
        interviewId: _interviewId,
        caseId: _caseId,
        createdAt: DateTime(2026, 7, 10),
        participants: const [],
        transcript: 'Some transcript',
      ),
    );
    expect(find.text('Generate summary & cues'), findsOneWidget);
    expect(find.text('Regenerate summary & cues'), findsNothing);
  });

  testWidgets('displays the existing summary and offers Regenerate', (tester) async {
    await _pump(
      tester,
      interview: InterviewModel(
        interviewId: _interviewId,
        caseId: _caseId,
        createdAt: DateTime(2026, 7, 10),
        participants: const [],
        transcript: 'Some transcript',
        summary: 'The superintendent confirmed the failure occurred mid-passage.',
      ),
    );

    expect(find.text('The superintendent confirmed the failure occurred mid-passage.'),
        findsOneWidget);
    expect(find.text('Regenerate summary & cues'), findsOneWidget);
    expect(find.text('Generate summary & cues'), findsNothing);
  });

  testWidgets('editing and saving the transcript calls updateInterview with the new text',
      (tester) async {
    final fake = await _pump(
      tester,
      interview: InterviewModel(
        interviewId: _interviewId,
        caseId: _caseId,
        createdAt: DateTime(2026, 7, 10),
        participants: const [],
        transcript: 'Original transcript',
      ),
    );

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Corrected transcript');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fake.updateCalls, hasLength(1));
    expect(fake.updateCalls.single.transcript, 'Corrected transcript');
  });

  testWidgets('delete shows a confirmation dialog; Cancel does not delete',
      (tester) async {
    final fake = await _pump(
      tester,
      interview: InterviewModel(
        interviewId: _interviewId,
        caseId: _caseId,
        createdAt: DateTime(2026, 7, 10),
        participants: const [],
        transcript: 'Some transcript',
      ),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Delete interview?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(fake.deleteCalls, isEmpty);
  });
}
