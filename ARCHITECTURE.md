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
| BMF pipeline | Producer — geocoded master + dated vintages + lookups | `nccs-data-bmf` |
| Core 990 pipeline | Producer — IRS SOI extracts, one row per filing | `nccs-data-core` |
| E-file pipeline | Producer — continuous trickle of raw Form 990 filings | `nccs-data-efile` |
| Merged producer | Derived producer — joins BMF + core (+ efile later) on EIN | TBD (likely new repo) |
| nccsdata R package | Consumer — programmatic reads with arrow filters + local cache | `nccsdata` |
| API | Consumer + service tier — parametric queries over the merged artifact via DuckDB | TBD (existing API to modernize) |
| Dashboard | Consumer — UI sitting on top of the API | TBD (existing dashboard to modernize) |

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
- **Manifest.** `MANIFEST.json` co-located with the artifact, listing
  files, sha256 sums, vintage, and generation timestamp.
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

The API is the general-purpose service tier. It reads canonical S3
artifacts (primarily `merged`) and serves parametric queries.

- **Tech baseline:** DuckDB embedded in the API process, querying
  partitioned parquet on S3 (or a local cache). LRU cache for hot
  partitions.
- **Athena retired** for API runtime. Optionally retained for
  human ad-hoc SQL. See `decisions/0003-retire-athena-for-duckdb.md`.
- **Dashboard is a consumer of the API**, not a peer reader of S3.
  Keeps the data path single-source.
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
work, deterministic GitHub Actions for everything else.

| Job | Mechanism |
|---|---|
| Schema validation on publish | GitHub Actions in producer repo |
| Manifest integrity check | GitHub Actions, scheduled |
| Drift detection (cron) | Scheduled GH Action opens issue → Copilot agent investigates and drafts PR |
| Drift detection (event) | Producer publish hook → contract validation → issue if drift |
| Cross-repo update PRs | Copilot agent triggered by issues |
| PR review on contract-adjacent code | Copilot agent, path-filtered to keep Opus costs bounded |

The agent reads `contracts/` and `ARCHITECTURE.md` for context. The
contract YAMLs are the only thing it needs to do useful drift work;
the architecture doc gives it the *why* for borderline cases.

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
