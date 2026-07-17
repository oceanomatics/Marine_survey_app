// lib/features/correspondence/utils/case_inbox_filter.dart
//
// Pure, testable helpers for the case-scoped Inbox (16 July 2026 reports).
// The Inbox reached from a case's Correspondence should default to only the
// mail relevant to THAT case, and hide anything already imported into the
// case's Correspondence register.
//
// Relevance is treated as OR across the case's identifying terms (vessel
// name / technical file no / claim reference), NOT a strict AND: requiring
// *every* term to appear in a single email would silently drop the common
// case where an owner emails about "MV Foo" without quoting the file number.
// The Gmail server-side query already scopes across the full message body;
// the local pass here is a belt-and-braces guard (snippet + subject only).

import '../../../core/services/gmail_service.dart';
import '../../cases/models/case_model.dart';

/// Case-identifying search terms — vessel name, technical file number and
/// claim reference. Placeholder/empty file numbers (TMP-…/TBC) are skipped so
/// they can't match half the inbox.
List<String> caseSearchTerms(CaseModel? c) {
  if (c == null) return const [];
  return <String>[
    if ((c.vesselName ?? '').trim().isNotEmpty) c.vesselName!.trim(),
    if (!c.hasPlaceholderFileNo) c.technicalFileNo.trim(),
    if ((c.claimReference ?? '').trim().isNotEmpty) c.claimReference!.trim(),
  ].where((t) => t.isNotEmpty).toList();
}

/// Builds a Gmail search query (`"term" OR "term"`) from [terms], or null when
/// there's nothing to scope by (the caller should then surface no case mail).
String? caseGmailQuery(List<String> terms) {
  if (terms.isEmpty) return null;
  return terms.map((t) => '"$t"').join(' OR ');
}

/// Normalises an email subject for dedupe: strips any run of leading
/// Re:/Fw:/Fwd: prefixes, lowercases, and collapses whitespace so a reply
/// imported as "Re: Foo" matches an inbox "RE:  Foo" and vice-versa.
String normaliseSubject(String subject) {
  var s = subject.trim().toLowerCase();
  final prefix = RegExp(r'^(re|fw|fwd)\s*:\s*');
  while (prefix.hasMatch(s)) {
    s = s.replaceFirst(prefix, '').trim();
  }
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Filters [messages] down to those relevant to a case AND not already
/// imported:
///   • relevant   — at least one of [caseTerms] appears (case-insensitively)
///     in the subject or snippet. If [caseTerms] is empty, every message is
///     treated as relevant (nothing to scope by).
///   • not imported — its normalised subject doesn't match any already-filed
///     correspondence title in [importedTitles].
List<GmailMessageSummary> filterCaseInbox({
  required List<GmailMessageSummary> messages,
  required List<String> caseTerms,
  required List<String> importedTitles,
}) {
  final terms = caseTerms
      .map((t) => t.toLowerCase())
      .where((t) => t.isNotEmpty)
      .toList();
  final imported = importedTitles.map(normaliseSubject).toSet();

  bool relevant(GmailMessageSummary m) {
    if (terms.isEmpty) return true;
    final hay = '${m.subject}\n${m.snippet}'.toLowerCase();
    return terms.any(hay.contains);
  }

  return messages
      .where((m) =>
          relevant(m) && !imported.contains(normaliseSubject(m.subject)))
      .toList();
}
