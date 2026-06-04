# 0008 — Modernize the Dataexplorer API

- **Status:** Accepted (planning; new API not yet built)
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

### Result delivery

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
  (working name: `nccs-data-api-results`; finalize at repo creation).
- **30-day S3 lifecycle policy** from day one: objects auto-delete
  30 days after creation. Users who need persistence re-run the
  query.
- **No prod/stg confusion.** Single bucket per environment, named
  unambiguously. Staging deployment writes to a staging bucket;
  production writes to a production bucket.

### Usage telemetry

- API logs **every query** to a per-day prefix
  (`s3://nccs-data-api/logs/queries/{YYYY-MM-DD}/`) as
  newline-delimited JSON: timestamp, user (or anon), query SQL,
  result size, duration, success/failure.
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
