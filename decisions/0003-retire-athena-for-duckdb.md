# 0003 — Retire Athena for API Runtime; Use DuckDB on Parquet

- **Status:** Accepted
- **Date:** 2026-05-14
- **Deciders:** sole maintainer

## Context

The API has used AWS Athena to query a pre-processed merged table.
With the merged dataset moving to canonical partitioned parquet
(see [0002](0002-canonical-merged-artifact.md)), the runtime query
engine is up for re-evaluation.

The API's query profile is overwhelmingly selective: filter by EIN,
state, NTEE, or filing year; project a column subset; return a
small slice. Heavy aggregations across the whole dataset are rare.

The merged table is roughly 50 GB CSV / 10 GB parquet today and
will grow as e-file is added.

## Decision

The API uses **DuckDB embedded in the API process**, querying
partitioned parquet on S3 (or a local cache). Athena is retired
from the API runtime. Athena may be retained for human ad-hoc SQL
and data quality work; it is not on any consumer's hot path.

## Consequences

**Positive:**

- For selective, column-projected queries (the common case): DuckDB
  on partitioned parquet is typically faster than Athena, with no
  per-query overhead.
- Zero per-query cost. Athena's pay-per-scan model is eliminated.
- Hot-data caching. DuckDB benefits naturally from OS page cache
  and can use a local SSD cache; Athena always re-reads from S3.
- Operational simplicity. No Athena tables, partitions, or DDL to
  maintain in sync with the producer pipelines.

**Negative:**

- Full-table aggregations are slower (single-machine vs. Athena's
  parallelism). Acceptable — these are rare and can stay on Athena
  for human use.
- Concurrent-load ceiling on a single API server is finite. Mitigated
  by vertical scaling and partition caching; revisit if traffic
  outgrows it.
- DuckDB version becomes a deployment dependency. Mitigated by
  pinning version in the API repo and testing upgrades.

## Alternatives Considered

- **Keep Athena.** Rejected: maintains a costly query engine for a
  workload that doesn't need it, and keeps the API tied to AWS
  query infrastructure.
- **Stand up a hosted database (Postgres, Redshift).** Rejected:
  duplicates the parquet store, adds operational surface (backups,
  schema migrations, replication), and the query profile doesn't
  benefit from a transactional engine.
- **Pure arrow without SQL.** Rejected: the API endpoints map
  naturally to SQL; rebuilding equivalent ergonomics in arrow code
  is gratuitous.

## Revisit trigger

Concurrent load exceeds ~200 req/s of selective queries on a
vertically-scaled single server, or full-table aggregations become
common enough to move back to a parallel engine.
