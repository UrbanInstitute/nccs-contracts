# 0041 — Recover Legacy Street Addresses; Re-geocode the Unified BMF; Address-Resolved Crosswalk

- **Status:** Accepted (2026-07-24)
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

_To be filled at reconcile: producer PR link + merge SHA, re-published
vintage list + manifest verification, unified rebuild + geocode-cycle
verification (per-source street completeness before/after, lat/lon coverage
delta), address-resolved crosswalk first publish + contract population._
