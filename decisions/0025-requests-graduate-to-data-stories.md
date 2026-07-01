# 0025 — Ad-hoc Requests Graduate to Public Data Stories

- **Status:** Reconciled (2026-07-01) — scaffold + first promotion both executed (`nccs` PR #89), which also exercised and closed Follow-up #2 (see Outcome for the reproducibility clarification it surfaced)
- **Date:** 2026-06-05
- **Deciders:** sole maintainer
- **Related:** [[0024-adhoc-data-requests-consumer-repo]] (refines it), [[0016-no-canonical-cross-dataset-merge]], [[0021-canonical-county-identity-via-fips-crosswalk]], [[0023-ct-planning-region-coordinate-resolution]]

## Context

[[0024-adhoc-data-requests-consumer-repo]] established `nccs-data-requests`
as a thin consumer that composes on-demand BMF × core × efile joins for
specific geographies, one folder per request, and that **publishes nothing
reusable** — explicitly not a producer, out of the drift loop.

Two facts make a public-facing extension natural:

1. **The NCCS website already has a working data-stories surface, on our
   exact stack.** The `nccs` repo (Jekyll) carries a `_stories` collection
   published to `/stories/:name/`. Stories are authored as **Quarto `.qmd`**
   with YAML front-matter (`title`, `date`, `description`, `featured`,
   `categories`, `author`, `citation`, `links`), rendered to gfm, built with
   `layout: story`. Existing stories already read via **R + `nccsdata`**
   (e.g. `nccsdata_geo`, `ceo-compensation`, `payroll`).

2. **That stack is identical to ADR 0024's tooling for the requests repo**
   (R + arrow, reusing `nccsdata`). A Quarto `.qmd` that reads via
   `nccsdata`, pins contract vintages, and renders charts is *simultaneously*
   the reproducible deliverable ADR 0024 already wants and a draft data
   story. The request folder **is** the draft story.

The opportunity: turn the request stream into public NCCS content. The risk
of doing it naively — "every request becomes a public story" — is twofold:
some requests are confidential (a specific funder's question) or one-off and
not generalizable, and full public stories carry real polish overhead. So
the question is not *whether* to publish stories, but *which* requests do.

## Decision

Make a public data story a **graduation path** for a request, not a mandate —
the same detector logic ADR 0024 already uses for data reuse, applied to
narrative reuse.

1. **Author every request as a reproducible Quarto `.qmd`.** This is the
   deliverable shape ADR 0024 asked for (pinned inputs + the query, runnable
   from the folder alone) and the draft-story shape the website expects —
   one artifact, not two. Most requests stop here, as private deliverables.

2. **Promote the generalizable, public-safe, interesting ones.** A request
   graduates to a public story when it clears three gates: **generalizable**
   (says something beyond the one requester's narrow ask), **public-safe**
   (only public IRS/derived data; no confidential request specifics), and
   **worth reading**. Promotion = the `.qmd` (+ its `_files/` assets) is
   PR'd into `nccs/_stories/`; the website renders and hosts it.

3. **The website is the consumer/host; the requests repo is still not an S3
   producer.** A story is human-facing *content*, not a machine data
   contract. `nccs-data-requests` publishes **no S3 data artifact**, gets no
   `contracts/*.yml`, and stays **out of the drift loop** — ADR 0024's
   non-producer framing holds unchanged. What ADR 0024 called "publishes
   nothing reusable" is sharpened here to "publishes no reusable *data
   artifact*"; a curated, human-facing story is an allowed output.

4. **Every story cites its pinned vintage.** The `.qmd` front-matter
   `citation:` block records the contract versions (hence artifact vintages)
   the analysis read. A public claim is reproducible from the cited pins —
   the provenance ADR 0024 requires, surfaced to the reader.

### The third graduation path

`nccs-data-requests` is a detector with three exits; a routine request takes
none of them and stays a private deliverable:

| When a request… | Graduates to |
|---|---|
| repeats a cross-dataset **join / geography** (2nd request) | a crosswalk or the API (ADR 0024) |
| reuses a **read helper** (2nd use) | `nccsdata` (ADR 0024) |
| is **generalizable + public-safe + worth reading** | a **data story** in `nccs/_stories/` (this ADR) |

## Invariants (enforced by the request template + promotion checklist)

- **Public-safe gate is explicit.** Each request folder records a yes/no
  public-safe determination; promotion is blocked until it is `yes`. Absence
  is not "safe" — an unanswered gate blocks (validate completeness
  positively).
- **Pinned-vintage citation is required** on any promoted `.qmd`; a story
  without a contract-version citation does not ship.
- **The story re-runs from the request's pins — in `nccs-data-requests`,
  not necessarily in place inside `nccs`.** The promoted `.qmd` reads the
  same pinned artifacts the private deliverable did — no separate,
  divergent re-query — but `nccs`'s Jekyll build never executes `.qmd`
  (it ships the pre-rendered `.md` + figures only), and the `.qmd`'s
  `source()` of `nccs-data-requests`-local read helpers is expected to
  only resolve from that repo. **The rendered `.md` is the portable,
  citable artifact; the `.qmd` is included for transparency and
  re-render-from-origin, not as a standalone-executable copy inside
  `nccs`.** This clarification was surfaced, not violated, by the
  Milwaukee promotion (see Outcome) — read-logic stays single-sourced in
  `nccs-data-requests` rather than duplicated or packaged into the
  content repo, keeping ADR 0025 §3's non-producer/no-coupling framing
  intact.

## Rejected alternatives

- **Every request → a public story by default.** Maximizes output but forces
  publication overhead on every request and risks publishing confidential or
  thin analyses. The three-gate graduation path captures the upside without
  the standing risk. Rejected.
- **Author stories separately in the website repo.** Splits the analysis
  from its narrative across two repos and duplicates the reads — the website
  `.qmd` would re-query what the request already pinned, inviting drift
  between the private deliverable and the public story. Rejected; the single
  `.qmd` travels from request folder to `_stories/`.
- **Make `nccs-data-requests` an S3 producer of "story data."** Over-models
  human-facing content as a machine contract, dragging it onto the drift
  loop and the producer pattern (ADR 0024 §3 obligations) for no consumer
  that reads it as data. Stories are content. Rejected.

## Consequences

- **The requests repo scaffold is Quarto-first.** Per-request folder built
  around a `.qmd` story template (front-matter + pinned-vintage citation +
  a public-safe gate), mirroring the website's gfm format so a promoted
  `.qmd` renders identically in `_stories/`.
- **A new consumer relationship: `nccs` website ← request stories.** It is a
  *content* inflow (PR into `_stories/`), not a data contract — so it is
  **not** added to any drift watch list (ARCHITECTURE §7, §9).
- **A public throughput for the request stream.** Ad-hoc work that would
  otherwise be invisible becomes NCCS content, on a surface that already
  exists and already runs CI (`nccs` `build.yml`).
- **ADR 0024 is refined, not reversed.** Its "thin consumer / not a
  producer / out of the drift loop" core is intact; only "publishes nothing"
  is sharpened to "publishes no reusable data artifact."

## Follow-up

1. **Scaffold `nccs-data-requests` Quarto-first** (R + arrow + `nccsdata`):
   `requests/<slug>/request.qmd` story template, a read helper that pins and
   logs contract versions, a promotion checklist (3 gates), and a `CLAUDE.md`
   so sessions in the repo carry the consumer role + graduation rules.
2. **Wire promotion to the website.** Document the `.qmd` → `nccs/_stories/`
   move (assets, front-matter mapping, the `build.yml` render path); decide
   whether promotion is a manual PR or an assisted copy.
3. **First real request** exercises the full path end to end and, if it
   clears the three gates, becomes the worked-example story.

## Outcome

Reconciled 2026-07-01 (a reconcile-lag sweep under ADR 0038 found the
Status line stale relative to the actual checklist state).

- Follow-up #1 (Quarto-first scaffold) — done: `requests/<slug>/` with
  `request.qmd`, `checklist.md`, `_pins.csv`, `_private.md` convention.
- Follow-up #3 (first real request) — the Milwaukee MSA request
  (`requests/2026-06-milwaukee-msa/checklist.md`) has cleared **all
  three promotion gates**: generalizable (yes), public-safe (yes),
  worth reading (yes), and its revenue completeness gate (1989-2023,
  Form 990/990-EZ/990-PF) is also checked off. **Not yet done**: add
  charts before promotion, pin the front-matter `citation:` from
  `_pins.csv`, remove `draft: true`, and actually move
  `request.qmd` (+ assets) into `nccs/_stories/` and open the PR — the
  checklist's own remaining unchecked items. This is genuinely the next
  concrete step, not blocked on anything.
- Follow-up #2 (wire promotion to the website — document the `.qmd` →
  `_stories/` move mechanically) — **exercised 2026-07-01** by the first
  promotion (`nccs` PR #89, `nccs-data-requests/requests/2026-06-milwaukee-msa/request.qmd`
  → `nccs/_stories/milwaukee-metro-nonprofits.qmd`). It surfaced exactly
  the gap this Follow-up existed to find: the promoted `.qmd`'s
  `source(here::here("R", "request_read.R"))` call is
  `nccs-data-requests`-local and won't resolve if the `.qmd` is
  re-rendered from inside `nccs`. Correctly not fixed unilaterally by the
  promoting session (out of the "move the file" scope) — surfaced back
  here instead. **Decided:** the Invariants section above is amended to
  clarify the rendered `.md` (not the `.qmd`) is the portable, standalone
  artifact; the `.qmd` re-renders from its origin repo, where the pins
  and helper actually live. No code changes to `nccs-data-requests` or
  `nccs` — this is a documentation clarification of what the invariant
  already effectively meant, not a new requirement. Follow-up #2 is now
  closed: the mechanics are proven out and documented.
