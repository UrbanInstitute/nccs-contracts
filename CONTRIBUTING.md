# Contributing to nccs-contracts

This repo is the contract surface for the NCCS data system. It has
no runtime; its outputs are YAML contracts, ADRs, and an
architecture description that producers, consumers, and (eventually)
Copilot agents all read. Changes here ripple outward — the workflow
below exists to keep the ripple legible.

If you are adding a *new* producer or consumer module, follow
`ARCHITECTURE.md` §10 ("Adding a New Module"). This document covers
everything else: modifying an existing module, executing an ADR that
was already accepted, reconciling downstream work back into the
contracts, and writing or revising ADRs mid-flight.

## The three-phase loop

Most non-trivial work follows the same shape.

### 1. Plan here

Open or revise an ADR in `decisions/` that captures the decision and
the alternatives. The ADR's Decision section is the spec you will
execute against later.

- Status starts as `Accepted (planning; not yet executed)`.
- Link related ADRs with `[[adr-slug]]`.
- If a contract YAML in `contracts/` will change shape, note that in
  the Follow-up section so reconcile-time you remember which file to
  touch.

You do not need a full implementation plan in the ADR — you need
enough that a future maintainer (including future-you) understands
*what* was decided and *why* the alternatives were rejected.

### 2. Execute downstream

Make the actual code changes in the relevant sibling repo
(`sector-in-brief`, `nccs-data-bmf`, etc., co-located alongside
this repo at `/root/NCCS/*`). The ADR is your reference; you do
not update it during execution.

**Leave ADR breadcrumbs in commit messages.** Format:

    ADR 0010 step 4 — port number_nonprofits panel

Or in the commit body:

    Implements ADR 0011 §1 (auto-refresh-at-startup pattern,
    amended from original "remove parquet" plan — see commit body
    for rationale).

The breadcrumb is what makes reconcile cheap. Without it, the
reconcile step in phase 3 is a full repo scan; with it, a
`git log --grep "ADR 0010"` produces the exact list of decisions you
acted on.

### 3. Reconcile here

Once the downstream work has settled, return to a `nccs-contracts`
session. All NCCS repos are peers under `/root/NCCS/*`, so a
session opened in this repo can read the sibling repos directly
without changing directories. Then:

1. **Flip the ADR Status** to one of:
   - `Accepted (executed YYYY-MM-DD)` — everything in the Decision
     section shipped as written.
   - `Accepted (partially executed YYYY-MM-DD) — see Outcome` —
     some shipped, some pending or diverged.
2. **Add an Outcome section** to the ADR. Two subsections:
   *Shipped* (what landed), *Diverged or pending* (what didn't, and
   why). The Outcome is what makes the ADR honest after the fact —
   it preserves the gap between plan and reality so future readers
   don't have to reverse-engineer it.
3. **Amend the Decision section** only when the divergence is
   *deliberate* and represents the new intended state. If the change
   is "we tried X, ran into Y, settled on Z," amend §X to describe
   Z; the Outcome records why. (Example: ADR 0011 §1 was rewritten
   when auto-refresh-at-startup replaced the original "remove
   committed parquet" plan.)
4. **Update the contract YAMLs** in `contracts/` that the change
   touched. Pin to current real-world state, even if it's interim
   (e.g. a sandbox S3 prefix). Mark interim values clearly with an
   `INTERIM` comment and a description of what flips at cutover.
5. **Update `ARCHITECTURE.md`** if the change altered the system map,
   producer/consumer pattern, or current-state description. The ADR
   preserves the *why*; `ARCHITECTURE.md` describes the *now*.

### When to reconcile

- *After each ADR fully ships* if the surface is small.
- *Mid-flight* when something diverges materially. If you make a
  downstream commit that contradicts the active ADR, open a
  `nccs-contracts` session in the same beat and amend the ADR. A
  five-minute interruption now prevents a plan-vs-reality drift
  cleanup later.

## Mid-flight ideas: amend, new ADR, or supersede?

When an idea hits while you're working downstream, classify it
before deciding where it goes.

**Tactical refinement.** The *decision* still stands; you're tweaking
*how* you execute it.

- *Example:* ADR 0011 originally specified removing committed
  parquet; execution kept the parquet as a cache seed and
  auto-refreshed on boot. Same goal (decouple from manual sync),
  different mechanism.
- *What to do:* note in the commit message, reconcile back when the
  work settles (amend Decision + record divergence in Outcome). No
  new ADR.

**New decision the ADR didn't anticipate.** Orthogonal to existing
ADRs, not a contradiction.

- *Example:* mid-execution, decide the CBSA crosswalk should be its
  own contracted lookup (ADR 0010 explicitly punted this).
- *What to do:* write a new ADR. Doesn't have to be before the code
  lands, but before the *next* thing depends on the decision.
  Cross-link from the relevant existing ADR's Follow-up section.

**Load-bearing reversal.** The idea contradicts what an ADR decided,
changes the contract surface, or invalidates a producer/consumer
pattern.

- *Example:* sector-in-brief-data publishing DuckDB files instead of
  parquet; dashboard reverting to API reads.
- *What to do:* come back here *before* the code lands. Either amend
  the existing ADR with a revision date (like ADR 0009's
  "recon corrected 2026-05-18") or supersede it with a new ADR
  (like the 2026-05-19 revision of ADR 0010 superseded its own
  earlier draft). CLAUDE.md's rule applies: contract-shape changes
  need an ADR before the code, not after.

**Litmus test.** If a future maintainer reading only the ADR would
be *surprised* by what's in the code, you owed the ADR an update.

## ADR conventions

- **Filename:** `NNNN-kebab-case-title.md`, with `NNNN` zero-padded
  to four digits and monotonically increasing.
- **Frontmatter fields:** Status, Date, Deciders, optional Supersedes
  / Superseded-by / Related.
- **Sections in order:** Context, Decision, (Migration plan if
  multi-step), Outcome (added at reconcile time), Consequences,
  Deprecation window, Follow-up.
- **Supersession:** when a new ADR replaces an old one, set the old
  one's Status to `Superseded by [link](path.md) (YYYY-MM-DD
  rationale)` rather than deleting it. History is the why.
- **Linking:** use `[[adr-slug]]` for ADR-to-ADR references; the
  slug is the filename without the number prefix and extension.

## Contract YAML conventions

- Every contract follows the shape in `contracts/_template.yml`.
- Required fields stay required even when value is `TODO` — keep the
  key visible so it can't be silently forgotten.
- Mark interim values with an `INTERIM` comment and describe what
  flips when the interim state ends. Example pattern in
  `contracts/sector-in-brief.yml`.
- Cross-reference other contracts with `[[contract-name]]` in
  `notes` fields.

## What requires an ADR

Per `CLAUDE.md`: any change that alters a contract's shape, a
producer/consumer pattern, or a load-bearing technology choice.

Concretely:

- New producer or new contract → ADR required.
- Existing contract's schema, S3 path, or cadence changes → ADR
  required.
- New consumer of an existing contract → contract YAML update;
  ADR optional (open one if the consumer changes how the contract
  is used).
- Internal-to-a-producer refactor that doesn't affect S3 output →
  no ADR; commit in the producer repo.
- Typo fixes, README polish, comment cleanup → no ADR.

## Deprecation window

Default is 90 days for breaking changes — old artifact stays
readable (often via the archive bucket) for 90 days after the new
one ships. Document the window in the ADR's Deprecation window
section. Shorter windows are allowed if no live consumer exists;
say so explicitly.

## A quick checklist for the reconcile step

When closing the loop on an executed ADR, walk this:

- [ ] ADR Status flipped (executed / partially executed / superseded)
- [ ] Outcome section added (Shipped / Diverged or pending)
- [ ] Decision section amended if intentional divergence
- [ ] Contract YAMLs in `contracts/` updated against real state
- [ ] `INTERIM` markers added if state is transitional
- [ ] `ARCHITECTURE.md` updated if system map / current-state shifted
- [ ] Downstream commits carry `ADR NNNN` breadcrumbs (verify with
      `git log --grep "ADR NNNN" -C /root/NCCS/<repo>`)
- [ ] Stale Follow-up bullets in the ADR removed or marked done
