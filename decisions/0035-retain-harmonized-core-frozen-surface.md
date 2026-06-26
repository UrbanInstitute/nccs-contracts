# 0035 — Retain the Harmonized CORE Surface as a Frozen, Protected Artifact

- **Status:** Accepted
- **Date:** 2026-06-26
- **Deciders:** sole maintainer
- **Related:** [[0015-core-contract-surface-restructure]] (corrects), [[0005-bmf-unified-superseded-by-master]], [[0033-deprecation-window-policy-and-critical-bug-override]], [[0013-versioned-producer-outputs]], [[0014-standardize-manifest-shape]], [[0001-s3-as-contract-surface]]

## Context

A 2026-06-26 review (responding to research-affiliate feedback on the CORE
interface) verified the live contents of `s3://nccsdata/harmonized/core/`. The
finding contradicts an assumption baked into ADR 0015:

- **The surface is real, populated, and consumer-facing — not a phantom.** It holds
  ~231 objects across five subsector subtrees (`501c3-pc/pf/pz`, `501ce-pc/pz`):
  per-subsector base CSVs (`CORE-{year}-{class}-HRMN.csv`, vintages 2012–2022),
  `marts/` (`CORE-{year}-{class}-HRMN-V{0,1}.csv`, to 2023), a `full/…HRMN…parquet`,
  a `dd/` dictionary, plus a top-level `CORE-HRMN_dd.csv`. It is keyed on **`EIN2`**
  (`EIN-XX-XXXXXXX`) — the legacy/NODC join convention (see
  `conventions/ein-format.md`).
- **It is frozen, not maintained.** Every object's `LastModified` falls between
  2023-12-05 and 2025-04-21. The 2026-05-08 CORE pipeline rewrite (which stood up the
  current `processed*/core/` tiers) did **not** touch, move, or delete any of it.
- **Downstream consumers depend on it.** External research packages — including the
  NODC / `irs990efile` lineage associated with the advisory affiliate — pull directly
  from these `harmonized/core/` paths and join on `EIN2`.

This surface is distinct from `s3://nccsdata/intermediate/core/harmonized/`, which is
the *current* pipeline's internal build tier (written by `R/03_harmonize.R`, promoted
to `processed/core/` by `R/08_upload.R`). ADR 0015 conflated the two: it correctly
retired the contract for the intermediate tier, but in doing so declared the published
`harmonized/core/` surface a "phantom" to which "no deprecation window applies"
(0015 §Deprecation window). That is factually wrong — the 2024 producer (commit
`9cbdb5d`) wrote it, and it is still live and consumed.

The risk is concrete and one-sided: the surface is un-versioned, un-manifested, and
formally marked `retired`, so it is one bucket cleanup away from **silent deletion** —
exactly the failure mode that stranded no one only because the BMF unified artifacts
were deliberately archived-with-notice ([[0005]]). A surface that external packages
still read should not be removable without warning.

## Decision

Recognize `s3://nccsdata/harmonized/core/` as a **retained, frozen, protected
published artifact** and contract it.

1. **Frozen, retained disposition.** The surface is no longer produced (no new
   vintages will land) but is **retained indefinitely** as a stable consumer
   interface. New status value `frozen` (see Conventions).

2. **Non-deletion + advance-notice guarantee.** The files will **not be moved,
   renamed, or removed without advance notice to known consumers and a deprecation
   window** — default 90 days per [[0033]]. The critical-bug override in 0033 does
   not apply here: a frozen artifact cannot acquire a correctness/corruption defect,
   so there is no harm-prolonging reason to shorten the window. If the surface is ever
   retired for real, it follows the [[0005]] pattern: archive-with-notice and a
   reachable replacement, never a silent delete.

3. **Contract it.** A new contract `contracts/core-harmonized-frozen.yml` describes
   the surface (paths, format, key, frozen vintage range, `EIN2` key, retention
   terms), so drift detection can assert the files still exist and flag any
   disappearance. The retired `contracts/core-harmonized.yml` (intermediate tier) is
   left in place but gets a clarifying cross-reference so the two are never again
   conflated.

4. **Correct ADR 0015 on the record** (see Correction below).

5. **Technical enforcement is an S3-level control, not the YAML.** This repo has no
   runtime; the contract *declares* the guarantee and lets drift detection *observe*
   deletion after the fact. Actual prevention requires an S3-side control on the
   `harmonized/core/` prefix — a bucket-policy `Deny` on `s3:DeleteObject` for that
   prefix, and/or S3 Object Lock / versioning. That is a bucket change executed by the
   maintainer (out of scope for this repo) and is listed as a Follow-up.

## Conventions

Extends the `status:` enumeration introduced by [[0015]]:

- **`frozen`** — published and **retained indefinitely** under a non-deletion +
  deprecation-window guarantee, but **no longer updated** (no new vintages, no fixes).
  Existing consumers may continue to read it; it is **not** a freshness source and new
  consumers should prefer the active replacement. Distinct from `retired` (which
  implies eventual removal after a deprecation window) and from `active` (currently
  produced). Added to `contracts/_template.yml`.

A `frozen` contract additionally carries a `retention:` block recording the guarantee,
the deprecation window, and the notice requirement.

## Correction to ADR 0015

ADR 0015 §Deprecation window states: *"`harmonized/core/` … to the extent that path
still exists on S3 at all … is not an active surface. No deprecation window applies to
a phantom contract."* This is **superseded**: the path exists, holds ~231 objects
(frozen 2023–2025), and has live external consumers. It is a retained frozen surface
under a 90-day deprecation guarantee per this ADR. ADR 0015's retirement of the
*`intermediate/core/harmonized/`* contract remains correct and is unchanged; only its
characterization of the published `harmonized/core/` surface is corrected.

## Consequences

**Positive:**
- External consumers (incl. the affiliate's NODC-lineage packages) keep a stable,
  now-contracted interface; a deletion would be detected by drift checks and is
  governance-barred.
- The spec-vs-reality gap that 0015 left (a real surface mislabeled phantom) is closed.
- Establishes a reusable `frozen` idiom for the next retained-but-unmaintained surface.

**Negative / costs:**
- The frozen surface is un-manifested; drift detection can assert presence but not
  byte-integrity until a one-time manifest is added (Follow-up; optional since frozen).
- Retaining it indefinitely is a (small) ongoing storage cost — accepted as the price
  of not stranding consumers.
- Real deletion-prevention depends on an S3-side control the maintainer must apply;
  until then the guarantee is governance-only.

## Deprecation window

90 days (default, [[0033]]) for any future move/rename/removal of the
`harmonized/core/` surface, with advance notice to known consumers. The critical-bug
override does not apply (a frozen artifact prolongs no harm).

## Follow-up

1. **✅ APPLIED 2026-06-26 — S3-level non-deletion control** on
   `s3://nccsdata/harmonized/core/`. Bucket-policy `Deny` on `s3:DeleteObject` +
   `s3:DeleteObjectVersion` for the prefix (Sid `ProtectFrozenHarmonizedCore-ADR0035`),
   applied on the nccs-data-core side via read-merge (the two pre-existing public
   statements preserved); verified live — `get-bucket-policy` shows the Sid and an
   `AccessDenied` delete dry-run confirmed the explicit deny. This is what actually
   *ensures* the files are not deleted. Runbook + policy:
   `notes/adr-0035-s3-enforcement.md`. **Full immutability (also denying `s3:PutObject`
   to block overwrites) was considered and DEFERRED by decision 2026-06-26** —
   delete-protection deemed sufficient; overwrite guarded by operator discipline (the
   maintainer will not overwrite the frozen keys). The keys stay technically
   overwritable; re-apply only if a hard no-overwrite guarantee is later wanted.
2. **✅ APPLIED 2026-06-26 — One-time `_manifest.json`** for the frozen surface at
   `harmonized/core/_manifest.json` (63,339 B; 232 file entries; ADR 0014 shape adapted
   for a frozen surface — top-level vintage `"frozen"`, git_sha `9cbdb5d` (the 2024 build
   commit), `frozen_since` 2025-04-21, `object_count` 232, `total_bytes` 29,925,863,035,
   `inputs` []). Written producer-side (nccs-data-core), verified by round-trip.
   **Deviation:** `integrity_basis` is **etag+size, not sha256** — full sha256 would
   require reading the entire ~30 GB of an already delete-protected frozen surface, and
   219/233 objects use multipart ETags (ETag ≠ MD5). ETag+size detects
   overwrite/disappearance; per-file sha256 (and `row_count`/`columns`) can be backfilled
   later without reshaping (recorded in the manifest's `deviations[]`).
3. **✅ APPLIED 2026-06-26 — Exact inventory enumerated** in
   `core-harmonized-frozen.yml` (the `inventory:` block; cross-checked against the
   manifest's 232 file entries, every year span contiguous). Per-(subsector, family,
   version) object counts + year ranges — drift detection can now assert coverage
   completeness, not merely prefix presence. **Verified finding:** the version token
   splits by **subsector, not family** — 501c3-pf is V0 across all families (base
   ABSENT, marts-only; dd is the irregular `DD-PF-HRMN-V0.csv`, no CLASS token); the
   other four subsectors are V1 across all families. Also corrected the `s3:`
   realized-layout comment + `schema.source` (the pf dictionary exception).
4. **Known consumers registered 2026-06-26 (living list).** `core-harmonized-frozen.yml`
   `consumers:` now records, evidence-based (grep of local repos + org code search):
   (a) the **NCCS public data-catalog website** (`UrbanInstitute/nccs`) — a CONFIRMED
   Urban-owned consumer that publishes download links to the surface and already labels
   it "deprecated, for reproducibility only"; advance-notice → DST / catalog maintainer.
   (b) the **external NODC / `irs990efile`-lineage** research consumers (not in any Urban
   repo, as expected for external) — advance-notice contacts confirmed 2026-06-26: the
   research advisory affiliates **Jesse Lecy, Lewis Faulk, Mirae Kim** ("for now").
   Inactive/stale refs noted but not
   gated (`nccs-dataexplorer-data` commented-out sync, superseded by sib-data per ADR
   0010; a stale `sector-in-brief-data` scaffold ref). Remains a living list — register
   more as they surface.
