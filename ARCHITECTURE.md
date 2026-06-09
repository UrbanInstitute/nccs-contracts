# NCCS Data System Architecture

This document is the current-state description of the NCCS data
system: what it is, why it's shaped this way, and how it grows. For
the history behind major calls, see the ADRs in `decisions/`.

## 1. System Map

```
              ┌─────────────────────────────────────────┐
              │              S3 (canonical)             │
  Producers ─►│   bmf/  core/  efile/  lookups/         │◄─ Consumers
              │   merged/  (derived from bmf+core+efile)│
              └─────────────────────────────────────────┘
                                │
                                ▼
                       nccs-contracts (this repo)
                                │
                                ▼
                    drift detection (Copilot + cron)
```

| Component | Role | Repo |
|---|---|---|
| BMF pipeline | Producer — geocoded master + dated vintages + lookups + geography crosswalks (`county-fips`, `cbsa`, and the coordinate-keyed `ct-planning-region` under `s3://nccsdata/crosswalks/`, per ADR 0021 + ADR 0023) | `nccs-data-bmf` |
| Core 990 pipeline | Producer — IRS SOI extracts, one row per filing | `nccs-data-core` |
| E-file pipeline | Producer — LIVE (Phase 0). Parses raw IRS 990/990-PF XML into form-agnostic parquet; first vintage `v2026.05` published 2026-05-29. Phase 0 ships two filing-grain metric tables (`government_grants`, `program_related_investments_total`) under `s3://nccsdata/processed/efile/phase0/`; Phase 1+ headline-990 surface still planned. See ADR 0007 / ADR 0017. | `nccs-data-efile` |
| Consumer-composed joins | Consumers compose BMF × core × e-file joins per use case (per ADR 0016 — no canonical cross-dataset merge). The within-core form union is contracted as `core-panel`. Geographic identity is composed the same way: the producer publishes the `county-fips` and `cbsa` crosswalks (resolution done once), consumers join them onto raw geo labels (per ADR 0021 — the master is deliberately not modified). Connecticut, whose retired-county labels can't resolve at the name grain, is recovered by a coordinate join against the `ct-planning-region` companion (per ADR 0023). | n/a |
| nccsdata R package | Consumer — programmatic reads with arrow filters + local cache | `nccsdata` |
| Ad-hoc data requests | Consumer — composes on-demand BMF × core × e-file joins for specific geographies, one folder per request, pinning contract versions (per ADR 0024). A thin consumer, not a merge layer: re-derives no geography (joins the published crosswalks), publishes no reusable data artifact, and is out of the drift loop. Each request is authored as a reproducible Quarto `.qmd`; recurring joins graduate to a crosswalk or the API, and generalizable + public-safe requests graduate to a public data story in the `nccs` website's `_stories/` collection (per ADR 0025). | `nccs-data-requests` |
| API | Consumer + service tier — `sector-in-brief-api`; DuckDB-on-parquet with query-time EIN joins (no pre-merged artifact, per ADR 0016); Lambda-first hybrid host with an async worker for the p99+ giant tail (ADR 0008 Outcome, Phase-0 2026-06-09); pattern-B downloads via durable `/download/{job_id}` (ADR 0026). Build not yet started. | `sector-in-brief-api` |
| Sector-in-Brief data | Derived producer — aggregates BMF/core/SOI/DAF into dashboard-ready parquet (replaces nccs-dataexplorer-data per ADR 0010) | `sector-in-brief-data` |
| Sector-in-Brief dashboard | Consumer — Shiny UI; reads sector-in-brief data from S3 directly at app startup (not via the API) per ADR 0011 | `sector-in-brief` |

## 2. Why S3 as the Contract Surface

- **Asynchronous decoupling.** Producers publish on their cadence;
  consumers read on theirs. No request/response coupling, no shared
  uptime requirements.
- **Cheap, durable, language-agnostic.** Every consumer language has
  good parquet + S3 support. No queue or broker to operate.
- **Already where the data lives.** The pipelines write S3 either way;
  making it the contract surface adds zero infrastructure.
- **Validatable as an artifact.** Manifests + sha256 + parquet schemas
  give us deterministic checks; agents diff "promised" against "on
  disk."

What we explicitly rejected and why is documented in
`decisions/0001-s3-as-contract-surface.md`.

## 3. Producer Pattern

Every producer publishes the same shape:

- **Data artifact(s).** Parquet preferred; CSV permitted only when
  parquet is not yet possible. Partitioned where the access pattern
  benefits (e.g. by state, year, or filing month).
- **Manifest.** `_manifest.json` co-located with the artifact, in the
  standard ADR 0014 shape (`vintage`, `built_at` UTC, `git_sha`,
  `inputs[]`, and per-file `sha256`/`bytes`/`row_count`/`columns[]`).
  Reference implementation: nccs-data-bmf `R/manifest.R`. Live for
  `bmf-lookups` (2026-06-03); rolling out to the other producers. The
  older `MANIFEST.json` name is dual-written through a 90-day window.
- **Versioned URL + `_latest` pointer.** Consumers pin a version;
  applications that always want the freshest data can reference the
  `_latest` alias.
- **Contract entry.** One YAML in `contracts/` describing the
  artifact. The pipeline references this on publish for validation.

A producer that doesn't follow this shape isn't a producer — it's an
ad-hoc data drop, and consumers should not depend on it.

## 4. Consumer Pattern

Consumers read canonical artifacts from S3 (directly, or via the API
for service-tier consumers).

- **No private upstream ETL.** Consumers do not re-clean or
  re-process producer outputs. If a consumer feels the need to, that
  signals a missing artifact or a contract gap and belongs upstream.
- **Pin a contract version.** Consumers reference contract version,
  not paths. Path moves are the producer's problem to coordinate;
  consumer code shouldn't break on rename.
- **Coerce at the boundary.** Type coercion (string → numeric, string
  → date) happens at the consumer, not in the published artifact,
  because vintage-stacked parquets need string types to avoid schema
  conflicts. Consumers document the coercion they perform.

## 5. The Derived-Artifact Tier

Some artifacts are derived from joining or transforming other
producers' outputs. The `merged` artifact (BMF + core, eventually +
efile) is the first.

**Derived artifacts are first-class producers.** They have their own
contract entry, their own manifest, their own version. They are not
private API implementation details. Reasons:

- One data reality. The API, the R package, and any future consumer
  see the same merged data.
- Auditable. The merge logic lives in code; the result lives as a
  diff-able artifact; agents can drift-check it.
- Reusable. The dashboard, ad-hoc analysts, and future ML pipelines
  all consume the same merged table without re-implementing the join.

See `decisions/0002-canonical-merged-artifact.md`.

## 6. The Service Tier

The API is the general-purpose service tier. It reads the contracted
S3 artifacts directly and composes joins per use case at query time —
there is no canonical `merged` artifact (ADR 0016) — serving parametric
queries.

- **Tech baseline:** DuckDB embedded in the API process, querying
  partitioned parquet on S3 (or a local cache). LRU cache for hot
  partitions.
- **Athena retired** for API runtime. Optionally retained for
  human ad-hoc SQL. See `decisions/0003-retire-athena-for-duckdb.md`.
- **Dashboard is a *hybrid* consumer.** Its visualization panels
  read S3 directly (ADR 0011); its data-download section goes through
  the API for bulk parametric exports that exceed what the Shiny
  process can serve (ADR 0026). The viz path stays up even if the API
  is down — the blast radius of an API outage is downloads only.
- **R package may eventually migrate** to read from the API instead
  of S3 (particularly when authenticated/metered access matters), but
  that's a later call. Today the package reads S3 directly.

## 7. Cadence Model

| Producer | Cadence | Drift detection trigger |
|---|---|---|
| BMF | Monthly batches | Weekly cron |
| Core 990 | Annual (SOI release schedule) | Weekly cron |
| E-file | Continuous trickle | Event-triggered (on each new batch) |
| Lookups | On schema change | Weekly cron |
| Merged | Derived; rebuilt when any input updates | Event-triggered (on input change) |

Cadence determines drift-detection trigger. See
`decisions/0004-cadence-aware-drift-detection.md`.

## 8. Versioning and Deprecation

- **Contract repo is versioned.** Each tagged release of
  `nccs-contracts` is referenceable. Consumers pin to a tag.
- **Each artifact carries a version.** Both in its URL path and in
  the manifest. Versions are additive; renames are breaking changes
  with a glide path.
- **Breaking changes get a deprecation window.** Producer publishes
  both old and new for a documented period (default 90 days).
  Consumers update at their cadence. ADR required for any breaking
  change.
- **`_latest` is for humans, not production.** Pipelines reading
  `_latest` are accepting that they may break; that's a deliberate
  choice, not a default.

## 9. Agentic Operations

The system uses GitHub Copilot agent (Opus) for fuzzy cross-repo
work, deterministic GitHub Actions for everything else. Three
loops run in steady state; the maintainer is the approver in all
three, not the debugger.

### Job-to-mechanism map

| Job | Mechanism |
|---|---|
| Schema validation on publish | GitHub Actions in producer repo |
| Manifest integrity check | GitHub Actions, scheduled |
| Drift detection (cron) | Scheduled GH Action opens issue → Copilot agent investigates and drafts PR |
| Drift detection (event) | Producer publish hook → contract validation → issue if drift |
| Cross-repo update PRs | Copilot agent triggered by issues |
| PR review on contract-adjacent code | Copilot agent, path-filtered to keep Opus costs bounded |

### Loop 1 — Drift detection

A producer publishes (e.g. `nccs-data-bmf` cuts a new vintage to
S3). One of two triggers fires depending on cadence:

- **Event trigger** (continuous producers like e-file): the
  producer's publish step fires a GH Actions workflow that reads
  `contracts/<name>.yml` and diffs the S3 artifact against it
  (schema, manifest, sha256, row counts within tolerance).
- **Cron trigger** (batch producers like BMF): same diff, run from
  a scheduled workflow in `nccs-contracts` rather than from a
  publish hook.

Pass is silent. Fail opens a GitHub issue in `nccs-contracts`
titled `[drift] <contract-name>` with the specific delta. The
Copilot agent then:

1. Reads the issue, `contracts/<name>.yml`, and any ADR linked
   from the YAML's notes.
2. Investigates — checks actual S3 layout, the producer repo's
   recent commits, whether the contract is stale or the producer
   drifted.
3. Drafts a PR in whichever repo owns the fix (producer if it
   regressed, `nccs-contracts` if the contract is wrong) with a
   one-paragraph diagnosis.
4. Posts a comment on the drift issue linking the PR.

The maintainer reviews and merges. The agent does not merge its
own PRs.

### Loop 2 — Cross-repo updates

The maintainer opens an issue like `[update] sector-in-brief.yml
pin to v2026.06`. The agent reads the contract, finds every
repo that pins it (looking at `consumers[].repo` in the YAML),
and drafts a pin-bump PR in each. Cross-links the PRs back on
the original issue. The maintainer merges them in dependency
order.

### Loop 3 — Contract-adjacent PR review

When a PR opens in any repo that touches contract-relevant paths
(configured by path filter to bound Opus cost — e.g. `R/publish.R`,
`data/*.parquet`, anything in `contracts/`), the agent leaves an
automated review checking: does this break the contract? Does it
match the relevant ADR? Did the author forget to update the YAML
or `ARCHITECTURE.md`?

This is the cheapest loop and the one that catches "I forgot to
update the contract" mistakes mid-flight rather than at drift-
detection time.

### What the agents read

- `contracts/*.yml` — source of truth for schemas, paths, cadence,
  pins.
- `ARCHITECTURE.md` — the *why* for borderline judgment calls.
- ADRs in `decisions/` — fetched by `[[link]]` references from the
  YAML or this doc when the agent needs deep context for a
  non-obvious decision.

### Cost shape

Opus is expensive, so the agents run **on triggers, not on
schedules-that-loop**. The cron jobs are deterministic GH Actions
(cheap); the agent only wakes when a deterministic check has
already found drift or a contract-adjacent PR opened. The PR
review loop uses path filters to skip PRs that can't possibly
affect the contract surface.

### Day-to-day maintainer load (in steady state)

- Review 0–3 agent-drafted PRs per week (more after producer
  releases, near-zero between releases).
- Open the occasional `[update]` issue when a contract version
  needs bumping.
- Open ADRs for new decisions — the agent will not initiate these.
- Reconcile downstream work back into ADRs after execution (see
  `CONTRIBUTING.md`).

### Not yet built

This section is aspirational. As of 2026-05-21, none of the loops
above run. What is missing before they can:

1. **A schema validator.** Nothing in this repo currently reads a
   contract YAML and a parquet file and tells you they agree. The
   `c5a75fb` commit added the scaffold of a `contracts-validate`
   GH Actions workflow but no validator behind it.
2. **Per-producer publish hooks.** Each producer repo needs a
   workflow step that calls into validation on publish (Loop 1's
   event trigger).
3. **The cron/event workflow.** A scheduled GH Action in
   `nccs-contracts` that opens drift issues when the validator
   finds delta (Loop 1's cron trigger and Loop 1's issue-opener).
4. **Copilot agent configuration.** Path filters, repo allowlist,
   and the system prompt that tells the agent to read `contracts/`
   and `ARCHITECTURE.md` before drafting any PR.
5. **A populated contract surface.** Several `contracts/*.yml`
   files still carry `TODO` markers. The agents are useless
   without an authoritative spec to diff against; populating these
   from authoritative sources is prerequisite work per `CLAUDE.md`.

Until those five pieces ship, "drift detection" is the maintainer,
manually, in a Claude session. The contract YAMLs and ADRs are
the leverage point — they are what makes the agentic workflow
possible later.

## 10. Adding a New Module

When adding a new producer or consumer:

1. **Open an ADR** in `decisions/` describing the new module, its
   role, and the alternatives considered. Reviewable PR.
2. **Add the contract entry** in `contracts/` for any new artifact
   the module publishes (producers) or pins (consumers).
3. **Register the module in `ARCHITECTURE.md`** — append to the
   system map table; update cadence model if the cadence is novel.
4. **Wire the module in.** Producers: add the publish-time
   validation hook. Consumers: pin the contract version, document
   any coercion they perform.
5. **Notify the drift detector.** Add the module to the agent's
   watch list (event trigger for continuous producers; cron for batch).

A module that skips any of these steps is invisible to the system
and will break silently. Don't.

## 11. Intentionally Out of Scope

- **No message queue / event bus.** S3 + manifests are enough. If we
  hit a use case that genuinely needs push-based notification (e.g.
  sub-minute consumer reactions to e-file batches), revisit then.
- **No monorepo.** The repo boundaries match the team and ownership
  boundaries (which here happen to be one person, but the model
  supports growth). If the system ever has multiple maintainers per
  repo, the per-repo CI and review surfaces will earn their keep.
- **No coordinator service / agent orchestrator.** GitHub-native
  triggers + Copilot agent are sufficient. Revisit if we end up
  needing cross-repo transactions or rollbacks.
- **No runtime database for the API.** DuckDB + parquet covers the
  query profile. Revisit if concurrent load exceeds ~200 req/s of
  selective queries or if we need transactional writes (we don't —
  the API is read-only).

Each of these comes with a revisit trigger so we can recognize when
the choice no longer fits.
