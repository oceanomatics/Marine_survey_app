// lib/features/correspondence/providers/case_inbox_provider.dart
//
// Case-scoped Inbox providers (16 July 2026 reports). The Inbox reached from
// a case's Correspondence defaults to only the mail relevant to THAT case
// (matching its vessel name / file no / claim reference across subject+body),
// minus anything already imported into the case's Correspondence register.
//
// Two entry points, deliberately split by interactivity:
//   • [caseInboxProvider]        — the on-screen list. Interactive Gmail path
//     (the surveyor opened the screen, so a sign-in prompt is acceptable).
//   • [caseNewMailCountProvider] — the background badge count (Case Home Mail
//     rail + Correspondence app-bar). Silent Gmail path: it can NEVER pop an
//     OAuth prompt out of a badge refresh, matching mail_poll_provider.dart.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/gmail_service.dart';
import '../../cases/providers/cases_provider.dart';
import '../utils/case_inbox_filter.dart';
import 'correspondence_provider.dart';

/// Raw Gmail fetch scoped to a case's search terms (interactive). Depends only
/// on the case's identifying terms, NOT on the imported-correspondence list,
/// so it isn't re-fetched every time an auto-extraction updates a row — the
/// (cheap, network-free) exclusion pass happens in [caseInboxProvider].
final caseInboxRawProvider =
    FutureProvider.autoDispose.family<List<GmailMessageSummary>, String>(
  (ref, caseId) async {
    final terms = caseSearchTerms(ref.watch(caseProvider(caseId)).value);
    final query = caseGmailQuery(terms);
    if (query == null) return const [];
    return GmailService.listRecent(query: query, maxResults: 25);
  },
);

/// Case-filtered Inbox for the screen: the raw fetch minus anything already
/// imported into this case's Correspondence. Recomputes without a network hit
/// whenever the imported list changes (e.g. a message was just filed).
final caseInboxProvider = Provider.autoDispose
    .family<AsyncValue<List<GmailMessageSummary>>, String>((ref, caseId) {
  final terms = caseSearchTerms(ref.watch(caseProvider(caseId)).value);
  final imported = ref.watch(correspondenceProvider(caseId)).value ?? const [];
  return ref.watch(caseInboxRawProvider(caseId)).whenData(
        (messages) => filterCaseInbox(
          messages: messages,
          caseTerms: terms,
          importedTitles: imported.map((c) => c.title).toList(),
        ),
      );
});

/// Case-scoped inbox as whole conversations (Gmail threads) — a case-relevant
/// email is a back-and-forth, so this returns every message in each matching
/// trail, not just the filter-matching few (24 July 2026: "18 in Gmail, only 2
/// shown"). Interactive path (a sign-in prompt is acceptable).
final caseInboxThreadsProvider = FutureProvider.autoDispose
    .family<List<GmailThreadSummary>, String>((ref, caseId) async {
  final terms = caseSearchTerms(ref.watch(caseProvider(caseId)).value);
  final query = caseGmailQuery(terms);
  if (query == null) return const [];
  return GmailService.listThreads(query: query, maxResults: 40);
});

/// Background, non-interactive count of new (filtered, not-yet-imported) case
/// mail — drives the badge on the Case Home Mail rail icon and the
/// Correspondence app-bar. Yields 0 when there's no silent Gmail session or
/// nothing relevant, so a signed-out surveyor never sees a phantom badge.
final caseNewMailCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, caseId) async {
  final terms = caseSearchTerms(ref.watch(caseProvider(caseId)).value);
  final query = caseGmailQuery(terms);
  if (query == null) return 0;
  final messages =
      await GmailService.listRecentSilent(query: query, maxResults: 25);
  if (messages == null) return 0;
  final imported = ref.watch(correspondenceProvider(caseId)).value ?? const [];
  return filterCaseInbox(
    messages: messages,
    caseTerms: terms,
    importedTitles: imported.map((c) => c.title).toList(),
  ).length;
});
