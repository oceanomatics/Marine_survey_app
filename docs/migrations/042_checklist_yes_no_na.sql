-- 042_checklist_yes_no_na.sql
--
-- Live audit finding (13 July 2026): many real checklist items (per Andy's
-- MM09 attendance-advice list) are document/access requests where "did we
-- get/see this" genuinely has three answers — Yes, No (still outstanding,
-- needs follow-up), or N/A (not fitted/not issued/not applicable) — not a
-- binary done/not-done tick. `checklists` has zero live rows (confirmed),
-- so this is a clean schema replacement, no data migration needed.
--
-- `response` replaces `completed` as the source of truth. NULL = not yet
-- answered. 'yes' = done. 'no' = answered but still outstanding (counts
-- against progress, same as unanswered — a real gap the surveyor still
-- needs to chase). 'na' = excluded entirely from progress/stage totals.
-- `completed_at`/`completed_by` are kept (renamed in intent, not in
-- column name, to avoid an unnecessary second migration) — they now record
-- when/who last set *any* response, not just a "yes".
CREATE TYPE checklist_response_enum AS ENUM ('yes', 'no', 'na');

ALTER TABLE checklists ADD COLUMN response checklist_response_enum;
ALTER TABLE checklists DROP COLUMN completed;
