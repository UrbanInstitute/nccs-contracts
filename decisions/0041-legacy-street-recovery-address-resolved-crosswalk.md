# 0041 — Recover Legacy Street Addresses; Re-geocode the Unified BMF; Address-Resolved Crosswalk

- **Status:** Reconciled (2026-07-26)
- **Date:** 2026-07-24
- **Deciders:** sole maintainer
- **Related:** [[0016-no-canonical-cross-dataset-merge]] (separate join layer, not master columns), [[0034]] (NTEE-resolved crosswalk; the "expose all, no opinionated pick" precedent this new artifact copies), [[0037-master-bmf-rename-unified-supersession-provenance]] + [[0039-unified-bmf-geocoded-extension-rename]] (ratified unified paths + dual-write discipline this work publishes under), [[0022]] (contracts guard), [[0014]] (manifest shape), producer issue `nccs-data-bmf#29`

## Context

A user report (2026-07-24, routed via `nccs-inbox`) flagged that
`org_addr_street_raw` is missing from the legacy processed BMF vintages.
Verification found the gap total: **every street-derived column** is absent
from all 88 `processed/bmf-legacy/` vintages. Root cause: the harmonization
crosswalk row `ADDRESS,ADDRESS,,drop,alias` claimed the legacy `ADDRESS`
column was "redundant with STREET," but **no legacy file has a STREET
column** (all 88 raw headers scanned). `ADDRESS` is the IRS mailing delivery
line (validated on ~35k-row samples across six vintages: never empty, never
a duplicate of city/zip, 67-70% street numbers, 28-32% PO boxes). It is
present in **58 vintages** (2009-01, 2009-10 through 2022-08); the remaining
30 (1989 through 2008, plus 2009-04/07) never carried streets.

Consequence at the consumer surface: in the geocoded Unified BMF,
`org_addr_street` is missing for **100% of the 1,479,311 legacy-sourced
rows** (0% for current-sourced), which is also why those orgs, all defunct
pre-2023, carry no lat/lon.

Why it was missed: the crosswalk was authored from the scraped NCCS
dictionary corpus, which never documents `ADDRESS` (`n_dicts_observed=0`);
the disposition was assigned by analogy to the current-IRS schema; the
slim-schema rule made the absence look intentional; and no quality gate
audits completeness by `bmf_source`.

## Decision

**1. Fix + guardrail (producer, `nccs-data-bmf#29`).** Remap
`ADDRESS → STREET` (`rename, alias`, the crosswalk's established alias
pattern). `load_crosswalk_v2()` now rejects any `drop`+`alias` row: an alias
of a current-schema concept must rename, never drop. Validated on a local
2013-07 run: exactly 8 additive columns (`org_addr_street`,
`org_addr_street_raw`, `org_addr_is_po_box`, `org_addr_is_rural_route`,
`org_addr_has_special_chars`, `org_addr_missing_number`, `org_addr_full`,
`org_addr_is_missing`), zero removals, identical row count.

**2. Re-publish the 58 affected legacy vintages** (EC2 batch,
`run_all_legacy.sh`; the 30 street-less vintages are skipped: their output
cannot change, and re-publishing would churn manifests for nothing).
Additive schema on the `processed/bmf-legacy/` surface; no deprecation
window required ([[0033]]: nothing breaks, nothing moves).

**3. Rebuild the Unified BMF, then run a full geocoding cycle.** The
unified rebuild backfills street values for legacy-sourced rows (schema
unchanged; the columns already exist). The geocode cycle (batch export →
Urban geocoder → merge) then covers the newly addressable ~1.48M
legacy-only orgs for the first time. Publication follows the **already
ratified** [[0039]] paths: `geocoding/unified-bmf/merged/bmf_unified_geocoded.*`
plus `unified/bmf/state_marts/`, with dual-writes to the old
`bmf-master`/`master` paths only while 0039's 90-day window (from
2026-07-02) is still open at publish time. This ADR makes no naming
decisions; it schedules the next expensive geocode cycle and pins what
rides it.

**4. New contracted artifact: the address-resolved crosswalk.**
`s3://nccsdata/crosswalks/address-resolved/` (parquet + CSV + ADR 0014
manifest), built like the NTEE-resolved crosswalk ([[0034]]): aggregate the
**raw** address fields per EIN across every vintage of both pipelines'
intermediate parquets, and expose all views with no opinionated pick:

- `addr_current` (may be NULL), `addr_most_recent`, `addr_first`: each as
  the (street, city, state, zip) tuple with its vintage stamps
- `n_distinct_addresses`, `n_vintages_with_address`, `addr_distribution`
  (JSON: address → first/last vintage observed)
- the additive EIN renderings `ein_prefixed` + `EIN2` ([[0036]])

Separate join layer keyed on `ein`; address-history fields are deliberately
NOT added to the Unified BMF ([[0016]]). Contract stub:
`contracts/address-resolved-crosswalk.yml`, populated from the published
artifact at reconcile. Supersedes the ad-hoc 2024 `meta/metadata-address*`
tables as the maintained address-history surface (those stay reachable;
no removal in this ADR).

**5. Machinery follow-up (this ADR's "why was it missed" answer).** Add
by-`bmf_source` completeness to the Unified BMF quality report so a column
family that is fully NA on one source can never look healthy at the master
grain again. (The drop+alias crosswalk gate shipped with #1.)

## Consequences

- Longitudinal street addresses become available 2009-2022 for legacy-only
  orgs; 1989-2008 remains street-less (never collected upstream; documented
  honestly in dictionaries and the catalog).
- The pre-2010 historical geocoding-coverage caveat (documented in the
  Milwaukee request) improves materially after step 3.
- One expensive geocoder round-trip, deliberately bundled per the
  cheapest-decisive-action pattern of [[0039]].
- Consumers of `processed/bmf-legacy/` see additive columns only; the
  Unified BMF sees value backfill only. The 0039 consumer-migration
  follow-ups (`nccsdata`, `sector-in-brief-api` path repoints) are
  unaffected and remain separately tracked.

## Deprecation window

None required: all changes are additive or value-backfill. Dual-write
obligations are [[0039]]'s, honored while its window is open.

## Outcome

Executed 2026-07-24 through 2026-07-26; every figure below verified
against live S3 by the reconciler.

- **Fix**: `nccs-data-bmf` PR #30 merged (`2daa055`); drop+alias
  crosswalk gate live. Guard companions merged: #31 (by-source
  tripwire), #33 (geocoder service docs).
- **Re-publish (S2)**: all 55 ADDRESS-carrying vintages rebuilt and
  published to `processed/bmf-legacy/` (profile run + 54-vintage batch,
  JOBS=10, ~65 min, zero failures). **Validation gate: 55/55 PASS**
  (row parity, deterministic column expectation, exact street parity,
  clean value checks); evidence:
  `s3://nccsdata/logs/adr0041/validation_gate.tsv` (+ all phase logs).
- **Unified rebuild (S3)**: published 2026-07-25 (3,687,435 rows,
  EIN-unique, git `15ecca9`, vintage 2026_07). Tripwire before/after:
  street family cleared the one-sided-outage flags (legacy 0% -> 56.93%
  non-null); the 21 remaining flags audited as legitimately one-sided
  (no legacy source columns exist for them). Manifest byte-overflow
  found (bytes:"NA" above 2 GiB) and fixed (PR #37, open at reconcile;
  published manifests hand-corrected).
- **Geocode cycle (S4)**: 2,592,609 unique addresses (vs 1,841,228 the
  prior cycle: +751k from street recovery) in 3 batches through the
  automated service; 100% match rate. One engine crash mid-batch-3
  (idle 4+ h, no service alarm): recovered via the now-documented
  stop/re-trigger procedure; stall-detection + recovery codified in
  `nccs-data-bmf/docs/reference/geocoder-service.md`. **Coverage:
  2,208,124 -> 3,050,331 orgs with lat/lon (59.9% -> 82.7%).**
  Published to the ADR 0039 paths with dual-writes; state marts
  rebuilt (63 partitions, both paths).
- **Address log (S5)**: shape per ADR 0042 Decision B; first publish
  `crosswalks/address-resolved/{v2026_07,latest}/`: 11,447,794 spells,
  3,687,468 EINs, 68.2% multi-address. A zip-format spell-splitting
  defect (raw ZIP+4 vs 5-digit) was caught by the zero-cross-source
  quality invariant BEFORE publish and fixed (zip5 key); invariants
  systematized as build-stopping gates + standing validation suite
  (producer PR #32, open at reconcile). Contract populated from the
  artifact in this reconcile.
- **Infra**: batch box terminated after evidence archive; lessons in
  `docs/reference/ec2-lessons.md` (PR #38).
- **Open at reconcile**: producer PRs #32/#34-#39, core #12, website
  #91 (naming + latest/ links + catalog) awaiting maintainer review;
  crash-alarm gap to be reported to the geocoder service owners;
  consumer repoints (`nccsdata`, API) to latest/ still pending per
  ADR 0039/0042 follow-ups.
