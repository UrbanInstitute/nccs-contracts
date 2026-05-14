# nccs-contracts

The contract surface for the NCCS data system. This repo describes
every artifact published to S3 by the NCCS data pipelines, the
conventions producers and consumers agree on, and the architectural
decisions behind that shape.

## What's in here

- `ARCHITECTURE.md` — system overview: producers, consumers, S3 spine,
  agentic operations. Read this first.
- `contracts/` — one YAML file per published artifact (BMF master,
  BMF lookups, core 990, e-file, merged). Each file is the source of
  truth for that artifact's path, format, cadence, schema, and
  producer/consumer mapping.
- `decisions/` — Architecture Decision Records (ADRs) capturing the
  *why* behind major calls. The architecture doc describes
  current state; ADRs preserve history.

## How this repo is used

- **Producers** (e.g. `nccs-data-bmf`, `nccs-data-core`,
  `nccs-data-efile`) reference the relevant contract on publish and
  validate their output against it.
- **Consumers** (e.g. `nccsdata` R package, dashboard, API) reference
  the same contract on read and pin to a contract version.
- **Agents** (Copilot, scheduled jobs) read contracts to drift-check
  what's actually on S3 against what the contracts promise.

## Status

v0 — scaffolding in place; contract YAMLs are stubs awaiting
authoritative population.
