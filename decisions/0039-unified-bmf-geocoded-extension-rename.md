# 0039 — Extend the Unified BMF Rename to the Geocoded Extension + State Marts

- **Status:** Reconciled (2026-07-02) — dual-write live and verified at both the geocoded and state-marts paths. See Outcome.
- **Date:** 2026-07-01
- **Deciders:** sole maintainer (DST)
- **Related:** [[0037-master-bmf-rename-unified-supersession-provenance]] (the un-geocoded rename this extends one layer deeper), [[0032-ntee-cleaner-university-code-loss]] (the legacy reprocess this rides alongside), [[0033-deprecation-window-policy-and-critical-bug-override]] (the 90-day window), [[0013-versioned-producer-outputs]] (vintage migration, still deferred), [[0016-no-canonical-cross-dataset-merge]], [[unified-bmf]], [[unified-bmf-geocoded]] (formerly `bmf-master-geocoded`)

## Context

ADR 0037 renamed the un-geocoded `master/bmf/` artifact to the Unified BMF
(`unified/bmf/`) but explicitly scoped the geocoded extension **out**:
`geocoding/bmf-master/` kept its name, on the reasoning that it's a separate
artifact whose only coupling is reading the renamed one as input.

That scoping call is revisited here. Leaving the geocoded companion on the old
`bmf-master` name is not a stable end state: if "Unified BMF" is the restored,
durable community identity for this product (the entire point of ADR 0037),
a geocoded extension still called `bmf-master-geocoded` — the artifact
`nccsdata::nccs_read()` actually serves by default — undermines that identity
at the surface consumers touch most.

The decisive practical factor: `nccs-data-bmf` is about to run an expensive,
manual, two-phase geocoding cycle anyway, to complete ADR 0032's deferred
legacy NTEE reprocess and refresh the geocoded master (BACKLOG L1 → G1). The
geocoder round-trip (batch export → external geocoder → merge) is the costly,
slow part of this whole exercise. Doing the rename's first non-silent publish
*inside* that already-scheduled run costs nothing extra; deferring it to a
future migration would mean paying for a second full geocode cycle later for
no reason other than the rename. Cheapest-decisive-action-first favors folding
it in now.

A second gap surfaced while checking S3 directly against `unified/bmf/`
(2026-07-01): `master/bmf/state_marts/` — the per-state shards derived from
the geocoded master (`R/master_state_marts.R`) — was **not** included in the
ADR 0037 rename at all. It still lives only under the old `master/bmf/`
prefix, which is itself scheduled to archive at the 2026-09-28 cutover. Left
as-is, the state marts would be orphaned with no successor path when
`master/bmf/` archives. This was an oversight in ADR 0037's scope, not a
deliberate decision — corrected here.

## Decision

**1. Rename `bmf-master-geocoded` → the geocoded Unified BMF**, mirroring the
ADR 0037 swap pattern (`master` → `unified`, structure otherwise unchanged):

- **Prefix:** `geocoding/unified-bmf/` (was `geocoding/bmf-master/`). Same
  `merged/` and `input/` sub-structure.
- **Stem:** `bmf_unified_geocoded` (was `bmf_master_geocoded`).
- Contract slug: `unified-bmf-geocoded` (file `contracts/unified-bmf-geocoded.yml`,
  was `bmf-master-geocoded.yml`).

**2. Rename the state marts path** to live under the new prefix:
`unified/bmf/state_marts/{csv,parquet}/` (was `master/bmf/state_marts/`). The
"why state marts sit with the master, not under `geocoding/`" rationale from
the prior contract is unchanged (they're partitions of the geocoded master,
not a geocoding step) — only the top segment swaps, in lockstep with the
un-geocoded rename this should have covered originally.

**3. Non-silent supersession, same discipline as ADR 0037.** Both the
geocoded extension and the state marts dual-publish: the new `unified-bmf`
paths **and** the old `bmf-master`/`master/bmf/state_marts` paths stay live
for 90 days from this publish, then the old paths move to the retained,
reachable archive (never deleted). This is a fresh 90-day clock starting at
whenever `nccs-data-bmf` actually completes this republish (Step 3/4 of the
BACKLOG L1→G1 executor task) — it does not need to align with ADR 0037's
2026-09-28 cutover, though it may land close to it.

**4. Consumer migration is separate, deliberate, cross-repo work — not done
by this ADR.** Two hardcoded reads exist today:

- `nccsdata::nccs_read()` (`R/nccs_read.R:401` — S3 URI — and `:407` — HTTPS
  mirror) reads `geocoding/bmf-master/merged/bmf_master_geocoded.parquet`
  directly.
- `sector-in-brief-api` reads the same path via DuckDB at query time.

Until those repos migrate their hardcoded strings to the new path, they
**keep working unchanged** — the old path stays live and fresh (both
publishes come from the same rebuild) through the dual-live window. Migrating
each consumer is tracked as separate BACKLOG follow-ups (new items, one per
repo), executed under this ADR's ratified path once `nccs-data-bmf` confirms
the new path is live. This ADR fixes the producer-side name/path; it does not
by itself change what any consumer reads.

**5. Per-build manifest — fold in opportunistically.** `bmf-master-geocoded`'s
Open item #1 (no `_manifest.json`, quality-report-only) has been outstanding
since 2026-05-21. Since this rebuild already touches `master_geocoding.R`,
add the same `R/manifest.R`-based ADR 0014 manifest emission used by
`write_master_outputs()` (closed for the un-geocoded artifact in ADR 0037).
Not a hard requirement of this ADR, but strongly recommended while the code
is already open for the rename — otherwise this gap persists for another full
geocoding cycle.

## Consequences

- **Naming consistency restored** at the surface consumers touch most
  (`nccs_read()`'s default read).
- **No second expensive geocode cycle** — the rename rides the already-budgeted
  ADR 0032 legacy-reprocess rebuild instead of requiring its own future run.
- **No consumer strands** — non-silent supersession, same as ADR 0037: both
  paths live 90 days, old path archives (not deleted) after.
- **State marts get a successor path before their current one archives** —
  closes a real gap that ADR 0037 left open.
- **Two follow-up PRs owed** (`nccsdata`, `sector-in-brief-api`) to actually
  point at the new path — tracked separately, not blocking this publish.

## Deprecation window

Standard **90 days** per [[0033-deprecation-window-policy-and-critical-bug-override]]:
both `geocoding/unified-bmf/` (new) and `geocoding/bmf-master/` (old) stay live
from the date `nccs-data-bmf` completes this republish; state marts likewise
under `unified/bmf/state_marts/` (new) and `master/bmf/state_marts/` (old).
After 90 days, the old paths move to the retained, reachable archive. Advance
notice to `nccsdata` and `sector-in-brief-api` maintainers, folded into the
existing ADR 0036/0037 consumer notice (E3).

## Outcome

Executed 2026-07-02 (`nccs-data-bmf`, branch `feat/ntee-resolved-crosswalk`,
PR #28, commit `3695028`). Verified independently against live S3 at this
reconcile, not just the executor's report.

**Geocoded extension.**
- Stem renamed `bmf_master_geocoded` → `bmf_unified_geocoded`, published to
  the ratified `s3://nccsdata/geocoding/unified-bmf/merged/` **and**
  dual-written under the old filenames to
  `s3://nccsdata/geocoding/bmf-master/merged/` for the 90-day window.
  Verified: both prefixes list the same four files with **identical byte
  sizes** (parquet 581,097,120 / csv 3,366,386,579), dated 2026-07-02.
- **`_manifest.json` — Open item #1 (long-open, since 2026-05-21) is
  CLOSED.** Verified live at `geocoding/unified-bmf/merged/_manifest.json`:
  `vintage: "2026_07"`, `built_at: 2026-07-02T20:10:11Z`, `git_sha:
  11380a2`, per-file sha256 + row_count (3,687,435, matching the Unified
  BMF). `master_geocoding.R` previously emitted no contract-standard
  manifest at all (only a quality report) — this is new, not a reformat.
- Merge validated by the executor: 1,841,228 geocoded addresses (100%
  coverage) → 3,687,435 Unified BMF rows, 2,208,124 carrying lat/lon.

**State marts.**
- Republished under `s3://nccsdata/unified/bmf/state_marts/` **and**
  dual-written to the old `s3://nccsdata/master/bmf/state_marts/` —
  verified both prefixes present (`csv/`, `parquet/` subdirs). Executor
  reports 63 matching state/territory partitions verified identical on
  both paths. Closes the ADR 0037 scope gap this ADR exists to fix — state
  marts now have a successor path before `master/bmf/` archives at its
  2026-09-28 cutover.

**Bonus fixes landed in the same PR** (found via the `nccs`-website
consumer-side check routed through `nccs-contracts`, not originally in
this ADR's scope, but fixed alongside since the same upload code was
already open):
- `upload_to_s3()` never set `Content-Type`, so every HTML/JSON/CSV upload
  defaulted to `binary/octet-stream` (forced download instead of
  in-browser rendering). Fixed centrally — all S3 uploads in the repo
  route through this one function — and reapplied retroactively to
  already-published files via S3 metadata copies. **Verified**: `curl -I`
  on both `unified/bmf/bmf_unified_quality_report.html`
  (`Content-Type: text/html; charset=utf-8`) and the geocoded quality
  report JSON (`application/json`) confirm the fix is live.
- `render_quality_report_index.R` matched the stale
  `bmf_master_quality_report.html` filename pattern, so the docs-site
  index silently **omitted** the Unified BMF report entirely (not just
  mislabeled it) — fixed.
- Backfilled 87 quality-report HTML files that had never rendered or gone
  stale (root cause: a missing `ggplot2` package on the EC2 box used for
  an earlier run).

**Diverged or pending.**
- **No contract-shape decisions made locally** — confirmed by the
  executor and consistent with this ADR's scope: the only two
  needs-ADR-review items (the exact unified path layout, ADR 0037 §5) were
  already ratified before this batch started.
- **90-day archive-key pins not yet set** for either new-path retirement
  (geocoded: from 2026-07-02; state marts: same date) — same open item as
  ADR 0037's `master/bmf/` archive key, pin at the respective cutovers.
- **Consumer migration (G2/G3) now unblocked.** `nccsdata::nccs_read()`
  and `sector-in-brief-api`'s hardcoded reads can be repointed to the new
  `geocoding/unified-bmf/merged/bmf_unified_geocoded.parquet` path — the
  old path stays live through the window, so this isn't urgent, but it's
  no longer gated on anything upstream.
- **`nccs-data-bmf` PR #28 is open, checks green, awaiting merge** — see
  BACKLOG for the merge-timing note (bundle the whole batch, don't merge
  piecemeal).
