# 0040 — Promote core-panel to Parquet-Canonical (extends ADR 0027)

- **Status:** Accepted (2026-07-01) — formalizes an already-live producer reality; see Outcome
- **Date:** 2026-07-01
- **Deciders:** sole maintainer
- **Related:** [[0027-core-990-parquet-promotion]] (the same decision for `core-990`, extended here to `core-panel`), [[core-panel]], [[0016-no-canonical-cross-dataset-merge]], [[0001-s3-as-contract-surface]]

## Context

While closing out BACKLOG C1 (confirm `core-panel` consumers migrated to
parquet before the ADR 0027 90-day window), the underlying premise turned
out to be checking the wrong artifact for one input and an undocumented
gap for the other:

- `nccs-data-core`'s `run_build_panel.R` (which produces `core-panel`)
  does **not** read the published `core-990` CSV/parquet artifact at all
  — it builds directly from local intermediate harmonized output within
  the same pipeline run. There is no CSV-vs-parquet migration question
  for that step.
- `core-panel` **itself** is dual-published as parquet — verified
  directly on S3 (`processed_merged/core/2015/990pf/core_2015_990pf.parquet`,
  dated 2026-05-20, alongside the CSV) — because `run_build_panel.R`
  sources the same `R/09_parquet.R` module `core-990` uses. This was
  never decided or documented; `contracts/core-panel.yml` still says
  `format: csv` with no mention of parquet.
- All three named consumers already read parquet exclusively:
  `sector-in-brief-data` (`R/read_core.R::core_pf_paths` builds only
  `.parquet` URIs) and `sector-in-brief-api` (`query/query.py:121`,
  `core_{y}_{f}.parquet`). No consumer in the contract's list reads the
  CSV mirror.

This is the same shape ADR 0027 found for `core-990`: a parquet artifact
already serving real consumers, with the contract not yet reflecting it.

## Decision

Promote `core-panel`'s parquet form to **service-tier-canonical**, same
as `core-990` under ADR 0027:

- `contracts/core-panel.yml`'s `format:` becomes `parquet` (was `csv`);
  the CSV mirror is retained as `csv_mirror_template` for the standard
  90-day deprecation window.
- No producer change needed — the parquet has been live since at least
  2026-05-20, before this decision. This ADR **formalizes existing
  practice**, it does not request new work.
- Same caveat as `core-990`: cross-vintage type stability is not
  asserted until `nccs-data-core` PR #9's route-A fix (pinned schema per
  form family) is actually applied to a republish — per ADR 0027's
  Outcome, that fix is code-complete but not yet live (every
  `processed/core/**` and `processed_merged/core/**` parquet is still
  dated 2026-05-20, before the fix merged 2026-06-09). `core-panel`
  readers should use `union_by_name=true` for multi-year reads until
  the next rebuild, exactly like `core-990`.

## Consequences

- **No consumer break.** Every real consumer was already reading
  parquet; this only makes the contract match reality.
- **CSV mirror retained** for the standard window even though no known
  consumer uses it — same conservative default as ADR 0027, in case an
  unlisted reader exists.
- **Closes BACKLOG C1** with no repo work required — the investigation
  that was supposed to confirm a migration found there was nothing left
  to migrate, and a different, smaller gap (the contract's own
  `format:` field) to fix instead.

## Deprecation window

90 days from this decision (2026-07-01) for the CSV mirror, same policy
as ADR 0027 ([[0033-deprecation-window-policy-and-critical-bug-override]]).

## Outcome

Executed in this same change: `contracts/core-panel.yml` updated
(`format: parquet`, `csv_mirror_template` added, consumer notes
corrected to describe the already-parquet reads). No producer or
consumer repo changes needed.
