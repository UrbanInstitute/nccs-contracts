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

_Last updated: 2026-09-16._

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
| Z1 | ~~Rebuild + re-publish everything the ZIP defect touched~~ | `nccs-data-bmf` | **DONE 2026-07-30** per ADR 0044 Outcome (85/85 vintages, unified 3.69M EINs, delta re-geocode, marts, address log). Detail: BACKLOG-ARCHIVE.md. Open follow-ups tracked as Z8 (done), batch-box role, exit-code checks. |
| Z2 | ~~Regenerate the BMF catalog and drop the ZIP caveat~~ | `nccs` | **DONE 2026-09-15** (nccs #97: file list refreshed, ZIP warning removed, coverage figure 82.7% confirmed, data changelog added; refreshed again in #98, #99, #100). Row closed 2026-09-16 during housekeeping. One part was NOT done and moves to Z24: the website e-file catalog still points at v2_1. |
| Z3 | Publish a data dictionary for the address-resolved crosswalk | `nccs-data-bmf` | No dictionary ships with the artifact today (probed: no `*_data_dictionary.csv` under `crosswalks/address-resolved/latest/`), unlike the Unified BMF. Columns are self-explanatory so this is not urgent, but every other published product has one. Fold into the Z1 re-publish if convenient. |
| Z4 | ~~Fix the address-resolved publisher's default prefix~~ | `nccs-data-bmf` | **DONE** — merged in bmf #41 with Z13. Detail: BACKLOG-ARCHIVE.md. |
| Z5 | Sweep every `_manifest.json` for `bytes: "NA"` | `nccs-data-bmf` | The 2 GiB integer overflow (fixed in PR #37) wrote `"NA"` into manifests for any file over 2 GiB. The 2026-07-25 unified manifest was hand-corrected; nobody has checked the rest of the bucket. Needs SSO. |
| Z6 | New ADR: NTEE metadata table | `nccs-contracts` | Maintainer call on ADR 0043: NTEE hierarchy derivables belong in a dedicated NTEE metadata table, not a CORE-legacy one. The ADR must settle ownership rather than mint a third NTEE surface: `lookups/bmf/` already publishes `ntee_code`, `ntee_common_code`, `ntee_code_major_group`, `nteev2_subsector`, and `crosswalks/ntee-resolved/` carries per-EIN resolved NTEE (ADR 0034), both produced by `nccs-data-bmf` while the legacy NTEE columns are CORE-side. Ship a data dictionary with the table. **ADR 0048 note:** the NTEE metadata ADR should also state a per-EIN resolution rule (NODC precedent: bmf_current / modal / most_recent / bmf_only + `ntee_rule` column); `ntee_agreement = mixed` for ~21-31% of EINs. |
| Z7 | New ADR: CORE-to-e-file record linkage | `nccs-contracts` | Maintainer call on ADR 0043: DLN cannot serve as the join key (present only 2000-2010 in PZ, 1999-2010 in PF, as DOCLOCNO 1997-1999), so it stops about where 990 e-file XML begins. Linking CORE rows to e-file filings needs a record-linkage procedure of our own. |
| Z8 | ~~Implement the geocoder ledger and address cache~~ | `nccs-data-bmf` | **DONE 2026-08-11** — bmf #43 merged (`R/master_geocoding_delta.R`; windowed submission, S3-synced fail-closed run state, run-stamped retention; rule-7 cache = published-artifact carryover). Detail + residuals: BACKLOG-ARCHIVE.md. |
| Z9 | ~~Wire `report$passed` into a hard gate~~ | `nccs-data-bmf` | **DONE 2026-09-16** (nccs-data-bmf PR #53 merged; verified on main). Both the monthly and the legacy runner stop before any upload when the quality report fails; `STRICT_QUALITY_GATES <- FALSE` is the deliberate override. The report was too weak to have caught the July ZIP defect (it only checked row counts and empty EINs), so it gained a check: a preserved column (identifier, pass-through copies, cleaned address parts, money amounts) that is completely empty after transformation while its source had values fails the report. Optional derivations such as ZIP+4 are outside the check, so a file of five-digit ZIPs does not fail; partial loss is reported, not gated (decided 2026-09-16, keep for now). Dry run: of the 121 published months, 120 pass the existing checks and one fails (June 1996 legacy: 21 rows with an empty EIN); the July 2026 file ran end to end locally under the gate and passed. **Open decision:** the 21 empty-EIN rows in June 1996 if that month is ever rebuilt. |
| Z10 | ADR note: `nccs-data-archive` made public-read | `nccs-contracts` | Bucket policy changed 2026-07-28: anonymous GetObject only (no ListBucket, ACLs still blocked). Contents audited: 117 objects, 9.89 GB, all superseded public-derived products. Changes the ADR 0037 supersession posture and turns those URLs into a retention commitment; needs an ADR note (amend 0037 or a short new ADR). |
| Z11 | Build the census-geo-resolved crosswalk (ADR 0045) | `nccs-data-bmf` | After Z1 (re-geocode moves ~124k coordinates). Per-EIN block GEOIDs (2010 + 2020 boundaries) via local point-in-polygon of geocoded lat/lon against TIGER/Line; point-level matches only; county-prefix consistency gate against the county-fips join. Demand: Milwaukee MSA, IL county, and the 2026-07-29 internal FIPS ask all reduce to "NCCS + census geography". |
| Z12 | Document the county-FIPS join recipe where users look | `nccs` + `nccsdata` | Recurring internal asks show people don't know FIPS is one crosswalk join away (and the API already serves `geo_county_fips` pre-joined). Add the recipe (label join; CT by coordinate) to the website catalog pages and the nccsdata vignette. Cheap, do before Z11 ships. |
| Z13 | ~~Merge publisher writes `v{YYYY_MM}/` + `latest/` itself~~ | `nccs-data-bmf` | **DONE; VERIFIED LIVE 2026-08-11** (bmf #41 merged; first machine-written v2026_08/ + latest/ publish, sha-skip observed). Detail + ops notes: BACKLOG-ARCHIVE.md. Z14 unblocked. |
| Z14 | ~~Repoint sector-in-brief-api + nccsdata to `geocoding/unified-bmf/latest/`~~ | `sector-in-brief-api` + `nccsdata` | **DONE 2026-09-16.** The R package (nccsdata #25) and the download API (sector-in-brief-api #21) now read the geocoded Unified BMF from `geocoding/unified-bmf/latest/`, and the contract records this. Before the change we checked that the old and new locations held identical files and that the new file downloads without AWS credentials. This also closes G2 and G3. Two side findings went to Z22: the API repository does not run the contract-change check, and the R package's local download usually times out. The old `geocoding/bmf-master/` location can be archived on 2026-09-30, which is 90 days after the geocoded data set was first published at the new location on 2026-07-02 (ADR 0039). The 2026-09-28 date applies to the plain, un-geocoded Unified BMF under `master/bmf/`. |
| Z16 | ~~Fix the NTEEV2 x00 rule + pre-0032 stale vintages — ADR 0048~~ | `nccs-data-bmf` then `nccs` | **DONE; PUBLISHED 2026-09-15** (bmf #46, contracts #81; reprocess 86 legacy + 35 current-monthly, criterion D both stages pass, all surfaces republished as vintage 2026_09 / git_sha `dbf33ae`). Outcome + numbers in ADR 0048; release note FINAL. Follow-ups split out as Z19-Z21. Z2 catalog re-render now unblocked. Notify Jesse (panel990 reads `latest/`) and Lily. |
| Z19 | ~~Per-state CSV file name: finish the ADR 0039 rename (`bmf_master_{ST}.csv` to `bmf_unified_{ST}.csv`)~~ | `nccs-data-bmf` then `nccs` | **DONE 2026-09-16** (nccs-data-bmf #51, nccs-contracts #85, nccs #100 all merged). Decision: rename, with both names published for 90 days. Background: the contract named the files `bmf_unified_{ST}.csv` since ADR 0039 (July), but the pipeline kept writing `bmf_master_{ST}.csv`, and the September 15 republish carried the old name. Nothing of ours reads the files by name; website visitors download them by link. Steps: (1) nccs-data-bmf writes both names through 2026-12-15 and only the new one from 2026-12-16, and stops writing the old `master/bmf/state_marts/` folder after 2026-09-30 (PR #51); (2) copy the 63 live files to the new name on S3 so the window starts now (PENDING, needs maintainer go-ahead; verify with anonymous HEAD on each new name); (3) re-render the website BMF catalog so it lists the new names; (4) from 2026-12-16 the old name is no longer written; delete the code marked TEMPORARY in `R/master_state_marts.R` (the two cutover constants, `state_mart_s3_roots()`, `state_mart_write_old_stem()`, the `retired_name` argument) and the S3 README line about the old name. Maintainer direction 2026-09-16: documentation describes only the `unified/` locations from now on; the old `master/` folder is not mentioned. |
| Z20 | ~~Legacy vintage inventory mismatches surfaced by the ADR 0048 reprocess~~ | `nccs-data-bmf` | **DONE 2026-09-16** (nccs-data-bmf PR #52). (a) The December 2018 legacy file stays published and is removed from the default skip list in `run_all_legacy.sh`. It had been skipped because an older reading of the file found made-up sequence numbers in the EIN column; the September 15 reprocess shows the current pipeline reads real EINs (1,499,450 rows, every EIN valid, 2,960 duplicate EINs, quality check passed). The other two skipped months (September and December 2017) stay unprocessed by maintainer decision on 2026-09-16: their tax period column holds no dates (checked directly; the old note blaming the EIN column was wrong), so their rows cannot be tied to a tax year. The source files stay in `legacy/bmf/` because other columns, such as addresses, may still be useful. (b) The master build now checks that every month folder under `processed/bmf/` and `processed/bmf-legacy/` contains its processed CSV and stops if one does not, naming the folders. An override flag (`ALLOW_INCOMPLETE_VINTAGES=TRUE`) turns the stop into a warning for a deliberate partial build. Checked 2026-09-16: 35 of 35 current and 86 of 86 legacy folders are complete. |
| Z21 | ~~EC2 batch hardening from the ADR 0048 run~~ | `nccs-data-bmf` | **DONE 2026-09-15, recorded 2026-09-16** (nccs-data-bmf PR #47, merged 2026-09-15). Covered: the setup script installs the metadata package that works on newer EC2 boxes; the three runners can be run without uploading to S3 by setting a flag; the lookup publisher loads the manifest code it needs; lessons written up in `docs/reference/ec2-lessons.md`. The 100 GB before-snapshot under `intermediate/tmp/` is gone (checked 2026-09-16). Two items remain outside code and are carried as open threads, not tasks: the batch role still cannot reach the geocoder bucket (needs an account admin), and the quality-report page does not render on the box (it was refreshed from a laptop on 2026-09-15). |
| Z22 | Two small fixes found during Z14: the R package's local download times out, and the API repository skips the contract-change check | `nccsdata` then `sector-in-brief-api` | **New 2026-09-16.** (a) When a user asks `nccs_read()` to keep a local copy of the geocoded BMF (641 MB), R gives the download only 60 seconds by default. On an ordinary connection that is not enough, so the local copy is never completed, the function quietly reads from S3 instead, and unfinished `.part` files pile up in the cache folder. Fix: allow the download more time, or use the `curl` package (already an optional dependency) which does not have this limit. (b) Every other repository runs an automated check on each pull request that touches a published data location, requiring the pull request to name the decision record (ADR) behind the change. The `sector-in-brief-api` repository has never had this check (ADR 0022 expects it). Add it. |
| Z23 | Plan to bring the e-file DuckDB archive build in-house | `nccs-contracts` then `nccs-data-efile` | **New 2026-09-16**, from the Z17 ownership decision. Today NODC's ef2 package builds the per-year database files that many users attach directly, and NCCS only hosts them (contract `efile-duckdb-archives`). NCCS wants to own that process eventually so the files can be an NCCS product with NCCS validation and versioning. No date. First step when picked up: a short decision record comparing (a) re-running ef2 under NCCS control, (b) producing the same per-year files from the NCCS relational extraction (ADR 0028), and (c) leaving them as a hosted external product for good. Talk to the producer before drafting. |
| Z24 | Website e-file catalog: list the v2_2 archives | `nccs` | **New 2026-09-16**, left over from Z2. The e-file data set page links to `catalogs/catalog-efile-v2_1.html`, and the catalog file list (`AWS-NCCS-EFILE-V2.csv`) only lists `efile_v2_0` files, while the newest archives are `efile_v2_2` (written 2026-08-11; see contract `efile-duckdb-archives`). Add or update the catalog page for v2_2, refresh the file list, and repoint the data set page. Say on the page that these archives are built by NODC and hosted by NCCS (ownership decision 2026-09-16). |
| Z17 | ~~Register NODC-published surfaces as contracted producer entries (register, don't ask)~~ | `nccs-contracts` | **DONE 2026-09-16** (PR #87). Two contract files written from direct listings: `npmatch-sources` (the folder under `crosswalks/npmatch/`: 10 files, 6.2 GB; owner NODC) and `efile-duckdb-archives` (per-year DuckDB files under `nccs-efile/duckdb/`, three versions, about 800 GB; owner NODC). Column-stability statement added to `unified-bmf`; NODC packages recorded as consumers there and on the geocoded contract (panel990 moved to `latest/` on 2026-09-02; its per-state fallback still uses the old `bmf_master_XX.csv` file name, which stops after 2026-12-15). Entry for the September minutes in `governance/decisions-pending.md`. **Ownership decided 2026-09-16 (chair):** the e-file archives are not an NCCS product because NCCS does not own the process; in-housing is a future plan, tracked as Z23. Weekly NODC audit routine (`trig_0167fGTULdcCEGHyPVYCPk4b`) files PRs under `governance/nodc-audits/`. |
| Z18 | 12 NTEE-CC codes missing from the `ntee_code` lookup sheet (incl. B29 charter schools) | `nccs-data-bmf` | **DONE 2026-09-21.** nccs-data-bmf #54 (lookup fix, IRS list, runbook) and #55 (per-file before/after checker) merged. All 121 months reprocessed 2026-09-17 with the checker passing on every file: 379,258 row-observations changed (legacy 208,458, current 170,800; July 2026 5,521). Unified BMF, geocoded build, 63 state marts, lookups and NTEE-resolved crosswalk rebuilt and published 2026-09-21 as vintage 2026_09 (git_sha 1b1f8a9); 8,184 Unified rows changed, all Z99 before. Release note: `governance/release-notes/ntee-missing-codes-correction.md` (FINAL). June 1996 ran with the quality-gate override (Z27). Follow-ups: Z25, Z26, Z27, Z28; delete the before-snapshot at `intermediate/tmp/z18_before/` (144 GB) once the release note is accepted. |
| Z25 | **Recurring, yearly (January):** check the NTEE code list against the IRS | `nccs-data-bmf` | **New 2026-09-17** (from Z18). The IRS adds codes without notice (seven added in 2021 went unnoticed until 2026). Nothing automated catches this. Procedure: `docs/runbooks/ntee-code-list-yearly-refresh.md` in nccs-data-bmf (run `scripts/refresh_ntee_lookup_from_irs.R`, review the printed differences, add rows by hand, measure, PR, reprocess). Also run it whenever a monthly quality report shows unrecognized raw codes. Last run: 2026-09-17 (IRS rev. 12/2024, 12 codes added). Next due: January 2027. Add to the governance calendar. |
| Z26 | Website "IRS version" NTEE list is out of date | `nccs` | **PR OPEN 2026-09-21** (nccs #101). The gap is 24 codes, not seven: all the IRS 2021 additions (food retail K6A-K6F and K90-K98, camps N2A/N2B, E6A, K2A-K2C, L4A/L4B, P7A). `data-raw/data.R` now supplements the NODC crosswalk from `irs_ntee_codes.csv` in nccs-data-bmf and stops if a new IRS code has no NAICS match. NAICS for the 24 taken from the NAICS 2022 industry with the same title (maintainer to check). Decision: P72 **kept** as a retired code with a note, matching the bmf lookup sheet. Follow-ups: (a) the sibling widgets `ntee1_table` and `ntee_descriptions` read the NODC file directly and also lack the 24 codes; (b) the bmf `ntee_code` sheet still has 16 of these codes with NAICS UNDEFINED and could copy the table from the website script. |
| Z29 | Make the `ntee_code` lookup the public NTEE-NAICS crosswalk (long descriptions, NAICS filled, website reads it, dataset page + download) | `nccs-contracts` → `nccs-data-bmf` → `nccs` | **ADR 0049 Proposed 2026-09-21** (from Z26). Maintainer chose 2026-09-21: download lives in the contracted `lookups/bmf/latest/ntee_code.csv`; widget rebuilt as a site-themed DT table with download button and major-group filter; new `_datasets/ntee.md` in the Data grid. Steps: bmf script adds `ntee_code_description` (NODC text) + fills 17 UNDEFINED NAICS, republish lookups; nccs widget reads S3, dataset page, delete `data-raw` copies; reconcile here. |
| Z30 | Self-service NTEE lookup by EIN on the website (sharded JSON EIN index) | `nccs-contracts` → `nccs-data-bmf` → `nccs` | **ADR 0050 Accepted; producer DONE and index PUBLISHED 2026-09-21** (nccs-data-bmf #58 merged; `unified/bmf/ein-index/v2026_09/` + `latest/`, 4,420 shards, 3,698,197 organizations, 140 MB; rerun uploads nothing). Website page nccs #107 pending. (Maintainer's idea in the nccs #103 review; shape chosen 2026-09-21: sharded JSON on S3 by four-digit EIN prefix, NTEE plus basic identity). Contract `bmf-ein-index.yml` (deferred until published). Steps: bmf builds `unified/bmf/ein-index/latest/{prefix}.json` from the geocoded Unified BMF, gzipped, manifest, hooked after the geocoded merge; nccs adds `/datasets/ntee/lookup/`. Out of scope: name search (API, ADR 0026). |
| Z27 | Empty-EIN quality check: threshold instead of any-row failure | `nccs-data-bmf` | **New 2026-09-17** (from the Z18 reprocess). June 1996 legacy has 21 rows with no EIN out of about 1.4 million, and the hard gate (Z9) stops the month for that. Maintainer view 2026-09-17: a handful of blank source rows should not reject a vintage; the rows carry the EIN-missing flag and cannot join to anything. Change the empty-EIN check to a small threshold (proposed: 1 in 10,000 rows) with the count always reported; the emptied-column check from Z9 stays as is. Until then June 1996 is reprocessed with the gate override, logged as a deliberate exception. |

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
| G2 | ~~Repoint `nccsdata::nccs_read()` to the new geocoded path~~ | `nccsdata` | **DONE 2026-09-16** as part of Z14 (nccsdata #25). |
| G3 | ~~Repoint `sector-in-brief-api`'s hardcoded geocoded-BMF read~~ | `sector-in-brief-api` | **DONE 2026-09-16** as part of Z14 (sector-in-brief-api #21). |
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
| 10 | ~~Branch protection on all core repos~~ **DONE 2026-08-11** | core repos | **ADR 0047 ratified + applied** (contracts #76): `branch-protection-baseline` ruleset ACTIVE on all 7 maintainer-admin repos — PRs required for every role (admin bypass = pull_request mode: self-merge yes, direct push no), 1 review for non-admins, contracts-guard required where the caller exists (6/7), force-push/deletion blocked. Approver policy decided: 'self' (revisit on second committer). Absorbs ADR 0022 step-4. Follow-up: `nccs` repo excluded (maintainer lacks admin; external collaborator holds it) — org-owner ask or admin-applied. |
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
| C1 | Ratify ADR 0046; review draft concordance in `notes/adr-0046-concordance-draft/` | nccs-contracts | Draft composes 344/344 unique (SOI var, form) keys across both harmonizations (year-split rows collapsed per review 2026-08-11); 131 carry legacy PZ names. |
| C2 | Build + publish `lookups/variable-concordance/` (vYYYY.MM + latest, manifest, dictionary) | nccs-data-core | Snapshot NODC crosswalk at recorded upstream SHA. PF = future extension. |
| C3 | Land EIN2/ein_prefixed in CORE outputs (ADR 0036, pending core PR #11 checklist item) | nccs-data-core | Now also the join key to NODC-keyed workflows; priority raised. |
| C4 | Provenance note in workspace `DATA-LIFECYCLE.md`: external BMF v1.1 pin + `raw/soi/processed_plus_bmf/` observation | workspace root | Documentation only, no contract. |

## ODC-BY licensing alignment (Steven Jones inquiry; Legal confirmed 2026-08-06)

Origin: external commercial-use question via datacatalog inbox; catalog says ODC-BY,
NCCS terms page said "personal use only" (legacy GuideStar-era boilerplate, per Boris).
Sarah Trumble (Legal) confirmed ODC-BY governs. Reply sent to Steven 2026-08-07.

| # | Task | Where | Notes |
|---|------|-------|-------|
| L1 | ~~Commit + deploy terms page update (new §3.5 ODC-BY carve-out, renumbered §3.6/§3.7)~~ | `nccs` | **DONE 2026-08-10** (commit 46bfcbf on main; stale `terms.html` removed). Row closed 2026-09-16 during housekeeping. |
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
