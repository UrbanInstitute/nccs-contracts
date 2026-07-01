# 0037 — Master BMF → Unified BMF: Rename, Non-Silent Supersession, Per-Build Provenance

- **Status:** Reconciled (2026-07-01) — see Outcome. Amended 2026-06-30 (§5 path layout pinned: `unified/bmf/` + `bmf_unified`, INTERIM flat). The Unified BMF is now **live on public S3** at the ratified path (commit `11380a2`); the only open item is the post-cutover archive-key pin, due at the 2026-09-28 deprecation cutover.
- **Date:** 2026-06-29
- **Deciders:** sole maintainer (DST), with advisory input from Jesse Lecy
- **Related:** [[0005-bmf-unified-superseded-by-master]] (the rename-to-master this **partially reverses**, and the silent-move pattern this corrects), [[0033-deprecation-window-policy-and-critical-bug-override]] (the 90-day window), [[0013-versioned-producer-outputs]] + [[0014-standardize-manifest-shape]] (the manifest/retention this executes), [[0036-ein-coercion-safety-additive-columns]] (the additive EIN columns the renamed artifact carries), [[0016-no-canonical-cross-dataset-merge]] (`ein` is the consumer-composed join key), [[0001-s3-as-contract-surface]], [[0022-cross-repo-contract-change-guard]] (the producer reconcile)

## Context

The new "master" BMF **is** the replacement for the Unified BMF.
[[0005-bmf-unified-superseded-by-master]] superseded the Unified BMF with the
"master" — which both **dropped the `EIN2` key** (it carries dashed `ein`, no
prefix) and **dropped the name** the affiliate/research community knew. That name
change is the direct source of a recent confusion: an earlier reply to Jesse
stated "the Unified BMF still carries `EIN2` and merges as it did" — true of the
**archived original** Unified BMF (frozen at `…/master/bmf/archive/unified-v1.2/`,
still `EIN2`-keyed), **not** of its replacement. Conceded cleanly in the reply.

More broadly, the *silent* supersession/rename of the unified is what triggered
the affiliate's concern in the first place. Supersession of a published artifact
must be non-silent.

## Decision

**1. Rename master → Unified BMF.** Restore the known community name so it carries
forward, and use the renamed artifact to supersede the prior file. (This
partially reverses [[0005-bmf-unified-superseded-by-master]]'s rename-to-master;
the `EIN2` key is separately re-provided additively per
[[0036-ein-coercion-safety-additive-columns]].)

**2. Non-silent supersession with a fallback.** The prior and renamed versions
stay **both available for 90 days** so nothing breaks. After 90 days the prior
version moves to the **retained archive — reachable and citable, not deleted**.

**3. Standing rule (recorded here, applies generally).** Supersession or renaming
of a published artifact **always** comes with advance notice and a reachable
fallback — a deprecation-windowed path move, never a silent one. This applies
[[0033-deprecation-window-policy-and-critical-bug-override]] and the
all-vintages-retained doctrine (architecture context §1) specifically to
artifact rename/supersession, and is the corrective to the silent-move pattern of
[[0005-bmf-unified-superseded-by-master]].

**4. The renamed Unified BMF carries the additive `ein_prefixed` + `EIN2`
columns** per [[0036-ein-coercion-safety-additive-columns]].

**5. Per-build provenance.** Each build carries a manifest (commit, input hashes,
row counts); prior builds are retained, so every version stays **citable and
reproducible**. This executes [[0013-versioned-producer-outputs]] /
[[0014-standardize-manifest-shape]] and is consistent with the in-flight
versioning + `/latest` direction.

**Amended 2026-06-30 — path layout pinned** (this §5 originally deferred the
exact layout). Ratified at reconcile, against the producer's staged defaults in
nccs-data-bmf PR #28:

- **Prefix:** `unified/bmf/` (bucket `nccsdata`). A clean top-segment swap of the
  retiring `master/bmf/` — same structure, so consumers re-pin by changing only
  `master` → `unified`. This **differs from the producer's staged
  `UNIFIED_S3_PREFIX="unified/"`**; the producer must set it to `unified/bmf/`
  before the first publish. (Rationale: preserve the `/bmf/` segment, parallel to
  `master/bmf/` and to the `bmf_master`/`bmf_unified` stems, and leave namespace
  room for a future `unified/` sibling.)
- **Filename stem:** `bmf_unified` (snake_case, product-first, parallel to
  `bmf_master`). Matches the staged `UNIFIED_STEM` — no producer change. The
  historical uppercase/versioned `UNIFIED_BMF_V1.2` form is **not** adopted; the
  community "Unified BMF" name lives in the docs/description, not the filename.
- **Versioning:** **INTERIM flat-now** — publish flat at
  `unified/bmf/bmf_unified.{parquet,csv}` (+ dictionary, quality report,
  `_manifest.json`). The versioned `{vintage}/` subdir + `latest/` mirror is
  deferred to the in-flight [[0013-versioned-producer-outputs]] work, which
  migrates this and [[bmf-master-geocoded]] in lockstep; vintage is carried in the
  manifest meanwhile.

**Scope:** the rename targets the **un-geocoded** community Unified BMF
(`master/bmf/` → `unified/bmf/`). The geocoded extension (`geocoding/bmf-master/`,
contract `bmf-master-geocoded`) is **not** renamed by this ADR; its only coupling
is that its producer reads this artifact as input, a cutover detail it switches
from `master/bmf/` to `unified/bmf/` during the dual-live window.

## Consequences

- **The known name carries forward** and the master/unified confusion is resolved
  at its source.
- **No consumer strands.** `nccsdata` and other consumers re-pin to the new path;
  the old path stays reachable for the 90-day window, then archives reachably.
  (Caveat: `nccsdata`'s cache is mtime-only and will not *see* a rename within its
  window — tracked as a flag under ADR 0036 / BACKLOG; a manifest sha or
  version-tagged path is the fix.)
- **Published-path change → guard + notice.** The move reconciles the contract
  YAML (`contracts/bmf-master.yml` → `unified-bmf.yml`) and `ARCHITECTURE.md`, and
  notifies known consumers, per [[0022-cross-repo-contract-change-guard]].
- **Provenance/citability** materially improve (manifest + retained vintages),
  the direction the affiliate explicitly praised.

## Deprecation window

Standard **90 days** per [[0033-deprecation-window-policy-and-critical-bug-override]]:
prior and renamed versions both live for the window; after it, the prior version
moves to the retained archive (reachable + citable, not deleted). Advance notice
to consumers.

## Outcome

Reconciled **2026-06-30 (partial)** against nccs-data-bmf PR #28 (commit
`fd0b366`, branch `feat/ntee-resolved-crosswalk`); **published 2026-07-01**
(commit `11380a2`, same branch) closing the one item that partial reconcile
left open.

**Published 2026-07-01.** `UNIFIED_S3_PREFIX` set to the ratified `unified/bmf/`
(commit `11380a2`, fixing the staged `unified/` delta flagged at the partial
reconcile) and `R/run_master_pipeline.R` run to completion. Live at
`s3://nccsdata/unified/bmf/`: `bmf_unified.parquet` (486,314,706 bytes),
`bmf_unified.csv` (2,973,363,906 bytes), `bmf_unified_data_dictionary.csv`,
`bmf_unified_quality_report.{json,html}`, `_manifest.json`. Per the manifest
and quality report (`vintage: "2026_07"`, `built_at: 2026-07-01T04:55:16Z`,
`git_sha: 11380a2`): **3,687,435 unique EINs** (`total_rows == distinct_eins`,
the hard gate, holds) from **118 source files** across **114 vintages**
(2,208,124 current-pipeline rows + 1,479,311 legacy-pipeline rows; year range
1989–2026). `ein_prefixed` + `EIN2` are present in the published schema
(ADR 0036). The prior `master/bmf/` path confirmed still live and unchanged
(`bmf_master.parquet` dated 2026-06-17) — non-silent supersession holds, both
paths dual-live pending the 2026-09-28 cutover.

**Shipped (code, 2026-06-30 partial).**
- `run_master_pipeline.R` publishes under `UNIFIED_S3_PREFIX` / `UNIFIED_STEM`
  (staged `unified/` + `bmf_unified`) and orchestrates the non-silent
  supersession: `MASTER_LEGACY_S3_PREFIX="master/bmf/"` stays reachable until
  `MASTER_DEPRECATION_CUTOVER="2026-09-28"` (90 days from 2026-06-30), then
  archives — not deleted. The pending-ratification gate was flagged correctly in
  the sitrep (`needs-ADR-review`) and the constants carry inline flags.
- `write_master_outputs()` now emits a per-build ADR 0014 `_manifest.json` via
  `R/manifest.R` (commit, input hashes/ETags, row counts, columns). **This closes
  the long-standing `unified-bmf` manifest gap (former `bmf-master` Open item #1).**
- N2 (nccsdata mtime-only cache): the producer chose the **manifest sha256** as
  the cache-bust signal; consumers re-pin on manifest change / version-tagged path.

**Shipped (contracts, this reconcile).**
- §5 amended to pin the layout: ratified **`unified/bmf/` + `bmf_unified`, INTERIM
  flat** (see Decision). The ratified prefix **differs from the staged
  `unified/`** — flagged back to the Executor.
- `contracts/bmf-master.yml` renamed → `contracts/unified-bmf.yml` (`name:
  unified-bmf`), repointed to `unified/bmf/`, manifest path set, EIN columns +
  non-silent supersession recorded. Live `[[bmf-master]]` cross-references in
  `sector-in-brief.yml` / `bmf-legacy.yml` / `core-990.yml` updated to
  `[[unified-bmf]]` (and their manifest-gap notes corrected — the Unified BMF is
  no longer a manifest-less peer).
- `ARCHITECTURE.md` system map names the Unified BMF + the supersession.

**Diverged or pending.**
- **90-day archive key not yet pinned.** The exact post-cutover archive location
  under `s3://nccs-data-archive/superseded/` is not set in producer code; pin it
  in `unified-bmf.yml` at the 2026-09-28 cutover reconcile.
- **Geocoded master + state marts** (`bmf-master-geocoded`) not renamed (out of
  scope); the EIN columns flow when those rebuild from the renamed Unified master.
- **Consumer notice** for the path move (nccsdata, website join instructions / BMF
  catalog, sector-in-brief API) drafted 2026-06-30 — now due for send, the publish
  it was gated on has landed.
- **Producer docs stale.** `nccs-data-bmf/docs/11-master-bmf.qmd` still shows the
  old `master/bmf/` output paths and a "pending nccs-contracts ratification"
  callout as of this reconcile — flag back to the Executor to refresh post-publish
  (not a contract-shape issue, so not blocking here).
