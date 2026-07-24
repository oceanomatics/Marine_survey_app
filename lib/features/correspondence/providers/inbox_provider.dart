// lib/features/correspondence/providers/inbox_provider.dart
//
// Backing provider for the Inbox triage screen (§3.5). Wraps the static
// GmailService.listRecent so the screen can watch an AsyncValue (and so the
// screen stays widget-testable by overriding this provider with fake
// messages, since GmailService itself is a static network client).
//
// Deliberately thin: the Inbox is a lightweight triage view, NOT a mail
// client — no unread/folder/search state lives here, just "the most recent N
// messages" for the surveyor to file.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/gmail_service.dart';

/// Most-recent inbox messages (metadata only). autoDispose so it re-fetches
/// when the Inbox screen is reopened rather than serving a stale list.
final inboxMessagesProvider =
    FutureProvider.autoDispose<List<GmailMessageSummary>>((ref) async {
  return GmailService.listRecent(maxResults: 25);
});

/// Free-text Gmail search for the Inbox — the surveyor's escape hatch from the
/// case-scoped filter, which was "too restrictive / not editable" (16 & 23 July
/// reports). Keyed by the raw query string (full Gmail search syntax: sender,
/// subject:, has:attachment, quoted phrases…). Returns empty for a blank query
/// so the screen falls back to its default (case filter / recent).
final inboxSearchProvider = FutureProvider.autoDispose
    .family<List<GmailMessageSummary>, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  return GmailService.listRecent(query: q, maxResults: 50);
});
