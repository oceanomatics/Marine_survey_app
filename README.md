# Marine Survey App — Oceanomatics Pty Ltd

Flutter + Supabase offline-first marine survey platform.

---

## Current status

Phase 1 testing — single-user deployment (ABL Group internal).

---

## Commercial deployment — TODO (pre-launch)

Before rolling out to other companies the following needs to be designed and built:

### Multi-tenancy
- Introduce `organisations` table; every case, vessel, document etc. gets an `org_id`
- Apply Row Level Security policies on all tables so companies are fully isolated
- User onboarding / invite flow per organisation
- Admin screen to manage organisations and users (ABL ops use)

### AI cost attribution (Case Analyst)
- Create `analyst_usage` table: `case_id, user_id, org_id, model, input_tokens, output_tokens, created_at`
- Update `case-analyst` Edge Function to insert a row after each Anthropic call
- Build a usage report view (per company, per case, per month)
- Decide on billing model: include in service fee vs. pass-through at cost

### Secrets / configuration per deployment
- Each deployment needs its own Supabase project (or shared project with org isolation)
- `ANTHROPIC_API_KEY` managed as a Supabase secret — one key per deployment or shared with org-level metering

### Other pre-launch items
- Terms of service and data processing agreement per client
- Backup / export policy for case data
- Audit log for destructive operations (delete case, delete document, etc.)

---

## Architecture notes

- **Backend**: Supabase (Postgres + Auth + Storage + Edge Functions)
- **Offline cache**: SQLite via sqflite, sync_status column (`synced` | `pending_upsert` | `pending_delete`)
- **State**: Riverpod AsyncNotifierProviderFamily — SQLite shown immediately, Supabase synced in background
- **AI**: Claude Haiku 4.5 via `case-analyst` Edge Function; context assembled from vessel, occurrences, damage register, surveyor notes
