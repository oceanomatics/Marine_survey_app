import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/core/services/gmail_service.dart';
import 'package:marine_survey_app/features/cases/models/case_model.dart';
import 'package:marine_survey_app/features/cases/providers/cases_provider.dart';
import 'package:marine_survey_app/features/correspondence/providers/inbox_provider.dart';
import 'package:marine_survey_app/features/correspondence/providers/case_inbox_provider.dart';
import 'package:marine_survey_app/features/correspondence/providers/mail_poll_provider.dart';
import 'package:marine_survey_app/features/correspondence/screens/inbox_screen.dart';

import '../../../support/fakes/fake_cases_notifier.dart';
import '../../../support/fakes/fake_case_notifier.dart';
import '../../../support/fakes/fake_mail_poll_notifier.dart';

// The Inbox now displays Gmail THREADS (whole trails). Each test thread wraps
// a single message so existing metadata assertions still hold.
GmailThreadSummary _thread({
  String id = 't1',
  String subject = 'Re: MV Surveyor main engine damage',
  String from = 'owner@ship.com',
  String snippet = 'Please find attached the repair quote for review.',
}) =>
    GmailThreadSummary(
      id: id,
      subject: subject,
      messages: [
        GmailThreadMessage(
          id: '${id}_m1',
          from: from,
          date: 'Mon, 28 Jun 2026 09:00:00 +1000',
          snippet: snippet,
        ),
      ],
    );

CaseModel _case({String id = 'case-1', String? title = 'MV Surveyor — H&M'}) =>
    CaseModel(
      caseId: id,
      technicalFileNo: 'ABL-2026-001',
      caseType: CaseType.hm,
      status: CaseStatus.open,
      title: title,
    );

Future<void> _pump(
  WidgetTester tester, {
  List<GmailThreadSummary>? threads,
  Object? error,
  List<CaseModel> cases = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        inboxThreadsProvider.overrideWith((ref) async {
          if (error != null) throw error;
          return threads ?? const [];
        }),
        casesProvider.overrideWith(() => FakeCasesNotifier(cases)),
        // Real mailPollProvider starts a Timer.periodic and hits the live
        // Gmail API — neither belongs in a widget test.
        mailPollProvider.overrideWith(FakeMailPollNotifier.new),
      ],
      child: const MaterialApp(home: InboxScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('InboxScreen', () {
    testWidgets('shows the triage banner and message metadata', (tester) async {
      await _pump(tester, threads: [_thread()]);

      expect(find.textContaining('Triage'), findsOneWidget);
      expect(find.text('Re: MV Surveyor main engine damage'), findsOneWidget);
      expect(find.text('owner@ship.com'), findsOneWidget);
      expect(find.textContaining('repair quote'), findsOneWidget);
      // Triage actions are present (global inbox → New case shown).
      expect(find.text('Link to case'), findsOneWidget);
      expect(find.text('New case'), findsOneWidget);
    });

    testWidgets('empty inbox shows the no-messages placeholder',
        (tester) async {
      await _pump(tester, threads: const []);
      expect(find.text('No recent messages.'), findsOneWidget);
    });

    testWidgets('error state offers a retry', (tester) async {
      await _pump(tester, error: Exception('network down'));
      expect(find.textContaining('network down'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Link to case opens a picker listing existing cases',
        (tester) async {
      await _pump(
        tester,
        threads: [_thread()],
        cases: [_case(), _case(id: 'case-2', title: 'MV Second — C&S')],
      );

      await tester.tap(find.text('Link to case'));
      await tester.pumpAndSettle();

      expect(find.text('File to which case?'), findsOneWidget);
      expect(find.text('MV Surveyor — H&M'), findsOneWidget);
      expect(find.text('MV Second — C&S'), findsOneWidget);
    });

    testWidgets(
        'opening the Inbox clears the shared §3.14 new-mail badge '
        '(marks seen)', (tester) async {
      final tracker = _TrackingMailPollNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inboxThreadsProvider.overrideWith((ref) async => [_thread()]),
            casesProvider.overrideWith(() => FakeCasesNotifier(const [])),
            mailPollProvider.overrideWith(() => tracker),
          ],
          child: const MaterialApp(home: InboxScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tracker.markSeenCalls, 1);
    });
  });

  group('InboxScreen (case-scoped)', () {
    Future<void> pumpCase(
      WidgetTester tester, {
      required List<GmailThreadSummary> caseThreads,
      List<GmailThreadSummary> allThreads = const [],
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            caseInboxThreadsProvider
                .overrideWith((ref, caseId) async => caseThreads),
            inboxThreadsProvider.overrideWith((ref) async => allThreads),
            caseProvider.overrideWith(() => FakeCaseNotifier(_case())),
            casesProvider.overrideWith(() => FakeCasesNotifier(const [])),
            mailPollProvider.overrideWith(FakeMailPollNotifier.new),
          ],
          child: const MaterialApp(home: InboxScreen(caseId: 'case-1')),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('defaults to the filtered case view with the scope toggle',
        (tester) async {
      await pumpCase(
        tester,
        caseThreads: [_thread(subject: 'MV Surveyor damage')],
        allThreads: [_thread(id: 'other', subject: 'Unrelated newsletter')],
      );

      // Case banner + the case-relevant message, not the unrelated one.
      expect(find.textContaining('relevant to this case'), findsOneWidget);
      expect(find.text('MV Surveyor damage'), findsOneWidget);
      expect(find.text('Unrelated newsletter'), findsNothing);
      // The scope toggle is present.
      expect(find.text('This case'), findsOneWidget);
      expect(find.text('All mail'), findsOneWidget);
    });

    testWidgets('empty case view shows the case-specific placeholder',
        (tester) async {
      await pumpCase(tester, caseThreads: const []);
      expect(find.text('No un-filed mail matches this case.'), findsOneWidget);
    });

    testWidgets('"All mail" toggle drops back to the unfiltered inbox',
        (tester) async {
      await pumpCase(
        tester,
        caseThreads: [_thread(subject: 'MV Surveyor damage')],
        allThreads: [_thread(id: 'other', subject: 'Unrelated newsletter')],
      );

      await tester.tap(find.text('All mail'));
      await tester.pumpAndSettle();

      // Now the whole-inbox message shows and the case filter is off.
      expect(find.text('Unrelated newsletter'), findsOneWidget);
      expect(find.textContaining('Triage:'), findsOneWidget);
    });
  });
}

/// Records whether InboxScreen's initState actually called markSeen(), per
/// the badge-clearing contract mail_poll_provider.dart documents.
class _TrackingMailPollNotifier extends FakeMailPollNotifier {
  int markSeenCalls = 0;

  @override
  Future<void> markSeen() async {
    markSeenCalls++;
    await super.markSeen();
  }
}
