// lib/features/correspondence/utils/correspondence_threads.dart
//
// TODO.md §3.14 — AI-generated thread-level trail summary. The existing
// per-message extraction summary (_CorrExtractionSummarySheet,
// correspondence_screen.dart) covers one email's fields/parties/actions —
// this covers a whole back-and-forth exchange instead.
//
// No Message-ID/In-Reply-To/References headers are parsed anywhere in this
// app (eml_parser.dart confirmed) — the only deterministic threading signal
// available is the subject line, so grouping uses the classic
// Re:/Fwd:-stripped subject heuristic. Per this project's convention #1
// (docs/context_cue_system_review.md — deterministic structure, LLM only
// for narrative synthesis), the sequence itself (who/when/subject) is
// composed here with zero AI calls; only the prose synthesis
// (claude_api.dart draftCorrespondenceTrailSummary) costs anything, and
// that's fetched on demand, not automatically.

import '../models/correspondence_model.dart';

class CorrespondenceThread {
  const CorrespondenceThread({required this.subject, required this.messages});

  /// Display subject — the earliest message's own (un-normalised) title.
  final String subject;

  /// Oldest-first.
  final List<CorrespondenceModel> messages;

  bool get isMultiMessage => messages.length > 1;
}

/// Strips repeated Re:/Fwd:/Fw: prefixes and case/whitespace differences so
/// "Re: Fwd: Engine damage" and "engine damage" group as the same thread.
String normalizeSubjectForThreading(String title) {
  var s = title.trim();
  final prefix = RegExp(r'^(re|fwd?|fw)\s*:\s*', caseSensitive: false);
  while (true) {
    final match = prefix.firstMatch(s);
    if (match == null) break;
    s = s.substring(match.end).trim();
  }
  return s.toLowerCase();
}

/// Groups [items] (already filtered to one case) into threads by normalised
/// subject, newest-thread-first (by its latest message). An item with an
/// empty/blank title is never grouped with another (falls back to its own
/// id as the key) so unrelated blank-subject imports don't collide.
List<CorrespondenceThread> groupCorrespondenceThreads(
    List<CorrespondenceModel> items) {
  final byKey = <String, List<CorrespondenceModel>>{};
  for (final item in items) {
    final normalized = normalizeSubjectForThreading(item.title);
    final key = normalized.isEmpty ? 'id:${item.id}' : normalized;
    byKey.putIfAbsent(key, () => []).add(item);
  }

  DateTime effectiveDate(CorrespondenceModel m) => m.corrDate ?? m.createdAt;

  final threads = byKey.values.map((group) {
    final sorted = [...group]
      ..sort((a, b) => effectiveDate(a).compareTo(effectiveDate(b)));
    return CorrespondenceThread(subject: sorted.first.title, messages: sorted);
  }).toList();

  threads.sort((a, b) => effectiveDate(b.messages.last)
      .compareTo(effectiveDate(a.messages.last)));
  return threads;
}
