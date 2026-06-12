# 0026 — Data-Download UX: Durable Links, Email Receipt by Default, and Download Telemetry

- **Status:** Accepted — executed: **staging 2026-06-09, prod cutover 2026-06-12** (slices 1–5.1 + the §6 dashboard-form rework & post-staging UX/correctness hardening, sector-in-brief PRs #68–#82; see Outcome). Refines [[0008-modernize-dataexplorer-api]]. Pattern B (§1) confirmed by data (Phase-0): 38.5 % of 2,539 real results exceed the 6 MB inline cap, so materialize-to-S3 is mandatory.
- **Date:** 2026-06-08
- **Deciders:** sole maintainer

## Context

The sector-in-brief dashboard already has a **data-download section**
that calls an API — today the legacy Athena endpoint at a hardcoded
`/stg/` URL (per [[0011-decouple-dashboard-from-committed-data]], whose
residual #1 defers the fix to ADR 0008). The dashboard is therefore
already a **hybrid consumer**: its visualization panels read S3 directly
(ADR 0011), while the download section goes through the API. This ADR is
about that download path specifically.

[[0008-modernize-dataexplorer-api]] already decided the broad
modernization: DuckDB-on-parquet runtime (per
[[0003-retire-athena-for-duckdb]]), a dedicated results bucket with a
**30-day S3 lifecycle from day one**, signed URLs, asynchronous delivery
with immediate notification (no artificial 24h delay), per-query NDJSON
logging, and a monthly rollup into the contracted [[usage-api]] artifact.
This ADR does **not** re-decide any of that.

Three gaps surfaced when we examined the download *experience* for the
dashboard's non-technical audience — gaps 0008 leaves open:

1. **Emailed links die.** The current form emails the requester an S3
   link (an artifact of Athena's slowness — the "24h emailed results").
   0008 keeps emailing but emails the *signed URL itself*, which expires
   with the retention/URL window; 0008 explicitly accepts that users
   "will hit 404s." A signed URL is an **access** clock, not the
   **object-lifecycle** clock — conflating them means "here's your link"
   silently becomes a dead link.
2. **Email is treated as a fallback, not a receipt.** 0008 notifies
   in-browser when the session is alive and emails only "otherwise." But
   the value of the email is durability — a record the user keeps after
   closing the page — independent of whether the session was alive.
3. **Downloads aren't measured.** 0008 logs *queries*. A user can
   request an export and never fetch it (the abandoned-page case); the
   request-vs-fetch gap is operationally interesting (it bounds the
   storage budget) but is invisible without a distinct `download` event.

## Decision

Refine ADR 0008's download path along four axes. Defer to 0008 for the
DuckDB runtime, the dedicated results bucket, the 30-day lifecycle, the
parallel-deploy/sunset migration, and the base per-query logging.

### 1. Delivery = materialize to S3 + presigned URL (pattern B)

For the dashboard download form, the API **always** runs the (filtered,
per-use-case — [[0016-no-canonical-cross-dataset-merge]]) DuckDB query,
writes the result to the results bucket, and returns a **presigned URL**.
The bytes never flow through Shiny or the API process — the browser pulls
them straight from S3. This is the only delivery mode that honors the
constraint that motivated this work ("Shiny cannot serve that much
data"): streaming through the API would just relocate the same
memory/timeout problem one tier over. 0008's synchronous-stream-for-small
path may remain for programmatic/API-direct callers; the **form** uses
pattern B uniformly. **(Confirmed by Phase-0, 2026-06-09: 38.5 % of
2,539 real results exceed the 6 MB API-Gateway cap, so pattern B is
required for the form, not merely preferred — see
[[0008-modernize-dataexplorer-api]] Outcome.)**

**Two clocks, kept distinct:**

- **Object lifecycle:** the result object expires per 0008's 30-day
  bucket rule. This is the *only* mechanism that reclaims storage; it is
  unconditional and server-side (we do not, and cannot reliably, detect
  "did the user click"). Mandatory — its absence is exactly the legacy
  Athena pileup (9.5 GB / 15 GB results sitting for months, per 0008).
- **URL TTL:** the presigned URL's validity, set **≤ the object
  lifetime**. A URL that outlives its object is a confusing 404.

### 2. Durable download endpoint + request registry

The emailed link is **not** a presigned URL. It is a stable endpoint,
`…/download/{job_id}`. On each click the API:

- result object still in the bucket → redirect to a **freshly issued**
  presigned URL;
- object already swept by the lifecycle rule → **re-run the (fast,
  DuckDB) query** from the stored parameters and serve a fresh result.

This makes the emailed link durable for as long as the underlying data
vintage exists, while storage stays bounded by the lifecycle rule. It
separates a **stable identity** (the request + its parameters) from the
**ephemeral materialization** (the S3 object + presigned URL), and
resolves both 0008's emailed-link-404 problem and ADR 0011 residual #1.

It requires a small **request registry**: `requests/{job_id}.json`
holding `{query params, pinned contract vintage, requester email,
timestamps}`. Stored as an S3 JSON sidecar on a longer clock than the
ephemeral result object — **not** a runtime database, honoring
`ARCHITECTURE.md` §11 ("no runtime database for the API"). The registry
powers both the durable link and the telemetry below.

### 3. Email receipt, default-on

Every download request emails the requester the durable
`…/download/{job_id}` link as a **receipt** — on by default, not a
session-dead fallback. The form already collects an email today, so this
is continuity, not new data collection; the upgrade is that the link now
arrives **instantly** (DuckDB, not Athena) and is **durable** (the
endpoint, not an expiring signed URL). When the session is alive the link
is also shown in-browser immediately; the email is the copy they keep.
The collected address doubles as the unique-user key for telemetry
(hashed in the published rollup — see §4).

### 4. Download telemetry

Extend 0008's per-query log with a `download` event so the
request-vs-fetch gap is measurable. Three structured (NDJSON) event types,
written to the API's logs prefix and aggregated by the monthly rollup
into [[usage-api]]:

- `request_created` — params, pinned vintage, requester (hashed)
- `export_materialized` — `row_count`, `bytes`, `duration_ms`, success/failure
- `download` — a `…/download/{job_id}` fetch; **0…n per job**

`request_created` minus `download` is the **abandonment rate** — it both
quantifies the closed-page case and bounds the storage budget (an
abandoned export costs only storage, never egress). `download` becomes a
first-class column in `usage-api.yml`.

### 5. Interface-contract home

Keep `nccs-contracts` describing **S3 artifacts only** (per
[[0001-s3-as-contract-surface]]). The request/response interface (filter
parameters in; `job_id`/status/presigned-URL out) is specified as
**OpenAPI in the `sector-in-brief-api` repo** and referenced from this
ADR, not added as a non-S3 contract entry here. Revisit if a second
consumer (beyond the dashboard form) appears and the interface needs a
neutral home.

### 6. UI prong (sector-in-brief)

Rework the existing download form for the non-technical audience:
filter inputs that map 1:1 onto the API request schema; a **row-count /
size estimate** shown before the user commits to a large export; an
immediate in-browser link plus an explicit "we've also emailed this to
you"; and a clear progress state for the rare export slow enough to wait
on. CSV is the primary format for this audience; parquet is offered as an
option.

## Outcome (staging 2026-06-09; prod cutover 2026-06-12)

Built in `sector-in-brief-api` (slices 1–5.1) and deployed to `stg` via a green
CI/CD pipeline with a post-deploy smoke gate. The request/response interface is
OpenAPI in that repo (`openapi.yaml`, per §5) — referenced, not re-homed here.
As-built:

- **§1 pattern B** — `POST /data` runs the DuckDB join, materializes the result
  to the results bucket (`results/` prefix), and returns presigned URLs; bytes
  never flow through the API. Confirmed mandatory by Phase-0 (38.5 % > 6 MB cap).
- **§2 durable link + registry** — `GET /download/{job_id}` resolves the S3
  registry `requests/{job_id}.json`; redirects to a freshly-issued presigned
  URL, or **re-materializes** from the stored params if the 30-day lifecycle
  swept the result. The registry sits on a longer clock than `results/`.
- **§3 email receipt, default-on** — SES sends the durable `/download/{job_id}`
  link from a verified urban.org sender.
- **§4 telemetry** — three NDJSON events (`request_created`,
  `export_materialized`, `download`) written to the results bucket's
  `logs/queries/{YYYY-MM-DD}/`; the monthly rollup (`jobs/rollup.py`) aggregates
  them into the contracted [[usage-api]] artifact.
- **Auth split (refines §5).** `POST /data` is a Lambda **Function URL** with
  `AuthType: AWS_IAM` — the sector-in-brief server signs SigV4 via a dedicated
  invoke IAM user; `GET /download/{job_id}` is a **separate, public** Function
  URL (`AuthType: NONE`) so the emailed link is clickable without signing. No
  API Gateway (sidesteps its 29 s / 6 MB limits). The download function is the
  same code gated `DOWNLOAD_ONLY`.
- **Size pre-check (refines §6).** Realized as an `estimate: true` flag on
  `POST /data`: the API returns exact `row_count` + a sampled byte estimate with
  no materialization; the dashboard presents it before the user commits to a
  large export.

**§6 dashboard-form rework + UI cutover — shipped (was pending at staging).**
The Custom Panel Datasets form was rewired to this API and hardened over a
post-staging round: four form types incl. first-class 990-PF, BMF org-level mode
([[0029-bmf-org-level-query-mode]]), async-202 email-and-wait
([[0030-async-giant-export-worker]]), FIPS-keyed county selection
([[0021-canonical-county-identity-via-fips-crosswalk]]), region→state picker
scoping, a bypass-proof pre-submit validation gate, friendly surfacing of the
API's validation `400`s, and form-specific year coverage
([[0031-core-tier-routing-api-canonical]]). **Cut over to prod 2026-06-12**
(sector-in-brief PRs #68–#82, ADR 0008 migration step 3): the prod dashboard
points at `query-prod` via a deploy-time `.Renviron`, never a code edit
(`download_api_config()` is env-driven). 1-week prod soak in progress;
legacy-API sunset pending ([[0008-modernize-dataexplorer-api]]).

## Consequences

**Positive:**

- Emailed links survive page-close and object expiry — "always have the
  link" becomes literally true, closing 0008's acknowledged 404 gap.
- Storage stays bounded by the lifecycle rule regardless of user
  behavior; the durable endpoint makes retention length a
  cost/latency knob, not a UX cliff.
- The abandoned-page question becomes a **measured** number, not a guess.
- Gives ADR 0008's API its concrete **first consumer** and resolves ADR
  0011 residual #1 (the `/stg/` URL).
- No runtime database; the request registry is serverless S3 JSON.

**Negative:**

- The durable endpoint + registry + re-materialize path is real
  engineering beyond 0008's "single signed URL" — more moving parts
  (registry lifecycle, re-run-on-expiry, hashing PII for the rollup).
- Email-by-default stores a requester address per request; the rollup
  must hash it and the registry sidecar must carry retention/PII
  discipline.
- Re-materialization on a stale link re-runs the query — cheap on
  DuckDB, but a slow/huge query pays it again on each post-expiry fetch
  (mitigable later by an optional dedup key on `(params, vintage)`).

## Deprecation window

Not applicable as a new decision — the legacy Athena download path is
sunset under ADR 0008's existing 90-day window. No additional break is
introduced here.

## Follow-up

1. **Build depends on [[0008-modernize-dataexplorer-api]]** standing up
   `sector-in-brief-api`. The interface OpenAPI (§5) is the first
   deliverable so the UI (prong 1) and API (prong 2) build against it in
   parallel.
2. Flesh out [[usage-api]] with the §4 event taxonomy and the realized
   rollup schema once the API logs at least one month.
3. Reconcile `ARCHITECTURE.md` §6: replace the stale "Dashboard is a
   consumer of the API" bullet with the **hybrid** reality (S3-direct viz
   per ADR 0011; API-backed downloads per this ADR).
4. Confirm the URL TTL and any dedup-key decision at build time; record
   here if they shift.
