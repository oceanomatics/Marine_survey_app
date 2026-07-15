-- 056_vessel_screw_count.sql
--
-- 14 July 2026 walkthrough §3 Q5: Propulsion Particulars reorganised into
-- three independent fields — number of screws / type of prime mover
-- (motor, steam, electric) / thruster type (fixed pitch, variable pitch,
-- azipods, waterjet) — replacing the old single "Propulsion Type" chip set
-- that conflated screw count with prime mover ("single screw, motor
-- driven"...), the "Propeller / Thruster Type" picker that duplicated screw
-- count again, and the separate "Propulsion Drive Type" chip set.
--
-- propulsion_type and propeller_type columns are reused (relabelled to
-- prime-mover-type and thruster-type respectively) rather than replaced —
-- only screw count is new. propulsion_drive_type is left in place, unused
-- going forward; not worth a destructive drop for a pre-production app.
--
-- Applied directly via Supabase Management API (see docs/TODO.md live
-- progress log for the exact statement run).

ALTER TABLE vessels
  ADD COLUMN IF NOT EXISTS screw_count integer;
