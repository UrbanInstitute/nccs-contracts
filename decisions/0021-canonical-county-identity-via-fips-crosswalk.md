# 0021 — Canonical Geography Identity via Published Crosswalks (County FIPS + CBSA)

- **Status:** Accepted (executed 2026-06-04) — see Outcome
- **Date:** 2026-06-03 (amended 2026-06-04 — two-crosswalk, master-unchanged design)
- **Deciders:** sole maintainer; BMF + data owners
- **Related:** [[0010-sector-in-brief-data-replaces-dataexplorer-data]], [[0011-decouple-dashboard-from-committed-data]], [[0013-versioned-producer-outputs]], [[0014-standardize-manifest-shape]], [[0016-no-canonical-cross-dataset-merge]], [[bmf-master-geocoded]], [[county-fips-crosswalk]], [[cbsa-crosswalk]], [[sector-in-brief]]

## Context

A consumer investigation into the Sector-in-Brief dashboard surfaced a
gross over-count: **33,368** nonprofits reported for the seven
Detroit-metro counties against **~21,000** from a direct BMF query for
the same place. The root cause is geographic *identity*, not the data:

1. **`geo_county` is a dirty free-text label.** The BMF's geocoded
   `geo_county` column is whatever string the geocoder emitted —
   inconsistent suffixing (`"Wayne"` vs `"Wayne County"`), spelling and
   punctuation variants (`"St Louis"` / `"St. Louis"`, `"LaRue"` /
   `"Larue"`), and a handful of bare-with-sibling strays (a bare label
   that also occurs in a suffixed/variant form). A name-equality filter
   therefore both over- and under-collects depending on which variant
   the query uses, and naive grouping double-counts.

2. **There is no county FIPS anywhere in the pipeline.** Nothing carries
   a stable county identifier, so a consumer cannot dedupe by identity
   and is forced into name-string matching — exactly the operation the
   dirty labels break.

3. **Name-only filtering collapses distinct jurisdictions.** County
   *names* are not unique. `"Monroe County"` exists in 17 states. Worse,
   several **independent cities** share a name with a separate county and
   are legally distinct geographies with distinct FIPS — Baltimore
   city / Baltimore County (MD), St. Louis city / St. Louis County (MO),
   and the Virginia independent cities (Fairfax, Franklin, Richmond,
   Roanoke — each a city *and* a county). Name matching silently merges
   these, inflating counts.

The same identity gap blocks a second need: the Sector-in-Brief metro
dimension (`CENSUS_CBSA_NAME`, "Metro/Micro Area"). [[0010-sector-in-brief-data-replaces-dataexplorer-data]]
derived it inside `sector-in-brief-data` from a repo-local Census
delineation file keyed on `(state, county-name)` — the *same* dirty
key, so the *same* bug class — and explicitly deferred the CBSA
crosswalk's own contract as a follow-up. A stable county FIPS makes CBSA
a clean derived attribute and lets that follow-up land here.

The Detroit-metro over-count is one visible symptom of this whole bug
class. Cleaning the names alone would not fix it: the city/county
collisions are genuinely distinct geographies that no spelling
normalization can separate. The pipeline needs a *stable identity key*.

## Decision

Fix at the producer, **but do not modify the master.** `nccs-data-bmf`
resolves county identity from the geocoded coordinates once and publishes
**two reusable crosswalk artifacts** that consumers join. Per
[[0016-no-canonical-cross-dataset-merge]], the join lives at the consumer;
the producer ships the resolution, not a pre-merged table.

1. **Resolve identity from coordinates, once.** Spatial-join each
   geocoded `(lat, lon)` against Census TIGER county polygons
   (`tigris::counties(cb = TRUE, year = TIGER_YEAR)`, default 2023) to
   obtain the authoritative county **GEOID** (5-char state+county FIPS).
   Done once at the producer, not per-consumer.

2. **Publish a name→FIPS crosswalk** ([[county-fips-crosswalk]]) keyed on
   the *raw* label — one row per distinct `(geo_state_abbr,
   geo_county_raw)` pair — mapping each dirty label to its
   `geo_county_fips`, `state_fips`, the Census **canonical** name
   (`geo_county_canonical` = `NAMELSAD`, carrying the correct suffix:
   County / Parish / Borough / Census Area / Municipality / city /
   Municipio), a `resolution` flag (`resolved` | `ambiguous` |
   `unresolved`), and the `tiger_year` it was resolved against.

3. **Publish a derived county→CBSA crosswalk** ([[cbsa-crosswalk]]) — one
   row per *resolved* county GEOID from #2 — mapping `county_fips` to its
   CBSA (`cbsa_code`, `cbsa_title`, `cbsa_type`, `central_outlying`) and
   CSA (`csa_code`, `csa_title`), with the `delineation_year`. Built from
   #2 plus the OMB delineation (Census "List 1", `list1_{year}.xlsx`,
   default July-2023). CBSA columns are `NA` for rural counties in no
   CBSA. This supersedes ADR 0010's repo-local CBSA derivation.

4. **The master is deliberately NOT modified.** `bmf-master-geocoded`
   gains **no** `geo_county_fips`/CBSA columns and `geo_county` stays the
   **raw** geocoder label. A consumer that wants canonical identity joins
   the crosswalks. Rationale below; recorded as an intentional non-change
   in [[bmf-master-geocoded]].

### The join chain (consumer-composed)

```
raw geocoder label
   │  join [[county-fips-crosswalk]] on (geo_state_abbr, geo_county)
   ▼
geo_county_fips  (+ state_fips, geo_county_canonical, resolution)
   │  join [[cbsa-crosswalk]] on county_fips = geo_county_fips
   ▼
cbsa_code / cbsa_title / cbsa_type / csa_code / csa_title
```

Both crosswalks are keyed for a cheap, reusable, human-auditable join:
the expensive per-coordinate TIGER resolution happens once at the
producer and is amortized across every consumer holding the same dirty
`(state, county-name)` strings. Nothing is added to the master.

### Why the master is not the place for this

The original draft of this ADR had `bmf-master-geocoded` left-join the
crosswalk to add `geo_county_fips` and overwrite `geo_county` with the
canonical name. That was **reversed** before execution:

- **It would pin a geography vintage into the master.** Baking
  `geo_county_fips`/CBSA into the master binds *every* master consumer to
  one TIGER/OMB delineation year. The crosswalks instead carry their own
  vintage (`tiger_year`/`delineation_year`) and are joined by whoever
  needs that vintage — consumers pick their geography year the way
  [[0013-versioned-producer-outputs]] lets them pin a data vintage.
- **It is the consumer's join to make.** Per
  [[0016-no-canonical-cross-dataset-merge]], the master is a producer
  surface; merges and derived attributes live at the consumer. Resolution
  (the expensive part) belongs at the producer; the join (the cheap part)
  belongs at the consumer.
- **It keeps the master additive-only.** No existing column changes
  meaning, so no master consumer can silently break.

### Why FIPS is the durable key

A 5-char county GEOID is the stable, collision-free federal identifier
for a county-equivalent. Keying on it ends the entire bug class at once:
name variants collapse to one identity, same-named counties in different
states stay distinct (the state digits differ), and independent cities
keep their own GEOID and canonical name and are never merged with the
like-named county. Names become a *display* attribute derived from the
key, not the join key. No amount of string cleaning achieves this,
because the failure is identity collision, not spelling.

**FIPS, CBSA, and CSA codes are strings, not integers.** Leading zeros
are significant (state `01` Alabama; the 5-char GEOID; padded 3-char
CSA codes). The producer pads and writes them as `chr`; consumers must
keep them as strings — a numeric cast silently corrupts every
leading-zero code.

### Scope boundary — county and state FIPS only

This decision resolves **state FIPS + county FIPS** and the CBSA/CSA
attributes that derive from a county GEOID. It explicitly does **not**
add tract, block, place, or ZCTA identifiers.

- **No consumer needs them.** The collisions and counting bugs are all
  at county grain; there is no current consumer keyed below county.
  CBSA/CSA are county-grain roll-ups, not finer geography.
- **They are per-coordinate, not per-label.** Sub-county geographies do
  not resolve from a `(state, county-name)` crosswalk — they require a
  point-in-polygon lookup per row, a materially larger and finer build.
- **Retrofit is cheap later.** Once every coordinate resolves to a stable
  county GEOID (and the coordinates remain), adding a finer identifier is
  the same resolution machinery, with no rework of what this ADR ships.

### S3 layout — flat prefix, no vintage subdir (ADR 0013 exception)

Both artifacts publish to a **flat** prefix —
`s3://nccsdata/crosswalks/county-fips/` and
`s3://nccsdata/crosswalks/cbsa/` — with **no `{vintage}/` subdir and no
`latest/` mirror**, a deliberate exception to
[[0013-versioned-producer-outputs]]. They are small (~3.6k / ~3.2k rows),
additive (new raw labels appended; existing mappings stable), the
geography vintage is carried *in-column* (`tiger_year` /
`delineation_year`) and *in the manifest* (`vintage`), and exactly one
geography vintage is live at a time. The reproducibility path-vintaging
buys is provided by the explicit vintage columns. The exemption is
recorded in [[0013-versioned-producer-outputs]]. **Revisit trigger:** when
a second geography vintage lands (TIGER/OMB 2024), a flat single file
cannot hold two delineation years at once — at that point both artifacts
move to `{key_prefix}/v{YYYY}/` + `latest/` (vintage = geography year).

## Invariants (guaranteed by the producer; asserted in the contracts)

- **One canonical name per FIPS.** For every state, the distinct
  `geo_county_fips` count equals the distinct `geo_county_canonical`
  count among resolved rows — the mapping FIPS→name is a function.
- **Cities never merge with counties.** Independent cities and their
  like-named counties carry distinct FIPS and distinct canonical names
  (the `city` suffix is preserved). They are never collapsed.
- **A county belongs to at most one CBSA.** [[cbsa-crosswalk]] has one
  row per county GEOID; `county_fips` is unique.
- **Vintage coupling.** [[county-fips-crosswalk]]'s `tiger_year` must
  equal [[cbsa-crosswalk]]'s `delineation_year` — the CBSA delineation is
  defined over the same county GEOID universe the FIPS crosswalk
  resolved. A mismatch means a county GEOID could exist in one and not
  the other. The two artifacts are rebuilt and republished together.
- **Left-join preserves counts.** Consumers left-join the crosswalk onto
  their org rows; no rows are dropped. Labels that are `ambiguous` or
  `unresolved` carry `NA` FIPS/canonical-name and fall out of
  FIPS-keyed selection — they are enumerated in the producer's
  `*_audit.csv` (see below), not silently merged.
- **Additive across vintages.** Existing `(state, raw label) → FIPS`
  mappings are stable; new raw labels are appended, never rewritten.

### Audit sidecars (not part of the contract surface)

Each build emits a `*_audit.csv` beside the artifact, useful for review
but **not** contracted (no consumer pins it):

- `county_fips_crosswalk_audit.csv` — the `ambiguous` + `unresolved`
  labels only (16 of 3,635 pairs; 99.6% resolve), with candidate
  GEOIDs and org-share diagnostics.
- `cbsa_crosswalk_audit.csv` — the rural tally (counties in no CBSA) and
  delineation counties absent from the BMF universe.

## Rejected / changed alternatives

- **Canonicalize in the master (original ADR 0021 draft).** *Changed.*
  Adding `geo_county_fips`/CBSA columns and rewriting `geo_county` in
  `bmf-master-geocoded` pins a geography vintage into the master and puts
  a derived join on the producer surface — both contrary to
  [[0016-no-canonical-cross-dataset-merge]]. Replaced by the
  consumer-composed join above.
- **Clean the names with regex/lookup, keep name as the key.** Brittle
  (every new geocoder variant reopens the bug) and, decisively, cannot
  separate the independent-city/county collisions — they are different
  geographies with identical names. Rejected.
- **Resolve FIPS/CBSA in each consumer.** Duplicates the TIGER + OMB
  resolution across every consumer, invites drift between them, and
  re-pays the cost each time. Resolution belongs once, at the producer;
  only the (cheap) join is per-consumer. Rejected.
- **Resolve finer geographies now (tract/block/place/ZCTA).** No
  consumer, larger build, and cheaply retrofittable later on the FIPS
  foundation. Premature. Rejected.

## Consequences

- **The master is unchanged** — purely a non-change. `geo_county` stays
  raw; no new column. No master consumer can break. Recorded in
  [[bmf-master-geocoded]].
- **Two new contracted artifacts** ([[county-fips-crosswalk]],
  [[cbsa-crosswalk]]) join the surface under a new top-level
  `s3://nccsdata/crosswalks/` prefix, reusable by any consumer holding
  dirty `(state, county)` strings.
- **ADR 0010's deferred CBSA-crosswalk follow-up is resolved** — CBSA is
  now a producer-published artifact, not a `sector-in-brief-data`-local
  file. `sector-in-brief-data` derives `CENSUS_CBSA_NAME` by joining
  [[cbsa-crosswalk]], and canonicalizes/dedupes its county dimension by
  joining [[county-fips-crosswalk]] (it changes *from* a repo-local
  delineation file *to* the published crosswalks — a real consumer-side
  change, unlike the original master-canonicalization plan which would
  have been transparent).
- **The over-count is fixable by every consumer** that adopts FIPS-keyed
  selection (33,368 → the true ~21k for the seven Detroit-metro
  counties). The fix is available at the source; it lands when each
  consumer joins.
- **A new dependency edge for the dashboard.** The `sector-in-brief`
  county filter/dropdown should move from name-based to FIPS-keyed
  selection (per [[0011-decouple-dashboard-from-committed-data]], it reads
  published data — the key it filters on should be the published FIPS).

## Deprecation window

No master field changes, so no break and no window there. The two
crosswalk artifacts are purely additive to the contract surface.
`sector-in-brief-data`'s switch from its repo-local delineation file to
[[cbsa-crosswalk]] is coordinated in that repo on its own cadence; the
repo-local file stays usable until it cuts over.

## Outcome (2026-06-04)

**Shipped.** `nccs-data-bmf` built and published both crosswalks:

- Build: `scripts/build_county_fips_crosswalk.R` (lat/lon → TIGER 2023
  county spatial join + name gazetteer fallback) and
  `scripts/build_cbsa_crosswalk.R` (county GEOID → OMB July-2023 List 1).
- Publish: `R/publish_county_fips_crosswalk.R` and
  `R/publish_cbsa_crosswalk.R`, thin wrappers over
  `R/publish_crosswalk.R` (parquet + CSV mirror + ADR 0014
  `_manifest.json`; sha256-keyed idempotent upload).
- `s3://nccsdata/crosswalks/county-fips/` — 3,635 rows (3,619 resolved,
  99.6%; 16 ambiguous/unresolved). `s3://nccsdata/crosswalks/cbsa/` —
  3,224 rows (one per resolved county GEOID; rural counties carry NA
  CBSA). `tiger_year` = `delineation_year` = 2023.
- Contracts reconciled: [[county-fips-crosswalk]] and [[cbsa-crosswalk]]
  (both `active`), and [[bmf-master-geocoded]] records the intentional
  non-change.

**Diverged from the original draft** (all folded into the Decision
above): (a) the master is *not* modified — the "canonicalize in the
master" step was dropped for consumer-composed joins per ADR 0016;
(b) a second derived artifact (CBSA) was added, resolving ADR 0010's
follow-up; (c) location moved from `geocoding/bmf-master/crosswalks/` to
a new top-level `crosswalks/` prefix; (d) `resolution` + `tiger_year`
columns added; (e) flat layout — documented ADR 0013 exception.

### Consumer adoption — sector-in-brief-data (2026-06-04)

**First contracted consumer cut over** (`sector-in-brief-data` commit
`c074f5d`, shipped in its vintage **v2026.07**). It joins both crosswalks
per the chain above — replacing its repo-local `(state, county-name)` OMB
delineation file — and:

- **Canonicalizes county + attaches FIPS.** `Census County` becomes the
  canonical name; `ambiguous`/`unresolved` labels resolve to **NA
  ("unassigned"), not raw passthrough** — consistent with the
  "fall out of FIPS-keyed selection" invariant above. Reproduces this
  ADR's motivating bug on its own geography — the seven SE-Michigan
  counties (Wayne, Oakland, Macomb, Washtenaw, Livingston, Monroe,
  St. Clair), where name-based selection produced the 33,368 over-count
  vs ~21k true: on v2026.07, selecting those county names across all
  states over-counts (501(c)(3), 2026: 30,811) vs FIPS-keyed (19,787),
  the inflation being same-named counties in other states.
- **Treats FIPS/CBSA codes as the identity key, in every panel.**
  `County FIPS` and `CBSA Code` (both `chr`) are added to every panel as
  dimensions (cardinality-free — 1:1 with their names); names are
  display-only. The consumer chose codes-in-every-panel over a
  lookup-only design so the dashboard filters by code with no name
  round-trip.
- **Sets a producer/consumer boundary (consumer-side decision).**
  `sector-in-brief-data` owns geography *identity* and publishes the
  enriched `nested_geographies` lookup + vintage-local copies of both
  crosswalks; the `sector-in-brief` dashboard derives *presentation* at
  runtime — dropdown options = distinct geographies present in a panel,
  "N records unassigned" per state = sum of the panel's NA-geography
  cells. Deliberately **not** pre-baked as artifacts (consistent-by-
  construction with the panels). Recorded in [[sector-in-brief]].
- **Surfaces a known coverage hole.** Connecticut's post-2022
  planning-region labels are `ambiguous` → NA, so ~14k CT orgs land as
  "unassigned county" downstream. Correct by this ADR's design, but a
  large, concentrated effect — see Follow-up 4.

**Pending — consumer adoption:**

1. **Done (2026-06-04).** `sector-in-brief-data` joined both crosswalks
   (see "Consumer adoption" above). First contracted consumer.
2. The NCCS website BMF data catalog (planned consumer of the CSV
   mirrors).
3. The `sector-in-brief` dashboard county filter/dropdown moves to
   FIPS-keyed selection. **Unblocked** (v2026.07 in prod since
   2026-06-04); pending the dashboard PR.

## Follow-up

1. **Done (2026-06-04).** `sector-in-brief-data`'s cutover is confirmed
   (v2026.07); both contracts record the consumer with pin `latest` (flat
   layout has no vintage subdir, so `latest` is the durable pin).
2. **Register the NCCS website BMF catalog** as a consumer of the CSV
   mirrors once it goes live (placeholder consumer recorded now).
3. **Vintage migration trigger.** When TIGER/OMB 2024 lands, move both
   crosswalks to `v{YYYY}/` + `latest/` per the revisit trigger above and
   flip `versioned_template`/`latest_template` in both contracts.
4. **CT planning-region coverage.** The 4 Connecticut planning-region
   labels resolve to NA, leaving ~14k CT orgs unassigned at county grain
   for every downstream consumer. Consider resolving CT planning regions
   to their FIPS (the 2022 county→planning-region delineation) in a future
   crosswalk vintage so CT regains county-grain geography.
