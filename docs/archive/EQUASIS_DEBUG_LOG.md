# Equasis Integration — Debug Log

Running log of every attempt to fix `lib/core/api/equasis_service.dart`
(login + ship-folder PDF fetch from equasis.org). Kept because we've gone in
circles on this a few times — read this before trying something new, so we
don't re-test a hypothesis that's already been ruled out.

**Append to this file on every attempt.** Don't delete earlier entries even
after a fix — if it turns out not to be the real fix, the history matters.

## Constraints on how this gets debugged

- For attempts 1–5, nobody on the dev side had valid Equasis credentials —
  those were informed by: (a) the surveyor's own device logs, (b) live
  unauthenticated `curl` probing of equasis.org, (c) a third-party
  reverse-engineered Equasis client on GitHub
  ([rhinonix/equasis-cli](https://github.com/rhinonix/equasis-cli)) — which
  turned out to be a **misleading** reference for the PDF-export step (see
  Attempt 6).
- The surveyor shared real credentials in-chat for Attempt 6, which let us
  test directly against a real authenticated session and get a fully
  verified answer instead of another guess. **Do not commit, log, or paste
  credentials into any file in this repo** — Attempt 6 below deliberately
  omits them; if you need to re-test live, get fresh credentials from the
  surveyor out-of-band rather than reusing anything written down here.
- Equasis signals success/failure via an embedded HTML modal
  (`id="warning"`, message text inside `<div class="modal-body"><p>...`),
  **not** via HTTP status/redirects. Always check the modal text before
  trusting a 200 response.

## Confirmed facts (don't re-derive these)

- Login endpoint: `GET`/`POST` `/EquasisWeb/authen/HomePage?fs=HomePage` —
  same URL for both steps.
- Login POST fields: `j_email`, `j_password`, `submit` (matches the real
  form/button; earlier code also sent `fs=Login`/`pageName=Login`, which are
  **not** part of the real form and conflict with the `fs=HomePage` already
  on the URL).
- Session cookie: `JSESSIONID` only — no CSRF/hidden token on the login form.
- **Selecting a ship** (the step that was broken through attempts 1–5): POST
  `/EquasisWeb/restricted/ShipInfo?fs=Search` with `P_IMO={imo}` in the
  body. This mimics the hidden `formShip` that real search-result rows
  submit (`onClick="document.formShip.P_IMO.value='...';
  document.formShip.submit();"`) — Equasis does **not** support landing on
  a ship page via a plain `GET .../ShipInfo?fs=ShipInfo&P_IMO=...`; that
  combination reliably produces `CtrlGeneralError` regardless of whether the
  IMO is valid (verified with real, working credentials in Attempt 6).
- **Fetching the PDF**, once a ship is selected: `GET
  /EquasisWeb/restricted/ShipFop?fs=ShipInfo&IMO={imo}` — parameter here is
  plain **`IMO`**, not `P_IMO`. This is the *opposite* of the `ShipInfo`
  selection step, and the opposite of what equasis-cli's `client.py`
  implied (it never actually calls `ShipFop` at all — it only reads the
  `ShipInfo`/`ShipInspection`/`ShipHistory` HTML tabs, using `P_IMO`
  throughout, which is why that reference was misleading for this
  specific step).

## Attempt history

### Baseline (original implementation, before this debug effort)
- GET `/EquasisWeb/public/HomePage`, scrape the first `<form action="...">`
  found on the page for the POST target, POST with `j_email`, `j_password`,
  `fs=Login`, `pageName=Login`.
- Fetch PDF via `GET /EquasisWeb/restricted/ShipFop?fs=ShipInfo&IMO={imo}`.
- Symptom reported: intermittent "session not authenticated", first-press
  Equasis-account "still loading".

### Attempt 1 — cookie handling + `await` fix, richer logging
- Fixed `ref.read(accountProvider)` → `await ref.read(accountProvider.future)`
  in `vessel_particulars_screen.dart` (was returning a stale/loading
  snapshot on the first press of the session).
- Made the initial homepage GET follow redirects manually (collecting
  `Set-Cookie` at every hop) instead of `followRedirects: true`, which
  silently drops intermediate cookies — a known Dart HTTP client gotcha.
- **Result**: fixed the first-press issue. Session-not-authenticated
  persisted.

### Attempt 2 — modal-message detection + wrong query param found
- Discovered Equasis no longer 302-redirects on login POST; it forwards
  server-side and returns 200 either way, with the real signal embedded in
  an `id="warning"` modal. Added `_extractModalMessage()` and wired it into
  both the login POST and the ShipFop fetch, replacing the generic "session
  not authenticated" message with Equasis's actual wording.
- **Result**: surfaced `"No ship has been found with your criteria"` — a
  real, actionable Equasis message (not a generic guess), which is what let
  us find the next bug: our query param was `IMO`, and Equasis expects
  `P_IMO`. Fixed to `P_IMO`.

### Attempt 3 — `CtrlGeneralError` discovered, ShipInfo-first flow added
- With `P_IMO` fixed, `ShipFop?fs=ShipInfo&P_IMO=...` started returning
  `<title>Equasis - CtrlGeneralError</title>` — Equasis's own server-side
  error handler, not a business-logic rejection.
- Rewrote `_fetchShipPdf` to land on `ShipInfo?fs=ShipInfo&P_IMO=...` first
  (confirmed live in equasis-cli), then scan that page's HTML for however it
  triggers the PDF export — checking both `<form action="...Fop...">`
  (Equasis navigates most of the site via hidden POST forms, e.g. the login
  form and the footer search box) and plain `<a href="...Fop...">` links,
  since the exact export mechanism was unconfirmed.
- **Result**: `ShipInfo` *also* came back as `CtrlGeneralError` — and the
  embedded modal message was, again, `"No ship has been found with your
  criteria"`. This ruled out "wrong endpoint for the PDF step" as the
  problem and pointed further upstream, to the login/session itself.

### Attempt 4 — login flow rebuilt to match a confirmed-working reference
- Compared our login flow line-by-line against equasis-cli's `client.py`
  (fetched and read the raw source, not just a summary). Found two real
  discrepancies:
  1. We were GETting `/EquasisWeb/public/HomePage` (the marketing homepage)
     and scraping a form action out of it; the working reference logs in
     directly against `/EquasisWeb/authen/HomePage?fs=HomePage`.
  2. Our POST body included `fs=Login` and `pageName=Login` — not part of
     the real form, and directly conflicting with the `fs=HomePage` already
     on the URL's query string.
- Rewrote `_login()` to GET and POST the same `/EquasisWeb/authen/HomePage?
  fs=HomePage` URL, sending only `j_email`, `j_password`, `submit`.
- Verified via `curl` (wrong test credentials, just to check mechanics) that
  this produces a clean, correctly-formed rejection modal — not
  `CtrlGeneralError` — confirming the request shape itself is now sound.
- **Result**: login itself now succeeds cleanly (status 200, no error modal,
  "login OK" with the `JSESSIONID` cookie) — but the `ShipInfo` lookup still
  came back as `CtrlGeneralError` / "No ship has been found with your
  criteria". See Attempt 5 for why this points away from our request
  mechanics entirely.

### Attempt 5 — byte-identical failure across two different login
implementations → likely account-side, not a protocol bug
- Surveyor reported: *"it was working a few days ago"* — new information,
  not previously stated. Re-examined the Attempt 4 retest log against the
  Attempt 3 log side by side.
- **Key observation**: the `ShipInfo` response is **byte-for-byte identical**
  between Attempt 3 and Attempt 4/5 — same 37806 bytes, same
  `CtrlGeneralError` title, same embedded "No ship has been found" message —
  despite the login implementation changing substantially in between (
  different URL, different POST fields). If the problem were in our request
  construction, changing the login mechanics that much should have changed
  *something* about the downstream response. It didn't, at all.
- This strongly suggests the failure is **not** in how we authenticate or
  query, but in something account-side on Equasis's end that's independent
  of the exact HTTP request shape — e.g. a monthly/free-tier ship-lookup
  quota exhausted, a lapsed subscription tier that no longer includes ship
  folder downloads, or a temporary Equasis-side restriction on this
  particular account. Equasis is known to gate the full ship-folder PDF
  behind account tier/quota for registered (free) users, and sites like this
  don't always surface quota-exceeded as a distinct, friendly message — it
  can plausibly fall through to the same generic error/"not found" path
  we're seeing here, which would also explain why a *correct* IMO
  consistently reads as "no ship found" instead of throwing a more specific
  error.
- **This is genuinely testable without more code changes**: log into
  equasis.org in a normal desktop browser with the same account and try to
  view/download the ship folder for this exact IMO. If the browser *also*
  fails or shows a quota/subscription notice, the fix is on the Equasis
  account side, not in this codebase, and further reverse-engineering here
  would be wasted effort. **Blocked on this check as of Attempt 5.**
- **Correction (Attempt 6): this hypothesis was wrong.** The account had no
  quota/subscription problem at all — logging in with real credentials and
  the *exact same* IMO worked once the request shape was fixed. The
  byte-identical responses across different login implementations weren't
  evidence of an account restriction; they were evidence that the login
  step was never the problem in the first place — attempts 3–5 were all
  correctly logged in, and the failure was entirely in how the ship was
  being selected afterward (see Attempt 6). Leaving this entry as-is since
  it was a reasonable inference from the evidence available at the time,
  but the actual lesson is: don't trust "byte-identical → account-side"
  reasoning over just testing with real credentials once they're available.

### Attempt 6 — tested live with real credentials; found the actual mechanism
- Surveyor shared real Equasis credentials in-chat to unblock this. Used
  them for one-off diagnostic `curl` testing only — not saved to any file,
  not committed, cookie jar deleted after use.
- Replayed our exact login flow via `curl`: succeeded cleanly (`Welcome`,
  `Logout`, `My Equasis` all present in the response, no error modal) —
  **confirming login was never the problem**, attempts 1–5 already had that
  right.
- Replayed our exact `ShipInfo?fs=ShipInfo&P_IMO=9797539` call (the on-file
  IMO for the surveyor's vessel): got the identical `CtrlGeneralError` /
  "No ship has been found with your criteria" response we'd been seeing —
  proof the failure is 100% reproducible outside our app, with valid
  credentials, and not account/quota-related.
- Used the real search endpoint (`POST /EquasisWeb/restricted/Search?
  fs=Search` with `P_ENTREE_ENTETE=9797539`) to check whether that IMO
  exists in Equasis at all: **"No company nor Ship has been found with your
  criteria"**. Searching by vessel name `ASTROLABE` instead *did* return
  ship results — but under **different IMOs** (`9766970`, `9462615`), not
  `9797539`. This suggests the on-file IMO for this vessel may itself be
  incorrect, or Equasis has no record for it — worth the surveyor
  double-checking that number against the vessel's actual documents,
  separately from the code issue.
- Used the confirmed-valid IMO `9766970` to trace the *real* selection
  mechanism end-to-end: the search-results row is a link with
  `onClick="document.formShip.P_IMO.value='9766970';
  document.formShip.submit();"`, targeting a hidden form
  `<FORM name="formShip" action="../restricted/ShipInfo?fs=Search"
  method="post">`. I.e. selecting a ship is a **POST to `ShipInfo?
  fs=Search` with `P_IMO` in the body** — not a GET with query params, and
  not `fs=ShipInfo` (which is what both our code and the equasis-cli
  reference had assumed).
- That POST returned a real `<title>Equasis - ShipInfo</title>` page (first
  non-error response of this whole effort), containing the actual
  ship-folder link: `onclick="javascript:window.open('../restricted/
  ShipFop?fs=ShipInfo&IMO=9766970')"` — **plain `IMO`, not `P_IMO`**, the
  opposite convention from the selection step.
- Fetched that URL directly: `%PDF-1.4` magic bytes, `content-type:
  application/pdf`, 28734 bytes. A genuine ship folder PDF, fully verified
  end-to-end outside the app.
- **Fix applied**: rewrote `_fetchShipPdf` to (1) POST `ShipInfo?fs=Search`
  with `P_IMO` to select the ship, then (2) GET `ShipFop?fs=ShipInfo&IMO=`
  (plain `IMO`) to fetch the PDF. Removed the speculative form/link-scanning
  fallback logic from Attempt 3 — no longer needed now that the real
  mechanism is known exactly, not guessed.
- **Result**: verified correct for a *different* IMO than the one on file
  for the surveyor's vessel (since that's the only IMO available to test
  with real credentials). **Not yet confirmed against the app itself or the
  surveyor's actual vessel** — pending retest. If it still fails for IMO
  9797539 specifically, the likely explanation per the search results above
  is that IMO is wrong/not in Equasis, not a remaining code bug.

### Attempt 7 — code fix confirmed working; IMO 9797539 confirmed absent from Equasis via three independent methods
- App retest came back with the same `CtrlGeneralError` / "No ship has been
  found" for IMO 9797539 — but the stack trace this time points at the
  *new* POST-based code path (`_fetchShipPdf` line 234, the modal-message
  throw added in Attempt 6), confirming **the Attempt 6 fix is running
  correctly and working as designed** — it made the right request and
  correctly surfaced Equasis's real answer. The question is now purely
  about the IMO, not the code.
- Surveyor pushed back: *"no it's not, if you search for L'Astrolabe you
  will find it"* — i.e. confident the vessel is genuinely in Equasis.
  Investigated further before concluding anything:
  1. Re-ran the Attempt 6 search (`P_ENTREE_ENTETE`/`fs=Search`) for
     `"L'ASTROLABE"` (with apostrophe) — still "No company nor Ship has
     been found".
  2. Re-checked the full `"ASTRO"` substring search (92 unique ship IMOs
     returned, no pagination/truncation limit hit) — `9797539` is not
     among them, and no result's name contains an apostrophe at all.
  3. **Found the search field names from Attempt 6 (`P_ENTREE_ENTETE`) were
     themselves not what the real homepage search box uses** — pulled the
     *actual* authenticated homepage HTML directly and found the real
     search form: `POST /EquasisWeb/restricted/Search?fs=HomePage` with
     `P_ENTREE_HOME`/`P_ENTREE_HOME_HIDDEN` (not `fs=Search` /
     `P_ENTREE_ENTETE` as previously used — that field name came from
     equasis-cli and, like its `ShipFop` assumption, turned out not to
     match the real site). Re-ran `"ASTROLABE"`, `"L'ASTROLABE"`, and
     `"9797539"` through this *actually-correct* search mechanism — same
     results: only the two Australian-flagged `ASTROLABE` ships (9766970,
     9462615), nothing for `9797539` or any apostrophe-name.
  4. Also re-ran ship *selection* directly (the exact mechanism confirmed
     working in Attempt 6) for `P_IMO=9797539` — still "No ship has been
     found", confirmed via the real mechanism this time, not the old
     broken one.
- **Conclusion**: through four independent checks (two search field
  variants × the real vs. assumed endpoint, plus direct selection), IMO
  9797539 does not exist in Equasis's database under any tested name
  variant. This is not a code issue. **Blocked on the surveyor performing
  the search themselves in-browser and reporting back the exact IMO number
  and ship name Equasis actually shows** — that's the only way to close
  the gap between "the code is now verified correct" and "the surveyor is
  confident the vessel is findable."

## Resolution

Surveyor checked equasis.org directly and confirmed: **L'Astrolabe does not
appear on Equasis at all — it's a navy vessel**, not a commercial ship, and
Equasis's coverage is fundamentally scoped to IMO-registered commercial
vessels. This matches option 3 from the "Next steps" list above. The
`9797539` number on file isn't necessarily wrong — the vessel simply isn't
in this database, full stop, regardless of what IMO it's under.

**Closed as: not a bug.** The Attempt 6 login/search/fetch flow is verified
correct end-to-end (real PDF fetched successfully for a different, valid
commercial-vessel IMO during testing) and should work for any vessel that's
actually in Equasis's coverage. Naval, government, and other
non-IMO-convention vessels are simply out of scope for this integration —
that's an Equasis data-coverage limitation, not something fixable in this
codebase.

**If this comes up again for other government/naval vessels**: the
Equasis fetch button will correctly report "No ship has been found with
your criteria" for these — that's accurate, not a failure. No further code
work is needed on that path; the practical workaround is to enter vessel
particulars manually for vessels outside Equasis's coverage.

### Confirmed working in the app (post-fix retest)

Surveyor retested against real vessels in the app itself:
- **MINRES ODIN** — succeeded. First confirmed successful in-app fetch since
  this debugging effort started, using the Attempt 6 flow.
- **Pangaea Ocean Explorer** — failed, but the surveyor had fetched this
  vessel's report successfully before and, on checking, found it "seems to
  have disappeared" from Equasis in the browser too (not just the app).
  Not investigated further yet, but the same category of issue as
  L'Astrolabe: Equasis's own data changing/disappearing over time (vessels
  get renamed, scrapped, sold, reflagged, or otherwise dropped from
  coverage), not a code regression — consistent with the surveyor's own
  browser check showing the same absence. Revisit only if it turns out the
  vessel is still genuinely searchable in Equasis and the app disagrees.

**Overall status: fixed and confirmed.** The Attempt 6 login → select ship
→ fetch PDF flow works correctly for vessels actually present in Equasis.
