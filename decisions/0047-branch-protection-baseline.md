# 0047 — Org-wide branch-protection baseline (require PRs, review, green checks)

Status: Proposed
Date: 2026-08-11
Relates: 0022 (contract-change guard; step-4 ruleset tooling), BACKLOG item 10

## Context

Every core repo today allows direct pushes to the default branch by any
collaborator with write access. The contract-surface ruleset (ADR 0022
step 4, `scripts/apply-contract-surface-ruleset.sh`) exists but was
never applied, and it governs only the contracts-guard check, not
review. Meanwhile the collaborator base is no longer maintainer-only:
external collaborators hold write on `nccs-data-bmf`, `nccs-data-core`,
and `nccsdata`, and admin on `nccs` (where the maintainer is NOT
admin). Nothing in current settings prevents an unreviewed change from
landing on any publish surface.

This is a **uniform policy decision, not a judgment about any
individual**: the same rules apply to every collaborator on every
in-scope repo, and the maintainer's own work moves to PR flow on the
guarded repos too.

## Decision

Apply a per-repo ruleset (`branch-protection-baseline`) to the default
branch of every in-scope repo where the maintainer holds admin:

1. **Pull requests required** — no direct pushes to the default branch.
2. **One approving review required**, with **repository admins as
   bypass actors**. Rationale: the maintainer is the only reviewer in
   practice; without a bypass, single-maintainer repos deadlock (an
   author cannot approve their own PR). The bypass is role-based
   (admin), not user-based.
3. **Required status checks**: `contracts-guard / contracts-guard` on
   repos that carry the guard caller (unchanged from ADR 0022 step 4;
   the guard's own `ADR NNNN` / `contracts-ack` relief valve stands).
   Repos without CI get rules 1-2 only until CI exists.
4. **Block force pushes and deletions** on the default branch.

In-scope now (maintainer admin confirmed 2026-08-11): `nccs-data-bmf`,
`nccs-data-core`, `nccs-data-efile`, `nccs-contracts`, `nccsdata`,
`sector-in-brief-data`, `sector-in-brief-api`.

Out of scope for self-service: `nccs` (maintainer lacks admin; the
external collaborator holds it). Adoption there goes through the org
owner or the repo admin applying the same ruleset — ask, not impose.

## Approver policy (the BACKLOG item-10 open call)

**Decided: "self" policy.** The maintainer reviews all non-maintainer
PRs; maintainer PRs merge under admin bypass. Revisit to "self + DST"
(second reviewer) if/when a second regular committer exists — the
ruleset change is one field.

## Consequences

- No unreviewed external change can reach a publish surface or the
  contract spine. The reporting-cycle (ADR 0038) review step becomes
  machine-enforced instead of conventional.
- Maintainer workflow on guarded repos becomes PR-first even for solo
  work (bypass covers emergencies; norm is PRs, as already practiced).
- Break-glass: set the ruleset `enforcement` to `disabled` on the
  affected repo; record why in the next reconcile.
- The `nccs` admin asymmetry is surfaced as its own follow-up rather
  than silently persisting.

## Execution

`scripts/apply-branch-protection-baseline.sh` (dry-run by default,
`--apply` to enforce). Rollout order: producer repos first
(`nccs-data-bmf`, `nccs-data-core`), then the spine and consumers.
Reconcile on the BACKLOG (item 10) with the applied-repo list.
