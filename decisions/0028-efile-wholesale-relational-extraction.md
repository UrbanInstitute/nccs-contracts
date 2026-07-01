# 0028 — E-file: Wholesale Extraction to a Normalized Relational Tier

- **Status:** Accepted (architecture ADR + extractor/publish path built, not yet executed — see Outcome)
- **Date:** 2026-06-09
- **Deciders:** sole maintainer
- **Amends:** [[0007-efile-urban-owned-producer]] (replaces the curated Phase 1/2/3 "extract the fields a consumer asks for" phasing with wholesale extraction; reassigns 0007's *researcher catalog* from NODC to an NCCS-owned raw tier), [[0017-efile-phase-0-vertical-slice]] (inverts §3's end-state: Layer 1 now **drives extraction**, not just verification; Layer 2 becomes curated views on top).
- **Related:** [[0001-s3-as-contract-surface]], [[0013-versioned-producer-outputs]], [[0014-standardize-manifest-shape]], [[0016-no-canonical-cross-dataset-merge]]

## Context

[[0007-efile-urban-owned-producer]] framed e-file as a **curated,
demand-driven** producer phased 1/2/3 (990 headline → schedules/990EZ/
backfill → 990PF), publishing form-agnostic `snake_case` fields, and
imagined "**two catalogs**": a general-user catalog (the Urban-owned
contracted surface) and a researcher catalog (filled by NODC).

[[0017-efile-phase-0-vertical-slice]] §3 set the two-layer concordance
and declared its end-state: *"Phase 1+ extracts run natively off NCCS's
layer-2 dictionary, with layer 1 as the XPath ground truth."* Extraction
was to be gated by the hand-curated Layer 2 — you only extract a field
once someone curates it.

**Phase 0.5 is now done** (producer record:
`nccs-data-efile/decisions/0003-two-layer-concordance.md`). Layer 1 — the
mechanical XSD inventory — is built and published, enumerating **every
element** per `(tax_year, version)` with **cardinality, parent path,
leaf-ness, and XSD type**. The "know every field that exists" problem is
solved, and the inventory already carries exactly the metadata needed to
separate non-repeating scalar leaves from repeating groups.

That changes the economics behind 0007/0017's curated framing, which is
why this ADR re-opens it.

## Decision

The producer adopts **wholesale extraction** to a **normalized
relational** destination, rolled out **incrementally**.

### 1. Layer 1 drives extraction (inverts 0017 §3)

Layer 1's inventory now **drives extraction of the full field universe**,
not the hand-curated Layer 2. Layer 1 remains the XPath ground truth (as
0017 §3 had it) *and* becomes the extraction driver. **Layer 2 is no
longer the gate on *what* gets extracted** — it becomes demand-driven
**curated views + naming** layered on top of the wholesale tier. This
supersedes 0017 §3's "Phase 1+ extracts run off Layer 2."

### 2. Normalized relational destination

The destination is a normalized relational set of tables, not one wide
table:

- a **header / scalar table** — one row per filing, the non-repeating
  scalar leaves; and
- **child tables per repeating group** (grants, officers, etc.), keyed
  back to the filing.

This shape is **borrowed from the domain, not invented**: it mirrors how
NODC itself groups fields (its `rdb_table` column).

### 3. Incremental rollout — scalar-first, repeating-groups on demand

- **Non-repeating scalar leaves first** (the header tables), identifiable
  directly from the inventory's cardinality + parent path. This covers
  the bulk of analytic demand at **near-zero added extraction cost**.
- **Repeating-group child tables are added demand-driven** — the first
  request for repeating data triggers that increment.

The scalar-first slice is a **genuine first increment of the full model,
not a detour**: the extraction engine *extends* to repeating groups
rather than being replaced, and the scalar header table is one of the
final relational tables — so there is no rework.

### 4. Contract-surface status of each tier (the contracts-level crux)

Two tiers, two contract statuses — this realizes 0007's "two catalogs"
with NCCS owning both:

- **Raw wholesale relational tier = the NCCS-owned researcher catalog.**
  Complete and schema-faithful, XPath/relational-named (the role 0007
  assigned to NODC). It is **published but explicitly best-effort /
  uncontracted** — a "researcher tier, no stability guarantee." It is
  faithful to the IRS XSD, so *it moves when the IRS form moves*; it
  carries **no deprecation-window or path-stability guarantee**.
  Consumers may read it at their own risk; they must **not** pin it as if
  it were stable. It lives on S3 under
  `s3://nccsdata/processed/efile/relational/` (one prefix per table:
  `relational/{table}/`); exact partitioning/file layout is a producer
  detail (see below).
- **Curated Layer 2 views = the general-user catalog, and the
  contracted/guaranteed surface.** Form-agnostic `snake_case`,
  versioned, manifest-shipping ([[0014-standardize-manifest-shape]]),
  deprecation policy ([[0013-versioned-producer-outputs]]) — this is what
  dashboards, the API, and the R package **pin**. Stability lives here,
  precisely because the raw tier (being XSD-faithful) cannot offer it.

Both tiers sit on S3 per [[0001-s3-as-contract-surface]]; the difference
is the *guarantee*, made explicit so no one mistakes "published" for
"contracted."

**Existing Phase 0 outputs** (`processed/efile/phase0/` —
`government_grants`, `program_related_investments`) **are reframed as the
first curated views**: they already match that role (form-agnostic
`snake_case`, consumed by `sector-in-brief-data`). They are
**grandfathered at their current path**; `contracts/efile.yml` continues
to describe them unchanged. Any re-homing under a curated-views layout is
a producer-repo detail, not a break.

## Rationale

- **Phase 0.5 already solved "know every field."** With Layer 1 built,
  the only remaining barrier to a complete tier was extraction + curation
  cost — and Layer 1 makes wholesale extraction tractable (it enumerates
  every field with the cardinality/parent-path metadata to split scalars
  from repeating groups).
- **Extraction is cheap per field; the XML parse dominates.** Per the
  producer's parse-cost work, once a filing's DOM is built, pulling the
  whole scalar universe costs ≈ the same as pulling two fields.
  **Curation, not extraction, is the bottleneck** — wholesale decouples
  them and removes the "consumers wait for curation" failure mode.
- **Optionality under unknown demand.** The maintainer does not know the
  next consumer's specific need. Wholesale-scalar is the hedge: whatever
  scalar a consumer asks for is *already extracted*, and curation (a
  friendly named view) is the only remaining step.
- **It completes the NODC-independence arc of 0007/0017.** The raw
  wholesale tier *is* the researcher catalog 0007 expected NODC to fill,
  now NCCS-owned. NODC stays an informational comparison artifact
  (per Phase 0.5); it is no longer load-bearing for anything.

### Alternatives considered

- **Stay curated (0007 / 0017 §3 as written).** Rejected. It keeps
  curation as the gate on extraction, so every new consumer field waits
  on a curate → extract → republish cycle. That made sense when "knowing
  what exists" was unsolved; Phase 0.5 solved it, so the curated-extraction
  bottleneck is now pure friction — and it never builds the researcher
  catalog.
- **Full wholesale at once (all scalars *and* all repeating groups
  immediately).** Rejected. The repeating-group child tables are where
  the normalization complexity and per-group modeling live; doing them
  all up front is multi-month work with no consumer waiting on most of
  it. Scalar-first delivers the bulk of demand now and defers the complex
  modeling to actual demand.
- **Incremental wholesale (chosen).** Scalar-first is a real first
  increment (extends, not replaces; the scalar header is a final table),
  captures most demand at near-zero marginal cost, and pulls
  repeating-group complexity in only when a consumer needs it.

## Consequences

**Positive:**

- Extraction is decoupled from curation; consumers no longer wait for
  curation — any scalar they ask for is already extracted, leaving only a
  named view to author.
- The NCCS-owned researcher catalog gets built as a by-product, finishing
  the NODC-independence arc.
- Scalar-first is near-zero marginal extraction cost (parse dominates).
- A consumer field request usually maps to an existing column + a curated
  view, not a producer change + republish.

**Negative / accepted tradeoffs:**

- **A two-status contract surface needs discipline.** The raw tier must
  be clearly and repeatedly marked best-effort/uncontracted, or a
  consumer will pin it and break on the next IRS form revision. The
  curated views are the only surface that carries a stability guarantee.
- The XSD-faithful raw tier **moves with IRS forms** — researchers
  reading it inherit that instability (by design; that is what
  "best-effort" means).
- Storage grows (the whole scalar universe vs. two fields), though scalars
  are cheap and repeating groups stay demand-gated.
- Curation labor is **decoupled and deferred, not eliminated** — curated
  views still need authoring (and naming, citations) when demand arrives.
- One more ADR in the e-file chain (0007 → 0017 → 0028) for future readers
  to traverse.

## Follow-up

1. **Producer architecture ADR — `nccs-data-efile/decisions/0004`** (to
   follow, citing this ADR) owns the **HOW**: the extractor design, the
   exact output schemas and column naming, the repeating-group
   representation, partitioning, and build mechanics. This ADR commits
   only to *normalized relational (header + child tables), wholesale,
   incremental, scalar-first* and the tier contract-statuses above.
2. **Contract the curated-views surface** in `contracts/efile.yml` as
   curated views land (they are the guaranteed surface). The raw
   relational tier is **not** added as a contracted surface — it is
   published best-effort; if external demand ever warrants a stability
   guarantee on part of it, promote that part to a curated view (or its
   own contract) at that point.
3. Update `ARCHITECTURE.md` if/when the relational tier publishes, to
   reflect the two-tier e-file surface.

## Outcome

Reconciled 2026-07-01 (a reconcile-lag sweep under ADR 0038 found this
Status line stale relative to real progress in `nccs-data-efile`).

**Shipped.**
- Follow-up #1: producer architecture ADR landed —
  `nccs-data-efile/decisions/0004-wholesale-relational-extraction.md`,
  owning the scalar-leaf test (leaf + non-repeating per the Layer 1
  inventory's `is_leaf`/`max_occurs`/`parent_path`), the header +
  per-repeating-group child table shape, and build mechanics.
- The extractor, the scale-build/publish path, and an EC2 runbook are
  built and merged: `nccs-data-efile` PRs #13 (docs), #15 (scalar
  extractor + per-form header tables), #16 (scale build + publish path +
  EC2 runbook), through commit `87eb274` (2026-06-12).

**Diverged or pending.**
- **Not yet executed.** Verified 2026-07-01: `s3://nccsdata/processed/efile/`
  has no `relational/` prefix (only `concordance/`, `diagnostics/`,
  `phase0/`, `schemas/`) — the built pipeline has not been run on the
  EC2 host, so nothing has published under the raw wholesale relational
  tier yet. Same shape as the BMF geocoding gap: architecture decided and
  code built, awaiting an operator run. Tracked in BACKLOG.
- Follow-up #2 (contract the curated-views surface) and #3 (update
  ARCHITECTURE.md) are correctly **not yet due** — both are explicitly
  gated on the relational tier actually publishing, which hasn't
  happened. `contracts/efile.yml` was reconciled at this same pass to at
  least describe the ADR 0028 direction accurately (Phase 1-3 marked
  superseded, the two-tier contract-status split documented) even though
  there's no new artifact to contract yet.
