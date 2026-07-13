import 'package:marine_survey_app/features/correspondence/providers/mail_poll_provider.dart';

/// Overrides the §3.14 shared mail-poll provider for widget tests. The real
/// notifier starts a Timer.periodic and hits the live Gmail API — neither is
/// appropriate (or safe against "Timer still pending" test failures) in a
/// widget test, so any screen that watches mailPollProvider (Cases list,
/// Correspondence, Inbox) should override it with this fixed, timer-free
/// fake instead.
class FakeMailPollNotifier extends MailPollNotifier {
  FakeMailPollNotifier([this._unseenCount = 0]);
  final int _unseenCount;

  @override
  MailPollState build() => MailPollState(unseenCount: _unseenCount);

  @override
  Future<void> markSeen() async {
    state = state.copyWith(unseenCount: 0);
  }
}
