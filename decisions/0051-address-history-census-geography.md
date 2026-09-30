# 0051: Census geography for the address history (a companion table to the address-resolved crosswalk)

- **Status:** Proposed (2026-09-30). Becomes Accepted when this pull request is merged.
- **Date:** 2026-09-30
- **Deciders:** sole maintainer
- **Related:** [[0045-census-geo-resolved-crosswalk]] (census geography for each organization's current address; its section 5 deferred this work), [[0041-legacy-street-recovery-address-resolved-crosswalk]] (the address history this table sits beside), [[0016-no-canonical-cross-dataset-merge]] (geography stays a join), [[0042-vintage-retention-latest-convention]] (publish layout), [[0036]] (EIN forms), [[0014]] (manifests), backlog rows Z15 (this work), Z30 (column revisions to the census crosswalk after Jesse Lecy's review)

## Context

The address-resolved crosswalk (ADR 0041) lists every mailing address an
organization has had in the Business Master File since 1989. Each row is one
"spell": one stretch of time during which an organization was listed at one
address. `spell_rank` 0 is the most recent address; higher ranks are earlier
ones.

The census-geo-resolved crosswalk (ADR 0045) gives the census block, ZIP Code
Tabulation Area and congressional district for each organization's current
address only. It deferred the earlier addresses "until someone asks for tract
history".

Someone has asked. A doctoral researcher at Columbia is tracking neighborhood
organizations in New York from year to year and needs to know which census
tract an organization was in at each point in time. We told her on 2026-08-24
that this work was starting.

Measured on 2026-09-25 against `crosswalks/address-resolved/latest/`:

- 7,612,332 earlier spells (rank above 0) across 3.69 million organizations.
- 3,857,982 of them have a street. They reduce to 3,239,201 distinct
  addresses. 258,332 of those are already geocoded, because they are also
  some organization's current address. 2,980,869 are new to the geocoder.
  That is about the size of one geocoding cycle (the July 2026 cycle was
  2.59 million addresses).
- 3,754,350 spells, all first seen before 2009, have no street. Almost all
  of them have a ZIP code.

The maintainer decided two things on 2026-09-30:

1. **Scope:** geocode every earlier address that has a street. ZIP-level
   placement for the spells with no street is left for a later round.
2. **Shape:** a separate companion table, not new columns on the address
   history.

## Decision

**1. New published table: `crosswalks/address-geo-resolved/`**, produced by
`nccs-data-bmf`. It is published the usual way (ADR 0042): a permanent
folder for each month, `v{YYYY_MM}/`, and a `latest/` copy, with a manifest
(ADR 0014), a CSV copy, a data dictionary and a 10,000-row sample file for
reviewers.

**2. One row per spell, every spell.** The table has exactly the same rows as
the address-resolved crosswalk of the same month, identified by
(`EIN2`, `spell_rank`), including rank 0. A user joins the two tables on
those two columns and gets the full address history with geography in one
step. Spells that could not be placed are present with empty geography
columns, so a missing row never has to be interpreted.

**3. The two tables must be from the same month.** `spell_rank` is renumbered
whenever an organization gains a new address, so rank 2 in one month may be
rank 3 in the next. The companion table is therefore always built from, and
published together with, the address-resolved crosswalk of the same month,
and its manifest records that file's checksum. The dictionary says plainly:
join `latest/` to `latest/`, or one `v{YYYY_MM}/` folder to the same
`v{YYYY_MM}/` folder, never across months.

**4. Columns.** Names follow the revisions agreed for the census crosswalk
after review (backlog Z30): every geography column carries its boundary year
or Congress number in its name, and values that are the same on every row
live in the manifest, not in a column.

- `EIN2`, `ein`, `ein_prefixed` (ADR 0036), `spell_rank`.
- `block_geoid_2020`, `block_geoid_2010`: the 15-digit census block under
  each set of boundaries. Tract, block group, county and state are the
  leading digits, as in ADR 0045.
- `zcta_2020`, `congressional_district_119`.
- `latitude`, `longitude`.
- `geo_match_level`: `address`, `po_box`, `zip`, `city`, or
  `not_geocoded` for spells with no street.
- `geo_addr_type`, `geo_score`, `geo_match_addr`, `org_addr_is_po_box`:
  carried from the geocoder so users can filter on quality.

**5. Same placement rule as ADR 0045.** Only address-level geocodes receive a
block. ZIP-centre and city-level matches keep their coordinates and their
`geo_match_level` but carry no block, because a wrong block that looks
plausible is worse than a missing one.

**6. Rank 0 is copied, not recomputed.** For current addresses the geography
comes from the census-geo-resolved crosswalk of the same month (operating
rule 6: read what is already published). A check in the build compares the
two and stops on any difference.

**7. Geocoding.** Earlier addresses are reduced to distinct
(street, city, state, 5-digit ZIP) combinations before anything is sent, so
an address shared by many organizations or many spells is geocoded once.
Submission reuses the existing machinery in `R/master_geocoding_delta.R`
under a new run identifier and follows operating rule 10 (at most three
batches in flight, a progress record kept on S3, resume from that record, no
blind resubmission). The geocoded distinct addresses are kept as a working
file so that later months send only addresses never seen before, which will
be a few thousand a month. The census step is the point-in-polygon code
already written for ADR 0045, run on a laptop.

**8. Out of scope for this round.**

- ZIP-level placement of the 3.75 million spells with no street. It needs a
  ZIP-to-ZCTA lookup that no repository has. These rows are published with
  `geo_match_level = not_geocoded`.
- Historical street networks. The geocoder places a 2010 address where that
  address is today. For nearly all addresses this is the same place. The
  dictionary states the limitation. Both 2010 and 2020 boundaries are
  supplied so users can pick the one that matches the period they study.

## Contract impact

Additive. A new contract file, `contracts/address-geo-resolved-crosswalk.yml`,
is added with this decision as `planned` and made `active` at first publish.
The address-resolved crosswalk and the census-geo-resolved crosswalk do not
change. No consumer is affected.

## Consequences

- Tract history becomes one join for any user of the address history.
- The table is rebuilt every month with the address history. After the first
  round the monthly geocoding load is small.
- The first round puts about 2.98 million addresses through the shared
  geocoder, roughly one ordinary cycle. It must not overlap with the monthly
  Unified BMF geocoding.
- Coverage is limited to spells with a street, which begin with the 2009
  files. Earlier spells are listed but not placed.
- Post office boxes locate the post office, not the organization, and are
  flagged, as in ADR 0045.
- A user who joins across different months gets wrong matches without any
  error. The same-month rule in section 3, the manifest checksum and the
  dictionary are the protection against this.

## Execution

| Step | Repo | Work |
|---|---|---|
| 1 | nccs-contracts | This decision, the planned contract, backlog row Z15. |
| 2 | nccs-data-bmf | Reduce earlier spells to distinct addresses; separate those already geocoded; submit the rest under a new run identifier; keep the geocoded-address working file. |
| 3 | nccs-data-bmf | Assign blocks, ZCTA and district with the ADR 0045 code; assemble one row per spell; copy rank 0 from the census crosswalk; run the checks below; publish with dictionary, CSV and sample. Breadcrumb `ADR 0051`. |
| 4 | nccs-contracts | Contract to `active`, Outcome section, release note in `governance/release-notes/`. |
| 5 | nccs | Catalog row and a short join example on the BMF page. |
| 6 | maintainer | Tell the requesting researcher it is available. |

## Acceptance

The build stops before publishing unless all of these hold:

- The row count equals the row count of the address-resolved crosswalk of
  the same month, and (`EIN2`, `spell_rank`) is unique and matches that
  table exactly.
- Every rank-0 row carries the same blocks, ZCTA and district as the
  census-geo-resolved crosswalk of the same month.
- Every spell with no street has `geo_match_level = not_geocoded` and empty
  geography.
- The state in the first two digits of each assigned block agrees with the
  spell's state for at least 99 percent of placed rows; disagreements are
  written to an audit file.
- Every distinct address submitted to the geocoder is accounted for in the
  progress record as returned or as failed, with none missing.
- Building twice from the same inputs gives identical files.
