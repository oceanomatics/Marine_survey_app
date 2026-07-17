# Accounts & Cost — reconciliation rework

Compiled 17 July 2026 from 14 in-app reports on the accounting side (Cost
Estimate / Accounts Summary / Accounts screen + repair budget). The accounting
UI exists and imports invoices; the problems are structure + reconciliation.

## The core problem (from the MINRES ODIN / Pangaea data)

The Accounts summary shows per-occurrence totals (Occ.1 AUD 3,400 + Occ.2 AUD
40,976 ≈ 44k) but **Total (gross) AUD 2,008,013** — they don't reconcile
because **32 lines are pending review** and **32 lines are not allocated to an
occurrence**, and none of that is surfaced in the summary. Separately, the
**estimates** entered on the repair budget / Cost Estimate tab are **not carried
through** to the summary at all.

## Modifications

1. **Merge "Cost Estimate" and "Accounts Summary"** (R3, R12). On Case Home they
   are two separate cards that open the *same* two-tab screen (Cost Estimate /
   Accounts) — redundant. Collapse to a single entry point.
2. **Reconciling summary** (R1, R5) — "make the summary match". The per-occurrence
   allocated total + **unreviewed** + **rejected** + **unallocated** must add up
   to Total (gross). Surface those buckets in the summary (they're currently
   hidden as "32 lines pending review / not allocated"), so the numbers tie out.
   List unreviewed and rejected items, don't just drop them from the maths.
3. **Carry estimates through** (R8, R10). Estimates entered on the repair budget
   ("here I have estimates … but not carried to the budget estimate") and the
   Cost Estimate tab must flow into the summary. Show **Estimate vs Actual**.
4. **Summary structure** (R3) — after the merge: one **Estimate** section (a
   total figure is enough) + the **complete accounts summary** (actuals,
   reconciled per #2).
5. **Clarity pass** (R6) — "give me something clearer": the summary needs a
   cleaner layout that makes the estimate → submitted → reviewed/approved →
   allocated flow legible at a glance.
6. **Too many AI icons** (R14) — the Accounts app bar shows two sparkle/AI icons
   (plus refresh); remove the redundant one.

## Notes / links
- Ties to the batched **FX** item (budget total showed USD without converting
  AUD items) and the **Repair Periods** cost-preset + currency work.
- The report-builder **Repair Cost** / **Accounts** sections (house style) will
  consume this reconciled summary — build the reconciliation first.
- Approval states in play: Approved / Pending Review / Rejected / Unallocated —
  and recall the surveyor's earlier note (§23) that approval is per *invoice*,
  and the account is a mixture of all invoices' states.
