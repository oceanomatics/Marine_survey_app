# Manual sweep — resume point (paused 16 July 2026)

Screen-by-screen manual sweep of the app on the RugKing tablet, driven by
in-app bug reports (the `debug_feedback` table). Fixed genuine bugs live;
batched enhancements for a focused build pass. This file is the resume anchor.

## How to resume

- Pull new reports: `debug_feedback` table via the Management API, ordered by
  `created_at desc`. As of 16 July it also has **`screenshot_instant_path`** —
  the tap-time still (catches transient errors the annotated shot missed).
  Screenshots live in the private `debug-feedback` storage bucket (sign a URL
  with the service_role key).
- Test case: **SI-M53-055873 – MINRES ODIN – H&M** (`3a0b4bcc-…`), fully
  populated. Pangaea (`5982c2c8-…`) and others also have data.
- Build/install: `flutter build apk --debug` + `adb install -r` (persistent
  debug build already on the tablet).

## Sweep progress: 11 / 18 screens

Done (1–11): Launch/Cases · Case Home · Vessel · Parties · Attendance ·
Certificates & Class · Occurrence · Notes · Case Timeline · Correspondence/
Inbox · Photos.

**Next up — Screen 12: Checklist** (Y/N/N-A, auto-tick, phase tabs), then
13 Case Analyst · 14 Interviews/Quick Capture · 15 Repair Periods ·
**16 Report Builder** (the big AI-draft convergence point) · 17 Accounts ·
18 API Usage.

## Fixed & committed this session (10 bug fixes)

- Back buttons on top-level go()-routed screens (`cfe2ecf`)
- Notes rename (undo "Advice to Owner") + readable debug feedback theme (`36a3cc8`)
- Vessel: screws field width, cert-link order, tab rename, machinery repeat
  under Previous Work (`7eb06be`)
- Attendances: Follow-up control moved inline; stakeholder picker as searchable
  sheet (`1145bcf`)
- Certificates: class-condition metadata overflow Row→Wrap (`e094a94`)
- **Parties import merge** — no longer skips existing stakeholders, fills in
  new email/company/phone (`7ee1f91`) [flagged most important]
- **Debug reporter tap-time capture** — catches transient errors (`3d34402`)
- Earlier same day: Capt title order, §25 usage-by-case, biometric grace,
  Pangaea attendance data migration (auto-created attendance for 5 orphans).

## Batched backlog (build in focused passes — NOT yet done)

### Bugs
- **Case-title rebuild drops the occurrence brief on vessel/component rename**
  (regression — must re-append occurrence brief).
- `/inbox` HTML entities (`&#39;`) + accented names (`Wánk`) not decoded.
- `/account` Drive Base Folder row opens the API-key editor (wrong wiring).
- Edit Cue sheet indentation wrong (Nature/Evidentiary/Origin indented; first
  chip clipped).
- Correspondence "badge cropped"; Parties "big gap not warranted".
- **Cloud storage (Drive) upload error** — awaiting re-capture with the new
  instant-shot to read the actual message. **Diagnose first thing.**

### Enhancements
- **Occurrence narrative feature** — full spec in
  [occurrence_narrative_spec.md](occurrence_narrative_spec.md): forked cues
  (before/incident/aftermath, mirror repair-period cue scoping), reported-by
  attendee picker, manual Add-cue per phase, prompt rewrite ("It was reported
  by the [role] that on [date] the **subject vessel** was…", aftermath,
  concise), voice-capitalize cues. Plus quick UX: remove the Active/Ignored
  toggle from `ContextCuesPanel`; Occurrence SaveBar.
- **Certificates & Class**: full condition text; related-to-incident pill;
  Issued-on + Status(open/closed) fields; certificate thumbnail + viewer from
  doc vault + source label; Port State Control detentions list (from Equasis).
- **Titles** (before report builder): flag missing in UI; deduce on add
  (Master→Capt., else first-name); extract titles for stakeholders.
- **Correspondence**: case-filtered inbox (name + tech-file-no across title &
  content, minus already-imported) + new-mail count badge (repeat on the Mail
  rail icon); auto-queue extraction for unextracted mail (surveyor just
  reviews); clearer "AI extracted" indicator.
- **Photos**: drop By Visit/By Inspection tabs; group by surveyor vs
  third-party (divers/crew) or differentiate at import; a field duplicates the
  caption.
- **Parties**: company-name resolution inconsistent; redundant "(Assured)"
  label; review "parties" vs "stakeholders" terminology.
- **Vessel**: auto-fill Build Country from Equasis (D); auto-fill machinery
  Unit/DG3 from extracted docs (E) — both via the extraction pipeline.

## Suggested order for the build pass

1. Quick independent wins: voice-capitalize, remove Active/Ignored toggle,
   Edit-Cue indent, Occurrence SaveBar, title-regression fix, badge/gap.
2. The **Occurrence narrative** feature (spec ready) — likely overlaps with the
   Report Builder (screen 16), so finish the sweep first if possible.
3. Certs enhancements (share schema work).
4. Titles feature (before report builder is finished).
5. Correspondence enhancements (filtered inbox + auto-extract).
6. Equasis/extraction autopop (D/E) — group with the extraction work.
