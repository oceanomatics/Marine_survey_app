# F0 review — H&M golden-file guard: feasibility & design

**F0** (from PHASE1_DETAILED_PLAN §3) is the regression test that snapshots the current H&M `.docx` output and asserts byte/structure-equivalence, so the **F3 exporter refactor** can proceed without silently changing H&M output. This is a review of whether F0 is feasible now and how to build it, grounded in the actual exporter code.

**Verdict: feasible and low-effort (S–M).** Fixtures already exist, and there is exactly **one** nondeterminism source to neutralize. Two small prep changes to the exporter are needed before the test can be written.

---

## What the exporter looks like (the facts)

- `DocxExportService.export(...)` ([docx_export_service.dart:39](../../lib/features/reports/services/docx_export_service.dart#L39)) is the public entry, but it has **side effects unsuitable for a golden test**: it downloads the org logo from Supabase Storage and delivers the file via `report_delivery.dart`. Don't test through this.
- `DocxExportService._buildDocx(...)` ([docx_export_service.dart:153](../../lib/features/reports/services/docx_export_service.dart#L153)) is the **pure core**: `(ReportOutput, AssembledReportData, sections, …bytes) → Uint8List`. No network, no filesystem — logo/photo bytes are passed in. **This is the seam to snapshot.**
- `DocxBuilder.build()` ([docx_builder.dart](../../lib/core/docx/docx_builder.dart)) returns a zipped `.docx` via `ZipEncoder().encode(archive)`.

## The one blocker to determinism

`_buildDocx` output embeds **today's date** via `_today()` ([docx_export_service.dart:1263](../../lib/features/reports/services/docx_export_service.dart#L1263)), rendered into the document body in two places:
- line 297 — the "Date Issued" row of the cover metadata table;
- line 1090 — the closing `"$city, <date>"` paragraph.

So two runs on different days produce different bytes. **This is the only nondeterminism inside the builder.** (The other `DateTime.now()`, at line 1257, is in the *filename* generator — it affects `export()`'s returned filename, not the `_buildDocx` bytes, so it's irrelevant to the golden comparison.)

Everything else is deterministic: image relationship IDs are sequential (`_images` index), colours come from branding data, and content comes from the passed-in fixtures.

## Zip-bytes caveat

`build()` wraps entries in `ArchiveFile(name, len, bytes)` with no explicit timestamp and `ZipEncoder`-compresses them. Raw-zip byte comparison risks flakiness from entry timestamps / compression details across `archive`-package versions. **Don't compare the zipped bytes.** Instead, unzip in the test and compare the **inner XML entries as text** (`word/document.xml`, `word/styles.xml`, `word/header2.xml`, …). This is more robust *and* gives readable diffs when F3 changes something.

## Fixtures already exist (why this is cheap)

[`test/support/fixtures/report_fixtures.dart`](../../test/support/fixtures/report_fixtures.dart) already provides `fixtureAssembledData()`, `fixtureOutput()`, `fixtureSection()`, and `fixtureAllSections()` — exactly the inputs `_buildDocx` needs. The hardest part of a golden test (constructing rich inputs) is already solved.

---

## Recommended F0 build (the plan)

1. **Make the date injectable.** Add an optional `DateTime? asOf` (or `String? issueDateOverride`) param to `_buildDocx`, thread it into `_today(asOf)`, defaulting to `DateTime.now()` in production. One-line change at each of the 3 sites (definition + 2 call sites). This is the only production-code change and is harmless.
2. **Expose the builder to tests.** Annotate `_buildDocx` `@visibleForTesting` (rename to `buildDocxForTest` or make package-visible), OR add a thin `@visibleForTesting` wrapper. No behaviour change.
3. **Write the golden test** (`test/features/reports/docx_golden_test.dart`):
   - Build inputs from `report_fixtures` for 2–3 representative outputs: a **Preliminary**, an **Advice**, and a **Final** (covers the `switch (outputType)` branches — the parts most at risk in F3).
   - Call the builder with a **fixed `asOf`** (e.g. `DateTime(2026, 1, 1)`).
   - Unzip the result (`ZipDecoder`) and, for each inner XML entry, compare against a committed golden file under `test/goldens/docx/<case>/<entry>.xml`.
   - First run writes the goldens (guard with an env flag, e.g. `UPDATE_GOLDENS=1`); subsequent runs assert equality.
4. **Wire it as the F3 gate.** F3 is done only when this test still passes (or the golden diff is reviewed and intentionally re-blessed).

## Effort & sequencing

- Steps 1–2: ~20 lines, no behaviour change — safe to land **now**, even before the H&M freeze, since they don't alter output.
- Step 3: the bulk, but bounded by the existing fixtures.
- **Recommendation:** land steps 1–2 now (they're pure prep and de-risk the freeze), then write step 3 immediately before starting F3. Do **not** start F3 until the golden test is green on the current exporter.

## Residual risks

- **Fixture coverage ≠ full coverage.** The goldens only cover what the fixtures exercise. If `report_fixtures` omits a section type or a conditional (e.g. machinery table, cost table with multi-currency), F3 could change that path undetected. Mitigation: before F3, extend `fixtureAllSections()` to populate every `SectionType` and both cost/no-cost paths.
- **Intentional F3 changes re-bless the golden.** That's expected — the value is that every change becomes *visible and deliberate* in the diff, not silent.
