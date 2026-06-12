# 0008 — Modernize the Dataexplorer API

- **Status:** Accepted (executed — staging 2026-06-09, prod deployed + sector-in-brief UI cutover 2026-06-12; 1-week prod soak in progress, legacy-API sunset pending) — see Outcome
- **Date:** 2026-05-15
- **Deciders:** sole maintainer
- **Extended by:** [[0029-bmf-org-level-query-mode]] (2026-06-11) — adds a second query mode (`source=bmf`) alongside the CORE-join mode specified here: an org-level registry read of bmf-master-geocoded (no CORE join, incl. non-filers), filtered by `active_years` as a lifespan overlap. Additive — does not change this ADR's host/timing or contract-surface decisions.
- **Extended by:** [[0031-core-tier-routing-api-canonical]] (2026-06-12) — pins *which* CORE tier the API reads per form (990combined/990pf from `core-panel`/`processed_merged/`, full range; 990/990ez from `core-990`/`processed/core/`, 2012+) and makes the API canonical for that routing (the dashboard conforms). Fixes the original `processed/core/`-only read that couldn't serve pre-2012.

## Context

The current API at `UI-Research/nccs-dataexplorer-api` powers
parametric queries and result downloads of BMF/core data, with a UI
on the sector-in-brief dashboard. It has known issues that compound:

- **Athena as runtime.** ADR 0003 already accepted DuckDB as the
  service-tier engine and put Athena on a retirement path. The
  existing API still runs on Athena (minute-scale latency, scan-based
  cost, separate cluster to operate).
- **Environment inversion.** The production deployment writes to
  `s3://nccs-dataexplorer-stg/`, not `s3://nccs-dataexplorer-prod/`,
  because the original cutover never happened. Bucket names no
  longer reflect roles; the actual prod bucket is dormant since
  2025-04 and is essentially abandoned state.
- **Result delivery is slow.** When a query produces a large result,
  users receive an email link 24 hours later — an artifact of
  Athena's batch-processing latency, not a UX choice.
- **No retention policy.** Result CSVs accumulate forever, including
  individual 9.5 GB and 15 GB query outputs that have been sitting
  in `stg/results/` for months. No lifecycle rules; no automatic
  cleanup.
- **Code typos perpetuating into S3.** The repo has parallel
  `query/` and `queries/` references; the `query/` bucket directory
  contains a single 2025-04 .txt file that traces to the typo.
- **No usage telemetry.** Result CSVs are the only proxy for usage;
  there's no structured per-query log or rollup metric.

The data layout the new API will read is already friendly to
DuckDB: `master/bmf/bmf_master.parquet`, `geocoding/bmf-master/`
merged parquet, and the core-990 parquet migration on the way per
ADR 0003 / contracts/core-990.yml.

The current API is actively used by external researchers and the
public. A modernization must avoid breaking traffic during the
transition.

## Decision

Build a new Urban-owned dataexplorer API in a **new repo** (clean
break from the existing one). Deploy in parallel; switch the
sector-in-brief UI pointer when the new API has soaked; sunset the
existing API after a deprecation window.

### Runtime architecture

- **Query engine:** DuckDB embedded in the API process, querying
  partitioned parquet on S3 via `httpfs`. Optional local LRU cache
  for hot partitions. Per ADR 0003.
- **No Athena dependency.** Athena may be retained for human
  ad-hoc SQL outside the API; the API runtime does not call it.
- **Host (confirmed 2026-06-09 by Phase-0 + build step 0; reverses the
  earlier App-Runner lean): Lambda-first hybrid.** Lambda materializes
  the bulk of the distribution straight to S3; an **async non-Lambda
  worker (Fargate / App Runner / Batch — platform TBD)** is reserved
  only for pathological multi-tier giants (990 + EZ + PF + legacy/efile
  spanning the 30–51 GB tail), surfaced through
  [[0026-data-download-durable-links-and-telemetry]]'s durable
  `/download/{job_id}`. The binding Lambda constraint is **join memory
  (10 GB)**, not wall-time — a real in-Lambda probe of the worst
  realistic query peaked at **6.0/10 GB (~60%)** and finished in 76 s,
  writing to the real results bucket at ~67 MB/s, so the 900 s wall is
  ~60 GB of headroom, above the 51 GB max (see Outcome).

### Result delivery

> **Amended 2026-06-09 (supersedes the sync/async-with-SSE split below
> for the dashboard form; confirmed by Phase-0 — see Outcome):** the
> form's delivery is **uniform pattern B** — always materialize the
> result to the results bucket and return a **presigned URL** via the
> durable `/download/{job_id}` endpoint, email receipt default-on
> ([[0026-data-download-durable-links-and-telemetry]]). Phase-0 settled
> this by data: **38.5 % of 2,539 real results exceed the 6 MB
> API-Gateway response cap**, so result bytes can never stream back
> through the API process. 0008's in-band path may still serve small
> programmatic / API-direct callers, but it is not the form's path.

_Original (superseded for the form by the amendment above):_

- **Synchronous** for queries returning under ~100 MB. Result
  streams back to the client in the same request.
- **Asynchronous with immediate notification** for larger queries.
  Result writes to S3; user receives notification (in-browser via
  SSE/WebSocket when the session is alive; email immediately
  otherwise). No artificial 24-hour delay.
- Single download link per result, signed URL, valid for the
  retention window.

### Result storage

- **New dedicated bucket** with a name that reflects its role
  (working name: `nccs-data-api-results`). **Finalized 2026-06-09 as
  `sector-in-brief-api-results-{stg,prod}`** (one per environment); the
  working name predates the 2026-06-04 repo rename and is stale.
- **30-day S3 lifecycle policy** from day one, **scoped to the `results/`
  prefix**: result objects auto-delete 30 days after creation, while the
  `logs/queries/` NDJSON and the `requests/{job_id}.json` registry sit at
  sibling prefixes on a longer clock (the two-clocks rule — see
  [[0026-data-download-durable-links-and-telemetry]] §1/§2). Users who need
  persistence re-run the query, or use the durable `/download/{job_id}` link.
- **No prod/stg confusion.** Single bucket per environment, named
  unambiguously. Staging deployment writes to a staging bucket;
  production writes to a production bucket.

### Usage telemetry

- API logs **every query** to a per-day prefix **inside the results bucket**
  (**as-built 2026-06-09:**
  `sector-in-brief-api-results-{stg,prod}/logs/queries/{YYYY-MM-DD}/`; the
  earlier separate-bucket `s3://sector-in-brief-api/logs/…` and the
  `nccs-data-api` name are both stale) as newline-delimited JSON: timestamp,
  user (or anon), query SQL, result size, duration, success/failure.
  The event set is extended to the three NDJSON types in
  [[0026-data-download-durable-links-and-telemetry]] §4
  (`request_created` / `export_materialized` / `download`);
  `contracts/usage-api.yml` is authoritative.
- **Monthly rollup** job aggregates the daily logs into a
  contracted parquet artifact published under
  `s3://nccsdata/usage/api/{YYYY_MM}/queries.parquet`. See the new
  `contracts/usage-api.yml` stub.
- Promotes API usage from inferred-from-leftover-CSVs to a
  first-class contracted artifact, analyzable from notebooks and
  dashboards.

### Repo and naming

- **New repo:** working name `UrbanInstitute/nccs-data-api` (or
  similar); finalized at creation. **Finalized 2026-06-04 as
  `UrbanInstitute/sector-in-brief-api`** (the authoritative name now lives
  in [[usage-api]]). Old repo
  (`UI-Research/nccs-dataexplorer-api`) is archived after sunset.
- Repo carries: API code, IaC for the new bucket + lifecycle
  policy, deployment config, the rollup job, and tests.

### Migration sequence

1. Stand up the new repo, deploy to staging.
2. Soak: run the new API in shadow mode against real queries (read
   traffic mirrored from production), compare results against the
   existing API.
3. Switch the sector-in-brief UI pointer to the new API endpoint.
4. Monitor production traffic on the new API for one week.
5. Announce sunset of the existing API with a 90-day window.
6. After the window, delete the existing API deployment.
7. Archive `nccs-dataexplorer-prod/` (dead state, immediately) and
   `nccs-dataexplorer-stg/` (after retention for users who pinned
   pre-sunset email links).

## Outcome (Phase 0 — 2026-06-09)

Phase-0 of the `sector-in-brief-api` build ran a vertical slice against
live `s3://nccsdata` and the legacy results bucket (us-east-1),
resolving the questions this ADR left open. The full build is not yet
started. Evidence: `sector-in-brief-api/phase0/FINDINGS.md`.

**Shipped (decided / confirmed):**

- **DuckDB-on-parquet path proven.** One real dashboard-style query —
  CORE 990 parquet ⋈ `bmf-master-geocoded` parquet, joined on lowercase
  `ein` at query time (per [[0016-no-canonical-cross-dataset-merge]]),
  materialized straight to S3 — runs clean. The join is sound: `ein` is
  unique in bmf-geocoded (3,672,933 distinct rows), so it does not fan
  out.
- **Pattern B confirmed by data.** 38.5 % of 2,539 real production
  results exceed the 6 MB API-Gateway cap → materialize-to-S3 is
  mandatory, not a preference (see
  [[0026-data-download-durable-links-and-telemetry]]).
- **Host decided: Lambda-first hybrid** (reverses the earlier App-Runner
  lean). The result-size distribution is violently bimodal — p50 0.1 MB,
  p75 117 MB, p95 11.7 GB, p99 30.7 GB, max 51 GB (the 1.6 GB mean
  describes no real query). In-region throughput is ~104 MB/s (the
  earlier 1.5 MB/s figure was egress to a local machine, not a host
  signal), so the 15-min Lambda wall ≈ 90 GB headroom > the 51 GB max.
- **Host confirmed by build step 0 (2026-06-09).** A SAM-deployed Lambda
  (10 GB / 900 s / 10 GB ephemeral) ran the worst realistic query —
  widest projection (~250 core columns), all 990 tax years, all states,
  no filter — as a DuckDB EIN join materialized to the real
  `sector-in-brief-api-results-stg` bucket: **peak 6.0/10 GB (~60%),
  76 s, a 4.70 GB / 3.75M-row result written at ~67 MB/s.** Wall-time is
  not the binding limit (~60 GB headroom > 51 GB max); join memory is,
  and it held at ~60% on the worst case. This also exercises pattern B
  end-to-end (materialize → real S3 bucket) and closes the deferred
  in-region S3-write check.
- **Names finalized (as-built):** the results bucket
  `sector-in-brief-api-results-{stg,prod}` carries three prefixes — `results/`
  (30-day lifecycle), `logs/queries/` (per-query NDJSON), and
  `requests/{job_id}.json` (durable-link registry, longer clock). The earlier
  separate-bucket log path `s3://sector-in-brief-api/logs/…` was provisional
  and is corrected here.

**Diverged or pending:**

- **Built + deployed to staging (2026-06-09).** Slices 1–5.1 shipped — the
  DuckDB-on-parquet `/data` handler, the `template.yaml` results
  bucket/lifecycle, durable `/download/{job_id}` + registry, SES receipt, and
  NDJSON telemetry — deployed to `stg` via a green CI/CD pipeline with a
  post-deploy smoke gate. Remaining: soak, the sector-in-brief UI cutover,
  prod, and the legacy-API sunset (migration steps 2–7). The as-built
  delivery/auth realizations are recorded in
  [[0026-data-download-durable-links-and-telemetry]]'s Outcome.
- **Prod deployed + sector-in-brief UI cutover (2026-06-12).** The prod stack
  (`sector-in-brief-api-prod`) is live — query/download Function URLs, the
  `sector-in-brief-api-results-prod` bucket (30-day lifecycle), and the
  [[0030-async-giant-export-worker]] Fargate worker (enabled, image pushed, 8 GB
  threshold). Verified against `query-prod`: byte-identical code to staging (same
  `CodeSha256`), modern + pre-2012 990combined exports (per
  [[0031-core-tier-routing-api-canonical]]), the empty-`IN` `400` guard, parquet,
  and the async-`202` wiring; the `sector-in-brief-dashboard-invoke` caller is
  authorized on the prod ARN. The `sector-in-brief` dashboard switched its prod
  pointer to the new API the same day (**migration step 3**) and is serving real
  download traffic at ~0% errors — **step 4 (1-week soak) is underway**.
  **Migration step 2 (shadow soak) was deliberately skipped**, not deferred: it
  diffs new-vs-old API outputs for the same query, but the new API reads
  *different* underlying data (canonical core parquet per
  [[0027-core-990-parquet-promotion]]; the panel's intersected 990combined column
  surface per [[0031-core-tier-routing-api-canonical]]), so an output-equality
  comparison against the legacy API has no meaningful baseline. Correctness was
  validated directly against `query-prod` (above) instead. Remaining:
  legacy-API sunset (steps 5–7), gated behind the soak; the 90-day deprecation
  window runs from this cutover date.
- **Production reads on canonical core parquet — RESOLVED 2026-06-09 by
  [[0027-core-990-parquet-promotion]].** Core parquet is promoted to
  service-tier-canonical (dual-published; CSV mirror on a 90-day window),
  so the API can read canonical core in production. The cross-vintage type
  drift is handled with `read_parquet(union_by_name=True)` and documented
  in `contracts/core-990.yml`; stabilizing the column types in
  `nccs-data-core` (retiring that workaround) is a producer fast-follow
  per ADR 0027.

## Consequences

**Positive:**

- Query latency drops from minute-scale (Athena cold) to
  sub-second (DuckDB on partitioned parquet) for typical queries.
- Result delivery becomes fast for the common case; large-result
  workflow no longer waits 24 hours.
- Storage cost shrinks: 30-day retention vs unbounded accumulation
  reclaims tens to hundreds of GB over time.
- Bucket naming reflects deployment role; future maintainers won't
  inherit the prod/stg confusion.
- API usage becomes measurable and contracted. Decisions about
  scaling, feature deprecation, and consumer outreach gain a
  factual basis.
- Athena exits the API critical path, simplifying the operational
  surface and aligning with ADR 0003.

**Negative:**

- Real engineering investment. Estimating an MVP at 6–10 weeks for
  one engineer, depending on parallel deploy infrastructure and
  shadow-mode tooling. Sunset of the old API extends the calendar
  another quarter.
- Brief operational double-burden during soak + cutover.
- Users with pinned email links to old-bucket S3 URLs will hit 404s
  after sunset. The 90-day deprecation window and a redirect note
  in the sunset announcement mitigate this; some user breakage is
  unavoidable.
- Result-CSV retention shift (currently unbounded, becoming 30
  days) is itself a soft breaking change for any user who returns
  to old results. Announce in sunset notice.

## Deprecation window

The existing API receives a **90-day sunset window** from the date
of UI cutover (step 3 above). During the window:

- Both APIs run in parallel.
- The old endpoint returns results normally, with a deprecation
  header and a notice page linking to the new API.
- Email-delivery links from the old API continue to resolve.

After the window, the old API and its buckets are torn down.

## Follow-up

1. Open a new repo (`UrbanInstitute/nccs-data-api` or final name)
   when work begins. Open ADR 0009 at that point if any design
   default shifts.
2. Once the rollup job runs at least once, populate
   `contracts/usage-api.yml` with the realized schema.
3. Update `ARCHITECTURE.md` §6 to point at the new repo and replace
   "API today; eventually modernize" language with the realized
   state.
4. Audit `nccs-dataexplorer-api` source for the `query/` ↔
   `queries/` typo and any other path mismatches so they aren't
   carried into the new code by reflex.
5. Consider whether usage telemetry should expand beyond the API
   (S3 access logs, dashboard hits, R-package downloads) into a
   dedicated `nccs-data-usage` repo — open ADR if/when.
