# Backlog — NCCS data system (prioritized next steps)

The maintainer's living to-do list, kept here because the workflow is: **boot the
`nccs-contracts` session first → plan against this list → execute in the downstream
repo → report back here and update this file.**

Maintenance: update at the **reconcile** step of each task (the three-phase loop in
`CONTRIBUTING.md`), ideally in the same PR as the work. `[where]` tags the repo a task
executes in. Keep the order = priority order.

_Last updated: 2026-06-26._

---

## ✅ Recently shipped (so we don't redo)

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
| 12 | Draft ADRs as the first July quarterly agenda | The 5 ADR-NEEDED items: master BMF versioning + `/latest`; NTEE backfill into master; modular `_nccs` metadata datasets (ratifies #7/#8); nccsdata optional-merge; quarterly governance cadence + decision-split taxonomy + auto-gen decision doc. |
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
