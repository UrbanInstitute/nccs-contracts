# nccs-contracts

The contract surface for the NCCS data system. This repo describes
every artifact published to S3 by the NCCS data pipelines, the
conventions producers and consumers agree on, and the architectural
decisions behind that shape.

> 📐 **New here for the approach, not the data?** See
> [`docs/agentic-systems-design.md`](docs/agentic-systems-design.md) —
> the system in three states (old → current → complete) and what a
> practical agentic approach to systems design looks like: build the
> contract + decision surface first, and let agents become the dividend.

## What's in here

- `ARCHITECTURE.md` — system overview: producers, consumers, S3 spine,
  agentic operations. Read this first.
- `contracts/` — one YAML file per published artifact (BMF master,
  BMF lookups, core tiers, e-file, sector-in-brief). Each file is the
  source of truth for that artifact's path, format, cadence, schema,
  and producer/consumer mapping. (There is no canonical cross-dataset
  merge — consumers compose joins per ADR 0016.)
- `decisions/` — Architecture Decision Records (ADRs) capturing the
  *why* behind major calls. The architecture doc describes
  current state; ADRs preserve history.
- `CONTRIBUTING.md` — how to make changes here: the **reporting cycle**
  (commander / executor / courier roles, the ADR Status state machine,
  the escalation gate, and the sitrep up-channel — ADR 0038), the
  plan/execute/reconcile loop with downstream repos, when to write a
  new ADR vs. amend, and the contract YAML conventions.
- `.claude/commands/reconcile-status.md` — `/reconcile-status`, the
  lag-sweep run at session boot: lists open-loop ADRs and cross-checks
  downstream PRs so reconcile lag stays visible.
- `docs/agentic-systems-design.md` — the system's old → current →
  complete arc as a worked example of designing for agents:
  legibility (contracts + ADRs) before autonomy.

## How this repo is used

- **Producers** (e.g. `nccs-data-bmf`, `nccs-data-core`,
  `nccs-data-efile`) reference the relevant contract on publish and
  validate their output against it.
- **Consumers** (e.g. `nccsdata` R package, dashboard, API) reference
  the same contract on read and pin to a contract version.
- **Agents** (Copilot, scheduled jobs) read contracts to drift-check
  what's actually on S3 against what the contracts promise.

## Status

Contract surface populated with 38 ADRs. E-file Phase 0 is live; the
first Copilot coding-agent pilot has run on `nccs-data-bmf`. The
cross-repo **reporting cycle** (ADR 0038) is the coordination protocol
that runs today in Claude sessions, with `/reconcile-status` surfacing
reconcile lag. The deterministic drift-detection loops described in
`ARCHITECTURE.md` §9 are not yet wired — see that section's "Not yet
built" list and `docs/agentic-systems-design.md` for where the system
sits on the curve.
