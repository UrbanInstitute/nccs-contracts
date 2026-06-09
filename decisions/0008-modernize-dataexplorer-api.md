# 0008 — Modernize the Dataexplorer API

- **Status:** Accepted (partially executed 2026-06-09 — Phase-0 measurement complete; full build not yet started) — see Outcome
- **Date:** 2026-05-15
- **Deciders:** sole maintainer

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
- **Host (resolved 2026-06-09 by Phase-0; reverses the earlier
  App-Runner lean): Lambda-first hybrid.** Lambda materializes the
  p50–p95 range (≤ ~10 GB) straight to S3; an **async non-Lambda worker
  (Fargate / App Runner / Batch — platform TBD)** handles only the p99+
  giant tail (30–51 GB) and any memory-heavy wide join, surfaced through
  [[0026-data-download-durable-links-and-telemetry]]'s durable
  `/download/{job_id}`. The binding Lambda constraint is **join memory
  (10 GB)**, not wall-time — at the measured ~104 MB/s in-region, the
  15-min wall is ≈ 90 GB of headroom, above the 51 GB observed max.
  Gated on a wide-join memory check (first build step; see Outcome).

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
- **30-day S3 lifecycle policy** from day one: objects auto-delete
  30 days after creation. Users who need persistence re-run the
  query.
- **No prod/stg confusion.** Single bucket per environment, named
  unambiguously. Staging deployment writes to a staging bucket;
  production writes to a production bucket.

### Usage telemetry

- API logs **every query** to a per-day prefix (**finalized 2026-06-09:**
  `s3://sector-in-brief-api/logs/queries/{YYYY-MM-DD}/`; the
  `nccs-data-api` name is stale) as newline-delimited JSON: timestamp,
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
- **Names finalized:** results buckets
  `sector-in-brief-api-results-{stg,prod}`; log prefix
  `s3://sector-in-brief-api/logs/…`.

**Diverged or pending:**

- **The full API build is unstarted** — the migration sequence above
  (deploy, soak, UI cutover, sunset) is still ahead.
- **The host has one residual that could still pivot it.** The binding
  Lambda limit is join memory (10 GB) on the widest/largest queries, not
  wall-time. This is tested as the **first gated build step** (a thin
  real Lambda running the wide-tail query); if it OOMs, the host pivots
  to always-async before the full rewrite. The async worker platform
  (Fargate / App Runner / Batch) is not yet chosen.
- **In-region S3-write rate** is deferred into the build (measured
  against the real results bucket + API role, not a throwaway box).
- **Production reads depend on the core-parquet promotion** — core-990
  parquet exists on S3 but is not yet contract-canonical; tracked on
  `contracts/core-990.yml` open item #3 and decided separately under
  [[0003-retire-athena-for-duckdb]].

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
of UI cutover (step 4 above). During the window:

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
