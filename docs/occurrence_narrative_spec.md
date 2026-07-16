# Occurrence narrative — structured drafting from forked cues

Spec agreed in the 16 July 2026 manual sweep (occurrence / AI-draft screen).
Not yet built. This replaces the current free-form occurrence narrative draft.

## The idea

A context cue allocated to the **Occurrence** section forks into one of three
phases, and the AI narrative is drafted from those phases **in order**:

1. **Activities immediately before the incident** (pre-event context)
2. **Information about the incident** (the event itself)
3. **The aftermath** (post-event)

## Narrative format (hard requirements)

Always open with this exact structure and voice:

> "It was reported by the **[Master / Chief Engineer / …]** that on **[date of
> casualty]**, the **subject vessel** was [pre-incident activity] … [the
> incident] … [the aftermath]."

- **Always** refer to the vessel as "**the subject vessel**" (after the first
  naming), never by name repeatedly.
- The **aftermath is a first-class phase** — never dropped (report #1: "the
  narrative does not take into consideration the aftermath").
- **Concise** — this is a summary, not a diary; avoid convolution (report #6).
- No cause/causation here (unchanged — that's a separate section).

## Implementation hint (surveyor's steer, 16 July)

Mirror the **existing repair-period cue scoping** — "that works well for repair
period, so implement the same for occurrence (before incident / incident /
aftermath)". The repair-period per-period cue scoping is the proven pattern to
copy for the three occurrence phases (see repair_periods_screen.dart / the
per-period cue scoping in the cue model). Reuse it rather than inventing a new
mechanism.

## Decisions (locked)

- **Reported by** = an **attendee picker** on the occurrence (lists the case's
  attendees + their roles: Master, Chief Engineer, etc.). The chosen
  attendee's role fills the "[role]" slot. New occurrence field:
  `reported_by_attendee_id` (FK → attendees).
- **Cue forking** = **surveyor picks, AI pre-sorts**. When a cue lands on
  Occurrence, the AI suggests a phase; the surveyor can override via a 3-way
  selector on the cue. New cue field: `occurrence_phase`
  (before | incident | aftermath), only meaningful for occurrence-section cues.

## Build checklist

- [ ] Schema: `occurrences.reported_by_attendee_id` (uuid FK → attendees).
- [ ] Schema: cue/`surveyor_notes` gains `occurrence_phase` text
      (before/incident/aftermath), nullable.
- [ ] Occurrence editor: "Reported by" picker (from `attendeesProvider`).
- [ ] Occurrence Context Cues panel: group by the 3 phases; per-cue 3-way
      phase selector; AI pre-sort on cue creation/allocation.
- [ ] **Each phase bucket has its own "Add cue" button** — the surveyor must be
      able to hand-enter cues into any phase, not only AI-extracted ones. Leave
      room for manual additions.
- [ ] AI pre-sort: classify each new occurrence cue into a phase (small call,
      route through aiTasksProvider).
- [ ] `ClaudeApi.draftOccurrenceNarrative` rewrite: take reporter role + the
      three ordered phase buckets; enforce the opening formula, "subject
      vessel", aftermath inclusion, and concision.

## Presentation: capitalise voice-inserted cues

Every cue inserted by voice (STT) must have its **first character
capitalised**, even if the transcript omitted it — dictation frequently starts
lowercase and it looks unpolished. Apply at the point a voice transcript
populates a cue's text (and reasonably, any voice-dictated cue/note field).
Small, high-value presentation win; can ship independently of the feature above.

## Related quick UX fixes (same screen, can ship independently)

- **Remove the Active / Ignored toggle** from the per-section Context Cues
  panel (`ContextCuesPanel`) — an ignored cue shouldn't reach a section panel
  at all, and you never ignore a brand-new cue (reports #3/#4/#7/#8). Ignoring
  still lives on the Notes screen's Ignored tab. NOTE: `ContextCuesPanel` is
  shared across sections — removing the toggle affects all of them (intended).
- **Occurrence Save** is hidden → adopt the standard green **SaveBar-on-change**
  convention used elsewhere (report #2).
