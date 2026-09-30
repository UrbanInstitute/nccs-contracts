# 0051: Census geography for the address history (a companion table to the address-resolved crosswalk)

- **Status:** Accepted (2026-09-30). The maintainer made the scope and shape decisions on this date; merging nccs-contracts #105 authorizes the work in `nccs-data-bmf`.
- **Date:** 2026-09-30
- **Deciders:** sole maintainer
- **Related:** [[0045-census-geo-resolved-crosswalk]] (census geography for each organization's current address; its section 5 deferred this work), [[0041-legacy-street-recovery-address-resolved-crosswalk]] (the address history this table sits beside), [[0016-no-canonical-cross-dataset-merge]] (geography stays a join), [[0042-vintage-retention-latest-convention]] (publish layout), [[0036]] (EIN forms), [[0014]] (manifests), backlog rows Z15 (this work), Z30 (column revisions to the census crosswalk after Jesse Lecy's review)

## Context

The address-resolved crosswalk (ADR 0041) lists every mailing address an
organization has had in the Business Master File since 1989. Each row is one
"spell": one distinct address for one organization, with the first and last
month it was seen. `spell_rank` 0 is the most recent address; higher ranks
are earlier ones.

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
2. **Shape:** a separate companion table, not geography columns on the
   address history.

## Decision

**1. New published table: `crosswalks/address-geo-resolved/`**, produced by
`nccs-data-bmf`. It is published the usual way (ADR 0042): a permanent
folder for each build, `v{YYYY_MM}/`, and a `latest/` copy, with a manifest
(ADR 0014), a CSV copy, a data dictionary and a 10,000-row sample file for
reviewers.

**2. One row per spell, every spell.** The table has exactly the same rows as
the address-resolved crosswalk it was built from, including each
organization's current address. A user joins the two tables and gets the
full address history with geography in one step. Spells that could not be
placed are present with empty geography columns, so a missing row never has
to be interpreted.

**3. A stable identifier for each spell, `spell_id`, in both tables.**
`spell_rank` cannot be the join key. It is renumbered whenever an
organization gains a new address, so rank 2 in one month may be rank 3 in
the next, and a join on rank between files from different months would
match the wrong addresses without any error. Publication to S3 is not
atomic, so even a reader who takes both `latest/` files can receive one
from before a monthly update and one from after.

A spell is one organization at one address, and that pair does not change
from month to month. So:

- `spell_id` is the first 16 hexadecimal characters of the SHA-256 of
  `EIN2`, street, city, state and 5-digit ZIP, in their normalized
  published form, joined with `|`, with a missing value written as an empty
  string. The build checks that it is unique.
- The companion table is keyed on `spell_id`. It does not carry
  `spell_rank`, so the unsafe join is not available.
- **The address-resolved crosswalk gains one added column, `spell_id`.**
  This is the only change to an existing table. It is additive: no column
  is renamed or removed and no row changes, so no current reader is
  affected. Its contract is updated when the column is first published.

With this key, joining files from different months cannot produce a wrong
match. The only effect is that a spell present in one file and not yet in
the other goes unmatched. For reproducible work, users should still pin
both tables to the same `v{YYYY_MM}/` folder. The manifest records the
checksum of the address-resolved file the table was built from, for anyone
who wants to verify the pairing.

**4. Columns.** This section defines the columns on its own terms. It does
not depend on the Z30 revisions to the census crosswalk, which are not yet
decided. The names chosen here match what Z30 proposes (boundary year or
Congress number in the name; values that are the same on every row live in
the manifest), so the two tables agree if Z30 is adopted as written.

| Column | Source |
|---|---|
| `spell_id` | Section 3. |
| `EIN2`, `ein`, `ein_prefixed` | From the address history (ADR 0036). |
| `block_geoid_2020`, `block_geoid_2010` | Point-in-polygon against TIGER/Line blocks, the ADR 0045 code. Tract, block group, county and state are the leading digits. |
| `zcta_2020` | Point-in-polygon, 2020 ZIP Code Tabulation Areas. |
| `congressional_district_119` | Point-in-polygon, districts of the 119th Congress. The same values the census crosswalk publishes today under the name `congressional_district`. |
| `latitude`, `longitude` | The geocoder's returned coordinates. |
| `geo_match_level` | Derived from the geocoder's result, see below. Never empty. |
| `geo_addr_type`, `geo_score`, `geo_match_addr`, `org_addr_is_po_box` | Carried from the geocoder so users can filter on quality. |

`geo_match_level` takes one of these values:

- `address`: the geocoder matched a specific address (tiers PointAddress,
  Subaddress, StreetAddress, StreetAddressExt, StreetInt, the ADR 0045 cut).
- `po_box`: the match is a post office box.
- `zip`: matched to a ZIP code centre only.
- `city`: matched to a city or place only.
- `other`: any other result, such as a street name without a number or a
  point of interest.
- `no_match`: the address was sent to the geocoder and came back with no
  match or an error.
- `not_geocoded`: the spell has no street and was not sent.

The geocoder tiers that fall under `zip`, `city` and `other` are fixed at
build time and listed in the dictionary.

**5. Same placement rule as ADR 0045.** Only `address` rows receive a block,
ZCTA and district. Other matched rows keep their coordinates and their
`geo_match_level` but carry no block, because a wrong block that looks
plausible is worse than a missing one. `no_match` and `not_geocoded` rows
have every geography column empty.

**6. Current addresses are copied, not recomputed.** For each organization's
current address the geography comes from the census-geo-resolved crosswalk
(operating rule 6: read what is already published). The build compares
`block_geoid_2020`, `block_geoid_2010`, `zcta_2020` and the district
(`congressional_district` there, `congressional_district_119` here) and
stops on any difference.

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

- A new contract file, `contracts/address-geo-resolved-crosswalk.yml`, is
  added with `status: deferred` (the template's state for a table that is
  decided but not yet published) and made active at first publish.
- `contracts/address-resolved-crosswalk.yml` gains the `spell_id` column
  when it is first published. Additive; no reader is affected.
- The census-geo-resolved crosswalk does not change.

## Consequences

- Tract history becomes one join for any user of the address history.
- The table is rebuilt about once a quarter, after a geocoded Unified BMF
  publish that adds newly geocoded addresses, not every month (review
  2026-09-30: monthly was too frequent for an 11 million row file that
  gains a few thousand spells a month). Between rebuilds, new spells in the
  address history go unmatched on `spell_id`, never mismatched. After the
  first round each rebuild sends only addresses never seen before.
- The first round puts about 2.98 million addresses through the shared
  geocoder, roughly one ordinary cycle. It must not overlap with the monthly
  Unified BMF geocoding.
- Coverage is limited to spells with a street, which begin with the 2009
  files. Earlier spells are listed but not placed.
- Post office boxes locate the post office, not the organization, and are
  flagged, as in ADR 0045.
- The address history grows by one 16-character column on about 11 million
  rows.

## Execution

| Step | Repo | Work |
|---|---|---|
| 1 | nccs-contracts | This decision, the deferred contract, backlog row Z15. |
| 2 | nccs-data-bmf | Add `spell_id` to the address history build and its checks. Reduce earlier spells to distinct addresses; separate those already geocoded; submit the rest under a new run identifier; keep the geocoded-address working file. |
| 3 | nccs-data-bmf | Assign blocks, ZCTA and district with the ADR 0045 code; assemble one row per spell; copy current addresses from the census crosswalk; run the checks below; publish both tables with dictionary, CSV and sample. Breadcrumb `ADR 0051`. |
| 4 | nccs-contracts | New contract to active; `spell_id` added to the address-resolved contract; Outcome section; release note in `governance/release-notes/`. |
| 5 | nccs | Catalog row and a short join example on the BMF page. |
| 6 | maintainer | Tell the requesting researcher it is available. |

## Acceptance

The build stops before publishing unless all of these hold:

- `spell_id` is unique in both tables, and the set of `spell_id` values in
  the companion table is exactly the set in the address-resolved crosswalk
  it was built from.
- Every current-address row carries the same blocks, ZCTA and district as
  the census-geo-resolved crosswalk.
- `geo_match_level` is never empty. Every spell with no street is
  `not_geocoded`; every spell with a street is one of the other six values.
- Every `no_match` and `not_geocoded` row has empty geography, and only
  `address` rows have a block.
- The state in the first two digits of each assigned block agrees with the
  spell's state for at least 99 percent of placed rows; disagreements are
  written to an audit file.
- Every distinct address submitted to the geocoder is accounted for in the
  progress record as returned or as failed, with none missing.
- Building twice from the same inputs gives identical files.

## Review changes (2026-09-30)

Changed after review of the first draft, before merge:

- The join key is a stable `spell_id` in both tables, not `spell_rank`. The
  draft told users to join `latest/` to `latest/`, which is not safe because
  the two files are not published in one atomic step.
- `geo_match_level` gained `no_match` (sent and not matched) and `other`.
  The draft had no value for a street address the geocoder could not place.
- The contract file carries `status: deferred`. The draft wrote the status
  as a comment, which the template reads as active.
- Status is `Accepted`, not "Proposed until merged", since the file's
  status line does not change by itself at merge.
- Section 4 defines the columns directly and no longer leans on Z30.
- Cadence changed from monthly to about quarterly (maintainer review).
