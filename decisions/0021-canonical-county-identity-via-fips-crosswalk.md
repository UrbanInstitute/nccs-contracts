# 0021 — Canonical County Identity via a Published FIPS Crosswalk

- **Status:** Accepted (planning; producer artifact pending) — see Follow-up
- **Date:** 2026-06-03
- **Deciders:** sole maintainer; BMF + data owners
- **Related:** [[0011-decouple-dashboard-from-committed-data]], [[0016-no-canonical-cross-dataset-merge]], [[bmf-master-geocoded]], [[county-fips-crosswalk]], [[sector-in-brief]]

## Context

A consumer investigation into the Sector-in-Brief dashboard surfaced a
gross over-count: **33,368** nonprofits reported for the seven
Detroit-metro counties against **~21,000** from a direct BMF query for
the same place. The root cause is county *identity*, not the data:

1. **`geo_county` is a dirty free-text label.** The BMF's geocoded
   `geo_county` column is whatever string the geocoder emitted —
   inconsistent suffixing (`"Wayne"` vs `"Wayne County"`), spelling and
   punctuation variants (`"St Louis"` / `"St. Louis"`, `"LaRue"` /
   `"Larue"`), and roughly **346 bare-with-sibling strays** (a bare
   label that also occurs in a suffixed/variant form). A name-equality
   filter therefore both over- and under-collects depending on which
   variant the query uses, and naive grouping double-counts.

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

The Detroit-metro over-count is one visible symptom of this whole bug
class. Cleaning the names alone would not fix it: the city/county
collisions are genuinely distinct geographies that no spelling
normalization can separate. The pipeline needs a *stable identity key*.

## Decision

Fix at the producer. `nccs-data-bmf` resolves county identity from the
geocoded coordinates and publishes a reusable crosswalk:

1. **Resolve identity from coordinates, once.** Spatial-join each
   geocoded `(lat, lon)` against Census TIGER county polygons to obtain
   the authoritative county **GEOID** (5-char state+county FIPS). This is
   done once at the producer, not per-consumer.

2. **Publish a reusable name→FIPS crosswalk** keyed on the *raw* label —
   one row per distinct `(geo_state_abbr, geo_county_raw)` pair (~3,638
   rows) — mapping each dirty label to its `geo_county_fips`,
   `state_fips`, and the Census **canonical** name (`NAMELSAD`, which
   carries the correct suffix: County / Parish / Borough / Census Area /
   Municipality / city / Municipio). Contract: [[county-fips-crosswalk]].

3. **Canonicalize in the master.** `bmf-master-geocoded` left-joins the
   crosswalk on `(geo_state_abbr, raw geo_county)` to (a) add the new
   `geo_county_fips` column and (b) overwrite `geo_county` with the
   canonical `NAMELSAD`. Coordinate-resolved strays merge into their true
   county; no rows are dropped. See [[bmf-master-geocoded]].

The crosswalk is keyed on the raw label (not on coordinates) so it is a
cheap, reusable, human-auditable join for *any* dataset that already
carries the same dirty `(state, county-name)` strings — the expensive
per-coordinate TIGER resolution happens once and is amortized.

### Why FIPS is the durable key

A 5-char county GEOID is the stable, collision-free federal identifier
for a county-equivalent. Keying on it ends the entire bug class at once:
name variants collapse to one identity, same-named counties in different
states stay distinct (the state digits differ), and independent cities
keep their own GEOID and canonical name and are never merged with the
like-named county. Names become a *display* attribute derived from the
key, not the join key. No amount of string cleaning achieves this,
because the failure is identity collision, not spelling.

### Scope boundary — county and state FIPS only

This decision resolves **state FIPS + county FIPS** and nothing finer.
It explicitly does **not** add tract, block, place, or ZCTA identifiers.
Rationale:

- **No consumer needs them.** The collisions and counting bugs are all
  at county grain; there is no current consumer keyed below county.
- **They are per-coordinate, not per-label.** Sub-county geographies do
  not resolve from a `(state, county-name)` crosswalk — they require a
  point-in-polygon lookup per row, a materially larger and finer build.
- **Retrofit is cheap later.** Once every row carries a stable
  `geo_county_fips` (and the coordinates remain), adding a finer
  identifier is an additive column on the same resolution machinery,
  with no rework of what this ADR ships.

## Invariants (guaranteed by the producer; asserted in the contracts)

- **One canonical name per FIPS.** For every state, the distinct
  `geo_county_fips` count equals the distinct `geo_county_canonical`
  count — the mapping FIPS→name is a function.
- **Cities never merge with counties.** Independent cities and their
  like-named counties carry distinct FIPS and distinct canonical names
  (the `city` suffix is preserved). They are never collapsed.
- **Counts are preserved.** Canonicalization is identity-merging only:
  strays merge by coordinates into their true county; no org rows are
  dropped. Non-geocoded rows (no `lat`/`lon`) get `geo_county_fips = NA`.
- **Additive across vintages.** Existing `(state, raw label) → FIPS`
  mappings are stable; new raw labels are appended, never rewritten.

## Rejected alternatives

- **Clean the names with regex/lookup, keep name as the key.** Brittle
  (every new geocoder variant reopens the bug) and, decisively, cannot
  separate the independent-city/county collisions — they are different
  geographies with identical names. Rejected.
- **Resolve FIPS in each consumer.** Duplicates the TIGER join across
  every consumer, invites drift between them, and re-pays the cost each
  time. The fix belongs once, at the producer, per the
  consumer-composes-*joins* (not *resolution*) model of
  [[0016-no-canonical-cross-dataset-merge]]. Rejected.
- **Resolve finer geographies now (tract/block/place/ZCTA).** No
  consumer, larger build, and cheaply retrofittable later on the FIPS
  foundation. Premature. Rejected.

## Consequences

- **`geo_county` semantics change** from raw geocoder text to canonical
  Census `NAMELSAD`. Because the raw values were never reliable, this is
  a data-quality *fix*, not a contract-shape break — but a consumer that
  hard-coded a specific dirty string will need to update. Documented in
  [[bmf-master-geocoded]]; the main consumer ([[sector-in-brief]]) takes
  the canonical name transparently and needs no change.
- **`geo_county_fips` is purely additive** — a new column; no existing
  column is removed or retyped.
- **A new contracted artifact** ([[county-fips-crosswalk]]) joins the
  surface, reusable by any consumer holding dirty `(state, county)`
  strings.
- The county over-count that started this (33,368 → the true ~21k for
  the seven Detroit-metro counties) is resolved at the source for every
  downstream reader at once.

## Deprecation window

The additive `geo_county_fips` column needs none. The `geo_county`
content change (raw → canonical) is a data-quality correction to a field
that was never trustworthy; it ships with the next `bmf-master-geocoded`
build rather than carrying a 90-day window. Any consumer found to depend
on a specific raw string is handled case-by-case at reconcile.

## Follow-up

1. **Producer lands the artifact** (`nccs-data-bmf`): publish
   `county_fips_crosswalk.parquet` and add `geo_county_fips` +
   canonical `geo_county` to `bmf-master-geocoded`. Confirm the publish
   location (target: `s3://nccsdata/geocoding/bmf-master/crosswalks/`).
2. **Reconcile the contracts against the real artifact.**
   [[county-fips-crosswalk]] is authored in parallel from the agreed
   target schema and carries `status: deferred` + INTERIM markers; flip
   to `active` and confirm exact column names, row count, and path once
   it exists.
3. **Consumers move to FIPS-keyed selection.** `sector-in-brief-data`'s
   county dimension comes straight from `geo_county`, so it inherits the
   canonical name with no change and may later adopt `geo_county_fips` as
   the geo key; the `sector-in-brief` dashboard's county filter/dropdown
   should move from name-based to FIPS-keyed selection (per
   [[0011-decouple-dashboard-from-committed-data]], the dashboard reads
   published data — the key it filters on should be the published FIPS).
