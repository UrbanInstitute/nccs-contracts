# 0022 — Cross-Repo Contract-Change Awareness (the contracts-guard + breadcrumb enforcement)

- **Status:** Accepted (mostly executed — guard live on every in-scope repo except `sector-in-brief-api`, deferred mid-rewrite; per-repo ruleset application still pending, BACKLOG #10) — see Migration plan and Outcome
- **Date:** 2026-06-04
- **Deciders:** sole maintainer
- **Related:** [[0001-s3-as-contract-surface]], [[0004-cadence-aware-drift-detection]], [[ARCHITECTURE.md]] §9 (Loop 3), `CONTRIBUTING.md` (three-phase loop)

## Context

`CONTRIBUTING.md` describes a three-phase loop: **plan here** (open/revise
an ADR) → **execute downstream** (change the sibling repo's code, leaving
`ADR NNNN` breadcrumbs) → **reconcile here** (update the ADR + contract
YAMLs). The loop breaks at the reconcile step. A decision gets made *in
code* in a producer/consumer repo, but the ADR / contract here doesn't get
updated in step — so the next repo ends up arbitrating between a stale ADR
and the actual code. The reconcile depends entirely on the author
remembering, and on someone later noticing.

This is a *propagation/sync* problem, not silent-S3-drift and not
pin-graph legibility. Two concrete proofs from this system, both 2026-06-04:

- **The audit** (`scripts/reconcile.sh`, introduced here) surfaced a real
  backlog of contract-relevant commits carrying **no `ADR` breadcrumb** —
  ~13 in `nccs-data-efile`, ~12 in `nccs-data-core`, several in
  `sector-in-brief-data`. Some are internal refactors with no contract
  impact; the point is nothing distinguished them at the time.
- **The API repo rename.** `nccs-data-api` → `sector-in-brief-api` was
  decided in GitHub and sat un-reconciled in `contracts/usage-api.yml` and
  ADR 0008 until caught by hand. Textbook reconcile lag.

`ARCHITECTURE.md` §9 **Loop 3** (contract-adjacent PR review — "did the
author forget to update the YAML/ADR?") was designed for exactly this. But
none of §9 is built, and the full Copilot/Opus agent stack is overkill —
and a recurring cost — for the part of Loop 3 that is purely mechanical:
*was the contract surface even acknowledged?* That part needs no judgment
and should be a deterministic check.

## Decision

Build the **deterministic floor of Loop 3** now, as zero-cost GitHub
Actions, and defer the semantic agent layer.

> **The guard verifies *acknowledgment*, not *correctness*.** A PR fails
> only if it changes the contract surface *without saying so* (no
> `ADR NNNN` breadcrumb and no `contracts-ack` label). It does **not** read
> the contract YAMLs and **cannot** tell whether a change actually
> *violates* a contract — a wrong-but-acknowledged change passes green.
> Judging whether the diff agrees with the ADR/contract is the deferred
> Loop-3 Copilot agent's job (§7). Don't over-trust the green check: it
> means "the contract surface was acknowledged," not "this change is
> contract-compliant."

1. **Enforce the breadcrumb convention; don't just document it.** Any PR in
   an in-scope repo that changes contract-relevant code (what or where the
   repo publishes, or the schema/manifest/dimension shape) must
   **acknowledge** the nccs-contracts impact, by one of:
   - an `ADR NNNN` breadcrumb in a commit message or the PR body
     (per `CONTRIBUTING.md` "Execute downstream"), or
   - a `contracts-ack` label (escape hatch for changes with genuinely no
     contract impact).
   The check **does not judge correctness** — only that the surface was
   acknowledged, so the reconcile can't be silently skipped.

2. **One reusable workflow, thin per-repo callers.** The guard logic lives
   **once** in this repo as a `workflow_call` reusable workflow at
   `.github/workflows/contracts-guard.yml`. Each in-scope repo adds a ~10-line
   caller that passes only its own `PATHS_REGEX`. Improving the guard is a
   single edit here; every caller inherits it. (Do **not** hand-copy the
   workflow into N repos — copies drift.)

3. **Scope = the contracts themselves.** The in-scope repos are exactly the
   distinct set named by `producer.repo` + `consumers[].repo` across
   `contracts/*.yml`. This is self-maintaining — it grows automatically when
   a contract names a new repo; there is no separate registry. Current set
   (updated 2026-06-05): `nccs-data-bmf`, `nccs-data-core`, `nccs-data-efile`,
   `nccsdata`, `sector-in-brief`, `sector-in-brief-data`,
   `sector-in-brief-api` (planned), `nccs` (live consumer of the geography
   crosswalks via the BMF data catalog; was the planned "nccs-website").

4. **Strong enforcement via an org ruleset — keyed on a property, not a
   repo list.** Per-repo callers are opt-in (a file each). To make
   enforcement non-optional, an **organization ruleset** can *require* the
   workflow — targeting repos by a **custom property `contract-surface=true`**
   (set on the in-scope repos), not an explicit list, so new in-scope repos
   are covered by setting the property. This needs **org-owner** rights; the
   maintainer is admin on `nccs-data-bmf`/`-core` but not org-owner, so it is
   a request to the org owner. Per-repo opt-in is the fallback that works
   without it.

   > **Amended 2026-06-12 — the org ruleset is not attainable.** Org-owner
   > access "does not seem like a possibility" (maintainer is repo-admin, not
   > org-owner, and that is not expected to change). The org-wide,
   > property-keyed ruleset above is therefore **superseded** by a **per-repo
   > ruleset** that requires the `contracts-guard / contracts-guard` status
   > check on the default branch — applied on each repo where the maintainer
   > *has* admin (`nccs-data-core`, `nccs-data-bmf` confirmed; verify the rest).
   > Repos the maintainer doesn't admin keep the guard **advisory** (it runs
   > via the caller but isn't required) until admin is obtained. The ruleset
   > carries **no bypass actors** — the guard's own escape hatch
   > (`contracts-ack` label or `ADR NNNN` breadcrumb) is the relief valve;
   > break-glass is temporarily setting the ruleset `enforcement` to
   > `disabled`. Artifacts: `scripts/contract-surface-ruleset.json` +
   > `scripts/apply-contract-surface-ruleset.sh` (dry-run by default).
   > Tradeoff vs. the property-keyed org ruleset: a new in-scope repo is **not**
   > auto-covered — applying the ruleset becomes an explicit step in the
   > "Adding a New Module" checklist (ARCHITECTURE §10), and the per-repo
   > ruleset *also* forces the PR flow on its targets (direct-to-main pushes
   > can no longer satisfy the required check), tightening a gap the original
   > plan left open.

5. **A companion audit helper** — `scripts/reconcile.sh` (this repo), the
   inverse of the guard. `reconcile.sh <ADR>` lists what was executed for a
   decision across siblings; bare `reconcile.sh` audits recent
   contract-relevant commits lacking a breadcrumb (candidate un-reconciled
   work). Read-only; no fetches. The guard nags at PR time; this finds what
   already slipped through.

6. **Discoverability for humans and coding agents.** Each in-scope repo's
   `CLAUDE.md` (+ README/CONTRIBUTING) carries a short pointer to this
   convention, so a contributor — or a Claude/Copilot agent working *in
   that repo* — is aware without reading the workflow. New repos inherit it
   via `ARCHITECTURE.md` §10 "Adding a New Module" (add the caller + the
   `contract-surface` property + the CLAUDE.md pointer).

7. **The semantic layer is a deliberate follow-on.** A Copilot agent that
   reads the diff against the relevant ADR/contract and judges whether they
   *agree* (Loop 3 proper) is valuable but Opus-priced. It comes later, in
   its own ADR, scoped tightly (path-filtered, only on guard-flagged PRs) to
   bound cost. This ADR ships the deterministic floor that makes that agent
   cheaper and better-targeted when it lands.

### Design details

- **Acknowledgment match:** `ADR[ -]?[0-9]{3,4}` (case-insensitive) in any
  commit message or the PR body; `contracts-ack` label bypasses.
- **`PATHS_REGEX` is per-repo** (the publish/config/manifest/schema code
  that defines what/where it publishes). Tuned examples already drafted:
  - `nccs-data-bmf`: `^(R/publish_.*\.R|R/run_.*\.R|R/master_.*\.R|R/config\.R|R/manifest\.R|scripts/build_.*\.R)$`
  - `sector-in-brief-data`: `^(R/publish\.R|R/config\.R|R/manifest\.R|R/build_.*\.R|R/data_dictionary_curation\.R|R/panel_.*\.R|R/read_.*\.R|config\.yml)$`
- **Caller pin:** `@main` initially — frictionless propagation, and the
  guard is simple enough that the blast radius of a bad edit is small;
  revisit to a moving tag (`@v1`) if the logic grows complex.
- **Always runs, passes when irrelevant** (relevance computed inside the
  job, no top-level `paths:` filter), so it is safe to mark "required."
- **Coupling note:** this introduces a **CI-time governance dependency** on
  `nccs-contracts` from every in-scope repo. That is intentional —
  `nccs-contracts` is the contract spine — and is distinct from the
  **runtime/data coupling the architecture forbids** (no code imports
  between siblings; data flows only via S3 per [[0001-s3-as-contract-surface]]).

## Rejected alternatives

- **Copy the workflow into each repo.** Rejected: N copies drift; a guard
  improvement becomes N edits. The reusable workflow keeps one source.
- **Org required-workflow as the *only* mechanism.** Rejected as sole
  approach: it needs org-owner (blocked today) and gives no in-repo
  discoverability for contributors/agents. Use it as belt-and-suspenders on
  top of the callers + CLAUDE.md pointers, not instead of them.
- **Jump straight to the Copilot Loop-3 agent.** Rejected as the first
  step: Opus cost on a still-churning surface, and you cannot see what it
  *should* catch until the deterministic guard has run. Floor first, agent
  after.
- **Keep it documentation/checklist only (status quo).** Rejected: that is
  what we have, and it leaks — the audit backlog and the API rename are the
  evidence. Enforcement makes forgetting loud.

## Consequences

**Positive:**
- Forgetting to reconcile becomes a red check, not a silent gap.
- One source of truth for the guard logic; behavior is consistent across
  repos and improves everywhere at once.
- Scope is derived from the contracts — no separate registry to maintain.
- The convention is discoverable by humans *and* agents (CLAUDE.md), and
  inherited by new repos via the §10 checklist.

**Negative / accepted tradeoffs:**
- A CI-time dependency on `nccs-contracts` from every in-scope repo
  (governance coupling — accepted; see Design details).
- Only catches changes that go through a PR; direct-to-main pushes bypass it
  (a nudge toward the PR flow).
- The guard checks *acknowledgment, not correctness* — a wrong-but-acknowledged
  change still passes. Closing that gap is the follow-on semantic agent.
- The `contracts-ack` escape hatch can be over-used; accepted as cheaper
  than the friction of false positives.

## Deprecation window

Not applicable — additive tooling; nothing on S3 or in any contract shape
changes.

## Migration plan

1. **Land this ADR + `scripts/reconcile.sh` + the reusable
   `.github/workflows/contracts-guard.yml`** in this repo.
2. **Convert the two drafted standalone guards** (`nccs-data-bmf`,
   `sector-in-brief-data`) into thin callers of the reusable workflow.
3. **Add callers** to the rest of the in-scope set, with a tuned
   `PATHS_REGEX` each.
4. ~~Set the `contract-surface=true` custom property on the in-scope repos and
   ask the org owner to add the requiring ruleset.~~ **Superseded 2026-06-12
   (org-owner not attainable):** apply a **per-repo ruleset** requiring the
   `contracts-guard / contracts-guard` check on the default branch of each
   repo the maintainer admins, via `scripts/apply-contract-surface-ruleset.sh`.
5. **Add `CLAUDE.md` pointers** per repo; update `ARCHITECTURE.md` §9 (this
   is the deterministic floor of Loop 3) and §10 (onboarding step).
6. **Follow-on:** the Copilot Loop-3 semantic agent, in its own ADR,
   cost-bounded.

## Outcome

*(reconcile-time; partially started 2026-06-04, continued 2026-06-05)*

- **Done (2026-06-04):** the API-repo rename reconciled in this same change
  (`contracts/usage-api.yml` + ADR 0008 finalized-name note) — folded in as
  the motivating example. `scripts/reconcile.sh` written and verified in
  both modes. Standalone guard workflows drafted in `nccs-data-bmf` and
  `sector-in-brief-data`.
- **Done (2026-06-05):** Migration **step 1 completed** — the reusable
  `workflow_call` guard now lives in this repo at
  `.github/workflows/contracts-guard.yml`, taking a single `paths_regex`
  input. It was extracted from the two standalone drafts, which differed
  only in `PATHS_REGEX` (and a few words of the error string), confirming the
  "one workflow, thin callers" design. The standalone drafts in
  `nccs-data-bmf` / `sector-in-brief-data` are now redundant and are to be
  replaced by thin callers (Migration step 2).
- **Done (2026-06-05):** Migration **step 2 completed** — `nccs-data-bmf`
  (PR #20) and `sector-in-brief-data` (PR #3) now carry thin callers of the
  reusable workflow; their uncommitted standalone drafts are superseded. The
  cross-repo call was verified live (the guard ran as
  `contracts-guard / contracts-guard` and passed on both PRs, whose only
  change was the workflow file — an irrelevant path), and the fail path was
  verified against controlled inputs (a contract-relevant change with no
  breadcrumb and no `contracts-ack` label exits non-zero; a breadcrumb or the
  label flips it to pass).
- **Done (2026-06-09):** Migration **step 3 completed** — thin callers merged
  across the remaining in-scope repos: `nccs-data-core` (PR #8),
  `nccs-data-efile` (PR #10 — which also added that repo's first `CLAUDE.md`),
  `nccsdata` (PR #21), `sector-in-brief` (PR #56), and `nccs` (PR #86). Each
  carries a `PATHS_REGEX` tuned to its surface — publish/config/parquet for the
  producers (`core`), publish/manifest/dictionary/value-gate for `efile`, and
  the read/pin/url/catalog surface for the consumers (`nccsdata`,
  `sector-in-brief`, `nccs`). CLAUDE.md guard pointers landed in the same PRs.
  With `nccs-data-bmf` + `sector-in-brief-data` (step 2), **every in-scope repo
  now carries the guard except `sector-in-brief-api`**, deferred until its
  rewrite settles (its publish/config layout is a moving target mid-build per
  [[0008-modernize-dataexplorer-api]]).
  ARCHITECTURE §9 (Loop 3) and §10 updated in this same change.
- **Done (2026-06-12):** Migration **step 4 re-scoped** — the org-wide
  property-keyed ruleset is abandoned (org-owner not attainable) in favour of a
  per-repo ruleset (see Decision §4 amendment). Shipped the reusable artifacts:
  `scripts/contract-surface-ruleset.json` (requires the `contracts-guard /
  contracts-guard` check on `~DEFAULT_BRANCH`, no bypass actors) and
  `scripts/apply-contract-surface-ruleset.sh` (dry-run by default; skips repos
  where the maintainer lacks admin or that lack the guard caller, so a required
  check can never strand a repo). **Not yet applied to any repo** — run with
  `--apply` against `nccs-data-core` / `nccs-data-bmf` to enforce.
- **Pending:** *apply* the per-repo ruleset on the admin'd repos (artifact
  ready, above); the `sector-in-brief-api` caller (deferred, mid-rewrite);
  admin-verify + roll the ruleset to the remaining in-scope repos; the
  follow-on Loop-3 semantic-agent ADR (step 6 / Follow-up 4); and tuning
  `paths_regex_for()` in `scripts/reconcile.sh` for
  `nccs-data-core`/`nccs-data-efile` (Follow-up 5).

## Follow-up

1. **Done 2026-06-09** — converted drafts → callers and rolled out to the full
   in-scope set (except the deferred `sector-in-brief-api`).
2. ~~Org ruleset on `contract-surface=true` (org-owner request).~~
   **Superseded 2026-06-12** by the per-repo ruleset (Decision §4 amendment,
   Outcome). Remaining work is to *apply* it on the admin'd repos and verify
   admin on the rest. The org-owner path is closed, not pending.
3. **Done 2026-06-09** — CLAUDE.md guard pointers added; ARCHITECTURE §9/§10 updated.
4. Open the follow-on ADR for the Copilot Loop-3 semantic agent.
5. Tune `paths_regex_for()` in `scripts/reconcile.sh` for `nccs-data-core`
   and `nccs-data-efile` (currently the generic default) so their audits
   are precise.
