# 0030 — Async Giant-Export Worker (Fargate) for the Data-Download Tail

- **Status:** Accepted (planning; not yet executed) — finalizes the "platform TBD" tail of [[0008-modernize-dataexplorer-api]]
- **Date:** 2026-06-11
- **Deciders:** sole maintainer
- **Related:** [[0008-modernize-dataexplorer-api]] (Lambda-first hybrid; this finalizes its async half), [[0026-data-download-durable-links-and-telemetry]] (durable `/download/{job_id}` + email receipt — the delivery this reuses), [[0029-bmf-org-level-query-mode]] (BMF mode has a hard ceiling and never needs this)
- **Follow-up (sector-in-brief-api):** new ECS/Fargate resources + IAM in `template.yaml`, a worker container, routing in `query.py`, a registry `status` field. No nccs-contracts artifact changes shape.

## Context

[[0008-modernize-dataexplorer-api]] decided a **Lambda-first hybrid** host:
Lambda materializes the bulk of the result-size distribution synchronously, and
an **async non-Lambda worker (platform TBD)** handles the pathological giants.
The Lambda path is built and live; the async half was never built.

The result-size distribution (Phase-0 gate 2, 2,539 real queries) is violently
bimodal: p50 0.1 MB, p95 11.7 GB, p99 30.7 GB, **max 51 GB**. The binding Lambda
constraint is **join memory (10 GB)**, not wall-time (at ~100 MB/s the 900 s wall
is ~60 GB of headroom). A real in-Lambda probe of the worst *realistic* query
peaked at 6/10 GB and finished in 76 s — fine — but the multi-tier giants
(990 + EZ + PF + legacy/efile, weakly filtered) can exceed 10 GB of join memory
and fail. Today such a job either OOMs the Lambda or makes the dashboard's
synchronous invoke wait minutes (the `HTTPException` / "Working…" hang reported in
sector-in-brief-api#8).

CORE mode is the only mode that fat-tails this way. [[0029-bmf-org-level-query-mode]]
is one row per EIN — a hard ~3.5 GB ceiling — so BMF never routes here.

## Decision

Build the async worker as **on-demand AWS Fargate**, route to it by a
**memory-safety size threshold**, and deliver via the **durable link + email
receipt that [[0026-data-download-durable-links-and-telemetry]] already
specifies**.

### 1. Platform — Fargate on-demand (ECS `RunTask`)

The query Lambda launches a one-shot Fargate task (`ecs:RunTask`) for a giant job
and returns immediately. Rationale:

- **Scales to zero** — no idle cost; giants are rare. (vs App Runner's always-on
  HTTP model, which also caps ~12 GB and can't hold the 51 GB tail.)
- **Memory headroom** — Fargate tasks go to 120 GB / 16 vCPU, far above the 51 GB
  max. (vs Lambda's hard 10 GB.)
- **Reuses the runtime** — the worker runs the *same* DuckDB materialization code
  (`query.py`) in a container image; no second implementation.
- **Right-sized machinery** — AWS Batch's queue/compute-env apparatus pays off
  only under high concurrency; on-demand `RunTask` fits a rare tail with less to
  operate.

The ~30–60 s task cold start (image pull + start) is immaterial for jobs that take
minutes and are delivered asynchronously anyway.

### 2. Routing — memory-safety threshold on the estimate

The query Lambda decides sync-vs-async using the **existing estimate** (exact
count + sampled bytes/row). If `estimated_bytes > ASYNC_THRESHOLD_BYTES` (env,
default **8 GB** — safely under the 10 GB join-memory cap), the job goes to
Fargate; otherwise Lambda materializes it synchronously as today.

**The fast path must not pay for the estimate.** Running a count before every
export would re-introduce the wasteful pass just removed in sector-in-brief-api#9.
So the estimate is **gated**: a request carrying a row-reducing filter (e.g.
`geo_state_abbr`, `org_type`) — which bounds the result small — skips the estimate
and goes straight to sync. Only **broad** requests (no reducing filter, and/or
many `tax_years × forms` partitions) pay a count to decide. This keeps every
typical dashboard query (state-scoped) on the immediate path; only the rare broad
request — the kind that *can* be a giant — pays to find out. The gate + threshold
are tunable as the real distribution is observed.

### 3. Delivery & UX — return `job_id` now, deliver by durable link + email

This reuses [[0026-data-download-durable-links-and-telemetry]] wholesale:

- The async `/data` response returns immediately with `status: "pending"`, the
  `job_id`, and the durable `download_path` / `download_url` — **no result URL
  yet**.
- The request **registry** (`requests/{job_id}.json`) gains a `status` field:
  `pending` → `ready` (→ `failed`). Durable `GET /download/{job_id}` returns
  **202 + status while `pending`** (it does *not* try to synchronously
  re-materialize a giant), and 302-redirects once `ready`.
- The **default-on email receipt is sent by the worker on completion**, not by
  the original request — the one behavioral move from the sync path. The email
  carries the same durable link.
- **Dashboard UX (its call, per the API/dashboard boundary):** on a `pending`
  response, surface *"This is a large export — we've started it and will email
  you a link when it's ready,"* and/or poll `GET /download/{job_id}` and reveal
  the link when it flips to `ready`. The estimate→confirm flow already warns the
  user before they commit to a giant. Both shapes are valid; email-and-wait is the
  robust default for multi-minute jobs.

### 4. Telemetry

The worker emits the same NDJSON `export_materialized` event (with the per-phase
timings added in #9) plus an `async: true` marker, so the monthly rollup
([[0008-modernize-dataexplorer-api]] / usage-api) sees sync and async jobs
uniformly.

## Consequences

- The fat tail no longer fails: giants that exceed Lambda's 10 GB run on Fargate
  with memory headroom over the 51 GB max, delivered by link + email.
- The fast path is unchanged — filtered/small queries never touch Fargate or the
  estimate, staying at the seconds-scale measured in #8.
- New infrastructure to operate: an ECS cluster + task definition, a worker
  container image, Fargate networking (subnets + security group; default-VPC
  public subnets to start), and IAM (`ecs:RunTask` + `iam:PassRole` on the Lambda;
  a task role with read `nccsdata`, read/write the results bucket, and `ses:SendEmail`).
- Cost is per-use only (scale-to-zero); a giant export costs one short Fargate task.
- One behavioral change: for async jobs the email receipt fires from the worker,
  so `_send_receipt` must be reachable from both entry points.

## Implementation outline (sector-in-brief-api)

1. **API code** — factor the estimate into a reusable `(rows, bytes)` helper;
   add the routing gate + `ecs:RunTask` dispatch in `_create_export`; add registry
   `status`; make `_download` return 202 while `pending`; a `worker` entrypoint
   that runs `_materialize`, flips `status` → `ready`/`failed`, and sends the
   receipt. Unit-test the routing decision (pure).
2. **Container** — a `Dockerfile` (DuckDB + boto3 + `query/`) for the Fargate task.
3. **IaC** — `template.yaml`: ECS cluster, Fargate `TaskDefinition` (high memory),
   task execution + task roles, the Lambda IAM additions, and env wiring
   (`ASYNC_THRESHOLD_BYTES`, cluster/task/subnets/SG).
4. **Deploy + smoke** (operator): deploy to staging; force a broad request over
   the threshold; assert `pending` → worker runs → `ready` → durable link + email.
