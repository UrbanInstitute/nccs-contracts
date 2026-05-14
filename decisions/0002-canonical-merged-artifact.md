# 0002 — Canonical Merged Artifact as a First-Class Producer

- **Status:** Accepted
- **Date:** 2026-05-14
- **Deciders:** sole maintainer

## Context

The API has historically served a join of BMF + core 990 data on
EIN. The merge was implemented as a private pre-processed table
queried via Athena, with the merge logic embedded in pipeline /
DDL code.

This created two data realities:

- The R package and direct-S3 consumers read the canonical BMF and
  core artifacts.
- The API and dashboard read the Athena-backed merged table.

When BMF or core columns changed, both realities had to be updated
in parallel, and there was no audit trail for the merge logic
beyond the pipeline source.

## Decision

The merged BMF + core (+ later e-file) dataset is promoted to a
**first-class derived producer**: it has its own contract entry,
its own manifest, its own version, and is published as partitioned
parquet to a canonical S3 path. The API reads this artifact like
any other consumer.

## Consequences

**Positive:**

- One data reality. Every consumer reads canonical S3.
- The merge logic produces a diff-able artifact; agents can
  drift-check it.
- Reusable. Dashboard, R package (eventually), ad-hoc analysts, and
  future ML pipelines can all consume the same merged table.
- Eliminates Athena from the API's runtime path (see
  [0003](0003-retire-athena-for-duckdb.md)).

**Negative:**

- One more pipeline to operate (the merge job). Lives in its own
  repo with its own CI; complexity is bounded.
- Storage cost. The merged table is materialized, not derived at
  query time. Acceptable — parquet compression keeps it modest
  (~10 GB vs. 50 GB CSV) and S3 storage is cheap relative to query
  cost.

## Alternatives Considered

- **Keep the merge as a private API concern, modernize the Athena
  table.** Rejected: perpetuates the two-realities problem and
  hides the merge logic.
- **Compute the merge at query time in the API.** Rejected: makes
  the API depend on multiple producers' fresh state at request time
  and trades materialization storage for per-request CPU. The API's
  query profile doesn't justify it.

## Revisit trigger

If the merge becomes too expensive to materialize at every input
update, or if multiple variant merges are needed (e.g. with vs.
without efile), revisit whether to publish materialized variants or
compute on demand.
