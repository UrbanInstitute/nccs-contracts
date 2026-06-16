# 0033 — Deprecation-Window Policy + Critical-Bug Override

- **Status:** Accepted (effective 2026-06-16) — policy; takes effect immediately
- **Date:** 2026-06-16
- **Deciders:** sole maintainer
- **Related:** [[0001-s3-as-contract-surface]] (the deprecation policy this ADR makes explicit), [[0022-cross-repo-contract-change-guard]] (the mechanism a break runs through), [[0013-versioned-producer-outputs]], [[0014-standardize-manifest-shape]], [[0032-ntee-cleaner-university-code-loss]] (a motivating critical-correctness fix), [[0008-modernize-dataexplorer-api]]

## Context

The "default 90-day deprecation window for breaking changes" is one of
the most-cited rules in this repo — ~10 ADRs apply it (0005, 0008, 0010,
0013, 0014, 0023, 0027, 0032, …) — yet it has **no definitional home**.
[[0001-s3-as-contract-surface]] mentions a "deprecation policy" without
stating the window; the actual *90 days* lives only as a one-line house
rule in `CLAUDE.md` and a bullet in `ARCHITECTURE.md §8`. ADRs 0013/0014
attribute the default to ADR 0001, which doesn't actually state it. This
ADR gives the policy a single decision record so the cite is real.

It also closes a gap the policy has carried implicitly: the 90-day window
is a **floor on consumer-update time**, written for the common case
(renames, path moves, additive-then-remove migrations) where the old
behavior is *fine* and the only cost of delay is consumer churn. But some
breaks are not like that — the old behavior is itself **harmful**, and
keeping it live for 90 days *prolongs the harm*. [[0032-ntee-cleaner-university-code-loss]]
is the live example: the published `nteev2_subsector` misclassifies a
meaningful record slice; a 90-day dual-publish of the *wrong* values is
worse than a faster cutover, not safer. The policy needs an explicit
escape hatch so this judgment is made deliberately and recorded — not
made silently by ignoring the rule, and not blocked by a rule written for
a different case.

## Decision

**1. The default deprecation window is 90 days, defined here.** Any
breaking change to a contracted producer surface (a rename, a path move,
a removed/retyped column, or a **value change on a published column** that
consumers may have pinned behavior on) publishes the old and new behavior
in parallel for **90 days** by default, during which consumers migrate at
their own cadence. This is the existing rule; this ADR is its home.

**2. A programmer may override the window for a critical bug, at their
discretion.** When continuing to serve the old behavior causes **ongoing
harm** — a correctness defect that misclassifies or miscounts published
data, a data-corruption issue, or a security problem — the programmer
making the change may **shorten or waive** the 90-day window. The judgment
is theirs; this ADR does not require sign-off, a committee, or a fixed
threshold.

**3. The override is bounded by recording, not by permission.** Discretion
is not silence. When the window is overridden, the programmer must, in the
ADR that ships the change (the existing per-change ADR — no extra ADR is
required for the override itself):

- **State the harm.** Why the old behavior is bad enough that prolonging
  it outweighs the cost of a faster break — the evidence, not just the
  verdict (per the engineering principles: record the measurement).
- **State the chosen window.** Override means *compress*, not necessarily
  *zero*. Prefer the **shortest window that mitigates the harm** — often a
  brief notice-and-cutover rather than an instant break, unless the harm
  (e.g. active security exposure) justifies zero.
- **Still notify known consumers.** A shortened window does not remove the
  duty to tell pinned consumers the cutover is coming; it shortens how
  long they have, which is the point.

**4. The break still runs through the guard.** An overridden window does
not bypass [[0022-cross-repo-contract-change-guard]]. The change is still a
contract change: the guard fires, the contract YAML and `ARCHITECTURE.md`
are reconciled, and the per-change ADR records both the break and the
override.

## Why discretion, not a rule

A fixed exhaustive list of "what counts as critical" would be a proxy for
the real question — *is keeping the old behavior live doing more harm than
the break?* — and proxies drift from the thing they stand for. The
programmer holds the context (what the bug does, who is pinned, how bad a
fast cutover is) that no static threshold captures. The control is
therefore **transparency**, not gatekeeping: the override is always
allowed, and always recorded with its justification, so a later reader can
see *why* a window was compressed and judge whether it was right. A
recorded judgment that turns out wrong is fixable; a silent one is not.

## Consequences

- **The 90-day default now has a real definitional home.** Existing cites
  resolve here; `CLAUDE.md` and `ARCHITECTURE.md §8` point at this ADR.
- **Critical-correctness fixes are unblocked.** A maintainer no longer has
  to choose between "violate the house rule" and "serve known-wrong data
  for 90 days." [[0032-ntee-cleaner-university-code-loss]] may invoke this
  to cut over the corrected `nteev2_subsector` faster than 90 days; its
  Deprecation-window section should cite this ADR if it does.
- **Auditability over ceremony.** No new approval step; the cost of the
  override is writing down why. That keeps the escape hatch cheap to use
  honestly and expensive to abuse quietly.
- **The default is unchanged for the common case.** Non-harmful breaks
  (renames, path moves, additive migrations) keep the full 90 days; nothing
  about routine deprecations changes.

## Deprecation window

Not applicable — this ADR *defines* the policy; it deprecates nothing. It
is additive to the governance surface (a clarification of ADR 0001 plus the
override clause) and takes effect immediately.
