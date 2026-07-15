// lib/shared/widgets/context_cues_panel.dart
//
// Reusable collapsible context-cues panel shown at the bottom of any case
// screen section. Filters cues by the given [section] and provides add/edit/
// delete actions. Mirrors the pattern established in background_screen.dart.
//
// Cue metadata rework (docs/context_cue_system_review.md §3.6, 5 July 2026):
// `NoteCategory` retired — replaced by two independent axes (NatureOfContent,
// EvidentiaryWeight) plus a new `origin` field (who the cue's content comes
// from). Priority moved to the top of the add/edit sheet; marking a cue
// Ignored auto-sets its lostRelevanceAt (handled in the provider) rather than
// needing a separate resolved toggle.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/surveyor_notes/models/surveyor_note_model.dart';
import '../../features/surveyor_notes/providers/surveyor_notes_provider.dart';
import '../../features/timeline/providers/timeline_provider.dart';
import '../../features/timeline/utils/cue_to_event.dart';
import '../../core/api/claude_api.dart';
import '../theme/app_theme.dart';

// ── Colour helpers ──────────────────────────────────────────────────────────

Color natureOfContentColor(NatureOfContent n) => switch (n) {
      NatureOfContent.observationFinding  => const Color(0xFF2A6099),
      NatureOfContent.recommendation      => const Color(0xFF0F766E),
      NatureOfContent.followUpOpenQuestion=> const Color(0xFFD97706),
      NatureOfContent.backgroundReference => const Color(0xFF6B7280),
    };

Color evidentiaryWeightColor(EvidentiaryWeight w) => switch (w) {
      EvidentiaryWeight.fact       => const Color(0xFF166534),
      EvidentiaryWeight.opinion    => const Color(0xFF7B5EA7),
      EvidentiaryWeight.allegation => const Color(0xFFDC2626),
      EvidentiaryWeight.hearsay    => const Color(0xFF9E9C96),
    };

Color cueOriginColor(CueOrigin o) => switch (o) {
      CueOrigin.assuredOwner => const Color(0xFF0369A1),
      CueOrigin.thirdParty   => const Color(0xFFB45309),
      CueOrigin.surveyor     => const Color(0xFF4A7A5A),
    };

Color sectionColor(CaseSection s) => switch (s) {
      CaseSection.background      => const Color(0xFF2A6B9E),
      CaseSection.occurrence      => const Color(0xFFDC2626),
      CaseSection.attendance      => const Color(0xFFBF7E3A),
      CaseSection.timeline        => const Color(0xFF2E7CB7),
      CaseSection.causation       => const Color(0xFFD97706),
      CaseSection.damage          => const Color(0xFFE05C2A),
      CaseSection.repairs         => const Color(0xFF1A6B9E),
      CaseSection.repairTimes     => const Color(0xFF0F766E),
      CaseSection.extraExpenses   => const Color(0xFF059669),
      CaseSection.generalExpenses => const Color(0xFF4A7A5A),
      CaseSection.notAverage      => const Color(0xFF6B7280),
      CaseSection.otherMatters    => const Color(0xFF7B5EA7),
      CaseSection.previousWorks   => const Color(0xFF92400E),
      CaseSection.contractualHire => const Color(0xFF0369A1),
    };

// ── Repair-period scoping ───────────────────────────────────────────────────
//
// For CaseSection.isRepairPeriodScoped sections (Work Not Concerning
// Average, General Services & Access — docs/context_cue_system_review.md
// §3.1/§3.2), a ContextCuesPanel shows either the cues linked to one
// specific repair period, or the "not allocated to a period" bucket.
// Irrelevant for every other section.
const String repairPeriodLinkType = 'repair_period';

/// `linked_to_type` tag for a cue routed to a specific occurrence — see
/// [ContextCuesPanel.routingLinkType]/[CueItemScope]. Moved here from
/// occurrence_editor_screen.dart (14 July 2026 walkthrough §4) so both the
/// single-occurrence auto-scope and the new multi-occurrence picker share
/// one definition.
const String occurrenceLinkType = 'occurrence';

class RepairPeriodScope {
  const RepairPeriodScope.forPeriod(this.periodId) : isUnassignedBucket = false;
  const RepairPeriodScope.unassigned()
      : periodId = null,
        isUnassignedBucket = true;

  final String? periodId;
  final bool isUnassignedBucket;
}

/// Shared scope-matching logic — the single source of truth for "does this
/// cue belong to this panel" used both inside [ContextCuesPanel] itself and
/// by callers that need a count *before* the panel is built (e.g.
/// RepairPeriodScopedCuesScreen collapsing the Unassigned bucket when it's
/// empty, TODO.md §3.10 — the count has to be known outside the panel to
/// decide how to render it, so this can't stay private).
bool cueMatchesScope(
  SurveyorNote n,
  CaseSection section, {
  RepairPeriodScope? periodScope,
  CueItemScope? itemScope,
}) {
  if (n.caseSection != section) return false;
  if (periodScope != null) {
    if (periodScope.isUnassignedBucket) {
      return n.linkedToType != repairPeriodLinkType || n.linkedToId == null;
    }
    return n.linkedToType == repairPeriodLinkType &&
        n.linkedToId == periodScope.periodId;
  }
  if (itemScope != null) {
    return n.linkedToType == itemScope.linkedToType &&
        n.linkedToId == itemScope.linkedToId;
  }
  return true;
}

// ── Generic per-item scoping ────────────────────────────────────────────────
//
// The standing design principle (docs/context_cue_system_review.md, added
// 8 July 2026) is that context cues should scope to a *specific instance*
// of a thing wherever that makes sense, not just a flat case-section tag —
// [RepairPeriodScope] above was the first instance of this (a repair period
// picked from a list, with an "unassigned" bucket). A cue embedded directly
// on the owning item's own screen (a single occurrence's Narrative tab, a
// single repair period card) doesn't need a picker or an unassigned bucket
// — it's always scoped to that one item. [CueItemScope] covers that case,
// reusing the same polymorphic linked_to_type/linked_to_id mechanism.
// [periodScope] and [itemScope] are mutually exclusive; pass whichever fits
// the screen.
class CueItemScope {
  const CueItemScope({required this.linkedToType, required this.linkedToId});
  final String linkedToType;
  final String linkedToId;
}

// ── Card wrapper (title + hint header, panel clipped into rounded card) ────
//
// Shared shape for embedding a ContextCuesPanel inside a titled card on a
// ListView-based screen — used by Additional Information's cue sections and
// by RepairPeriodScopedCuesScreen (WNCA / General Services & Access).

class CueSectionCard extends StatelessWidget {
  const CueSectionCard({
    super.key,
    required this.title,
    this.hint,
    required this.child,
  });

  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Single Container owning both the border and the clip (same RRect for
    // both) instead of a separate outer ClipRRect — two independently
    // computed rounded paths at the same nominal radius don't perfectly
    // align pixel-for-pixel, which produced the "rounded corners not
    // showing well" seam reported 8 July 2026 across WNCA/General
    // Services & Access/Additional Information (all built on this widget).
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(hint!,
                      style: const TextStyle(
                          fontSize: 10.5, color: AppColors.textTertiary)),
                ],
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ── Public panel widget ───────────────────────────────────────────────────────

class ContextCuesPanel extends ConsumerStatefulWidget {
  const ContextCuesPanel({
    super.key,
    required this.caseId,
    required this.section,
    this.periodScope,
    this.itemScope,
    this.routingLinkType,
    this.routingOptions,
    this.initiallyExpanded = true,
    this.onPromote,
  });

  final String caseId;
  final CaseSection section;
  /// Only meaningful when `section.isRepairPeriodScoped` — see
  /// [RepairPeriodScope]. Ignored otherwise. Mutually exclusive with
  /// [itemScope].
  final RepairPeriodScope? periodScope;
  /// Scopes this panel to one specific item instance (an occurrence, a
  /// repair period embedded on its own screen, etc.) — see [CueItemScope].
  /// Mutually exclusive with [periodScope].
  final CueItemScope? itemScope;
  /// When there's more than one possible target of [itemScope]'s kind (e.g.
  /// a multi-occurrence case), pass the shared `linkedToType` here plus
  /// [routingOptions] instead of [itemScope] — the add/edit cue sheet then
  /// shows a picker so the surveyor chooses which one a given cue routes
  /// to, rather than every cue silently going unscoped (14 July 2026
  /// walkthrough §4 — "if the case only has one occurrence, default to it
  /// automatically, no prompt needed" — that single-item case is exactly
  /// what [itemScope] already covers; this is for the >1 case).
  final String? routingLinkType;
  /// (id, label) pairs offered by the picker described above. Ignored
  /// unless [routingOptions] has more than one entry.
  final List<MapEntry<String, String>>? routingOptions;
  /// Set false when stacking multiple panels on one screen (e.g. Repairs +
  /// Repair Times) so they don't all default open at once.
  final bool initiallyExpanded;
  /// Optional "promote this cue" action shown on each cue tile (e.g. turn a
  /// Damage Register cue into a damage item, per the standing cue-action
  /// principle in docs/context_cue_system_review.md — create new or merge
  /// into existing). Omitted (null) everywhere else; cue presentation
  /// outside the Damage Register needs no change.
  final void Function(SurveyorNote note)? onPromote;

  @override
  ConsumerState<ContextCuesPanel> createState() => _ContextCuesPanelState();
}

class _ContextCuesPanelState extends ConsumerState<ContextCuesPanel> {
  late bool _expanded = widget.initiallyExpanded;
  int _tab = 0; // 0 = active, 1 = ignored

  // ── Collapsed-state quick summary (docs/context_cue_system_review.md §3.3)
  // — case-screen presentation only, never fed into report content. Only
  // (re)generated while collapsed, and only when the active-cue set has
  // changed since the last summary, to avoid firing an AI call on every
  // rebuild.
  String? _summary;
  bool _summaryLoading = false;
  String? _summarizedSignature;

  bool _matchesScope(SurveyorNote n) => cueMatchesScope(
        n,
        widget.section,
        periodScope: widget.periodScope,
        itemScope: widget.itemScope,
      );

  /// §3.10/§3.11: expanded height scales with [itemCount] instead of always
  /// reserving the old flat 268 — a near-empty basket no longer eats the
  /// same space as a full one. Clamped so a long list scrolls inside a
  /// sane max rather than growing unboundedly.
  double _expandedHeight(int itemCount) {
    const chrome = 92.0; // header row + tab pills row + list padding
    const itemHeight = 46.0; // approx. one cue tile incl. its bottom margin
    const emptyStateHeight = 40.0;
    final contentHeight =
        itemCount == 0 ? emptyStateHeight : itemCount * itemHeight;
    return (chrome + contentHeight).clamp(150.0, 268.0);
  }

  String _signatureFor(List<SurveyorNote> notes) =>
      notes.map((n) => '${n.id}:${n.updatedAt.millisecondsSinceEpoch}').join('|');

  void _maybeFetchSummary(List<SurveyorNote> activeNotes) {
    if (_expanded || activeNotes.isEmpty || _summaryLoading) return;
    final sig = _signatureFor(activeNotes);
    if (sig == _summarizedSignature) return;
    _summaryLoading = true;
    ClaudeApi.draftCueQuickSummary(
      sectionLabel: widget.section.label,
      cues: activeNotes.map((n) => n.content).toList(),
    ).then((text) {
      if (!mounted) return;
      setState(() {
        _summary = text;
        _summarizedSignature = sig;
        _summaryLoading = false;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _summaryLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = sectionColor(widget.section);
    final notesAsync = ref.watch(surveyorNotesProvider(widget.caseId));
    final sectionNotes =
        notesAsync.value?.where(_matchesScope).toList() ?? [];

    final timelineAsync = ref.watch(timelineProvider(widget.caseId));
    final eventSourceKeys = timelineAsync.valueOrNull
            ?.map((e) => e.sourceKey)
            .whereType<String>()
            .toSet() ??
        <String>{};

    final activeNotes =
        sectionNotes.where((n) => n.priority != CuePriority.ignored).toList();
    final ignoredNotes =
        sectionNotes.where((n) => n.priority == CuePriority.ignored).toList();
    final visibleNotes = _tab == 0 ? activeNotes : ignoredNotes;

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeFetchSummary(activeNotes));
    final showSummary =
        !_expanded && activeNotes.isNotEmpty && (_summary?.isNotEmpty ?? false);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      // Collapsed state uses a minHeight, not a tight height: a fixed pixel
      // budget for the header row (44, then 48) kept recurring as a "few px"
      // RenderFlex overflow under larger system text-scale settings and
      // during the summary-text appear/disappear transition — the header's
      // real intrinsic height isn't a constant, it depends on font metrics
      // and text scale. minHeight lets the box grow to fit whatever the
      // header actually needs instead of clipping it (docs/TODO.md §3.9,
      // reopened 14 July 2026 walkthrough — live repro on Repair Periods).
      //
      // Expanded height (§3.10/§3.11, 13 July 2026) still needs a tight
      // value: the Expanded(ListView) inside requires a bounded max height
      // from its parent to divide space, and it scales with item count
      // instead of a flat 268 so a near-empty basket doesn't reserve the
      // same space as a full one.
      constraints: _expanded
          ? BoxConstraints.tightFor(
              height: _expandedHeight(visibleNotes.length))
          : BoxConstraints(minHeight: showSummary ? 62 : 48),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.label_outline, color: accent, size: 14),
                  ),
                  const SizedBox(width: 9),
                  // The title + "not allocated" pill + count badge cluster
                  // is wrapped in Expanded (with the pill's own text
                  // ellipsized) so it compresses instead of overflowing —
                  // on a narrow viewport "Context Cues" + "Not allocated to
                  // a period" + the Add button/chevron didn't all fit,
                  // confirmed via live widget-test reproduction on the
                  // Repair Periods screen's per-period unassigned-cue
                  // panels (docs/TODO.md §3.9, 9 July 2026).
                  Expanded(
                    child: Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Context Cues',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary),
                          ),
                        ),
                        if (widget.periodScope?.isUnassignedBucket == true) ...[
                          const SizedBox(width: 7),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Not allocated to a period',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning),
                              ),
                            ),
                          ),
                        ],
                        if (activeNotes.isNotEmpty) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${activeNotes.length}',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: accent),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _addNote(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        '+ Add',
                        style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.0 : 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_up,
                        color: AppColors.textTertiary, size: 18),
                  ),
                ],
              ),
            ),
          ),

          // ── Collapsed-state quick summary (§3.3) ──────────────────────
          if (showSummary)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                _summary!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                    height: 1.3),
              ),
            ),

          // ── Tab bar + list ───────────────────────────────────────────
          if (_expanded) ...[
            // Tab pills
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Row(
                children: [
                  _CueTabPill(
                    label: 'Active',
                    count: activeNotes.length,
                    selected: _tab == 0,
                    accent: accent,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  const SizedBox(width: 6),
                  _CueTabPill(
                    label: 'Ignored',
                    count: ignoredNotes.length,
                    selected: _tab == 1,
                    accent: AppColors.textSecondary,
                    onTap: () => setState(() => _tab = 1),
                  ),
                ],
              ),
            ),

            // Notes list
            Expanded(
              child: notesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (_) => visibleNotes.isEmpty
                    ? _CuesPanelEmpty(
                        section: widget.section,
                        isIgnoredTab: _tab == 1,
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        itemCount: visibleNotes.length,
                        itemBuilder: (_, i) => _CuePanelTile(
                          note: visibleNotes[i],
                          accent: _tab == 0 ? accent : AppColors.textSecondary,
                          onEdit: () => _editNote(context, visibleNotes[i]),
                          onDelete: () => ref
                              .read(surveyorNotesProvider(widget.caseId)
                                  .notifier)
                              .delete(visibleNotes[i].id),
                          onPromote: widget.onPromote == null
                              ? null
                              : () => widget.onPromote!(visibleNotes[i]),
                          hasEvent: eventSourceKeys
                              .contains(cueEventSourceKey(visibleNotes[i].id)),
                          onCreateEvent: () => convertCueToTimelineEvent(
                            context,
                            ref,
                            caseId: widget.caseId,
                            note: visibleNotes[i],
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _addNote(BuildContext context) =>
      _openSheet(context, existing: null);

  void _editNote(BuildContext context, SurveyorNote note) =>
      _openSheet(context, existing: note);

  void _openSheet(BuildContext context, {SurveyorNote? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CuePanelSheet(
        section: widget.section,
        existing: existing,
        routingLinkType: widget.routingOptions != null &&
                widget.routingOptions!.length > 1
            ? widget.routingLinkType
            : null,
        routingOptions:
            widget.routingOptions != null && widget.routingOptions!.length > 1
                ? widget.routingOptions
                : null,
        initialRoutedId: existing != null &&
                existing.linkedToType == widget.routingLinkType
            ? existing.linkedToId
            : null,
        onPromote: existing == null || widget.onPromote == null
            ? null
            : () {
                Navigator.pop(context);
                widget.onPromote!(existing);
              },
        onSave: (content, priority, nature, weight, origin, routedId) async {
          final notifier =
              ref.read(surveyorNotesProvider(widget.caseId).notifier);
          final scope = widget.periodScope;
          final item = widget.itemScope;
          final String? linkedToType;
          final String? linkedToId;
          if (scope != null && !scope.isUnassignedBucket) {
            linkedToType = repairPeriodLinkType;
            linkedToId = scope.periodId;
          } else if (widget.routingOptions != null &&
              widget.routingOptions!.length > 1) {
            // Multi-item routing (e.g. multiple occurrences) — only scoped
            // if the surveyor actually picked one; otherwise stays
            // unscoped, same as before this picker existed.
            linkedToType = routedId != null ? widget.routingLinkType : null;
            linkedToId = routedId;
          } else {
            linkedToType = item?.linkedToType;
            linkedToId = item?.linkedToId;
          }
          if (existing == null) {
            await notifier.add(
              caseId:            widget.caseId,
              content:           content,
              priority:          priority,
              natureOfContent:   nature,
              evidentiaryWeight: weight,
              origin:            origin,
              caseSection:       widget.section,
              linkedToType:      linkedToType,
              linkedToId:        linkedToId,
            );
          } else {
            await notifier.editNote(
              existing.id,
              content:           content,
              priority:          priority,
              natureOfContent:   nature,
              evidentiaryWeight: weight,
              origin:            origin,
              caseSection:       widget.section,
              linkedToType:      linkedToType,
              linkedToId:        linkedToId,
            );
          }
        },
      ),
    );
  }
}

// ── Tab pill ──────────────────────────────────────────────────────────────────

class _CueTabPill extends StatelessWidget {
  const _CueTabPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? accent : accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? accent : accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : accent),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : accent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _CuePanelTile extends StatelessWidget {
  const _CuePanelTile({
    required this.note,
    required this.accent,
    required this.onEdit,
    required this.onDelete,
    this.onPromote,
    this.hasEvent = false,
    this.onCreateEvent,
  });

  final SurveyorNote note;
  final Color accent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onPromote;
  /// Whether a Timeline event already links back to this cue via
  /// `sourceKey` (15 July 2026 walkthrough §16 — "Event created" pill).
  final bool hasEvent;
  final VoidCallback? onCreateEvent;

  @override
  Widget build(BuildContext context) {
    final nature = note.natureOfContent;
    final natureColor = nature != null ? natureOfContentColor(nature) : accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      if (nature != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: natureColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            nature.label,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: natureColor),
                          ),
                        ),
                        const SizedBox(width: 7),
                      ],
                      Flexible(
                        child: Text(
                          note.content,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: accent == AppColors.textSecondary
                                  ? AppColors.textTertiary
                                  : AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onPromote != null)
                Tooltip(
                  // 14 July 2026 walkthrough §5 Q2 — "not visible/
                  // discoverable" that this icon promotes the cue; it had
                  // no label at all. A full redesign is explicitly
                  // deferred by the surveyor (not urgent, may resolve
                  // itself once cue-processing UX gets addressed more
                  // broadly per §16), so this is a small, safe addition
                  // rather than reworking the control itself.
                  message: 'Promote to damage item',
                  child: GestureDetector(
                    onTap: onPromote,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.arrow_circle_right_outlined,
                          size: 15, color: accent),
                    ),
                  ),
                ),
              if (hasEvent)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.midBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_available,
                            size: 10, color: AppColors.midBlue),
                        SizedBox(width: 3),
                        Text('Event',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.midBlue)),
                      ],
                    ),
                  ),
                )
              else if (onCreateEvent != null)
                GestureDetector(
                  onTap: onCreateEvent,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.event_outlined,
                        size: 15, color: accent),
                  ),
                ),
              GestureDetector(
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.close,
                      size: 13, color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Quick add/edit sheet ──────────────────────────────────────────────────────

typedef _CueSaveCallback = Future<void> Function(
  String content,
  CuePriority priority,
  NatureOfContent? nature,
  EvidentiaryWeight? weight,
  CueOrigin? origin,
  String? routedId,
);

class _CuePanelSheet extends StatefulWidget {
  const _CuePanelSheet({
    required this.section,
    required this.onSave,
    this.existing,
    this.onPromote,
    this.routingLinkType,
    this.routingOptions,
    this.initialRoutedId,
  });

  final CaseSection section;
  final SurveyorNote? existing;
  final _CueSaveCallback onSave;
  /// Duplicated here from the list tile (14 July 2026 walkthrough — the
  /// list tile's promote control was "too tiny/hard to hit"), positioned
  /// next to "Tagged: X" so it's reachable right where a cue is being
  /// allocated, not just from the collapsed list.
  final VoidCallback? onPromote;
  /// See [ContextCuesPanel.routingLinkType] — non-null (with >1
  /// [routingOptions]) shows a picker for which item this cue routes to.
  final String? routingLinkType;
  final List<MapEntry<String, String>>? routingOptions;
  final String? initialRoutedId;

  @override
  State<_CuePanelSheet> createState() => _CuePanelSheetState();
}

class _CuePanelSheetState extends State<_CuePanelSheet> {
  late final TextEditingController _ctrl;
  late CuePriority _priority;
  NatureOfContent? _nature;
  EvidentiaryWeight? _weight;
  CueOrigin? _origin;
  String? _routedId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.existing?.content ?? '');
    _priority = widget.existing?.priority ?? CuePriority.normal;
    _nature = widget.existing?.natureOfContent;
    _weight = widget.existing?.evidentiaryWeight;
    _origin = widget.existing?.origin;
    _routedId = widget.initialRoutedId;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = sectionColor(widget.section);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.existing == null
                            ? 'Add Context Cue'
                            : 'Edit Context Cue',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                      Text(
                        'Tagged: ${widget.section.label}',
                        style: TextStyle(fontSize: 11, color: accent),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (widget.onPromote != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      color: accent,
                      tooltip: 'Promote',
                      onPressed: widget.onPromote,
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style:
                            TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Routing picker (e.g. which occurrence, when a case has
            // more than one) — surfaced right where the cue is being
            // allocated (14 July 2026 walkthrough §4).
            if (widget.routingOptions != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Route to',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary)),
                    const SizedBox(height: 5),
                    CueChipRow<String>(
                      values: widget.routingOptions!.map((o) => o.key).toList(),
                      selected: _routedId,
                      labelOf: (id) => widget.routingOptions!
                          .firstWhere((o) => o.key == id)
                          .value,
                      colorOf: (_) => accent,
                      onTap: (id) => setState(
                          () => _routedId = _routedId == id ? null : id),
                      allowDeselect: true,
                    ),
                  ],
                ),
              ),

            // ── Priority — first decision, positioned at the top ────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CueChipRow<CuePriority>(
                values: CuePriority.values,
                selected: _priority,
                labelOf: (p) => p.label,
                colorOf: _priorityColor,
                onTap: (p) => setState(() => _priority = p),
                allowDeselect: false,
              ),
            ),
            const SizedBox(height: 12),

            // Cue text + its origin (source doc/page), shown together, not
            // buried below the classification chips (14 July 2026
            // walkthrough — this is what actually informs classification).
            if (widget.existing?.source != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.midBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    const Icon(Icons.description_outlined,
                        size: 12, color: AppColors.midBlue),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        widget.existing!.source!,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.midBlue,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                maxLines: 5,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter context cue…',
                  hintStyle: const TextStyle(
                      color: AppColors.textTertiary, fontSize: 13),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: accent, width: 1.5)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 14),

            // Further classification skipped once Ignored — same reasoning
            // as the standalone Advice-to-Owner editor sheet.
            if (_priority != CuePriority.ignored) ...[
              LabeledCueChipRow<NatureOfContent>(
                label: 'Nature of content',
                values: NatureOfContent.values,
                selected: _nature,
                labelOf: (n) => n.label,
                colorOf: natureOfContentColor,
                onTap: (n) =>
                    setState(() => _nature = _nature == n ? null : n),
              ),
              const SizedBox(height: 10),
              LabeledCueChipRow<EvidentiaryWeight>(
                label: 'Evidentiary weight',
                values: EvidentiaryWeight.values,
                selected: _weight,
                labelOf: (w) => w.label,
                colorOf: evidentiaryWeightColor,
                onTap: (w) =>
                    setState(() => _weight = _weight == w ? null : w),
              ),
              const SizedBox(height: 10),
              LabeledCueChipRow<CueOrigin>(
                label: 'Origin',
                values: CueOrigin.values,
                selected: _origin,
                labelOf: (o) => o.label,
                colorOf: cueOriginColor,
                onTap: (o) =>
                    setState(() => _origin = _origin == o ? null : o),
              ),
            ],
            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        widget.existing == null ? 'Save Cue' : 'Update Cue',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _priorityColor(CuePriority p) => switch (p) {
        CuePriority.important => const Color(0xFFDC2626),
        CuePriority.normal    => const Color(0xFF4A7A5A),
        CuePriority.ignored   => const Color(0xFF9E9C96),
      };

  Future<void> _save() async {
    final content = _ctrl.text.trim();
    if (content.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
          content, _priority, _nature, _weight, _origin, _routedId);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Shared chip-row helpers ─────────────────────────────────────────────────

class LabeledCueChipRow<T> extends StatelessWidget {
  const LabeledCueChipRow({
    super.key,
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.colorOf,
    required this.onTap,
  });

  final String label;
  final List<T> values;
  final T? selected;
  final String Function(T) labelOf;
  final Color Function(T) colorOf;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary)),
          const SizedBox(height: 5),
          CueChipRow<T>(
            values: values,
            selected: selected,
            labelOf: labelOf,
            colorOf: colorOf,
            onTap: onTap,
            allowDeselect: true,
          ),
        ],
      ),
    );
  }
}

class CueChipRow<T> extends StatelessWidget {
  const CueChipRow({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.colorOf,
    required this.onTap,
    required this.allowDeselect,
  });

  final List<T> values;
  final T? selected;
  final String Function(T) labelOf;
  final Color Function(T) colorOf;
  final ValueChanged<T> onTap;
  final bool allowDeselect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: values.map((v) {
        final isSelected = selected == v;
        final color = colorOf(v);
        return GestureDetector(
          onTap: () => onTap(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? color : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: color.withValues(alpha: isSelected ? 1.0 : 0.25)),
            ),
            child: Text(
              labelOf(v),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : color),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _CuesPanelEmpty extends StatelessWidget {
  const _CuesPanelEmpty({required this.section, this.isIgnoredTab = false});
  final CaseSection section;
  final bool isIgnoredTab;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Text(
        isIgnoredTab
            ? 'No ignored cues for ${section.label}.'
            : 'No context cues for ${section.label} yet. Tap + Add to capture a cue.',
        style: const TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
            fontStyle: FontStyle.italic),
      ),
    );
  }
}
