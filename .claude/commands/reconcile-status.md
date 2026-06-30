---
description: Sweep ADRs for open loops (Accepted/Executing) and cross-reference downstream PRs to surface reconcile lag
allowed-tools: Bash, Read, Grep
---

Run the **reconcile-lag sweep** defined by ADR 0038 (the coordination protocol).
The goal: make every open loop visible and flag the lag where downstream work has
landed but the contract surface here hasn't caught up. Surface only — never edit
ADRs or contracts; this is a read-only report the maintainer acts on.

## Steps

1. **Collect ADR statuses.** For every file in `decisions/*.md`, read the
   `Status:` line and take its **leading canonical token** (`Proposed`,
   `Accepted`, `Executing`, `Reconciled`, `Amended`, `Superseded`). Treat a
   historical `Accepted (executed …)` / `Accepted (partially executed …)` as
   `Reconciled` / partial. Anything else starting with `Accepted` or `Executing`
   is an **open loop**.

   ```
   grep -nH '^- \*\*Status:\*\*' decisions/*.md
   ```

2. **For each open-loop ADR**, find its downstream work. The executor leaves
   `ADR NNNN` breadcrumbs in commits and a sitrep in the PR body. Check the
   sibling producer/consumer repos on GitHub (org `UrbanInstitute`) — the ones
   plausibly named in the ADR's Follow-up / BACKLOG `[where]` tag. Useful repos:
   `nccs-data-bmf`, `nccs-data-core`, `nccs-data-efile`, `nccsdata`,
   `sector-in-brief`, `sector-in-brief-data`, `sector-in-brief-api`,
   `nccs-data-requests`, `nccs`.

   ```
   # open + recently-merged PRs that reference the ADR (adjust NNNN and repo)
   gh pr list --repo UrbanInstitute/<repo> --state all --search "ADR NNNN" \
     --json number,title,state,mergedAt,url --limit 20
   ```

   If `gh` is unavailable or unauthenticated, say so and fall back to a
   docs-only report (statuses + BACKLOG cross-reference), clearly flagged as
   not having checked live PR state — do not silently skip the PR check.

3. **Classify each open loop:**
   - **Order out, not started** — `Accepted`, no downstream PR found.
   - **In flight** — `Executing` (or `Accepted` with an open PR); link the PR.
   - **⚠ LAG** — downstream PR **merged**, ADR still `Accepted`/`Executing` here.
     This is the reconcile lag the sweep exists to catch. Name the merged PR and
     the contract surfaces its sitrep listed as touched.
   - **⚠ ESCALATION** — a sitrep carries `needs-ADR-review`. Surface the flagged
     decision; it is waiting on a commander call.

4. **Cross-check `BACKLOG.md`.** Reconcile the open loops against the command
   board — flag any open-loop ADR with no backlog item, or any backlog item
   marked executing whose ADR says otherwise.

## Output

A short board, most-urgent first (LAG and ESCALATION at top), e.g.:

```
RECONCILE STATUS — <date from `date` if needed>
⚠ LAG         ADR 0036  nccs-data-bmf#NN merged 3d ago → reconcile ntee-resolved-crosswalk.yml, conventions/ein-format.md
⚠ ESCALATION  ADR 00..  needs-ADR-review: <decision> (nccs-data-core#NN)
In flight     ADR 0037  nccs-data-bmf#NN open
Order out     ADR 00..  Accepted, no PR yet
```

End with the one or two highest-value next actions (which reconcile to run, which
escalation to rule on). Keep it tight — this runs at session boot.
