# AGENTS.md — nccs-contracts

Tool-neutral operating guidance for any coding agent (Codex, Claude Code, or
other) working in this repository. `CLAUDE.md` adds Claude-specific notes
only; this file is the shared truth.

## Repository role

The contract-surface repo and spine of the NCCS multi-repo data system. It
has no runtime. It holds:

- `contracts/*.yml` — authoritative description of what each producer
  publishes to `s3://nccsdata` (paths, columns, manifests, consumers).
- `decisions/NNNN-*.md` — ADRs. Every load-bearing call lives here.
- `governance/` — data-governance committee: charter, minutes, release
  notes, pending decisions. Release notes are authored ONLY here.
- `BACKLOG.md` — the maintainer's prioritized command board (ADR 0038).
- `ARCHITECTURE.md`, `CONTRIBUTING.md`, `conventions/`.

Sibling repos live under `../` (or in a worktree elsewhere). S3 is the only
inter-repo contract surface; code dependencies between siblings are avoided.

## Read before changing anything

1. `BACKLOG.md` — find or add the row for the task.
2. `CONTRIBUTING.md` — the three-phase loop (decide here, execute
   downstream, reconcile here) and the ADR Status state machine.
3. The ADR(s) the task names, plus any it `Relates:` to.
4. The `contracts/*.yml` the task touches. `contracts/_template.yml` is the shape.

## Change routing

- Any change to a contract's shape, a producer/consumer pattern, or a
  load-bearing technology choice needs a new ADR. Resolve the next number
  from `ls decisions/` immediately before creating the file; never from
  memory.
- ADR `Status:` begins with one token: `Proposed` -> `Accepted` ->
  `Executing` -> `Reconciled (YYYY-MM-DD)`. Only the maintainer flips
  `Proposed` to `Accepted`.
- Downstream repos must not decide contract shapes locally; they route
  back here (`needs-ADR-review`).
- Breaking changes default to a 90-day deprecation window (ADR 0033);
  the critical-bug waiver must be recorded in the ADR with the harm.
- PRs touching publish/read surfaces in sibling repos carry an `ADR NNNN`
  breadcrumb for the contracts-guard CI (ADR 0022).

## Commands

There is nothing to build or test. Useful checks:

```bash
ls decisions | tail -1            # next ADR number
git diff --stat origin/main...HEAD
```

## Evidence discipline

Label claims in ADRs, reviews, and reports as one of: verified, inferred,
remembered, unverified, contradicted, dependent on another agent's report.
State the verification level of any data check: code-only, local artifact,
or live S3 object (name the object). Never fold an unperformed live check
into "done".

## Production safety

- AWS: profile `thiya`, read-only by default. Publishing, touching
  `latest/`, deleting, or changing bucket policy requires a distinct
  instruction naming bucket, prefix, vintage, and expected file set.
- Merge-ready and publish-ready are separate gates.

## Completion criteria for a task that starts here

ADR written with reviewer-reproducible acceptance criteria; BACKLOG row
added or updated; contract YAMLs reconciled after downstream ships; ADR
Outcome section filled and Status flipped; release note drafted in
`governance/release-notes/` when a published artifact changed.
