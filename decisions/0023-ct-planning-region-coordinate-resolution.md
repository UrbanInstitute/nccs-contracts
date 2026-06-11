# 0023 — Connecticut Geography via a Coordinate-Keyed Planning-Region Crosswalk

- **Status:** Accepted (executed 2026-06-04) — see Outcome
- **Date:** 2026-06-04
- **Deciders:** sole maintainer; BMF + data owners
- **Related:** [[0021-canonical-county-identity-via-fips-crosswalk]] (resolves its Follow-up 4), [[0016-no-canonical-cross-dataset-merge]], [[0013-versioned-producer-outputs]], [[0014-standardize-manifest-shape]], [[county-fips-crosswalk]], [[cbsa-crosswalk]], [[ct-planning-region-crosswalk]], [[bmf-master-geocoded]], [[sector-in-brief]]

## Context

[[0021-canonical-county-identity-via-fips-crosswalk]] resolved BMF county
identity by publishing two label-keyed crosswalks ([[county-fips-crosswalk]],
[[cbsa-crosswalk]]) joined on the raw `(geo_state_abbr, geo_county)` label.
It left one coverage hole, recorded as its **Follow-up 4**: Connecticut.

In 2022 the Census Bureau **retired Connecticut's eight historical counties**
and adopted **nine planning regions** as the state's county-equivalents
(GEOIDs `09110`–`09190`), reflected in TIGER 2022+ and the OMB 2023 CBSA
delineation. The geocoder, however, still emits the *old* county labels
(`Fairfield County`, `Hartford County`, …). The two geographies **do not
nest**: a single retired county spreads across several planning regions. So
at the `(state, county-name)` grain that ADR 0021's crosswalks use, there is
**no single GEOID that is correct** for a CT county label — e.g. orgs labeled
`Fairfield County` actually sit in Western CT (68.5%), Greater Bridgeport
(28.2%), and Naugatuck Valley (3.3%).

This produced two concrete defects:

1. **~14k CT orgs unassigned.** ADR 0021's build marked the CT labels
   `ambiguous` → NA. The first contracted consumer, `sector-in-brief-data`
   (v2026.07), correctly carried that through as "unassigned county" for
   every CT nonprofit — a large, concentrated coverage hole (ADR 0021's
   Outcome flagged it explicitly).
2. **Silent mis-resolution of half of CT.** The county build's org-mass
   fallback resolved the *four* retired counties whose mass happened to
   exceed its 90% dominance threshold (`Hartford`, `Middlesex`,
   `New London`, `Tolland`) onto a single planning region — silently
   mislabeling the minority slivers (e.g. 315 `Hartford County` orgs stamped
   `09110` that are actually in Naugatuck Valley / Northwest Hills / Lower CT
   River Valley). The other four split evenly enough to be flagged ambiguous;
   the inconsistency was latent.

ADR 0021's scope boundary already named the shape of the fix: sub-county and
per-coordinate geographies "do not resolve from a `(state, county-name)`
crosswalk — they require a point-in-polygon lookup per row." Connecticut is
the case where the **county-equivalent itself** (not a finer geography) is
recoverable only from the coordinate, because the resolvable label names a
*retired* county.

## Decision

Resolve Connecticut by **coordinate**, in a new companion crosswalk, while
keeping the master unchanged (ADR 0016) and every other state on the existing
label-keyed crosswalks.

1. **Defer the CT labels, don't guess.** In [[county-fips-crosswalk]], all
   eight CT `<name> County` labels get a new `resolution` value
   `deferred_ct_planning_region` (NA FIPS), replacing the previous mix of
   `ambiguous` and silently-mass-resolved. This removes the silent
   mis-resolution and points consumers at the companion. Bare CT *town*
   labels (e.g. `Hartford`, `New Haven` without "County") sit in exactly one
   region and still resolve normally.

2. **Publish a coordinate-keyed companion** ([[ct-planning-region-crosswalk]]).
   A dense **0.01° lookup grid** over Connecticut, built purely from TIGER
   2023 planning-region polygons (no BMF input, no S3 read — the same
   "derive from the authoritative source" shape as the CBSA build from OMB).
   Each cell carries the planning-region GEOID covering it, an `area_share`,
   and a `straddle` flag for boundary cells. A consumer rounds the geocoded
   `(geo_lat, geo_lon)` it already holds to 0.01° and joins on
   `(lat2, lon2)`. This is the **first coordinate-keyed crosswalk** — a
   deliberate, bounded crossing of ADR 0021's per-label scope boundary,
   justified because CT's county-equivalent is recoverable only from the
   point.

3. **Fold CT into the CBSA universe.** [[cbsa-crosswalk]]'s universe is no
   longer "resolved county GEOIDs from county-fips" alone; it now **unions in
   the nine CT planning-region GEOIDs from the companion**, so the chain
   `raw coord → planning region → CBSA` completes. The CBSA audit's
   "delineation county absent from BMF" set drops from the four CT
   metros/micros to zero.

4. **The master is still NOT modified.** [[bmf-master-geocoded]] gains no
   FIPS column; the companion joins on the geocoded lat/lon the master
   already carries. ADR 0016 / ADR 0021's non-change holds.

### The CT join chain (consumer-composed)

```
geocoded (geo_lat, geo_lon)
   │  round to 0.01°  →  (lat2, lon2)
   │  join [[ct-planning-region-crosswalk]] on (lat2, lon2)   [CT only]
   ▼
geo_county_fips  (091xx planning region) + geo_county_canonical
   │  join [[cbsa-crosswalk]] on county_fips = geo_county_fips
   ▼
cbsa_code / cbsa_title / cbsa_type / csa_code / csa_title
```

For non-CT states the ADR 0021 label chain is unchanged. A consumer unions
the CT coordinate-resolved rows back with the label-resolved rows; both
expose the same `geo_county_fips` / `geo_county_canonical` columns.

## Invariants (guaranteed by the producer; asserted in the contracts)

- **Three-way vintage coupling.** [[county-fips-crosswalk]] `tiger_year` ==
  [[cbsa-crosswalk]] `delineation_year` == [[ct-planning-region-crosswalk]]
  `tiger_year` (all 2023). The three are rebuilt and republished together so
  every CT planning-region GEOID in the companion exists in the CBSA
  delineation.
- **CT GEOIDs enter the CBSA universe from the companion**, not from
  county-fips resolved rows (those are `deferred_ct_planning_region`, NA
  FIPS). This is the one documented seam in ADR 0021's "every county GEOID in
  one exists in the other" guarantee: for CT the source is the companion.
- **Complete CT-land coverage.** The grid is cut from the polygons, not from
  observed data, so every CT coordinate lands on a cell — including addresses
  not yet in the BMF. Validated: 100% of the 25,922 geocoded CT org points
  resolve; 1.26% fall on a flagged `straddle` cell.
- **Straddle honesty.** A ~1 km (0.01°) cell can cross a planning-region
  boundary; such cells are flagged (`straddle = TRUE`, `area_share < 0.95`)
  and listed in the build's audit rather than silently assigned. Consumers
  needing sub-cell precision there point-in-polygon the raw coordinate.
- **Flat-prefix ADR 0013 exception extends to the companion** — same
  rationale as the other two crosswalks (small, additive, single live
  vintage carried in-column via `tiger_year` and in the manifest).

## Rejected alternatives

- **Resolve CT to its retired 8-county FIPS (`09001`…).** Keeps the
  `(state, county)` grain 1:1, but the GEOIDs no longer exist in TIGER 2023
  or the OMB 2023 delineation, so the CBSA chain would dead-end unless we
  sourced and maintained a *second, older* OMB delineation just for CT — a
  vintage island, contrary to the vintage-coupling invariant. Rejected.
- **Stamp planning-region FIPS into the master.** Most directly usable, but
  pins a TIGER vintage into [[bmf-master-geocoded]] and puts a derived join
  on the producer surface — exactly what ADR 0016 / ADR 0021 reversed.
  Rejected.
- **Leave CT `ambiguous` (status quo).** Leaves ~14k CT orgs unassigned for
  every consumer and leaves the silent mis-resolution of the four
  mass-dominant counties in place. Rejected.
- **A finer or coarser grid.** 0.01° matches the geocoder's coordinate
  precision and the existing point cache. Finer (0.001°) shrinks straddle but
  multiplies rows and risks consumer-side rounding mismatches; coarser raises
  the straddle fraction. 0.01° + an explicit straddle flag is the balance.

## Consequences

- **One new contracted artifact** ([[ct-planning-region-crosswalk]]) under
  the existing `s3://nccsdata/crosswalks/` prefix, coordinate-keyed.
- **Two existing contracts change shape and are republished.**
  [[county-fips-crosswalk]] gains the `deferred_ct_planning_region`
  `resolution` value (3,615 resolved / 8 deferred / 8 ambiguous / 4
  unresolved); [[cbsa-crosswalk]]'s universe gains the 9 CT GEOIDs
  (3,224 → 3,228 rows). Both were overwritten on S3 (flat prefix, sha256
  idempotent), so a consumer pinned to the prior sha picks up the new content
  on its next pull.
- **`sector-in-brief-data`'s CT hole becomes fixable.** Adopting the
  companion (a new coordinate join, CT-only) recovers the ~14k CT orgs that
  are currently "unassigned county". This is a real consumer-side change, not
  a transparent one — tracked as a follow-up, not assumed.
- **ADR 0021 Follow-up 4 is resolved.** CT regains county-grain geography.
- **The per-coordinate door is open.** This is the first coordinate-keyed
  crosswalk; the same machinery (grid + point-in-polygon) is how any future
  sub-county identifier would be retrofitted, consistent with ADR 0021's
  scope-boundary note.

## Deprecation window

No master field changes, so no break there. The companion is additive to the
contract surface. The two reshaped crosswalks are additive-in-spirit (CT rows
moved from `ambiguous`/silent to `deferred` + companion; no non-CT mapping
changed); the standard 90-day window applies to any consumer that pinned CT's
prior (wrong) behavior.

## Outcome (2026-06-04)

**Shipped.** `nccs-data-bmf` built and published the companion and rebuilt
the two affected crosswalks:

- Build: `scripts/build_ct_planning_region_crosswalk.R` (TIGER 2023 CT
  polygons → dense 0.01° grid, 5×5 sub-sampled point-in-polygon per cell →
  14,271 cells, all 9 regions, 3.7% straddle).
- Publish: `R/publish_ct_planning_region_crosswalk.R`, thin wrapper over
  `R/publish_crosswalk.R` (parquet + CSV mirror + ADR 0014 `_manifest.json`,
  sha256-idempotent).
- `s3://nccsdata/crosswalks/ct-planning-region/` — new. `county-fips/` and
  `cbsa/` overwritten with the reshaped content. `tiger_year` ==
  `delineation_year` == 2023 across all three.
- Producer PRs #18 (artifact + producer docs) and #19 (guidebook index)
  merged to `nccs-data-bmf` `main`.

**Consumer adoption — sector-in-brief-api (2026-06-09).** The modernized
data-download API adopts the CT companion from the start: it resolves CT by
joining this crosswalk on `(geo_state_abbr, printf('%.2f', geo_lat),
printf('%.2f', geo_lon)) → geo_county_fips` (the AUTHORITATIVE CT override),
chaining [[cbsa-crosswalk]] on the resolved FIPS — so its CT orgs resolve to
planning-region FIPS rather than landing unassigned. Live in staging (slices
1–5.1); recorded in the [[ct-planning-region-crosswalk]] consumer entry. Note
the contrast with Follow-up 1: `sector-in-brief-data` still carries the ~14k-org
CT hole pending its own adoption, so the two consumers' CT geography can differ
until that lands.

**Join-implementation hazard (surfaced 2026-06-11, [[0029-bmf-org-level-query-mode]]
Outcome).** The `geo_state_abbr = 'CT'` term above must be a **two-sided
equi-join key** (`b.geo_state_abbr = ct._ct_state`, carrying the `'CT'` literal
on the crosswalk side), **not** a single-sided constant filter on the probe row.
As a constant filter, DuckDB hash-joins on the rounded `(lat2, lon2)` cell
alone, so any non-CT org sharing a 0.01° cell with a CT crosswalk point fans
out before the state predicate prunes it — on a weakly-filtered, full-registry
query this explodes into the billions and hangs. Latent for label-first
consumers (they reduce to a small state before the join); it bit the API's
unfiltered `source=bmf` worst case. Not BMF-specific — any consumer of this
crosswalk must key the state on **both** sides. Fixed in sector-in-brief-api PR #6.

## Follow-up

1. **`sector-in-brief-data` adopts the CT companion** to recover the ~14k
   unassigned CT orgs — a coordinate join on its geocoded rows, unioned back
   with the label-resolved rows. Currently the live consumer with the hole.
2. **NCCS website BMF data catalog** surfaces the companion's CSV mirror
   alongside the other two (planned consumer; register the real pin when
   live).
3. **Vintage migration trigger (extends ADR 0021's).** When TIGER/OMB 2024
   lands, all **three** crosswalks move to `v{YYYY}/` + `latest/` together —
   the companion is now part of the coupled vintage set.
