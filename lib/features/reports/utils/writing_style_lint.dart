// lib/features/reports/utils/writing_style_lint.dart
//
// Non-blocking checks against the Writing Style Rulebook
// (docs/report_builder_editor_notes.md — "Writing Style Rulebook" +
// "Common Drafting Errors" tables). Surfaced as advisory flags in the
// section editor and rolled up as a soft export warning; never blocks
// export on its own.

import '../providers/report_provider.dart';

class StyleFlag {
  const StyleFlag(this.phrase, this.reason);
  final String phrase;
  final String reason;
}

// Section types where the "Reportedly" rule applies — narrative content
// here typically describes events the surveyor did not directly witness.
const _attributionRequiredTypes = {
  SectionType.background,
  SectionType.occurrence,
  SectionType.executiveSummary,
};

// Phrases that mark a statement as attributed to a source, per the
// Attribution table in the rulebook. Case-insensitive substring match.
const _attributionMarkers = [
  'reportedly',
  'it was reported',
  'according to',
  'as reported by',
  'stated that',
  'it is understood that',
  'has been informed that',
  'in the opinion of the undersigned',
  'it is the view of the undersigned',
  'upon inspection by the undersigned',
  'the undersigned observed',
];

// Prohibited / flagged phrases, each with the reason from the rulebook.
// Word-boundary matched, case-insensitive.
const _prohibitedPhrases = <String, String>{
  'apparently': 'Unquantified qualifier — state the fact or flag uncertainty explicitly.',
  'seemingly': 'Unquantified qualifier — state the fact or flag uncertainty explicitly.',
  'obviously': 'Unquantified qualifier / emotive — state the fact plainly.',
  'good condition': 'Not quantifiable without a reference standard — state the standard applied or describe the observed condition.',
  'fair wear and tear': 'Not quantifiable without a reference standard — state the standard applied or describe the observed condition.',
  'unfortunately': 'Emotive language — keep a neutral, factual register.',
  'clearly': 'Emotive / unquantified qualifier — state the fact plainly.',
  'as anyone can see': 'Emotive / conversational — keep a neutral, factual register.',
  'i inspected': 'First person — use "the Undersigned" formulations.',
  'i visited': 'First person — use "the Undersigned" formulations.',
  'i observed': 'First person — use "the Undersigned" formulations.',
  'my opinion': 'First person — use "the Undersigned" formulations.',
  'we inspected': 'First person — use "the Undersigned" formulations.',
  'we visited': 'First person — use "the Undersigned" formulations.',
  'we observed': 'First person — use "the Undersigned" formulations.',
};

final _prohibitedPattern = RegExp(
  r'\b(' +
      _prohibitedPhrases.keys.map(RegExp.escape).join('|') +
      r')\b',
  caseSensitive: false,
);

/// Flags prohibited/emotive phrasing anywhere in [text].
List<StyleFlag> lintProhibitedLanguage(String text) {
  final flags = <StyleFlag>[];
  final seen = <String>{};
  for (final match in _prohibitedPattern.allMatches(text)) {
    final matched = match.group(0)!;
    final key = matched.toLowerCase();
    if (seen.add(key)) {
      flags.add(StyleFlag(matched, _prohibitedPhrases[key]!));
    }
  }
  return flags;
}

/// True if [text] contains at least one recognised attribution phrase.
bool hasAttributionMarker(String text) {
  final lower = text.toLowerCase();
  return _attributionMarkers.any(lower.contains);
}

/// Full lint pass for a section: prohibited language everywhere, plus the
/// "Reportedly" attribution check for section types where it applies.
List<StyleFlag> lintSection(SectionType type, String text) {
  if (text.trim().isEmpty) return const [];

  final flags = <StyleFlag>[...lintProhibitedLanguage(text)];

  if (_attributionRequiredTypes.contains(type) && !hasAttributionMarker(text)) {
    flags.add(const StyleFlag(
      'No attribution phrase found',
      'Events not directly witnessed by the surveyor should be marked '
          '(e.g. "reportedly", "according to the Master…") — the "Reportedly" rule.',
    ));
  }

  return flags;
}
