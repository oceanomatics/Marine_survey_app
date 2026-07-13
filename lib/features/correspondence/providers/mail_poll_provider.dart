// lib/features/correspondence/providers/mail_poll_provider.dart
//
// §3.14/§3.5 shared background mail-check. Per the design intent logged in
// TODO.md: ONE app-level poller drives both the Inbox new-mail badge and the
// Correspondence new-mail badge, rather than two screens independently
// hitting the Gmail API. Gated on:
//   • connectivity (skip while offline, catch up immediately on reconnect —
//     same ref.listen(connectivityProvider) convention already used by
//     correspondence_provider.dart / photo_provider.dart / surveyor_notes).
//   • app lifecycle (only polls while the app is foregrounded).
//   • an already-active Google session — GmailService.listRecentSilent()
//     never triggers an interactive sign-in, so this timer can never pop an
//     OAuth prompt out of nowhere while the surveyor is doing something
//     unrelated. That was the specific live-OAuth risk this item was held
//     back for; a silent-only token path removes it rather than working
//     around it.
//
// Deliberately NOT wired to fire the §3.3 photo-upload retry queue on the
// same tick, despite that being floated as a possible extension in the
// original TODO note — that queue already has its own connectivity-driven
// trigger (photo_provider.dart), and bolting a second, unrelated trigger
// onto this timer would just be two mechanisms doing the same job.

import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/connectivity_service.dart';
import '../../../core/services/gmail_service.dart';

const _kPollInterval = Duration(minutes: 5);
const _kLastSeenIdKey = 'mail_poll.last_seen_message_id';

@immutable
class MailPollState {
  const MailPollState({this.unseenCount = 0, this.capped = false});
  final int unseenCount;

  /// True when [unseenCount] is a floor, not an exact count — the last-seen
  /// message fell outside the page fetched by the periodic silent check, so
  /// there may be more unseen mail than [unseenCount] shows. The badge
  /// should render e.g. "10+" rather than implying an exact number.
  final bool capped;

  MailPollState copyWith({int? unseenCount, bool? capped}) => MailPollState(
        unseenCount: unseenCount ?? this.unseenCount,
        capped: capped ?? this.capped,
      );
}

final mailPollProvider =
    NotifierProvider<MailPollNotifier, MailPollState>(MailPollNotifier.new);

class MailPollNotifier extends Notifier<MailPollState> {
  Timer? _timer;
  AppLifecycleListener? _lifecycleListener;
  String? _lastSeenId;
  bool _checking = false;
  bool _restoredLastSeen = false;

  @override
  MailPollState build() {
    ref.listen<AsyncValue<bool>>(connectivityProvider, (_, next) {
      if (next.value == true) _check();
    });

    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        _startTimer();
        _check();
      },
      onPause: _stopTimer,
    );

    ref.onDispose(() {
      _timer?.cancel();
      _lifecycleListener?.dispose();
    });

    _startTimer();
    _check();

    return const MailPollState();
  }

  void _startTimer() {
    _timer ??= Timer.periodic(_kPollInterval, (_) => _check());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      if (!_restoredLastSeen) {
        final prefs = await SharedPreferences.getInstance();
        _lastSeenId = prefs.getString(_kLastSeenIdKey);
        _restoredLastSeen = true;
      }

      final messages =
          await GmailService.listRecentSilent(maxResults: 10);
      if (messages == null) return; // no silent session — skip this cycle
      if (messages.isEmpty) {
        state = state.copyWith(unseenCount: 0, capped: false);
        return;
      }
      if (_lastSeenId == null) {
        // First run ever on this device — don't retroactively flag the
        // surveyor's existing inbox as "new", only mail that arrives from
        // here on.
        await _persistLastSeen(messages.first.id);
        state = state.copyWith(unseenCount: 0, capped: false);
        return;
      }
      final idx = messages.indexWhere((m) => m.id == _lastSeenId);
      // idx == -1 means the last-seen message fell off the fetched page —
      // there are *at least* messages.length unseen, not exactly that many
      // (previously reported as an exact count, silently understating a
      // busy inbox — see the 2026-07-13 review).
      state = state.copyWith(
          unseenCount: idx == -1 ? messages.length : idx, capped: idx == -1);
    } catch (_) {
      // Network hiccup / API error — leave the badge as it was, next tick
      // (or the next connectivity/lifecycle event) will retry.
    } finally {
      _checking = false;
    }
  }

  Future<void> _persistLastSeen(String id) async {
    _lastSeenId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastSeenIdKey, id);
  }

  /// Call when the surveyor actually opens the Inbox — clears the badge and
  /// remembers the newest message on screen so it isn't re-counted next
  /// poll. Uses the normal (interactive-capable) GmailService.listRecent
  /// since this only ever runs from an explicit user action, not the timer.
  /// Swallows errors the same way [_check] does: this is a best-effort
  /// badge clear, not something the Inbox screen (which has its own
  /// error/retry UI via inboxMessagesProvider) should surface a second time.
  Future<void> markSeen() async {
    try {
      final messages = await GmailService.listRecent(maxResults: 1);
      if (messages.isNotEmpty) await _persistLastSeen(messages.first.id);
    } catch (_) {
      // Ignore — inboxMessagesProvider on the same screen already shows the
      // real error/retry state if Gmail is unreachable or unauthenticated.
    } finally {
      state = state.copyWith(unseenCount: 0, capped: false);
    }
  }
}
