# 0045 — Census-Geo-Resolved Crosswalk (per-EIN tract/block assignment)

- **Status:** Reconciled (2026-09-21). Built and published the same day (nccs-data-bmf #61; contract nccs-contracts #102, active).
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

- `ein` (canonical `XX-XXXXXXX`) plus the additive coercion-safe forms
  `ein_prefixed` / `EIN2` per ADR 0036, so legacy/NODC-keyed workflows join
  without reformatting.
- `block_geoid_2020`, `block_geoid_2010` — one column per decennial
  boundary vintage. Both ship from day one: analysts joining pre-2020 ACS
  need 2010 boundaries. Tract/BG/county are documented derivations
  (substring), not stored columns.
- `zcta_2020`, `congressional_district` — also point-in-polygon
  assignments with no substring relationship to the block GEOID, so they
  are stored, not derived. ZCTA because ZIP-to-ZCTA is a common analyst
  trap (ZIPs are routes, ZCTAs are areas); congressional district because
  it is the most-requested policy geography. The CD column is labeled with
  the Congress/TIGER vintage it was drawn from in the dictionary, since
  redistricting invalidates it on a different clock than the decennial.
- **CBSA/MSA is deliberately NOT a column.** County→CBSA is already
  published as the `cbsa` crosswalk; consumers derive the county FIPS from
  the block GEOID prefix and join that crosswalk. Duplicating it here
  would mint a second CBSA surface that can drift from the first (the ADR
  0016 rule: one authoritative surface per relationship).
- `geo_match_type`, `geo_score`, `org_addr_is_po_box` carried through so
  consumers can filter on assignment quality.

**3. Match-quality gate.** Only point-level geocodes get a block
assignment. ZIP-centroid / city-level matches get NA, never a
centroid-derived block: a wrong-but-plausible block GEOID is worse than a
missing one. The exact `geo_match_type`/`geo_score` cut is settled at build
time and recorded in the dictionary.

**4. Implementation: local point-in-polygon**, ~2.4M geocoded points
against TIGER/Line block shapefiles (sf or DuckDB spatial) in
`nccs-data-bmf`. No geocoder involvement, no per-call cost. **No EC2**:
partitioned state-by-state (the largest state's block file is ~1M polygons)
this is a laptop-scale job, minutes per state with a spatial index; an EC2
box would add provisioning and teardown overhead for a compute step smaller
than the validation runs we already do locally. Escalate to EC2 only if
memory forces it, which is not expected. Validation
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

## Outcome (2026-09-21)

**Artifact:** `s3://nccsdata/crosswalks/census-geo-resolved/v2026_09/` (parquet,
retained) and `latest/` (parquet, CSV, data dictionary), ADR 0014 manifests
pinning TIGER/Line 2020 and 2010 blocks, ZCTA 2020, congressional districts
from TIGER 2024 (119th Congress). Contract `census-geo-resolved-crosswalk.yml`
active. Built by `scripts/build_census_geo_resolved_crosswalk.R` on a laptop
(45 minutes cold, 11 minutes with TIGER cached); no EC2 was needed.

**Coverage, source vintage 2026_09:** 3,698,197 rows (one per EIN);
3,077,405 geocoded; 2,420,990 address-level (PointAddress, Subaddress,
StreetAddress, StreetAddressExt, StreetInt) and eligible for a block;
2,420,942 with a 2020 block, 2,420,937 with a 2010 block, 2,420,917 with a
ZCTA, 2,420,990 with a district. The 48 eligible points without a block lie
outside every polygon (shoreline, water). The 656,415 ZIP-centroid, street,
place and point-of-interest matches carry NA by the §3 gate.

**County-consistency gate (§4):** 707 disagreements in 2,392,335 comparable
rows, 0.03% against a 1% limit; written to an audit CSV. The gate is
implemented as a hard stop above the limit.

**Decisions taken at build time:** the tier cut above; `geo_match_addr`
(the geocoder's matched address) added as a column at the maintainer's
request so consumers can see what the coordinates stand for; the shared
crosswalk publisher now checks every upload before writing a manifest.

**Incident during the day:** a two-state trial file was published first by
mistake (the corrective rebuild had died after the script was edited while
running); it was replaced by the national build about two hours later,
before the contract was made active and before any consumer read the path.

**Next:** Z15, tract identifiers on the address-history spells (a new ADR),
now unblocked.
