# 0012 — Sector-In-Brief Dashboard Architecture Refactor

- **Status:** Accepted (planning; deferred indefinitely until a forcing function arises)
- **Date:** 2026-05-15
- **Deciders:** sole maintainer

## Context

The sector-in-brief dashboard codebase is over-fragmented relative
to its scope. 2026-05-15 recon found:

- **89 R files, ~3,900 LOC** for a 4-tab Shiny app.
- **One-function-per-file convention** applied even where the
  function is trivial:
  - 7 `caption_*.R` files (one per metric).
  - 7 `table_builder_*.R` files (one per table type).
  - 5 `urbn_*.R` files wrapping `shinyWidgets` for Urban styling.
  - Many small `plot_*.R`, `render_*.R`, `text_*.R` files.
- **Tribble-based dispatch** (`visualpanel_args`,
  `data_server_args`) is clever but opaque: adding a panel
  requires touching multiple tribbles plus several builder files,
  with no compile-time check that everything lines up.
- **`tests/` directory exists** but contains old shinytest
  recordings from late 2024; no maintained test suite.
- **No documented module boundaries.** Finding the code that
  renders a specific chart requires grep-archaeology across
  ~10 files.

None of these are runtime bugs. They are **maintenance taxes** —
every change pays them. The cost compounds with each new tab,
metric, or filter.

This ADR is deliberately the lowest-priority dashboard work. ADR
0009 (hygiene) and ADR 0011 (data decoupling) deliver more value
per unit of effort and ship sooner. The refactor here only earns
its keep when:

- Someone is about to add a meaningful new feature (new tab,
  significantly different filter, new domain like efile data)
  and the existing structure makes it painful, OR
- A second engineer joins and bounces off the structure, OR
- Onboarding cost for new contributors becomes a recurring drag.

Without one of those forcing functions, the refactor is yak-shaving.

## Decision

When (and only when) a forcing function arises, execute a
structured refactor in three layers:

### Layer 1 — Consolidate trivial files

Group small, single-responsibility files by domain:

- `caption_*.R` (7 files) → single `R/captions.R` with a dispatch
  function `caption(metric)`.
- `table_builder_*.R` (7 files) → single `R/table_builders.R`
  with a dispatch function `build_table(type, ...)`.
- `text_*.R` (4 files) → single `R/texts.R` of static HTML
  components.
- `urbn_*.R` (5 files) → single `R/urban_widgets.R` (Urban styled
  shinyWidgets wrappers).

Target: 89 files → ~25–30 files. No behavior changes.

### Layer 2 — Replace tribble dispatch with a registry pattern

Today: panel definitions split across `visualpanel_args`,
`data_server_args`, builder files, and inline server code.
Adding a panel touches all of them, with no errors if the names
diverge.

Replacement: a single panel registry, where each panel is one
object with all metadata (data source, server logic, plot config,
captions, validation rules). Adding a panel means writing one
object; the dispatch is mechanical.

Likely R idiom: a list of S4/R6 objects or named lists, validated
on app startup against a schema.

### Layer 3 — Test infrastructure

Add `shinytest2` (or maintained shinytest) test suite covering:

- Each panel loads without error on the default selection.
- Each filter combination renders a non-empty plot/table.
- The download path produces a valid CSV.
- Snapshot tests for the rendered HTML of a representative panel.

Target: ~70% line coverage on the server logic, ~100% on the
filter validation.

### Documentation

Concurrent with the refactor:

- `ARCHITECTURE.md` in the dashboard repo describing module
  boundaries, data flow, and the panel registry.
- Diagrams (Mermaid or similar) for the server pipeline.

## Consequences

**Positive (when executed):**

- Adding a new panel becomes a 1-file task instead of a
  4-tribble-plus-3-builder task.
- Onboarding new contributors gets a real ARCHITECTURE doc and a
  test suite that demonstrates expected behavior.
- Maintenance changes have automated regression coverage.
- File count drops by ~65%, easier to navigate.

**Negative:**

- Real engineering investment (estimated 3–4 weeks for one engineer
  including tests).
- Refactor risk: large no-behavior-change PRs are error-prone;
  needs careful test coverage before and after.
- Deferred indefinitely means it might never happen — that's
  acceptable if the forcing functions don't arise.

## Deprecation window

Not applicable; internal refactor with no external surface
changes.

## Follow-up

This ADR exists primarily as a **future-trigger**: when one of the
forcing functions (above) arises, this ADR is the starting point
rather than a from-scratch discussion. If the forcing function
never arises, the ADR documents the deliberate decision not to
invest, which is itself useful — it prevents future-you (or a new
team member) from reflexively launching the refactor without a
reason.

Reopen and re-evaluate this ADR when:

- A new dashboard tab or domain is on the roadmap.
- A second engineer is onboarding and complains about the structure.
- The `nccs-data-api` rewrite (ADR 0008) ships and someone wants
  to materially change the download tab.
