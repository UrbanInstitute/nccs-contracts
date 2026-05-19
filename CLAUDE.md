You're in nccs-contracts, the contract-surface repo for the NCCS data system. It is the spine of a multi-repo system: producers (nccs-data-bmf, nccs-data-core, nccs-data-efile, and a forthcoming nccs-data-merged) publish parquet/CSV artifacts to S3; consumers (nccsdata R package, an API, a dashboard) read those artifacts. This repo describes the contract surface, not the code that produces or consumes it.

Sibling repos live one level up under `../` (nccsdata is the most mature consumer; the others are at varying states). S3 is the only inter-repo contract surface — code dependencies between sibling repos are intentionally avoided.

Start every non-trivial task by reading:

1. `ARCHITECTURE.md` — current-state system description.
2. `decisions/` — ADRs for the load-bearing calls (0001 S3 surface, 0002 merged artifact, 0003 DuckDB over Athena, 0004 cadence-aware drift detection). Read the ones relevant to the task.
3. `contracts/_template.yml` — the canonical shape every contract follows.
4. The specific `contracts/*.yml` relevant to the task. Most are TODO stubs awaiting authoritative population from the producer repos and live S3 artifacts.

House rules:

- Any change that alters a contract's shape, a producer/consumer pattern, or a load-bearing technology choice requires a new ADR in `decisions/`. Update `ARCHITECTURE.md` to reflect the new state; the ADR preserves the why.
- Contract YAMLs are authoritative. If a producer or consumer drifts from its contract, the contract isn't wrong by default — investigate which side is out of date.
- Default deprecation window for breaking changes is 90 days.
- This repo has no runtime; CI here will eventually validate the YAMLs against schema and against live S3, but doesn't yet.

## Current state of play

Scaffolding (ARCHITECTURE, four ADRs, contract template, six stub contracts) was just committed. The immediate next work is filling the TODOs in `contracts/*.yml` from authoritative sources — for each, that means reading the producer repo's publish code and inspecting the actual S3 layout. Start there unless directed elsewhere.
