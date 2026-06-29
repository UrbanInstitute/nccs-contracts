# 0037 — Master BMF → Unified BMF: Rename, Non-Silent Supersession, Per-Build Provenance

- **Status:** Accepted (committed) — implementation pending in nccs-data-bmf; reconcile contracts + ARCHITECTURE on execution
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
versioning + `/latest` direction (the exact path layout follows that work).

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

_Pending implementation in nccs-data-bmf: rename/supersede with both paths live
for 90 days, attach the per-build manifest, carry the ADR 0036 columns, then
reconcile `contracts/` + `ARCHITECTURE.md` and notify consumers. Update with the
build/publish commit and the live `unified` layout when executed._
