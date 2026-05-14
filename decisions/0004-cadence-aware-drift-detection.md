# 0004 — Cadence-Aware Drift Detection

- **Status:** Accepted
- **Date:** 2026-05-14
- **Deciders:** sole maintainer

## Context

Drift detection — verifying that what's on S3 matches what the
contracts promise, and that consumers' bundled references (e.g.
`nccsdata`'s bundled lookups) match upstream — is the single
highest-leverage agentic operation in the system.

Producers update on different cadences:

- BMF and lookups: monthly batches.
- Core 990: annual SOI release.
- E-file: continuous trickle, multiple times per week.
- Merged: derived; rebuilds whenever any input updates.

A single uniform trigger (e.g. "weekly cron") works fine for the
monthly batches but leaves a window of days where e-file drift
could go undetected.

## Decision

Drift detection trigger is **cadence-aware**:

- **Weekly cron** for monthly/annual batch producers (BMF, core,
  lookups).
- **Event-triggered** for continuous producers (e-file) and derived
  artifacts (merged). The producer's publish hook fires a contract
  validation; failure opens an issue that the Copilot agent picks up.

Both paths converge on the same outcome: an issue describing the
drift, a Copilot agent drafting a remediation PR, a human (sole
maintainer) reviewing and merging.

## Consequences

**Positive:**

- E-file drift is caught within minutes of publish, not days.
- Batch producers don't incur per-publish CI overhead they don't
  need.
- Copilot agent cost is bounded — runs only when there's actual
  drift to investigate, not on every cron tick that finds nothing.

**Negative:**

- Two trigger mechanisms to maintain (cron + event). Modest
  complexity; both are GitHub Actions workflows.
- Event-triggered detection depends on the producer remembering to
  fire the hook. Mitigated by making the hook part of the
  publish-time validation that producers run anyway (a producer
  that skips the hook also skips its own validation, which CI will
  catch).

## Alternatives Considered

- **Cron everywhere.** Rejected: leaves e-file drift undetected for
  up to a week.
- **Event everywhere.** Rejected: batch producers don't need the
  per-publish trigger overhead; monthly cron is sufficient.
- **No drift detection, rely on user reports.** Rejected: this is
  exactly the kind of silent-drift class that sole-maintainer
  workflows can't absorb.

## Revisit trigger

If consumer-side drift becomes the dominant source of bugs (vs.
producer-side), expand drift detection to include consumer bundled
state vs. live producer state on the same cadence-aware basis.
