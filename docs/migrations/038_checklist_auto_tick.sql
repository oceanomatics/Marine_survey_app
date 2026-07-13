-- 038_checklist_auto_tick.sql
--
-- TODO.md §4.4 — Checklist Auto-Ticking. Reuses the existing
-- checklists.linked_section column (already used for "tap to navigate to
-- the relevant screen") as the auto-tick rule key too — a checklist item
-- whose linked_section matches one of case_completeness.dart's section
-- keys (e.g. 'vessel_particulars', 'damage_description') auto-ticks once
-- that section's data condition is met.
--
-- auto_tick_attempted marks "the system has already acted on this item
-- once" so a surveyor manually un-ticking an auto-ticked item is never
-- immediately re-ticked by the next evaluation pass (the underlying data
-- condition is still true) — auto-tick is a one-shot nudge, not a
-- perpetually-enforced state. Items ticked manually before their condition
-- was ever met never set this (evaluation only ever looks at incomplete
-- items), which is fine — completed is already true either way, so
-- evaluation has nothing further to do regardless of this flag's value.
ALTER TABLE checklists
  ADD COLUMN IF NOT EXISTS auto_tick_attempted boolean NOT NULL DEFAULT false;
