# Report Builder — modifications to meet the house style

Compiled 17 July 2026 from **docs/house_style.md** (Marsh Maritime H&M
templates) + 20 in-app reports on the Report Builder *editor*. This is the
change list for aligning the builder's structure, drafting prompts and export
to the house style. Report numbers (R#) reference the 17 Jul debug_feedback
notes.

## Format strategy (17 July, surveyor)

The app already carries a **multi-format** system (`case.outputFormat` — abl /
nordic / …; prompts take a `reportFormat`). The surveyor is consolidating an
**"Oceanoservices"** ideal format (house_style.md is that template, being
refined). Plan:
1. Build the house-style rules against **Oceanoservices as the canonical
   format** first (section set, purpose lines, templates, prompts).
2. **Then remap** to the other formats (ABL/Nordic/Marsh/etc.) — same section
   machinery, format-specific wording/section-order/branding.
Note: the test cases (e.g. MINRES ODIN) were drafted in an unknown/mixed format
— don't assume; treat Oceanoservices as the source of truth and migrate.

## A. Global drafting rules (apply to every section)

1. **Italic purpose line under every section heading.** One italic present-tense
   sentence starting "This section …" (12–25 words), before any content.
   House-style §"Italic purpose line" gives the exact wording per section — seed
   these as the section templates.
2. **Empty-section handling** (R15, R18, R19). A section with no data must NOT be
   left as an empty/omitted paragraph. Either (a) drop it if genuinely optional,
   or (b) emit an explicit negative statement, e.g. *"No indication was given
   that additional expenses were engaged to reduce delay."* Make this a
   first-class drafting rule + per-section "no-data sentence".
3. **Calibrated hedging** (house-style GLOBAL RULE). Match verb to evidence:
   observed = stated as fact; reported = attributed; inferred = one calibrated
   hedge; predicted = hedge + dependency. One hedge per proposition, never
   stacked. Reserve "is consistent with" for the damage→mechanism link. Bake
   this into the Cause / Damage / Closing prompts.
4. **"Subject vessel"** voice + **reported register** for Background/Occurrence
   (surveyor's own voice only from Damage Description onward).
5. **Without-prejudice** framing on findings/approved costs where appropriate.

## B. Missing / needed sections (structural)

6. **Introduction / Scope of Work** (R14) — add, using house-style §1 template:
   "At the request of [UNDERWRITER] … attended [VESSEL/LOCATION] on [DATE(S)] to
   examine and report on [NATURE_OF_DAMAGE] sustained on [DOL]."
7. **Complete Chronology of Events / Vessel's Movements** (R4) — a proper dated
   table section, placed immediately before Background (or after §5 Class &
   Statutory); it is the tabular skeleton the Background/Occurrence expand.
8. **Class & Statutory Certification** (R1) — currently omits: statutory review,
   **detentions (or "none")**, **ISM status**, **ISPS status**. Add these
   (ties to the batched Certs/PSC-detentions + Equasis work).
9. **Reviewer provision** (R7) — reserve the Reviewer/QC block even when a
   reviewer isn't picked yet; and fix its placement ("between the two blocks").
10. **Waiver** (R8/R9) — auto-generate from the ticks of the relevant sections
    using the legal-clauses library (docs/legal_clauses.md), not free text.

## C. Section drafting prompts (rewrite to house style)

11. **Occurrence Narrative** — the big one; already spec'd in
    **docs/occurrence_narrative_spec.md**. House-style confirms/extends it:
    - Open "It was reported by the vessel's Master that …" (or C/E, owner's rep).
    - **Three-act = Prelude / Event / Aftermath** — exactly the before/incident/
      aftermath cue forking. Keep reported register throughout.
    - **Data-capture rule**: consume EVERY hard datum + cue first (times, ISO
      positions, named persons by rank, equipment states, alarms+responses,
      weather actual-vs-forecast, cascading failures, notifications w/ refs);
      absent fact → "Not confirmed", never invented.
12. **Background** — narrative, ends *just before* the incident (role/employment
    → specific voyage/operation → immediate circumstances). Optional source
    attribution opener when drawn from an owner/third-party report.
13. **Damage Description** — surveyor's own voice; per-object bulleted findings
    (component + identifier + condition/mode + measurements), one bullet per
    object, never merged; basis-of-findings opener; consequential-damage line;
    absent field → "Not confirmed". Consume all structured damage fields first.
14. **Cause Consideration** — surveyor's reasoned opinion, every causal statement
    anchored to a Damage-Description finding or a cited source; certainty ladder
    (preliminary / qualified / firm), always framed as the surveyor's opinion.
15. **Repair Times** — per-period nesting (Period → Occurrence → average vs
    Owners'), **no grand total across periods**; opinion framing ("had the
    repairs been carried out separately, the following periods would have been
    required"); Owners' own work introduced separately.

## D. Section-specific fixes

16. **A section repeats "Available Documentation"** (R3) — evaluate merging the
    two.
17. **Repair-times formatting** (R10): remove the literal word "days"; put the
    value inline with the figure. (R12): a shown total = afloat + drydock +
    owners days — reconcile with the "no grand total" rule (it's a per-period
    breakdown, not a cross-period sum).
18. **Documentation table** (R5): drop the oversized "number" column (low value);
    **later**, when a file is in an annexure, render it as a **hyperlink to the
    annexure** rather than a plain number.
19. **Missing AI-draft buttons** (R16, R18) — some sections have no "AI draft"
    action; add them so every draftable section routes through the AI task queue.

## E. Export (docx) — tables as tables

20. Vessel's Particulars (2-col table), Attending Representatives (Name/Company/
    Function table), Chronology, Repair Times, compartment matrices, and any
    Analyst-inserted table must export as **real Word tables**, not flattened
    text (ties to the batched "Analyst → export tables as tables"). Section §3
    Vessel's Particulars has **no lead sentence** — heading then table.

## Sequencing note

This overlaps heavily with already-batched items: occurrence-narrative feature,
Certs/PSC-detentions, Equasis autopop, titles, table-export. Suggest building the
**house-style section framework** (italic purpose lines, empty-section handling,
per-section templates + no-data sentences, missing sections) as one pass, then
the **drafting-prompt rewrites** (occurrence → cause → damage → background) as a
second pass, since they share the data-capture/hedging machinery.
