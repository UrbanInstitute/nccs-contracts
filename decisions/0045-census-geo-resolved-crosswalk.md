# 0045 — Census-Geo-Resolved Crosswalk (per-EIN tract/block assignment)

- **Status:** Proposed
- **Date:** 2026-07-29
- **Deciders:** sole maintainer
- **Related:** [[0034]] (ntee-resolved; the per-EIN resolved-artifact pattern this copies), [[0041-legacy-street-recovery-address-resolved-crosswalk]] (address-resolved crosswalk; source of the spell grain a future extension would use), [[0016-no-canonical-cross-dataset-merge]] (geography stays a join, not master columns), [[0023]] (county-fips crosswalk precedent, CT planning-region handling), [[0042-vintage-retention-latest-convention]] (publish layout), [[0044-legacy-zip-leading-zero-restoration]] (Z1 rebuild this sequences behind)

## Context

Repeated internal requests reduce to "NCCS data + census geography": the
Milwaukee MSA request, the Illinois county request, and a 2026-07-29 internal
ask for FIPS availability across BMF/CORE/e-file. County FIPS is served by a
label join against the published `county-fips` crosswalk (ADR 0023), but
**census tracts, block groups, and blocks have no label in any source
dataset**: they can only come from a spatial assignment of the geocoded
Unified BMF's `geo_lat`/`geo_lon`.

That makes this a different artifact class from `county-fips`: not a label
lookup consumers join by name, but a **per-EIN resolved table** in the ADR
0034 pattern (compute once, publish, everyone joins by `ein`).

## Decision

**1. New published artifact: `crosswalks/census-geo-resolved/`** (name
final at build time), produced by `nccs-data-bmf`, published under the ADR
0042 `{vYYYY.MM, latest}` convention with an ADR 0014 manifest and a data
dictionary.

**2. Store the block GEOID; derive everything else by prefix.** Census
GEOIDs nest: the 15-digit block GEOID contains block group (12), tract (11),
county (5), and state (2) as prefixes. Columns:

- `ein` (canonical `XX-XXXXXXX`)
- `block_geoid_2020`, `block_geoid_2010` — one column per decennial
  boundary vintage. Both ship from day one: analysts joining pre-2020 ACS
  need 2010 boundaries. Tract/BG/county are documented derivations
  (substring), not stored columns.
- `geo_match_type`, `geo_score`, `org_addr_is_po_box` carried through so
  consumers can filter on assignment quality.

**3. Match-quality gate.** Only point-level geocodes get a block
assignment. ZIP-centroid / city-level matches get NA, never a
centroid-derived block: a wrong-but-plausible block GEOID is worse than a
missing one. The exact `geo_match_type`/`geo_score` cut is settled at build
time and recorded in the dictionary.

**4. Implementation: local point-in-polygon**, ~2.4M geocoded points
against TIGER/Line block shapefiles (sf or DuckDB spatial) in
`nccs-data-bmf`. No geocoder involvement, no per-call cost. Validation
gate: every assigned block's county prefix must match the org's
crosswalk-resolved county FIPS; disagreements halt and are triaged as
geocoding defects (free quality check on the geocoder itself).

**5. Scope: current address only.** One row per EIN from the geocoded
Unified BMF. A tract-per-spell extension over the address-resolved
crosswalk (ADR 0041) is explicitly deferred until someone asks for tract
*history*.

**6. Sequencing: after the Z1 rebuild (ADR 0044).** Z1 re-geocodes ~124k
orgs whose coordinates are wrong-or-missing today; assigning blocks first
would mean an immediate republish.

## Contract impact

Additive: a new contract YAML (`contracts/census-geo-resolved.yml`) at
first publish. No existing surface changes. Consumers (nccsdata, the
download API, requests repo) may later expose the join, each as its own
contract-guarded change.

## Consequences

- Tract/block/BG analysis becomes a single `ein` join for every consumer,
  with boundary vintage explicit.
- Coverage is bounded by geocoding (82.7% of orgs pre-Z1, point-level
  matches only), and mailing addresses (PO boxes) locate the box, not the
  org: both are documented consumer caveats, not fixable here.
- TIGER/Line vintage used for each boundary set is pinned in the manifest.

## Outcome

_To be filled at reconcile: artifact path, row/coverage counts by match
tier, county-consistency gate results, contract YAML population._
