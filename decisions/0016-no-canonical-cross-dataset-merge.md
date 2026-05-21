# 0016 — No Canonical Cross-Dataset Merge

- **Status:** Accepted (planning; not yet executed)
- **Date:** 2026-05-21
- **Deciders:** sole maintainer
- **Supersedes:** [[0002-canonical-merged-artifact]]
- **Related:** [[0003-retire-athena-for-duckdb]], [[0004-cadence-aware-drift-detection]], [[0015-core-contract-surface-restructure]]

## Context

[[0002-canonical-merged-artifact]] (2026-05-14) decided that the
join of BMF + core (+ eventually e-file) on EIN should be
materialized as a first-class derived producer — published to S3
with its own contract, its own manifest, its own version. The
goal was "one data reality": instead of the API and the dashboard
reading a private Athena-backed merge while the R package read raw
BMF/core, all consumers would read a single canonical merged
artifact.

That ADR has not yet been executed. In the year since it was
written, three things have shifted:

1. **The actual cross-consumer experience pulled the other way.**
   The two consumers that ended up being built — the
   sector-in-brief dashboard (via the `sector-in-brief-data`
   producer per [[0010-sector-in-brief-data-replaces-dataexplorer-data]])
   and the in-progress dataexplorer API (per
   [[0008-modernize-dataexplorer-api]]) — both compose their own
   merges from raw sources rather than reading a pre-merged
   artifact. `sector-in-brief-data/config.yml` reads
   `bmf-master-geocoded` plus the three core tiers
   (`processed/core/`, `processed_legacy/core/`,
   `processed_merged/core/`) plus external DAF e-files, then
   derives panel-specific aggregates. No future consumer is on
   the horizon that genuinely wants a generic pre-joined table.

2. **Use cases are heterogeneous in ways a canonical merge can't
   serve.** Different consumers need different join keys, year
   windows, included/excluded form types, and aggregation grains:
   - A research panel needs one row per EIN-year across the full
     time range, joining BMF firm-level attributes onto core
     filings.
   - A dashboard like sector-in-brief needs pre-aggregated metrics
     by Census geography × subsector × size, derived from BMF + core
     + external sources.
   - An EIN lookup needs current-vintage BMF attributes only.
   - A foundation-grants analysis needs BMF + 990-PF without 990
     or 990-EZ.

   A single canonical merged table either serves none of these
   well (too generic) or balloons into multiple variants (which
   0002's Revisit trigger already anticipated as a failure mode).

3. **The cadence mismatch is harder than 0002 acknowledged.** Per
   [[0004-cadence-aware-drift-detection]], BMF is monthly, core
   is annual (tied to IRS SOI release), and e-file is a continuous
   trickle. A merged artifact has to pick a cadence and rebuild on
   every input change — operationally expensive, and the merged
   view is stale-of-something the moment any single input updates.
   Consumers that compose their own merges can pin each input's
   vintage independently and decide their own freshness tolerance.

[[0002-canonical-merged-artifact]]'s "Revisit trigger" explicitly
flagged this case: "If multiple variant merges are needed (e.g.
with vs. without efile), revisit whether to publish materialized
variants or compute on demand." We have arrived at the case the
trigger anticipated.

## Decision

**BMF, core, and e-file remain as separate contracted producers.
There is no canonical cross-dataset merged artifact.** Consumers
compose joins from the three datasets — pinned to vintages per
their reproducibility needs — at their layer.

Concretely:

- `bmf-master`, `bmf-master-geocoded`, `bmf-lookups`, `bmf-legacy`
  stay as the BMF surface.
- `core-990` (`processed/core/`), `core-legacy`
  (`processed_legacy/core/`), and `core-panel`
  (`processed_merged/core/`, post-rename per
  [[0015-core-contract-surface-restructure]]) stay as the core
  surface.
- `efile` stays as the e-file surface (per
  [[0007-efile-urban-owned-producer]]).
- No `merged` contract describing a BMF×core×efile join exists.
  The placeholder `contracts/merged.yml` is renamed to
  `contracts/core-panel.yml` under 0015 — that artifact is a
  *within-core* form-type union (990 + 990-EZ + 990-PF), not the
  cross-dataset merge that 0002 envisioned.
- The future `nccs-data-merged` repo envisioned in 0002 is
  **dropped**. There is no plan to build it.

### What replaces "one data reality"

0002 framed the alternative as "two data realities" — canonical
S3 artifacts on one side, a pre-joined Athena table on the other.
That framing still matters, but the resolution is different:

**The contracts themselves are the single source of truth, not a
pre-joined artifact.** Every consumer that composes a merge reads
the same contracted upstream surfaces (the bullets above), pinned
to specific vintages per [[0013-versioned-producer-outputs]].
Drift detection runs on the contracts. If a consumer's merge
breaks because BMF changed a column, the break shows up at the
*contract* layer — not in mismatched downstream materializations.

The merge logic itself moves to the consumer side, where it
belongs. Different consumers can compose different merges without
forcing the producer to canonicalize an answer.

### Service-tier consequences

[[0003-retire-athena-for-duckdb]] decided the API moves to DuckDB
over raw contracted parquet. 0003 implicitly assumed the merged
table from 0002 would exist as the API's primary table. With 0002
superseded, the API instead opens DuckDB views across multiple
contracted parquets and serves joined results per-query. DuckDB
handles this fine — it's its design center.

This shifts join cost from materialization (storage,
materialize-on-publish) to query time (CPU, materialize-on-read).
For the dataexplorer query profile (low QPS, parametric filters),
the trade is favorable: storage savings + simpler producer
orchestration outweigh the per-query CPU cost.

## Consequences

**Positive:**

- Operational complexity drops: one fewer pipeline to build, no
  cadence-coordination problem, no merge-variant management.
- Each consumer can pin upstreams independently and decide its
  own freshness/reproducibility tradeoff.
- Producers (BMF, core, e-file) evolve on independent schedules
  without forcing a downstream merge rebuild.
- Storage cost drops (no materialized cross-join table).
- The contracts surface (this repo) becomes the single source of
  truth more cleanly than under 0002, where the merged artifact
  was *also* a source of truth but for joined data.

**Negative:**

- Each consumer that wants a merge implements (or copies) join
  logic. Mitigated by: there are very few such consumers; the
  joins are simple (EIN-based); each consumer needs a different
  variant anyway.
- No agent-friendly "what did the merge produce last vintage?"
  artifact to drift-check. Drift detection runs on individual
  contracts and on per-consumer materializations; the merge
  itself is verified at consumer-side ingest, not centrally.
- Slight cost to the API service tier — query-time join CPU
  instead of pre-materialized reads. DuckDB makes this small;
  see "Service-tier consequences" above.

## Alternatives considered

- **Keep 0002, defer execution.** Rejected: the longer 0002 sits
  un-executed while consumers compose their own merges, the more
  divergence between the spec and reality. Better to align the
  spec with what's actually happening.
- **Publish merge variants under a single `merged` contract**
  (e.g. `merged/bmf-core/`, `merged/bmf-core-efile/`). Rejected
  for the reasons in Context §2 — variants proliferate; no
  variant serves any one consumer perfectly; consumers still end
  up post-filtering.
- **Compute the merge at the API and call that "the canonical
  view".** Rejected: the API is one consumer of many; canonical
  views shouldn't live inside a service-tier component.

## Migration plan

This ADR is mostly about *not* building something. Concrete edits:

1. **`contracts/merged.yml` rename.** Already covered by
   [[0015-core-contract-surface-restructure]] — rename to
   `contracts/core-panel.yml` and scope to the within-core
   union, not a cross-dataset merge.
2. **`ARCHITECTURE.md` updates.** The system map's "Merged
   producer" row currently reads
   `Derived producer — joins BMF + core (+ efile later) on EIN`
   with the repo as `TBD (likely new repo)`. Replace with a note
   that consumers compose joins themselves; drop the "Merged
   producer" row from the table or relabel it as a generalized
   "Derived consumer-side joins" entry pointing at this ADR.
3. **Mark [[0002-canonical-merged-artifact]] Status as
   superseded** by this ADR. Keep the file (history).
4. **Touch [[0003-retire-athena-for-duckdb]]'s Follow-up
   section** to note that the API now serves joins via DuckDB
   views across multiple contracted parquets, not a single
   pre-merged table.
5. **Touch [[0010-sector-in-brief-data-replaces-dataexplorer-data]]'s
   notes** — it currently lists the merged table as a planned
   future input. With 0002 superseded, sector-in-brief-data is
   already a model of the consumer-composes-joins pattern; the
   ADR's mention of the merged table can be updated to reflect
   that.

## Deprecation window

Not applicable; the canonical merged artifact was never built, so
nothing on S3 is being retired by this ADR.

## Follow-up

1. If a future use case emerges that genuinely wants a
   pre-materialized BMF×core join (e.g. a Tableau / BI tool that
   can't run DuckDB joins efficiently), revisit. The decision
   here is "no canonical merge today," not "no canonical merge
   ever."
2. Consider whether a small shared R helper library
   (`nccsdata::join_bmf_core()` or similar) should ship — would
   give consumers a tested join template without forcing a
   materialized artifact. Out of scope for this ADR; raise as a
   separate proposal in `nccsdata` if it gains traction.
3. The `nccs-data-merged` repo placeholder in
   [[0010-sector-in-brief-data-replaces-dataexplorer-data]] and
   in ARCHITECTURE.md is dropped. No GitHub repo, no skeleton,
   no contract.
