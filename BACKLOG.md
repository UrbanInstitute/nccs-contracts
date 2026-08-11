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

_Last updated: 2026-08-07._

---

## Legacy street recovery + re-geocode + address-resolved crosswalk — ADR 0041 (RECONCILED 2026-07-26)

Origin: user discrepancy report (nccs-inbox thread `2026-07-legacy-bmf-street-raw`;
producer issue `nccs-data-bmf#29`). All street-derived columns silently absent from
every `processed/bmf-legacy/` vintage; 58 vintages recoverable from raw `ADDRESS`.

**RECONCILED 2026-07-26** — S1-S6 executed and verified (see ADR 0041 Outcome):
55/55 vintages re-published + gate PASS; unified rebuilt (street legacy 0% -> 56.9%);
geocoded coverage 59.9% -> **82.7%** (+842,207 orgs); address log first-published
(11.45M spells, v2026_07 + latest); marts rebuilt; batch box terminated. ADR 0042
first versioned publishes live for all three artifacts.

**REVIEW DEBT (resilience-note throttle rule)**: open PRs awaiting maintainer:
bmf #32 #34 #35 #36 #37 #38 #39, core #12, contracts #66 #67 #68, website #90 #91.
Send-ready in nccs-inbox: Jesse email, Dylan reply, 3 triage replies.

**NEW FOLLOW-UPS**: report geocoder crash-alarm gap to UI-Research/techforms-geocoding
owners (incident 2026-07-26; procedure documented producer-side); consumer repoints
to latest/ (nccsdata + sector-in-brief-api; website in PR #91); delta-geocoding
address cache (etiquette doc, next cycle); ADR 0043 implementation (compat views +
legacy metadata tables in nccs-data-core) is the next build.

| # | Task | Where | Status / notes |
|---|------|-------|----------------|
| Z1 | ~~Rebuild + re-publish everything the ZIP defect touched~~ **DONE 2026-07-30** | `nccs-data-bmf` | Executed per ADR 0044 (see its Outcome): 85/85 vintages re-run (gate PASS), unified rebuilt (3.69M EINs), 60,257-address delta re-geocode + 2.53M carryover, marts rebuilt, address log re-published (11.30M spells, ~148k phantoms collapsed), `validate_address_crosswalk.R` all checks PASS (cross-source 15.82%, no state below floor). Box terminated. New follow-ups: batch-box role lacks geocoder-bucket PutObject (submit as maintainer); export script must check `system()` exit codes; `run_all_legacy.sh` exits 0 on all-fail; `setup_ec2.sh` missing `aws.ec2metadata`. |
| Z2 | Regenerate the BMF catalog and drop the ZIP caveat | `nccs` | After Z1. `catalogs/get-aws-files.R bmf`, re-render `catalog-bmf.qmd`, delete the warning callout added in nccs #92, refresh the coverage figure if re-geocoding moves it off 82.7%. |
| Z3 | Publish a data dictionary for the address-resolved crosswalk | `nccs-data-bmf` | No dictionary ships with the artifact today (probed: no `*_data_dictionary.csv` under `crosswalks/address-resolved/latest/`), unlike the Unified BMF. Columns are self-explanatory so this is not urgent, but every other published product has one. Fold into the Z1 re-publish if convenient. |
| Z4 | Fix the address-resolved publisher's default prefix | `nccs-data-bmf` | **PR OPEN 2026-08-05** — folded into Z13's bmf PR #41 (`include_csv` flag on `publish_crosswalk()`; wrapper defaults now write `v{vintage}/` + `latest/`; dry-run verified against the local 11.45M-row artifact). |
| Z5 | Sweep every `_manifest.json` for `bytes: "NA"` | `nccs-data-bmf` | The 2 GiB integer overflow (fixed in PR #37) wrote `"NA"` into manifests for any file over 2 GiB. The 2026-07-25 unified manifest was hand-corrected; nobody has checked the rest of the bucket. Needs SSO. |
| Z6 | New ADR: NTEE metadata table | `nccs-contracts` | Maintainer call on ADR 0043: NTEE hierarchy derivables belong in a dedicated NTEE metadata table, not a CORE-legacy one. The ADR must settle ownership rather than mint a third NTEE surface: `lookups/bmf/` already publishes `ntee_code`, `ntee_common_code`, `ntee_code_major_group`, `nteev2_subsector`, and `crosswalks/ntee-resolved/` carries per-EIN resolved NTEE (ADR 0034), both produced by `nccs-data-bmf` while the legacy NTEE columns are CORE-side. Ship a data dictionary with the table. |
| Z7 | New ADR: CORE-to-e-file record linkage | `nccs-contracts` | Maintainer call on ADR 0043: DLN cannot serve as the join key (present only 2000-2010 in PZ, 1999-2010 in PF, as DOCLOCNO 1997-1999), so it stops about where 990 e-file XML begins. Linking CORE rows to e-file filings needs a record-linkage procedure of our own. |
| Z8 | Implement the geocoder ledger and address cache | `nccs-data-bmf` | `docs/reference/geocoder-service.md` (PR #35) mandates a `geocode_ledger.tsv` and a persistent `f_address` cache; neither exists in code, so rules 3, 4, 6 and 7 are a checklist someone follows at 1am. The cache pays for itself at Z1: keyed on normalized `f_address`, the ~124k repaired addresses miss and resubmit while ~3.5M stay cached. |
| Z9 | Wire `report$passed` into a hard gate | `nccs-data-bmf` | `generate_quality_report()` computes it and neither pipeline reads it; `STRICT_QUALITY_GATES` only ever bound the pre-checks. That is why a transform could empty a column across 55 vintages and still report success. Not done with the ZIP fix because flipping it on would likely fail legacy vintages on pre-existing critical-field nulls, untested across the 55. Needs a dry run first. |
| Z10 | ADR note: `nccs-data-archive` made public-read | `nccs-contracts` | Bucket policy changed 2026-07-28: anonymous GetObject only (no ListBucket, ACLs still blocked). Contents audited: 117 objects, 9.89 GB, all superseded public-derived products. Changes the ADR 0037 supersession posture and turns those URLs into a retention commitment; needs an ADR note (amend 0037 or a short new ADR). |
| Z11 | Build the census-geo-resolved crosswalk (ADR 0045) | `nccs-data-bmf` | After Z1 (re-geocode moves ~124k coordinates). Per-EIN block GEOIDs (2010 + 2020 boundaries) via local point-in-polygon of geocoded lat/lon against TIGER/Line; point-level matches only; county-prefix consistency gate against the county-fips join. Demand: Milwaukee MSA, IL county, and the 2026-07-29 internal FIPS ask all reduce to "NCCS + census geography". |
| Z12 | Document the county-FIPS join recipe where users look | `nccs` + `nccsdata` | Recurring internal asks show people don't know FIPS is one crosswalk join away (and the API already serves `geo_county_fips` pre-joined). Add the recipe (label join; CT by coordinate) to the website catalog pages and the nccsdata vignette. Cheap, do before Z11 ships. |
| Z13 | Merge publisher must write `v{YYYY_MM}/` + `latest/` itself | `nccs-data-bmf` | **PR OPEN 2026-08-05** — bmf PR #41 (`ADR 0042` breadcrumb, contracts-guard green): `merge_master_geocoded_results()` writes `v{YYYY_MM}/` (parquet-only, Decision A) + `latest/` (full set) with per-prefix `_manifest.json`, idempotent sha256 vs the remote manifest; `merged/` + old `bmf-master/` stay as window dual-writes. Z4 folded in. **MERGED 2026-08-10** (+ review commit `78b9c17`: naming cleanups). Live verification DEFERRED by decision to the August monthly cycle: local re-merge would need reconstructed inputs (7/26 staged addr-lookup/batches predate the Z1 ZIP repairs; the box's regenerated inputs died with it) and a byte-different parquet would overwrite the verified 7/29 `latest/`. Recovery note: the Z1 delta geocoder output survives at `s3://geocoding-codestar-prod/data/output-data/thiya-1785360031-public.csv` (60,257 addresses; ledger in `geocoding/unified-bmf/runs/z1_2026_07/`). **VERIFIED LIVE 2026-08-11**: first machine-written publish of v2026_08/ (parquet-only + ADR 0014 manifest, git sha 6a7862c, 3,698,124 rows) + latest/ full set + both deprecated aliases; sha-skip idempotency observed live (v2026_08 parquet SKIP-unchanged on re-run). Run rode the 2026-08 monthly cycle (2026-07 vintage processed, unified rebuilt +10,689 EINs, 51,330-address delta geocode via the new delta script). **Z14 now unblocked.** Ops notes: geocoder engine wedged twice (see bmf#42-adjacent report to UI-Research/techforms-geocoding; form-JSON schema hypothesis), aws.s3::put_object OOM on multi-GB files fixed by CLI streaming in upload_to_s3. |
| Z14 | Repoint sector-in-brief-api + nccsdata to `geocoding/unified-bmf/latest/` | `sector-in-brief-api` + `nccsdata` | Both still read the pre-ADR-0039 `geocoding/bmf-master/merged/` path, alive only via dual-write until the 90-day window closes (~2026-10). Sequence AFTER Z13 (or the interim manual copy) so `latest/` is trustworthy first. Each PR needs its contracts-guard breadcrumb. Was prose in the ADR 0041 follow-ups; now a row. |
| S1 | XWALK `ADDRESS→STREET` fix + drop+alias crosswalk gate + exists()-guarded control flags + fail-loud manifest upload; PR with `ADR 0041` breadcrumb | `nccs-data-bmf` | Branch `fix/legacy-street-address-29`; validated on 2013-07 (8 additive cols, 0 removals, identical row count). PR opening 2026-07-24. |
| S2 | EC2 batch re-run + re-publish the **58** ADDRESS-carrying legacy vintages (skip the 30 street-less: output unchanged) | `nccs-data-bmf` | `run_all_legacy.sh` + SKIP_VINTAGES list; profile `thiya` provisions, role/exported creds on box. |
| S3 | Unified BMF rebuild (street value-backfill for legacy-sourced rows; schema unchanged) + by-`bmf_source` completeness tripwire in master quality report (ADR 0041 §5) | `nccs-data-bmf` | After S2. |
| S4 | Full geocoding cycle (export → Urban geocoder → merge): ~1.48M legacy-only orgs newly addressable; publish per **ADR 0039 ratified paths** (`geocoding/unified-bmf/`, `unified/bmf/state_marts/`), dual-write old paths only while 0039's window (from 2026-07-02) is open | `nccs-data-bmf` | Manual two-phase workflow; the expensive step this batch was bundled around. |
| S5 | Build + first publish `crosswalks/address-resolved/` (ADR 0034 pattern); populate `contracts/address-resolved-crosswalk.yml` from the artifact | `nccs-data-bmf` + contracts | Blocked on S2 (needs street in legacy intermediates). |
| S6 | Reconcile here: ADR 0041 Outcome, contract population, this board; reply to reporter (drafted in nccs-inbox); note pre-2010 geocoding-coverage caveat improvement for the Milwaukee request docs | contracts + nccs-inbox | At the end. |
| S7 | ADR 0042 (Proposed): vintage retention + latest/ for unified/geocoded/metadata tables; long-format address log (amends 0041 §4); docs-automation CI; validation gate. Two decision points await maintainer in the PR | contracts + `nccs-data-bmf` | Drafted 2026-07-25; evidence incl. Capital One v1.1 breakage (unknown consumer, no notice). |

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
| L1 | ~~Complete ADR 0032 — full legacy NTEE reprocess~~ | *closed* | **✅ DONE 2026-07-02.** All 85 in-scope legacy vintages reprocessed; `Z99` share 58.2% → **23.79%** (better than the ~30.7% projection). Unified BMF rebuilt + republished off the corrected data (commit `3695028`, same row count — corrects values in place). See ADR 0032 Outcome. |
| G1 | ~~Fix geocoding path; rebuild + rename + publish geocoded Unified BMF + state marts~~ | *closed* | **✅ DONE 2026-07-02** (`nccs-data-bmf` PR #28, commit `3695028`). Verified independently against live S3: `geocoding/unified-bmf/merged/` + `unified/bmf/state_marts/` live, dual-written alongside the old paths (byte-identical), `_manifest.json` closes the long-open Open item #1. Bonus fixes in the same PR: S3 `Content-Type` (quality reports were forcing downloads), quality-report index silently omitting the Unified BMF report, 87 backfilled quality-report HTML files. **PR #28 open, checks green, awaiting merge** — hold until nothing else needs to land in the same batch (don't merge piecemeal). See ADR 0039 Outcome. |
| G2 | Repoint `nccsdata::nccs_read()` to the new geocoded path | `nccsdata` | **UNBLOCKED 2026-07-02** — G1's publish confirmed live. Hardcoded at `R/nccs_read.R:401` (S3 URI) + `:407` (HTTPS mirror) — `geocoding/bmf-master/merged/bmf_master_geocoded.parquet` → `geocoding/unified-bmf/merged/bmf_unified_geocoded.parquet`. Not urgent (old path stays live through the 90-day window) but ready to prompt whenever. |
| G3 | Repoint `sector-in-brief-api`'s hardcoded geocoded-BMF read | `sector-in-brief-api` | **UNBLOCKED 2026-07-02** — same as G2. Same path swap, DuckDB query-time read. Ready to prompt whenever. |
| R1 | Run the ADR 0028 wholesale relational extraction on EC2 + publish | `nccs-data-efile` | **Found 2026-07-01 (reconcile-lag sweep, ADR 0038).** Architecture ADR (producer `decisions/0004`) + extractor + scale-build/publish path + EC2 runbook are all built and merged (PRs #13/#15/#16, `87eb274`, 2026-06-12) — but the run itself never happened. Verified: `s3://nccsdata/processed/efile/relational/` doesn't exist. Same shape as the BMF geocoding gap (G1) — built, waiting on an operator run on a capable host. The raw tier is uncontracted by design (ADR 0028 §4) so this doesn't need a contracts PR to *publish*, only to register once it's live (`contracts/efile.yml` already reconciled to describe the two-tier direction ahead of that). |
| P1 | ~~Promote the Milwaukee MSA request to a public data story~~ | *closed* | **✅ DONE 2026-07-01** — `nccs` PR #89 merged (`nccs-data-requests/requests/2026-06-milwaukee-msa/request.qmd` → `nccs/_stories/milwaukee-metro-nonprofits.qmd`). Surfaced a real ADR 0025 Follow-up #2 gap in the process (promoted `.qmd` sources a `nccs-data-requests`-local helper, won't re-render standalone inside `nccs`) — resolved as a documentation clarification (ADR 0025 amended: the `.md` is the portable artifact, the `.qmd` re-renders from origin), no code changes needed. See ADR 0025 Outcome. |
| P2 | Add a short comment to `nccs/_stories/milwaukee-metro-nonprofits.qmd` noting the `source()` line only resolves from `nccs-data-requests` | `nccs` | **New, 2026-07-01.** Low-priority documentation follow-up from the ADR 0025 amendment above — so a future person doesn't hit a confusing error trying to `quarto render` the promoted copy in place. Not urgent; batch with other `nccs` work. |
| C1 | ~~Confirm `sector-in-brief-data`/`core-panel` read core parquet~~ | *closed* | **✅ CLOSED 2026-07-01, no repo work needed.** Verified directly: `sector-in-brief-data` (`R/read_core.R::core_pf_paths`) and `sector-in-brief-api` (`query/query.py:121`) both already read `.parquet` exclusively for `core-990` and `core-panel` — no CSV reads anywhere. `run_build_panel.R` (core-panel's producer) doesn't read the published core-990 artifact at all, so there was never a migration question there. The *actual* gap found: `contracts/core-panel.yml` itself still said `format: csv` despite parquet being live since ≥2026-05-20 — fixed via **ADR 0040** (extends ADR 0027 to core-panel). |
| 3 | Make harmonized CORE datasets more visible on the NCCS website | `nccs` | Not started. Batch with #4–#6 (all `nccs`). |
| 4 | Link/mention the bmf + core crosswalks on the website's BMF & CORE pages | `nccs` | BMF page: geography crosswalks (`county-fips`/`cbsa`/`ct-planning-region`) + `ntee-resolved`. CORE page: the legacy→harmonized crosswalks (live in the producer repos). |
| 5 | CORE page copy: parallel datasets use different column names (beginner accessibility); harmonized CORE remains available on site | `nccs` | Copy task. |
| 5b | Contact-page deflection for misdirected NTEE-assignment emails | `nccs` | **New 2026-08-10** (nccs-inbox thread `2026-08-ntee-misdirected-requests`; several/week per Thiya). The deflection content already exists at `_resources/ntee.md`; the gap is routing: add an "Applying for tax-exempt status / need an NTEE code?" callout on the contact page linking `resources/ntee/`, plus a form dropdown category whose NTEE/IRS option shows the deflection inline or fires a Formspree auto-reply (pattern per inbox thread `2026-07-formspree-delivery`). Keyword-sniffing free text rejected (false positives on real data questions). Canned reply template lives in the inbox thread. Batch with #3-#5 or Z2. |
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

## NODC SOI-harmonization interoperability — ADR 0046 (Proposed 2026-08-06)

Origin: Jesse's public repo `Nonprofit-Open-Data-Collective/soi-extract-harmonization`
(pinned review SHA `8632a5f`) independently harmonizes the same SOI extracts to NODC
`F9_*` names, consumes our `BMF_UNIFIED_V1.1.csv`, and references an uncontracted
write at `raw/soi/processed_plus_bmf/`. All work below is unilateral (no ask of Jesse).

| # | Task | Where | Notes |
|---|------|-------|-------|
| C1 | Ratify ADR 0046; review draft concordance in `notes/adr-0046-concordance-draft/` | nccs-contracts | Draft composes 345/345 SOI 990+EZ vars across both harmonizations; 132 carry legacy PZ names. |
| C2 | Build + publish `lookups/variable-concordance/` (vYYYY.MM + latest, manifest, dictionary) | nccs-data-core | Snapshot NODC crosswalk at recorded upstream SHA. PF = future extension. |
| C3 | Land EIN2/ein_prefixed in CORE outputs (ADR 0036, pending core PR #11 checklist item) | nccs-data-core | Now also the join key to NODC-keyed workflows; priority raised. |
| C4 | Provenance note in workspace `DATA-LIFECYCLE.md`: external BMF v1.1 pin + `raw/soi/processed_plus_bmf/` observation | workspace root | Documentation only, no contract. |

## ODC-BY licensing alignment (Steven Jones inquiry; Legal confirmed 2026-08-06)

Origin: external commercial-use question via datacatalog inbox; catalog says ODC-BY,
NCCS terms page said "personal use only" (legacy GuideStar-era boilerplate, per Boris).
Sarah Trumble (Legal) confirmed ODC-BY governs. Reply sent to Steven 2026-08-07.

| # | Task | Where | Notes |
|---|------|-------|-------|
| L1 | Commit + deploy terms page update (new §3.5 ODC-BY carve-out, renumbered §3.6/§3.7) | `nccs` | Edited in working tree 2026-08-07, uncommitted. Delete or re-render stale root `terms.html` in same commit. Optionally run §3.5 wording past Sarah first. |
| L2 | Flag to Graham (datacatalog) once live so he can note it catalog-side | email | Catalog entry itself unchanged by design. |

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
