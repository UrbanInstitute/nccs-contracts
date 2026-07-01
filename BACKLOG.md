# Backlog — NCCS data system (prioritized next steps)

The maintainer's living to-do list, kept here because the workflow is: **boot the
`nccs-contracts` session first → plan against this list → execute in the downstream
repo → report back here and update this file.**

Maintenance: update at the **reconcile** step of each task (the three-phase loop in
`CONTRIBUTING.md`), ideally in the same PR as the work. `[where]` tags the repo a task
executes in. Keep the order = priority order.

This file is the **command board** of the reporting cycle (ADR 0038): every
open-loop ADR (`Accepted`/`Executing`) should map to a row here. Run
`/reconcile-status` at boot to cross-check the board against downstream PRs and
catch reconcile lag.

_Last updated: 2026-07-01._

---

## EIN format + Unified BMF — decided 2026-06-29 (record: `notes/ein-format-unified-bmf-decisions-2026-06-29.md`)

**Committed → execute downstream — GREEN-LIT: Jesse confirmed 2026-06-30** (consumer
sign-off on both calls — `EIN2` prefix "saves me a lot of headache" + "in favor of
retaining the Unified BMF name"; ADR 0022 consumer-notification obligation satisfied):**

| # | Task | Where | Status / notes |
|---|------|-------|----------------|
| E1 | Emit additive `ein_prefixed` (`ein-XX-XXXXXXX`) + `EIN2` (`EIN-XX-XXXXXXX`) columns; keep dashed `ein` **unchanged** | `nccs-data-bmf` (Unified BMF + ntee-resolved crosswalk) + `nccs-data-core` (CORE tiers) | **ADR 0036 — Reconciled (partial) 2026-07-01.** SHIPPED: ntee crosswalk **live** since 2026-06-30 (20 cols); Unified BMF cols **live 2026-07-01** (commit `11380a2`) alongside the E2 publish. CORE PR #11 (`f94d21e`) still **OPEN** — twin helpers byte-identical (verified). Contracts done: `conventions/ein-format.md` (6th rendering), `contracts/ntee-resolved-crosswalk.yml` (20 cols, amends 0034). PENDING: CORE PR #11 merge, CORE-tier contract reconcile, API schema bump, consumer notice send. |
| E2 | Rename master → **Unified BMF**; non-silent supersession (both live 90 days → prior to retained reachable archive); per-build manifest | `nccs-data-bmf` + contracts | **ADR 0037 — Reconciled 2026-07-01.** **PUBLISHED** to `s3://nccsdata/unified/bmf/` (commit `11380a2`): 3,687,435 unique EINs from 118 source files/114 vintages, verified directly against the manifest + quality report + bucket listing. `master/bmf/` confirmed still live (dual-live holds). Contracts done: `bmf-master.yml`→`unified-bmf.yml`, `ARCHITECTURE.md`. Path `unified/bmf/` + `bmf_unified` (INTERIM flat) ratified 2026-06-30, producer applied the delta (`UNIFIED_S3_PREFIX`) in commit `11380a2`. PENDING: consumer notice send (drafted, gated on this publish — now due), archive-key pin at the 2026-09-28 cutover. Geocoded master NOT renamed (out of scope). |

**July governance (do NOT decide/draft as settled):**

| # | Task | Notes |
|---|------|-------|
| ~~J1~~ | Canonical-format convergence — **DECIDED 2026-06-29: not pursued** | Permanent multi-rendering (ADR 0036). No convergence, no migration, dashed `ein` retained. The `qmd:56` dashed rationale stands (no longer needs superseding). July EIN deferral dropped. |
| J2 | "Represent all join IDs the same way across files" convention | **Optional** future group topic — NOT a committed item; nothing waits on it. Jesse's broader ID point. |
| J3 | Giving Tuesday EIN format — **CONFIRM** GT renders bare-9 `XXXXXXXXX` (zero-padded? always 9? prefix?) | Decision 5. Ingestion-normalization (consume + normalize on intake), not output-compat. A *4th* external rendering → evidence for "canonical key + deterministic bridges." **Keep OUT of the Jesse reply.** |

**Flags (governance hygiene, not Jesse-facing now):**

| # | Task | Notes |
|---|------|-------|
| F1 | Promote `conventions/ein-format.md` to an ADR-gated / CI-governed surface | Currently outside `adr-required` scope; a format change should be mechanically gated. |
| F1a | Reconcile the `ein_raw` description + decide its true format | **RESOLVED 2026-06-30 by RELABEL (ADR 0036, BMF PR #28):** the DD/docs now describe `ein_raw` as the lossy bare-integer surface (matching `ein-format.md §1/§5`), rather than retyping to padded-9. Retype would have changed the contracted shape → that was the escalation path; relabel is convention-consistent, so no escalation fired. Original inconsistency below. **Inconsistency:** `ein-format.md §1/§4` classify `ein_raw` as the **lossy bare-integer surface** (leading zeros dropped — test vector shows Master BMF `ein_raw = 4` for EIN `000000004`; "never join on it"), but the Master BMF **data dictionary** labels it "Original 9-digit EIN value." Decide: relabel the DD to match the lossy reality, **or** fix `ein_raw` to a character-typed padded-9 so it actually is the 9-digit source (the read-time numeric coercion that drops leading zeros is itself the failure mode Jesse flagged). Surfaced 2026-06-29 while vetting the Jesse reply. |
| F2 | sector-in-brief-api: adding `ein_prefixed`/`EIN2` response columns is an API-schema version bump | Coordinate ADR 0013/0022/0031. |

**Noted / background:**

| # | Task | Notes |
|---|------|-------|
| N1 | Consolidate the two duplicate `transform_ein` formatters (BMF + CORE) | Drift risk. **Parity verified 2026-06-30:** BMF `R/ein.R::ein_to_prefixed/ein_to_ein2` and CORE `R/transforms/ein.R` twins are byte-identical (`paste0("ein-"/"EIN-", ein)`, NA-preserving); CORE carries a cross-ref comment. No drift today, but still two copies kept in sync by convention + comment, not machinery — consolidation (or a shared contract test on the §5 vectors) remains the durable fix. |
| N2 | nccsdata cache is mtime-only (30-day) — won't see an upstream rename/reformat | Needs manifest/sha or version-tagged path busting. |
| N3 | nccs-data-efile producer `ein` is padded-9 (already divergent) | Any change = S3 producer-output contract change; must move in lockstep with the API normalizer. |

---

## ✅ Recently shipped (so we don't redo)

- **Cross-repo coordination protocol (the reporting cycle)** — **ADR 0038** + `CONTRIBUTING.md` (Status state machine, escalation gate, sitrep up-channel), `.github/PULL_REQUEST_TEMPLATE.md`, `/reconcile-status` lag-sweep command, README/ARCHITECTURE/CLAUDE wiring. Tier 0 + Tier 1. (Tier 2 — downstream escalation hook + Status-validating CI — deferred, conditional.)

- **EIN ↔ EIN2 bridge** — `nccsdata::nccs_ein_to_ein2()` / `nccs_ein2_to_ein()` (nccsdata PR #22) + spec `conventions/ein-format.md` (nccs-contracts PR #40). Both merged.
- **Harmonized CORE retained-frozen artifact** — ADR 0035 + `contracts/core-harmonized-frozen.yml` (PR #41); FU1 S3 delete-protection applied, FU2 `_manifest.json`, FU3 inventory, FU4 consumers (Jesse Lecy / Lewis Faulk / Mirae Kim as external notice contacts) (PR #42). Full-immutability `s3:PutObject` deny **deferred by decision**. All merged.
- **ntee-resolved crosswalk contract reconcile** — ADR 0034 + `contracts/ntee-resolved-crosswalk.yml` + ARCHITECTURE registration (PR #43). Merged. (Artifact was already live on S3.)
- **NTEE-EIN crosswalk on the website (#6)** — published on the BMF data catalog (nccs PR #88, live on Pages); the catalog registered as the contract's first consumer + ADR 0034 Outcome note (nccs-contracts PR #45).

---

## Active

| # | Task | Where | Status / notes |
|---|------|-------|----------------|
| 1 | Email Jesse: EIN conversion function is ready | *you* | **Artifact READY** — point him to `nccsdata::nccs_ein_to_ein2/ein2_to_ein` + `conventions/ein-format.md`. Just send. |
| 2 | Email Jesse: harmonized retained-artifact contract is in place | *you* | **DONE & live** — ADR 0035 merged, contract committed, S3 delete-protection applied. Just send. |
| E3 | Send the ADR 0036/0037 consumer notice | *you* → nccsdata, sector-in-brief API team | **Website leg CLOSED 2026-07-01** — `nccs` executed its half directly (catalog-bmf.qmd renamed to Unified BMF, new path documented, row counts, EIN columns, automation updated; reconciled in `contracts/unified-bmf.yml` consumers:). **Still owed:** nccsdata + sector-in-brief API — fold into the same notice as BACKLOG G2/G3 (ADR 0039 geocoded rename), since both read the geocoded artifact, not this one, directly. |
| L1 | **Complete ADR 0032** — full legacy NTEE reprocess (all ~86 vintages, `scripts/run_all_legacy.sh` **without** `SKIP_EXISTING` — must overwrite, not skip) to fix `nteev2_subsector`/`Z99` for legacy-sourced Unified BMF rows (currently `Z99` 58.2%, target ~30.7%); then rebuild + republish the Unified BMF off the reprocessed legacy data | `nccs-data-bmf` | **Reopened 2026-07-01** — deferred since the 2026-06-17 partial fix and had fallen off this board (reconcile lag; ADR 0032 Status still says "partially executed"). ~6h serial / faster with `JOBS=N` on a bigger host (c5.18xlarge used for the original measurement pass). **Does NOT require regenerating the ntee-resolved crosswalk** — that artifact aggregates vintage-invariant `ntee_code_raw` and cleans it once via the already-fixed `transform_ntee_code`, so it's unaffected by whether the legacy pipeline itself gets rerun (ADR 0034 was designed to sidestep exactly this). Must complete **before** G1's geocoded-master rebuild (sequencing below), so the geocoded master isn't built twice. |
| G1 | Fix broken geocoding input path; rebuild + **rename + publish** the geocoded Unified BMF + state marts | `nccs-data-bmf` | **Found 2026-07-01. Sequenced after L1. DECIDED via ADR 0039** (2026-07-01) — folds the geocoded-extension rename into this same rebuild rather than deferring it (avoids paying for a second expensive geocoder round-trip). `run_master_geocoding.R`'s `MASTER_PARQUET_PATH` still hardcodes `data/master/bmf_master.parquet`, but `run_master_pipeline.R` now writes `data/master/bmf_unified.parquet` (stem `UNIFIED_STEM`, ADR 0037) — repoint before running. Publish under the ADR 0039-ratified path `geocoding/unified-bmf/merged/bmf_unified_geocoded.*` (was `geocoding/bmf-master/merged/bmf_master_geocoded.*`) **alongside** the old path (90-day dual-live, same discipline as ADR 0037) — do not silently cut over. Also move state marts to `unified/bmf/state_marts/` (was `master/bmf/state_marts/` — an ADR 0037 scope gap ADR 0039 corrects, since `master/bmf/` itself archives at its 2026-09-28 cutover and would otherwise orphan the marts). While the code is open: fold in the long-open `_manifest.json` gap (ADR 0014, same `R/manifest.R` helper used for the un-geocoded artifact). Contracts done: `bmf-master-geocoded.yml` → `unified-bmf-geocoded.yml`, ARCHITECTURE.md. |
| G2 | Repoint `nccsdata::nccs_read()` to the new geocoded path | `nccsdata` | **New, ADR 0039 §4.** Hardcoded at `R/nccs_read.R:401` (S3 URI) + `:407` (HTTPS mirror) — `geocoding/bmf-master/merged/bmf_master_geocoded.parquet` → `geocoding/unified-bmf/merged/bmf_unified_geocoded.parquet`. Wait for G1's publish confirmation first; the old path stays live through the dual-live window, so this isn't urgent the moment G1 lands. |
| G3 | Repoint `sector-in-brief-api`'s hardcoded geocoded-BMF read | `sector-in-brief-api` | **New, ADR 0039 §4.** Same path swap as G2, DuckDB query-time read. Wait for G1's publish confirmation. |
| R1 | Run the ADR 0028 wholesale relational extraction on EC2 + publish | `nccs-data-efile` | **Found 2026-07-01 (reconcile-lag sweep, ADR 0038).** Architecture ADR (producer `decisions/0004`) + extractor + scale-build/publish path + EC2 runbook are all built and merged (PRs #13/#15/#16, `87eb274`, 2026-06-12) — but the run itself never happened. Verified: `s3://nccsdata/processed/efile/relational/` doesn't exist. Same shape as the BMF geocoding gap (G1) — built, waiting on an operator run on a capable host. The raw tier is uncontracted by design (ADR 0028 §4) so this doesn't need a contracts PR to *publish*, only to register once it's live (`contracts/efile.yml` already reconciled to describe the two-tier direction ahead of that). |
| P1 | Promote the Milwaukee MSA request to a public data story | `nccs-data-requests` → `nccs` | **Found 2026-07-01 (reconcile-lag sweep, ADR 0038).** All three ADR 0025 promotion gates cleared (generalizable, public-safe, worth reading) plus the revenue-completeness gate (1989-2023) — verified against `requests/2026-06-milwaukee-msa/checklist.md`. Remaining unchecked items are mechanical: add charts, pin `citation:` from `_pins.csv`, remove `draft: true`, move `request.qmd` (+ assets) into `nccs/_stories/` and open the PR. Not blocked on anything — the ready-to-execute item in the requests pipeline. |
| C1 | Confirm `sector-in-brief-data`/`core-panel` read core parquet (not the CSV mirror) before the ADR 0027 90-day window closes | `sector-in-brief-data` + contracts | **Found 2026-07-01 (reconcile-lag sweep, ADR 0038).** Not independently verified. Low urgency, not time-critical yet — window closes ~2026-09-07 (90d from the ADR 0027 decision date). |
| 3 | Make harmonized CORE datasets more visible on the NCCS website | `nccs` | Not started. Batch with #4–#6 (all `nccs`). |
| 4 | Link/mention the bmf + core crosswalks on the website's BMF & CORE pages | `nccs` | BMF page: geography crosswalks (`county-fips`/`cbsa`/`ct-planning-region`) + `ntee-resolved`. CORE page: the legacy→harmonized crosswalks (live in the producer repos). |
| 5 | CORE page copy: parallel datasets use different column names (beginner accessibility); harmonized CORE remains available on site | `nccs` | Copy task. |
| 6 | Publish/formalize the NTEE-EIN crosswalk on the website | `nccs` | **✅ DONE** — published on the BMF catalog (nccs PR #88, live on Pages); consumer back-reconciled into the contract + ADR 0034 (nccs-contracts PR #45). |
| 7 | Build the modular `_nccs` metadata datasets (separate, contracted, joinable on `ein`) | `nccs-data-bmf` / `nccs-data-core` + contracts | **ADR-NEEDED (§4.2).** ⚠️ overlaps #12 (Jesse ratifies). See sequencing note below. |
| 8 | Expose the optional metadata merge in nccsdata (off by default) | `nccsdata` | **ADR-NEEDED (§4.3).** Same Jesse-gating as #7. Design sketch in the fact-finding §4.3. |
| 9 | Update harmonized datasets from the new CORE (convert columns via crosswalk) so the parallel surface keeps functioning | `nccs-data-core` + contracts | ⚠️ **This is a NEW ongoing "compatibility shim" surface, distinct from the FROZEN run-1 files (ADR 0035).** Needs its own ADR (new producer pattern) + interacts with #15. Decide *whether* to build before building. |
| 10 | Branch protection on all core repos (require PRs, review, passing CI); decide approver policy (self vs self+DST) | core repos (GitHub settings) | Ties to **ADR 0022 step-4** per-repo ruleset (tooling shipped, not yet applied). Independent of Jesse; DST-aligned. Approver policy is a deliberate governance call. |
| 11 | New ADR correcting ADR 0015's "retired/never-written" description + record the retained-frozen decision + contract | nccs-contracts | **✅ DONE via ADR 0035** (PR #41) — corrects 0015's "phantom/never-written" claim + records retained-frozen + the contract YAML. Note: ADR 0035 *corrects* (not supersedes) 0015 — 0015's retirement of the *intermediate* tier stands. **→ close this item.** |

## Held until Jesse replies

| # | Task | Notes |
|---|------|-------|
| 12 | Draft ADRs as the first July quarterly agenda | The 5 ADR-NEEDED items: master BMF versioning + `/latest`; NTEE backfill into master; modular `_nccs` metadata datasets (ratifies #7/#8); nccsdata optional-merge; quarterly governance cadence + decision-split taxonomy + auto-gen decision doc. **+ EIN cluster: J2 (all-join-IDs, optional) + J3 (Giving Tuesday format confirm); J1 convergence is decided (not pursued).** |
| 13 | Schedule the July check-in once Jesse responds; bring the decision-split taxonomy draft | — |

## Background / noted (not urgent)

| # | Task | Notes |
|---|------|-------|
| 14 | `efile_v2_1` contract gap (consumer e-file uncontracted *by design*, ADR 0007) | Governance agenda item, not action now. |
| 15 | Long-term e-file deprecation question | Don't let the compatibility shim become a permanent invisible obligation. **Directly informs #9.** |
| 16 | E-file parallel build | Proceed under Erika's blessing, DST track, separate from the Jesse thread. |

---

## Prioritization notes (2026-06-26)

- **Quick clears:** #11 is already done (ADR 0035) — close it. #1/#2 collapse to "send the emails" — the artifacts they reference are all merged/live. That's three active items effectively cleared.
- **Batch the website cluster:** #3, #4, #5, #6 all execute in the `nccs` repo — do them in one `nccs` session (#6's prompt already exists). #6 is mid-flight.
- **Sequencing flag on #7 / #8 / #9 vs #12:** #7 and #8 are explicitly the things #12 ratifies *after Jesse*. Building them now risks rework if his input reshapes the design — recommend hold the *contracted* build until the ADRs land (a throwaway prototype is fine; don't publish/contract it). **#9 is the riskiest:** it reopens the "frozen" stance (ADR 0035) by standing up a *new ongoing* harmonized-format surface, and #15 is the caution. Treat #9 as a *decision to make* (with Erika/Jesse) before any build.
- **#10 is unblocked and independent** of the Jesse thread — can go anytime; ties to existing ADR 0022 work.
