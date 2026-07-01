# 0024 — Ad-hoc Data Requests as a Thin Consumer Repo

- **Status:** Reconciled (2026-07-01) — repo stood up 2026-06-05, first request shipped same day (Milwaukee MSA, CBSA 33340). See Outcome.
- **Date:** 2026-06-05
- **Deciders:** sole maintainer
- **Related:** [[0016-no-canonical-cross-dataset-merge]], [[0002-canonical-merged-artifact]] (superseded by 0016), [[0021-canonical-county-identity-via-fips-crosswalk]], [[0023-ct-planning-region-coordinate-resolution]], [[0008-modernize-dataexplorer-api]], [[county-fips-crosswalk]], [[cbsa-crosswalk]], [[ct-planning-region-crosswalk]]

## Context

The maintainer is beginning to receive **ad-hoc data requests** that
require some combination of `core` / `bmf` / `efile` data for specific
geographies (e.g. "all 990 filers in the Hartford CBSA with program-related
investments," "BMF org counts by CT planning region"). These are
cross-dataset, geography-keyed pulls produced on demand for a requester,
not a standing dashboard or package feature.

Three facts from the existing architecture decide where this work belongs:

1. **Cross-dataset joins are a consumer activity, by decision.**
   [[0016-no-canonical-cross-dataset-merge]] reversed [[0002-canonical-merged-artifact]]:
   there is no canonical merged artifact; consumers compose BMF × core ×
   efile joins per use case. An ad-hoc geography pull is exactly such a
   composition.

2. **Geographic identity is already a reusable, contracted surface.**
   [[0021-canonical-county-identity-via-fips-crosswalk]] and
   [[0023-ct-planning-region-coordinate-resolution]] publish the
   [[county-fips-crosswalk]], [[cbsa-crosswalk]], and
   [[ct-planning-region-crosswalk]] under `s3://nccsdata/crosswalks/`.
   Ad-hoc geography work joins these onto raw geo labels / coordinates — it
   does not re-derive geography.

3. **Consumers must not do private upstream ETL** (ARCHITECTURE §4). If an
   ad-hoc analysis keeps re-cleaning a producer output, that signals a
   missing artifact and belongs upstream — not buried in a one-off script.

What was missing was a *home* for this work. The default — notebooks and
emailed CSVs — produces undated, unpinned "ad-hoc data drops" of exactly
the kind the producer pattern warns against (ARCHITECTURE §3): no record of
which BMF vintage × which crosswalk produced a deliverable, so it can't be
reproduced or trusted six months later.

## Decision

Stand up a single new repo, **`nccs-data-requests`**, as a **thin consumer**
in the sense of ARCHITECTURE §4 — it reads canonical S3 artifacts plus the
published crosswalks and composes joins per request. It is **not** a
producer and **not** a second merge layer.

1. **Role: consumer, request-grained.** One folder per request
   (`requests/YYYY-MM-<slug>/`), each holding the query/script that produced
   the deliverable and the deliverable itself (or a pointer to where it was
   sent). Tooling is **R + arrow**, reusing [[nccsdata]] for reads and
   arrow filters — same stack as the other mature consumers.

2. **Pin contract versions, record coercions.** Every request records the
   contract versions (hence artifact vintages) it read and any type
   coercion it performed at the boundary (ARCHITECTURE §4). A deliverable is
   reproducible from its folder alone: pinned inputs + the query.

3. **Geography via the crosswalks, never re-derived.** Geographic identity
   is composed exactly as the contracts prescribe — label join on
   [[county-fips-crosswalk]] / [[cbsa-crosswalk]] for most states, the
   coordinate join on [[ct-planning-region-crosswalk]] for Connecticut
   ([[0023-ct-planning-region-coordinate-resolution]]). No private county /
   CBSA resolution logic.

4. **No private upstream ETL** (ARCHITECTURE §4). The repo may read + join +
   shape for a deliverable. It may not re-clean producer outputs. A felt
   need to do so is a missing-artifact signal routed upstream, not absorbed
   here.

5. **Publishes nothing reusable; gets no contract entry; is out of the
   drift loop.** It is a leaf consumer. It has no `contracts/*.yml`, no
   `_manifest.json`, and is not on any producer drift-detection watch list
   (ARCHITECTURE §7, §9). It pins contracts; it is not pinned by anyone.

### The graduate-at-second-request rule (the load-bearing guardrail)

The failure mode for this repo is becoming a **shadow merge layer** —
accumulating private join/cleaning logic that re-implements what
[[0016-no-canonical-cross-dataset-merge]] deliberately decentralized and
that ARCHITECTURE §5 says belongs in the contracted derived/crosswalk tier.

The guardrail is a rule, not vigilance:

> **The moment a join or geography is requested a second time, it stops
> being ad-hoc.** Open an ADR and promote it to the reusable surface — a
> published crosswalk (the [[county-fips-crosswalk]] / [[cbsa-crosswalk]]
> template) or, if a service-tier query, the API ([[0008-modernize-dataexplorer-api]]).
> The ad-hoc repo then *consumes* the promoted artifact like everyone else.

This makes `nccs-data-requests` a **demand detector**: each request is
evidence of which cross-dataset join is actually wanted, and the
second-request trigger is how that evidence graduates into the contract
surface instead of ossifying as private code.

## Rejected alternatives

- **Fold ad-hoc joins into [[nccsdata]].** The R package is a mature,
  general-purpose consumer; one-off request logic would pollute its public
  surface and entangle request lifecycles with package releases. Genuinely
  general reads still belong in `nccsdata` — but a one-off pull is not that.
  Rejected for ad-hoc work; kept as the promotion target for joins that turn
  out to be general.
- **No repo — notebooks / emailed CSVs.** Zero provenance: no pinned
  vintages, no reproducibility, no demand signal. This is the "ad-hoc data
  drop" the producer pattern explicitly disallows (ARCHITECTURE §3).
  Rejected.
- **Revive a canonical merged artifact to serve these.** Directly contrary
  to [[0016-no-canonical-cross-dataset-merge]]. Ad-hoc demand is the
  *input* to deciding which joins deserve promotion, not a reason to undo
  the no-canonical-merge call wholesale. Rejected.
- **Make it a producer (own contract + manifest).** Over-models genuinely
  one-off deliverables and puts the maintainer on the hook for drift-
  checking throwaway outputs. The whole point is that most requests never
  recur; the ones that do graduate (above). Rejected.

## Consequences

- **One new repo, registered as a consumer** in ARCHITECTURE §1. No new
  `contracts/*.yml`; no producer-pattern obligations (§3); no drift watch
  entry (§7, §9).
- **Per-request reproducibility** becomes the norm: pinned contract
  versions + recorded coercions + the query, co-located with each
  deliverable.
- **A demand signal feeds the contract surface.** Recurring requests
  surface promotion candidates (new crosswalk, new API query) via the
  second-request rule, instead of accumulating as private join logic.
- **A bounded new-module cost.** Per ARCHITECTURE §10, standing up the
  module = this ADR + the §1 registration + pinning contracts on first use.
  No publish hook, since it publishes nothing.

## Follow-up

1. **Stand up `nccs-data-requests`** (R + arrow): `requests/` folder
   convention, a `README` stating the consumer role + the graduate-at-
   second-request rule, and a small read helper that pins contract versions
   and logs them per request. Scaffold once the repo is created and cloned.
2. **First real request** exercises the geography join end to end (label
   crosswalks + the CT coordinate companion) and becomes the worked example
   in the README.
3. **Watch for the second request of any join** — the first promotion to a
   crosswalk or an API query gets its own ADR, closing the loop this ADR
   opens.

## Outcome

Reconciled 2026-07-01 (a reconcile-lag sweep under ADR 0038 found the
Status line stale — the repo had been live for nearly a month).

- Follow-up #1: `nccs-data-requests` stood up 2026-06-05 (`README`,
  `_private.md` confidentiality convention added same day as house rule 0).
- Follow-up #2: first real request shipped 2026-06-05 — Milwaukee MSA
  (CBSA 33340, four counties), counts + focus area 1989-2026 from the
  geocoded BMF master, revenue by source/focus 1989-2023 from CORE
  990/990-EZ/990-PF, nominal and real, rendered to gfm + a public GitHub
  Pages guide. Exercised the geography join end to end as intended.
- Follow-up #3 (second-request ADR trigger) — not yet applicable; only
  one request has landed so far.
- See [[0025-requests-graduate-to-data-stories]] for the separate,
  still-open question of promoting this request to a public data story.
