-- 024_cue_pending_review.sql
--
-- AI-extraction auto-classification (docs/context_cue_system_review.md
-- §3.5): extraction now suggests a case_section/origin per cue, but
-- nothing is treated as confirmed until a human reviews it. `pending_review`
-- marks a cue as an unconfirmed AI suggestion — surfaced in a dedicated
-- "Suggested" tab in the Context Cue Manager, and excluded from feeding any
-- AI-drafted report section until cleared (confirmed or edited).

ALTER TABLE surveyor_notes ADD COLUMN pending_review boolean NOT NULL DEFAULT false;
