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

_Last updated: 2026-06-30._

---

## EIN format + Unified BMF — decided 2026-06-29 (record: `notes/ein-format-unified-bmf-decisions-2026-06-29.md`)

**Committed → execute downstream — GREEN-LIT: Jesse confirmed 2026-06-30** (consumer
sign-off on both calls — `EIN2` prefix "saves me a lot of headache" + "in favor of
retaining the Unified BMF name"; ADR 0022 consumer-notification obligation satisfied):**

| # | Task | Where | Status / notes |
|---|------|-------|----------------|
| E1 | Emit additive `ein_prefixed` (`ein-XX-XXXXXXX`) + `EIN2` (`EIN-XX-XXXXXXX`) columns; keep dashed `ein` **unchanged** | `nccs-data-bmf` (Unified BMF + ntee-resolved crosswalk) + `nccs-data-core` (CORE tiers) | **ADR 0036 — Reconciled (partial) 2026-06-30.** SHIPPED: BMF PR #28 (`fd0b366`) — ntee crosswalk **live** (20 cols); Unified BMF cols staged. CORE PR #11 (`f94d21e`, **OPEN**) — twin helpers byte-identical (verified). Contracts done: `conventions/ein-format.md` (6th rendering), `contracts/ntee-resolved-crosswalk.yml` (20 cols, amends 0034). PENDING: Unified BMF publish (gated on E2 path), BMF #28 + CORE #11 merges, CORE-tier contract reconcile, API schema bump. |
| E2 | Rename master → **Unified BMF**; non-silent supersession (both live 90 days → prior to retained reachable archive); per-build manifest | `nccs-data-bmf` + contracts | **ADR 0037 — Amended (path pinned) + Reconciled (partial) 2026-06-30.** SHIPPED (code, BMF PR #28 `fd0b366`): publish-under-`unified/` + 90-day non-silent supersession (`master/bmf/` reachable → archive 2026-09-28) + ADR 0014 `_manifest.json` (closes the old `bmf-master` manifest gap). Contracts done: `bmf-master.yml`→`unified-bmf.yml`, `ARCHITECTURE.md`. **RATIFIED path `unified/bmf/` + `bmf_unified` (INTERIM flat)** — DELTA: producer staged `unified/` (no `/bmf/`); must set `UNIFIED_S3_PREFIX="unified/bmf/"` before publish. PENDING: that publish, consumer notice, archive-key pin at cutover. Geocoded master NOT renamed (out of scope). |

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
