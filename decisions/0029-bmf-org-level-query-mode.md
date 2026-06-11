# 0029 — BMF Org-Level Query Mode (`source=bmf`) with Lifespan-Overlap Filtering

- **Status:** Accepted (executed 2026-06-11; merged to sector-in-brief-api `main` via PR #5, worst-case timing measured in-region — see Outcome)
- **Date:** 2026-06-11
- **Deciders:** sole maintainer
- **Related:** [[0008-modernize-dataexplorer-api]], [[0016-no-canonical-cross-dataset-merge]], [[0026-data-download-durable-links-and-telemetry]], [[0003-retire-athena-for-duckdb]]
- **Follow-up (reconciled):** `contracts/bmf-master-geocoded.yml` — `active_years` lifespan-overlap usage added to the `sector-in-brief-api` consumer entry (done, PR #24).

## Context

The modernized data-download API ([[0008-modernize-dataexplorer-api]])
ships a single query mode: join the CORE tax-year partitions to
bmf-master-geocoded on `ein` and filter by `tax_years`
([[0016-no-canonical-cross-dataset-merge]]). Every result is therefore a
**filing-level** product — it can only contain orgs that filed a 990 in
the requested tax years, and it carries financials/tax-year columns.

But a large class of requests is **org-level**: "every registered
nonprofit in RI," counts that include **non-filers**, anything keyed to
the BMF registry rather than to filings. The CORE join structurally
cannot answer these — non-filers have no CORE row, so the inner join
drops them. bmf-master-geocoded already holds exactly this: one row per
`ein` for the whole registry, including orgs that never filed.

The registry's year information is also shaped differently. It has **no
per-year membership** — each org carries only a lifespan
`[first_year_in_bmf, last_year_in_bmf]`. There is no `tax_years`
partition to filter on. So "active in year(s) Y" must be answered from
the lifespan endpoints alone.

A naive translation — `last_year_in_bmf IN (Y...)` (or `first_year ...`)
— is **wrong by ~19x**, and wrong in a way that looks plausible: for a
single year it returns only orgs that *died* (or *were born*) that year,
not orgs *alive* that year. Measured against the artifact:
`last_year_in_bmf = 2020` → 94,227 rows, vs. orgs active-in-2020 →
1,769,696. This is the same trap the artifact's own contract already
warns about ([[bmf-master-geocoded]] "Counting active orgs" note), and
the same active-window rule [[sector-in-brief]] counts by
(`org_year_first ≤ Y ≤ org_year_last`).

## Decision

Add a second query mode to the API, selected by a `source` field
(`core` default, `bmf` opt-in). It does **not** change the contract
surface of any artifact; it is a new *way the API consumes*
bmf-master-geocoded.

### 1. `source=bmf` — org-level registry mode

- Drops the CORE join entirely; selects one row per `ein` straight from
  bmf-master-geocoded (the API still composes the crosswalk-derived geo
  and classification columns on top, as in core mode).
- `tax_years` and `forms` are **rejected** in this mode (they are CORE
  partition concepts) so the two models are never silently conflated.
- The result has no financials / tax-year columns — it is the registry,
  including non-filers.

### 2. `active_years` — lifespan-overlap filter, not an `IN`

The BMF year filter is `active_years` (a list of years). Its semantic is
**lifespan overlap with the requested span**:

    first_year_in_bmf <= max(active_years) AND last_year_in_bmf >= min(active_years)

i.e. "the org was active at **any point** during the span." Only the
span **endpoints** matter; gaps listed between them are not honored
(BMF cannot express a gap — it has no per-year membership). This is the
*only* semantic the artifact can answer faithfully, and it matches
[[sector-in-brief]]'s active-window count. `tax_years` is rejected here;
`active_years` is rejected in core mode.

Rejected alternative: `column IN (years)` on a single lifespan endpoint —
returns the births/deaths in those years, not the active set (~19x
smaller). Rejected because it is silently, plausibly wrong.

### 3. Filter provenance — force both lifespan columns into output

When `active_years` is applied, the API forces **both**
`first_year_in_bmf` and `last_year_in_bmf` into the result columns
(deduped, like `ein`). The result then **self-audits** the overlap
predicate: a reader can verify each row's match from the row alone. Both
endpoints are required — an overlap match cannot be verified from one.

This is scoped as an **API invariant** (record evidence, not verdicts),
deliberately distinct from a default-column **UX** choice, which remains
the dashboard's to make. The API forces `ein` always (identity) and the
filter's basis columns when the filter is applied (provenance); it does
not otherwise pick columns for the caller.

## Consequences

- The API answers org-level / non-filer questions it structurally could
  not before, with year semantics that agree with the canonical
  sector-in-brief count rather than contradicting it by ~19x.
- New request shape: `{source, active_years}` join the existing
  `{tax_years, forms, columns, filters, format, email, estimate}`.
  Documented in the repo's `openapi.yaml` (per [[0026-data-download-durable-links-and-telemetry]] §5,
  OpenAPI lives in the API repo, not here).
- No artifact contract changes shape. Only the consumer *note* on
  bmf-master-geocoded gains the lifespan-filter usage (Follow-up above).
- Host/timing: BMF mode is **Lambda-safe with no tail** — measured
  in-region, see Outcome. Unlike core's fat-tailed result distribution
  ([[0008-modernize-dataexplorer-api]]), BMF output has a hard ceiling
  (one row per EIN), so it never needs the async worker.

## Outcome (2026-06-11)

Built and merged to sector-in-brief-api `main` (PR #5). Worst-case timing
measured **in-region** (us-east-1; dev-box S3-from-internet timing is
invalid — gate-3 showed ~70x egress skew), `COPY` to local disk to isolate
read+join+materialize from the S3 upload, peak RSS unconstrained:

| scenario | columns | rows | output | wall | peak RSS |
|----------|---------|------|--------|------|----------|
| unfiltered, geo cols | 6 | 3.67M | 234 MB | 6.8s | 273 MB |
| unfiltered, ALL cols | 115 | 3.67M | 3.5 GB | 35.7s | 1.85 GB |
| `active_years` filter | 8 | 1.70M | 125 MB | 6.9s | 298 MB |

**Lambda-safe with an order of magnitude of headroom.** The absolute worst
case (all 115 columns, whole registry, unfiltered) is 35.7s against the 900s
wall and 1.85 GB against the 10 GB memory cap. Because BMF mode is always one
row per EIN, ~3.5 GB is a *hard* output ceiling — no fat tail, so (unlike
core) it needs no async-worker fallback. RSS holding at 1.85 GB while writing
3.5 GB also confirms DuckDB streams the `COPY` (closes [[0008-modernize-dataexplorer-api]]
FINDINGS gate-3 open items #2 peak-join-memory and #3 streaming-COPY, for this mode).

**Bug found by the measurement (fixed in PR #6):** the unfiltered worst case
initially *hung*. Decomposition localized it to `_bmf_source()`'s CT
planning-region join ([[0023-ct-planning-region-coordinate-resolution]]):
`b.geo_state_abbr = 'CT'` was a single-sided constant filter, not a join key,
so DuckDB hash-joined on the rounded `printf('%.2f', lat/lon)` coordinates
alone and probed all 3.67M rows — non-CT orgs sharing a 2dp coordinate cell
with CT crosswalk points fanned out into the billions before the state filter
pruned them. Latent until now because gate-3's spike had no crosswalk joins
and every prior query filtered to a small state first (reducing `b` before the
join); it is **not BMF-specific** — any weakly-filtered core query could hit
it too. Fix: carry the `'CT'` literal on the ct side so
`b.geo_state_abbr = ct._ct_state` is a real two-sided equi-join key; non-CT
rows miss the hash immediately. Same results, full-registry `_bmf_source()`
now 1.35s (was: hung).
