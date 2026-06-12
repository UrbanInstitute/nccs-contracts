# 0031 — CORE Tier Routing: the Download API is Canonical

- **Status:** Accepted (executed — shipped in `sector-in-brief-api` PR #19, deployed to staging 2026-06-12)
- **Date:** 2026-06-12
- **Deciders:** sole maintainer
- **Extends:** [[0008-modernize-dataexplorer-api]] (which tier the API reads CORE from, per form)
- **Refines:** [[0016-no-canonical-cross-dataset-merge]] (the consumer note on where 990combined is read from)
- **Related:** [[0015-core-contract-surface-restructure]] (defines `core-panel`), [[0027-core-990-parquet-promotion]]

## Context

The CORE filing surface is **three separately-contracted producer
artifacts** (per [[0013-versioned-producer-outputs]] / [[0016-no-canonical-cross-dataset-merge]]),
same `core_{tax_year}_{form}.parquet` + dictionary shape in each:

| Artifact | Prefix | Years | Forms |
|---|---|---|---|
| `core-990` | `processed/core/` | 2012–2024 | 990, 990ez, 990pf, 990combined |
| `core-legacy` | `processed_legacy/core/` | 1987–2011 | 990combined, 990pf |
| `core-panel` | `processed_merged/core/` | 1987–2024 | 990combined (990+990EZ union on the common variable set), 990pf |

`sector-in-brief-api` (the download API per [[0008-modernize-dataexplorer-api]])
originally hardcoded a single prefix, `processed/core/` (`core-990`). That tier
only covers 2012+, so a request for pre-2012 `990combined` constructed a key the
tier doesn't carry and 404'd (`sector-in-brief-api` #14). A first fix HEAD-checked
keys and *skipped* the missing ones — which silently dropped the entire pre-2012
`990combined` tier from exports with no error (worse than the loud 404). Ground
truth: the pre-2012 data was never unpublished — it lives in `core-legacy` and
`core-panel`. The API was simply under-reading the contracted CORE surface.

A consumer must therefore decide *which tier each form is read from*. Two options:

- **A — per-consumer composition.** Mirror what `sector-in-brief-data` does
  (`config.yml`): `990combined` from `core-990` ∪ `core-legacy` directly, `990pf`
  from `core-panel`. The two-prefix splice needs a boundary (2012) and per-year
  existence handling, and it reads the *fuller* modern standalone `990combined`
  column set (carries Pt IX 5/6/7/8/9).
- **B — API-canonical panel routing.** The API reads `990combined`/`990pf` from
  `core-panel` (`processed_merged/`), a single full-range 1987–2024 prefix that
  already composes legacy+modern, and `990`/`990ez` from `core-990`. Simpler (one
  prefix, no boundary), at the cost of `990combined` carrying the panel's
  *intersected* (990∩990EZ common) variable set.

## Decision

**The download API (`sector-in-brief-api`) is the canonical authority for CORE
form→tier routing. Other consumers — notably the `sector-in-brief` dashboard /
`sector-in-brief-data` — conform to the API, not vice-versa.** We adopt option B:

| Form | Tier | Prefix | Range |
|---|---|---|---|
| `990combined`, `990pf` | `core-panel` | `processed_merged/core/` | 1987–2024 |
| `990`, `990ez` | `core-990` | `processed/core/` | 2012–2024 (separate forms; do not exist pre-2012) |

Consequences:

1. **`990combined`'s column surface is the panel's 990+990EZ union on the common
   variable set** — fewer columns than the modern standalone `core-990`
   `990combined`. Accepted deliberately; the dashboard moves onto the panel too, so
   the two stay consistent.
2. **A genuinely-missing `(year, form)`** (e.g. `990` pre-2012) is a hard `400`
   listing the gap — never a silent skip. (`validate completeness positively`.)
3. **This refines [[0016-no-canonical-cross-dataset-merge]]'s consumer note** (and
   `contracts/core-panel.yml`'s) that said `990combined` is read from `core-990` +
   `core-legacy` directly. That remains true for `sector-in-brief-data` *today*,
   but the canonical target is the panel; the dashboard's download path realigns to
   the API. 0016's core thesis is unchanged — there is still no pre-merged
   cross-dataset artifact; `core-panel` is a within-core union, and this ADR only
   fixes *which* contracted tier the API reads per form.

The routing lives in `sector-in-brief-api` `query/query.py` (`CORE_PREFIX`).

## Alternatives considered

- **Option A (per-consumer two-prefix splice).** Rejected as the *canonical* path:
  it pushes boundary/existence logic into every consumer and leaves the API and
  dashboard free to drift. Keeping the richer modern `990combined` column set is a
  real upside, but a single canonical source the dashboard mirrors was judged more
  valuable than the extra columns. Revisit if the intersected column set proves
  insufficient for a download use case.
- **Status quo (`processed/core/` only).** Rejected — structurally cannot serve
  pre-2012, which the dashboard offers (1989–2023).

## Follow-up / reconcile

- `sector-in-brief-api`: **done** — `CORE_PREFIX` routing + raise-on-missing (PR #19,
  closed #14), deployed to staging 2026-06-12.
- `sector-in-brief` dashboard: **done** — the dashboard calls the API and never
  reads CORE from S3 itself, so routing stays API-side; its only job was to offer
  each form's real year range. The form-specific picker floor (`990combined`/
  `990pf` → 1989, standalone `990`/`990ez` → 2012) shipped in `sector-in-brief`
  #80, live in prod 2026-06-12.
- `contracts/core-panel.yml`: add `sector-in-brief-api` as a consumer of the
  `990combined` + `990pf` families (done in this change).
