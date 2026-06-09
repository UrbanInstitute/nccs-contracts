# 0027 — Promote core-990 to Parquet-Canonical (Service Tier), with Documented Cross-Vintage Type Drift

- **Status:** Accepted
- **Date:** 2026-06-09
- **Deciders:** sole maintainer
- **Related:** [[0003-retire-athena-for-duckdb]], [[0008-modernize-dataexplorer-api]], [[0016-no-canonical-cross-dataset-merge]], [[0015-core-contract-surface-restructure]], [[0001-s3-as-contract-surface]], [[0013-versioned-producer-outputs]], [[0014-standardize-manifest-shape]]
- **Resolves:** [[0015-core-contract-surface-restructure]] open item #4 and `contracts/core-990.yml` open item #3 (the long-deferred promote/dual-publish/hold question).

## Context

`core-990` has been **CSV-canonical** with parquet *present but
uncontracted*: `nccs-data-core/R/09_parquet.R` dual-writes a parquet
copy next to each CSV (live on S3 since 2026-05-20), but the contract
never declared it canonical. [[0015-core-contract-surface-restructure]]
left the promote/dual-publish/hold decision open; `core-990.yml` open
item #3 tracked it.

It is now **load-bearing**. The modernized API
([[0008-modernize-dataexplorer-api]]) runs DuckDB-on-parquet
([[0003-retire-athena-for-duckdb]]) and joins the contracted core tier
on lowercase `ein` at query time ([[0016-no-canonical-cross-dataset-merge]]).
The API rewrite is built and in testing, and is cutting over to read
core **in production** — which [[0001-s3-as-contract-surface]] forbids
against an uncontracted surface. So the contract must declare parquet
canonical now.

One wrinkle from the API's build step 0: the published parquet has
**cross-vintage type drift** — e.g. `gross_income_other` is INT in early
years but DOUBLE in 2015 (out of INT32 range). DuckDB infers a glob's
schema from the first file and fails the cast, so multi-year reads need
`read_parquet(..., union_by_name=True)`. The parquet is therefore **not
cross-year type-stable today**, and a "canonical" declaration must be
honest about that rather than assert a stability that doesn't exist.

## Decision

Promote parquet to the **service-tier-canonical** format for `core-990`,
**dual-published** with a CSV mirror:

- **Parquet is canonical** — the read target for the API and any
  parquet-native consumer. `core-990.yml`'s `format` and
  `latest_template` describe parquet. The producer already emits it
  (`R/09_parquet.R`); no new producer publish path is required for the
  cutover.
- **CSV is retained as a mirror** at the existing path for current CSV
  consumers (`sector-in-brief-data` `inputs.core_modern`; the
  `core-panel` build in `nccs-data-core`), for a **90-day window** so
  they migrate on their own cadence. Both forms are emitted from the
  same processed frame per `(tax_year, form)`.

### Type-drift posture — route B (document now), route A (producer fast-follow)

- **(B, now):** declare parquet canonical and have the contract
  **document the cross-vintage type drift and the
  `read_parquet(..., union_by_name=True)` requirement** for multi-year
  reads. This matches reality — the API already does exactly this — and
  unblocks the cutover today. The contract does **not** assert cross-year
  type stability.
- **(A, fast-follow):** `nccs-data-core` stabilizes column types across
  vintages (pin a schema / cast at write in `R/09_parquet.R`) so the
  `union_by_name` workaround can retire and the contract can later assert
  stability. Tracked as a producer follow-up; **not** a blocker for the
  cutover.

This does not change [[0003-retire-athena-for-duckdb]] (engine) or
[[0016-no-canonical-cross-dataset-merge]] (no pre-merged table) — the API
still composes joins at query time; this only makes the core read target
a contracted parquet.

## Consequences

**Positive:**

- Unblocks the API production cutover against a *contracted* surface, not
  ad-hoc parquet (honors [[0001-s3-as-contract-surface]]).
- No flag-day break: CSV consumers keep working through the window.
- Honest about the drift — the contract documents the workaround instead
  of asserting a false stability.

**Negative:**

- Until route A lands, **every multi-year core consumer** (not just the
  API — `nccsdata`, `sector-in-brief-data`) must read with
  `union_by_name=True`. The cost is pushed to consumers in the interim.
- The CSV mirror roughly doubles core-990 storage during the window
  (already the case, since the producer dual-writes today).
- Parquet compression is arrow's default **snappy** (`R/09_parquet.R:39`,
  no `compression=` arg), not zstd like the BMF tiers — fine, but noted
  so the contract is accurate.

## Alternatives Considered

- **Promote outright (drop CSV now).** Rejected: breaks
  `sector-in-brief-data` and the `core-panel` build until they migrate.
  Reachable once the 90-day window closes.
- **Hold until the producer fixes types (route A first).** Rejected as
  the immediate path: it blocks a finished, in-testing API rewrite on a
  producer republish, when the drift is already handled with
  `union_by_name` today. Adopted as the fast-follow instead.

## Deprecation window

90 days for the CSV mirror, starting now. Retiring it is a follow-up once
the CSV consumers confirm migration to parquet.

## Follow-up

1. **Route A (producer):** `nccs-data-core` stabilizes cross-vintage
   column types in `R/09_parquet.R` (pin schema / cast at write) so the
   `union_by_name` requirement can retire; then this contract can assert
   cross-year type stability.
2. **Consumer migration:** move `sector-in-brief-data` (`inputs.core_modern`)
   and the `core-panel` build to parquet within the window.
3. **`core-990.yml`** flipped to parquet-canonical in this change; ADR 0008
   Outcome's core-parquet pending item reconciled to resolved.
