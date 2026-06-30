# 0038 — Cross-Repo Coordination Protocol (the reporting cycle)

- **Status:** Accepted (2026-06-30) — protocol effective on merge of this PR; the procedural detail lives in `CONTRIBUTING.md`, the surfacing tool is the `/reconcile-status` command, ARCHITECTURE §9 Loop 3 points here. Self-reconciling: its "downstream" is this repo's own docs, landing in the same PR.
- **Date:** 2026-06-30
- **Deciders:** sole maintainer (DST)
- **Related:** [[0022-cross-repo-contract-change-guard]] (the deterministic floor this sits on — guard checks *acknowledgment*; this protocol governs the *decision flow* around it), [[0033-deprecation-window-policy-and-critical-bug-override]] (the window an escalated breaking change inherits), [[0001-s3-as-contract-surface]] (why coordination is needed at all — S3 is the only inter-repo contract, code coupling is avoided), and `CONTRIBUTING.md` (the three-phase loop this names and completes)

## Context

The system is a contract-surface repo (`nccs-contracts`) plus a constellation of
producer and consumer repos under `/root/NCCS/*`. There is no code coupling
between them by design ([[0001-s3-as-contract-surface]]); the only shared surface
is S3 and the ADR/contract spec in this repo. Work therefore crosses repo *and*
session boundaries constantly: a decision is made here, executed in a sibling
repo, and must come back here to keep the contracts honest.

`CONTRIBUTING.md` already documents the **three-phase loop** — plan here → execute
downstream → reconcile here — with ADR breadcrumbs in commits and a reconcile
checklist. `BACKLOG.md` already serves as the live command board. What is *not*
yet formalized, and is the documented source of the main coordination pain
(reconcile lag — ARCHITECTURE §9 Loop 3):

1. **No defined ADR Status state machine.** Statuses are freeform
   ("Accepted (committed) — implementation pending", "Accepted (executed …)").
   An ADR mid-execution is indistinguishable at a glance from a closed one, so
   open loops go invisible and reconcile lags silently.
2. **No escalation gate.** When a downstream session discovers, mid-execution, a
   choice that would change the contract's shape, there is no named rule that
   says *stop and route it back up* rather than decide locally. CONTRIBUTING's
   "load-bearing reversal → come back before the code lands" is the seed, but it
   reads as maintainer self-discipline, not a protocol with a flag.
3. **No up-channel shape.** Downstream work reports back ad hoc. There is no
   fixed sitrep the commander-side session can read to reconcile or escalate.

This ADR names the whole thing as one doctrine — the **reporting cycle** — and
fills those three gaps. It does *not* re-document the three-phase loop or the
reconcile checklist; those stay in `CONTRIBUTING.md` and this ADR references
them.

## Decision

Adopt an explicit coordination protocol with three roles, a Status state
machine, an escalation gate, and a fixed up-channel.

### 1. Roles

- **Commander** — a `nccs-contracts` session. Owns the ADR/contract surface:
  makes the decisions, drafts ADRs, reviews escalations for feasibility and
  appropriateness, and runs the reconcile close-out. Does **not** edit downstream
  producer code as the way of work; it issues orders (ADRs) and reconciles.
- **Executor** — a sibling-repo session (`nccs-data-bmf`, `nccs-data-core`, …)
  under the maintainer's direct steering. Implements an `Accepted` ADR, leaves
  ADR breadcrumbs, opens a PR, and reports up via the sitrep.
- **Courier** — the maintainer. Carries the **go-signal** down (authorizes
  `Proposed` → `Accepted`), steers execution, and carries **escalations** up. The
  two human-judgment moments — *authorize* and *assess-escalation* — are
  deliberately the courier's, never automated.

Git + `gh` is the durable substrate (ADRs on disk are readable from any sibling
session; PRs are readable via `gh` from the commander session). The courier
routes only the two judgment moments.

### 2. ADR Status state machine

Every ADR's `Status:` line **begins** with one canonical state (optionally
followed by a parenthetical/date/PR reference). The two middle states are open
loops — the thing `/reconcile-status` surfaces:

| State | Meaning | Loop |
|---|---|---|
| `Proposed` | Drafted here; decision made but not yet authorized for execution | not yet open |
| `Accepted` | Authorized; downstream execution may begin | **open** |
| `Executing` | Downstream implementation in flight (name the repo/PR) | **open** |
| `Reconciled` | Downstream landed **and** contracts/`ARCHITECTURE.md` updated to match | closed |
| `Amended (YYYY-MM-DD)` | Substance changed after feedback; says what changed | (re-opens) |
| `Superseded by [[adr]]` | Replaced; old ADR retained | closed |

`Reconciled` is the new terminal-success status. Historical ADRs reading
`Accepted (executed YYYY-MM-DD)` mean the same thing and are **grandfathered** —
not mass-rewritten. The canonical leading token is what makes the lag sweep
parseable; the parenthetical carries the human detail.

### 3. The escalation gate (downstream → commander)

One rule the executor follows: **if implementation forces a choice that changes
the contract's shape, a producer/consumer pattern, or contradicts the ADR's
Decision — stop. Do not decide it locally.** Flag it `needs-ADR-review` in the
sitrep. The decision routes back to a `nccs-contracts` session, where the
commander assesses feasibility/appropriateness and either **amends the ADR**
(→ `Amended`, re-authorize) or **holds**. Implementation-detail choices that
don't touch the contract surface, the executor just makes and records as a
breadcrumb — those reconcile silently. The gate fires on exactly the threshold
`CLAUDE.md` already uses for "requires a new ADR." This is CONTRIBUTING's
"load-bearing reversal" rule, given a name and a flag.

### 4. The sitrep up-channel (the fixed shape)

The downstream PR description **is** the sitrep, in this shape (canonical
template installed as `.github/PULL_REQUEST_TEMPLATE.md` in each repo):

```
## Sitrep — ADR NNNN
- Implements: ADR NNNN (<backlog item / step>)
- Diverged from ADR: none | <what + why>
- Needs ADR review: none | needs-ADR-review: <the contract-shape decision forced>
- Contract surfaces touched: <contracts/*.yml, conventions/*, ARCHITECTURE.md, or none>
```

The commander reads it with `gh pr view --repo UrbanInstitute/<repo>`. A
non-empty *Needs ADR review* is the escalation trigger; a non-empty *Contract
surfaces touched* is the reconcile work-list. No copy-paste courier step for the
report itself — `gh` is the channel.

### 5. Surfacing (Tier 1) and the enforcement roadmap

- **Now:** the `/reconcile-status` slash command (this repo's `.claude/commands/`)
  runs the lag sweep on demand — lists every ADR in `Accepted`/`Executing`,
  cross-references open/merged sibling-repo PRs via `gh`, reports the gaps. Run
  it at session boot alongside reading `BACKLOG.md`.
- **Later, conditional (do not build up front):** a downstream `Stop`/`PreToolUse`
  hook that fires the escalation gate when an executor edits a contracted-schema
  surface; a CI check that validates the ADR `Status` leading token is legal and
  that a PR touching `decisions/` updates it. These graduate the protocol from
  convention to machinery if the manual steps slip — consistent with the
  "enforced by machinery" bar, but only when warranted.

## Consequences

- **Open loops become visible.** Any ADR in `Accepted`/`Executing` is, by
  definition, unfinished work; the lag sweep can list them. Reconcile lag stops
  being silent.
- **Local drift on contract shape is structurally discouraged.** The escalation
  gate routes shape-changing decisions back to the ADR surface *before* they
  land, which is where [[0022-cross-repo-contract-change-guard]] expects the
  acknowledgment anyway.
- **Low ceremony.** The whole protocol is a Status token, a PR-description shape,
  one stop-and-escalate rule, and one command. No new tracking files beyond
  `BACKLOG.md`, no new directories, no automated couriering. If it grows past
  that, it is failing — the reconcile-lag pain is to be made visible, not
  abstracted into a framework.
- **The judgment loop stays human.** Authorize and assess-escalation are the
  courier's; the machinery only surfaces and (later) gates.

## Deprecation window

N/A — process/governance ADR; no published artifact changes shape.

## Follow-up

- `CONTRIBUTING.md`: adopt the canonical Status vocabulary, add the escalation
  gate + sitrep sections. (Done in this PR.)
- `BACKLOG.md`: note the command-board / open-loop convention. (Done in this PR.)
- `.github/PULL_REQUEST_TEMPLATE.md`: install the sitrep shape here; downstream
  repos install the same in their own sessions. (This repo: done in this PR.)
- `.claude/commands/reconcile-status.md`: the Tier-1 lag sweep. (Done in this PR.)
- README + ARCHITECTURE §9: reference this ADR. (Done in this PR.)
- Normalize live open-loop ADRs (0036, 0037) to the canonical Status tokens so
  the sweep has correct first data. (Done in this PR.)
- Tier-2 hook + CI check: deferred, conditional (see Decision §5).
