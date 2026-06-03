# 0018 — Standardize the sector-in-brief e-file panel names to the efile producer's names

- **Status:** Accepted (pre-publish; rename must land before first publish of the two panels)
- **Date:** 2026-05-30
- **Deciders:** sole maintainer
- **Related:** [[0010-sector-in-brief-data-replaces-dataexplorer-data]], [[0016-no-canonical-cross-dataset-merge]], [[0017-efile-phase-0-vertical-slice]]
- **Amends:** [[0010-sector-in-brief-data-replaces-dataexplorer-data]] and [[0017-efile-phase-0-vertical-slice]] §5 (renames the two deferred panels `gov_grants` / `pf_pri` to `government_grants` / `program_related_investments`)

## Context

The `efile` Phase 0 producer publishes two filing-grain metric tables
under `s3://nccsdata/processed/efile/phase0/`:

- `government_grants.parquet` (column `government_grants`)
- `program_related_investments.parquet` (column
  `program_related_investments_total`)

`sector-in-brief-data` consumes those, aggregates them to the
dashboard dimension grain, and publishes two derived panels. Across
[[0010]] and [[0017]] §5 those panels were named `gov_grants` and
`pf_pri` — the short panel-label convention shared by the existing
sector-in-brief panels (`daf`, `pf_grants`, `number_nonprofits`,
`finances`). The panels are now built in `sector-in-brief-data`
(`panel_gov_grants.R` / `panel_pf_pri.R`) but not yet published to
`s3://nccsdata/sector-in-brief/` (current `latest/` is the 2026-05-21
six-panel cut).

The result is a naming seam at the contract boundary: the same
measure is `government_grants` upstream and `gov_grants` downstream;
`program_related_investments` upstream and the cryptic `pf_pri`
downstream. A consumer reading both contracts cannot tell at a glance
that they are the same quantity at two grains. Because the downstream
panels are still unpublished, this is the one moment the seam can be
closed at zero deprecation cost.

## Decision

The two sector-in-brief panel **artifacts** adopt the efile producer's
file names:

| Old (ADR 0010 / 0017 §5) | New (this ADR) |
| --- | --- |
| `gov_grants.parquet` | `government_grants.parquet` |
| `pf_pri.parquet` | `program_related_investments.parquet` |

The direction is downstream-onto-upstream deliberately: `efile`
v2026.05 is **live** (published 2026-05-29), so renaming it would be a
breaking change to a published producer carrying the 90-day
deprecation window. The sector-in-brief panels are unpublished, so
renaming them costs nothing and the change lands before any consumer
pins them.

**Scope is the file/artifact name, not the column dtype convention.**
Sector-in-brief's columns remain Title Case per [[0010]]'s output-schema
normalization (`Organization Type`, `Census State`, …) — that
normalization is load-bearing: the dashboard's `R/options_nogeo.R`
matches column strings verbatim. The aggregated metric column inside
each panel therefore stays a Title-Case aggregate
(`Total Government Grants`, `Total Program-Related Investments` —
the latter renamed from the `Total PRI` / `PRI_TOTAL` sketched in
[[0010]] for the same de-crypticizing reason), defined authoritatively
in `data_dictionary.parquet` at publish. This ADR does **not** push
efile's snake_case column names (`government_grants`,
`program_related_investments_total`) down into the panels; those name a
different-grain filing-level value, not the dimension-grain sum.

## Why this direction

- **One side is live, one is not.** Converging the unpublished side is
  non-breaking; converging the live side is not. Cheapest decisive move.
- **The measure should read the same across the boundary.** File-name
  parity makes the upstream→downstream lineage legible without a
  crosswalk, reinforcing the consumer-composes-joins model of [[0016]].
- **`pf_pri` was the worst offender.** It encodes producer-internal
  shorthand (PF = private foundation, PRI = program-related
  investments) that means nothing to a contract reader.

## Rejected alternatives

- **efile adopts the short names (`gov_grants` / `pf_pri`).** Breaking
  rename of a producer that shipped two days prior; 90-day window; and
  the short forms are less legible. Rejected.
- **Align only the columns, keep panel file names.** Leaves the
  file-name seam (`gov_grants.parquet` vs `government_grants.parquet`)
  in place — the more visible half of the divergence. Rejected.
- **Leave it; document the mapping.** A standing crosswalk is exactly
  the cognitive tax this closes for free while the panels are
  unpublished. Rejected.

## Outcome (execution feedback, 2026-06-03)

`sector-in-brief-data` implemented the rename and reported two refinements
that this ADR's original "file/artifact names only" scoping understated:

- **There is no panel→path mapping table.** The output `.parquet`
  filename is simply the *key* of the in-memory `panels` list:
  `pipeline/run.R` sets `panels$gov_grants` / `panels$pf_pri`, and
  `R/publish.R` writes each panel as `<name>.<fmt>` by iterating
  `names(panels)`. So the load-bearing rename is renaming those two list
  keys to `panels$government_grants` /
  `panels$program_related_investments`. The `build_*` functions and the
  Title-Case metric columns (`Total Government Grants` /
  `Total Program-Related Investments`) are untouched and correct, as the
  Decision intended.

- **The artifact filename is also a load-bearing key in the
  data-dictionary subsystem** — this ADR's instructions missed it.
  `build_data_dictionary()` runs a drift check that `stop()`s the
  pipeline if any emitted `(file, column)` pair lacks a curated entry,
  joined on the *filename*. Renaming the artifact without updating the
  curation makes the new file emit with zero curated rows and kills the
  run before publish. Two more files therefore change in the *same*
  load-bearing commit, because they ARE artifact-filename keys (in scope
  by this ADR's own definition): `R/build_data_dictionary.R`
  (`.DD_FILES_WITH_SHARED_DIMS` hardcodes the old filenames) and
  `R/data_dictionary_curation.R` (per-panel curated entries keyed on the
  old filenames).

**Scope clarification.** "Artifact filename" in the Decision means *every
load-bearing occurrence of the filename string* — the writer's `panels`
keys AND the data-dictionary curation keys — not just the file written to
S3. The producer is landing this as commit 1 (rename the two `panels`
keys + the two data-dictionary files = the complete, build-passing
artifact rename) and an optional commit 2 (hygiene: `panel_*.R` files,
`build_*` / `read_*_raw` functions, internal config keys, call sites,
tests). Verified to a sandbox prefix; no prod publish yet.

Sandbox note: the panels were published to the *sandbox* prefix
(v2026.06) earlier on 2026-06-03 under the OLD names. Sandbox is not a
consumer and the rename re-run overwrites it, so the zero-deprecation
property in "Deprecation window" below is unaffected. Producer PR #1
(`feat/gov-grants-pf-pri-panels` → main) still references the old names
and will be updated.

## Consequences

- Sector-in-brief gains two panels whose file names match other
  panels' convention less tightly (long, snake_case vs `daf` /
  `pf_grants`). Accepted trade-off: cross-producer legibility over
  within-producer brevity for these two e-file-sourced panels.
- `sector-in-brief-data` is now in drift from this contract: it builds
  `gov_grants.parquet` / `pf_pri.parquet`. Per the house rule that the
  contract is authoritative, the producer must rename its outputs before
  the next vintage cut. The load-bearing rename touches the two writer
  `panels` keys *and* the data-dictionary curation keyed on the filename
  (see Outcome); the `panel_*.R` scripts and `build_*` functions are
  optional hygiene. No published artifact changes, so no consumer breaks.

## Deprecation window

None required — neither panel is published. The rename must be applied
before first publish; after that, a rename would re-incur the standard
90-day window.

## Follow-up

1. `sector-in-brief-data`: rename the two panel outputs to
   `government_grants.parquet` / `program_related_investments.parquet`
   before publishing the next `sector-in-brief` vintage. The artifact
   name lives in three load-bearing places, all of which must change
   together (see Outcome): the two `panels` list keys
   (`pipeline/run.R`), `.DD_FILES_WITH_SHARED_DIMS`
   (`R/build_data_dictionary.R`), and the per-panel curated entries
   (`R/data_dictionary_curation.R`). Optionally, for hygiene, also
   rename `panel_government_grants.R` /
   `panel_program_related_investments.R` and the `build_*` / `read_*_raw`
   functions.
2. At publish, register both panels' columns in
   `data_dictionary.parquet`, including the Title-Case aggregate metric
   column names.
3. Promote the two files from the "Built, pending publish" subsection
   to the published-files list in `contracts/sector-in-brief.yml`.
