# 0010 — `sector-in-brief-data` Replaces `nccs-dataexplorer-data`

- **Status:** Accepted (executed 2026-05-21; two panels deferred to a future ADR — see Outcome)
- **Date:** 2026-05-19
- **Deciders:** sole maintainer
- **Supersedes:** the 2026-05-15 draft of ADR 0010 (`0010-dataexplorer-data-as-derived-producer.md`) — this revision changes the decision shape after on-disk recon corrected several premises.
- **Related:** [[0005-bmf-unified-superseded-by-master]], [[0008-modernize-dataexplorer-api]], [[0009-sector-in-brief-dashboard-hygiene]], [[0011-decouple-dashboard-from-committed-data]], [[0012-sector-in-brief-architecture-refactor]]

## Context

The 2026-05-15 draft of this ADR proposed promoting `UrbanInstitute/nccs-dataexplorer-data` to a contracted derived producer in place. A 2026-05-19 on-disk recon of the repo (`git fetch` on a fresh clone, S3 reads against actual prefixes, schema dumps of the actual parquet outputs, and full reading of `R/options_nogeo.R` in the consuming dashboard) corrected several premises the prior draft was built on:

1. **The repo is not in a maintainable state.** The current clone showed 51 commits of upstream drift hidden by a stale `git status`, a 16-file CRLF↔LF mirage from `core.autocrlf` being unset, two untracked R scripts that are stale local drafts of work already merged upstream under different filenames, and one untracked benchmarking spike. The "real edit" to `R/derive_ein2.R` is duplicate work — origin commit `3d0ab39` already made the same `stringr::str_pad` refactor and renamed the file to `R/format_ein.R`. The repo's structural problems (hardcoded `nccs-dataexplorer-data/...` paths assuming a specific cwd, no functions/package boundary, no tests, inconsistent column-naming across outputs, vestigial `rapidxml-1.13/` vendoring with zero references) are not worth fixing in place.

2. **`s3://nccsdata/sector-in-brief/` is not currently produced by this repo.** Recon found zero references to `sector-in-brief/` in any reachable git history of `nccs-dataexplorer-data` other than README hyperlinks to the dashboard repo. The 2024-09 contents at that prefix are a previous-generation artifact (predecessor of the current `R/` scripts, per [[0011-decouple-dashboard-from-committed-data]]) that has been frozen since the producer moved to `dataexplorer/visuals/`. Either way, no live code path writes there today.

3. **The BMF "broken upstream" is real but it is a translation contract, not a path swap.** `s3://nccsdata/harmonized/bmf/unified/` is confirmed empty. The replacement (`bmf-master-geocoded`) uses lowercase snake_case columns (`ein, nteev2, subsection_code, asset_amount, geo_state_abbr, geo_county`); the pipeline expects Title Case derived columns (`EIN2, NTEEV2, BMF_SUBSECTION_CODE, F990_TOTAL_ASSETS_RECENT, CENSUS_STATE_ABBR, CENSUS_COUNTY_NAME, CENSUS_CBSA_NAME, NCCS_LEVEL_1, ORG_YEAR_FIRST, ORG_YEAR_LAST`). Three of those (`NCCS_LEVEL_1`, `ORG_YEAR_FIRST`, `ORG_YEAR_LAST`) have to be derived from new-BMF fields; one (`CENSUS_CBSA_NAME`) has no direct equivalent in the master products and needs a CBSA crosswalk or a swap to the geocoder's `geo_*` taxonomy.

4. **Current outputs (`dataexplorer/visuals/v1.1/`, vintage 2025-05-20) are structurally close to what the dashboard needs but cosmetically inconsistent.** Six parquets (`daf, finances, gov_grants, number_nonprofits, pf_grants, pf_pri`) and two CSVs (`nested_geographies, panel_dd`). All carry the same dimension columns (`Organization Type, Subsector, Size, Census Region, Census State, Census County, Metro/Micro Area`) except inconsistencies: `pf_pri.parquet` uses SCREAMING_SNAKE (`TAX_YEAR`, `PRI_TOTAL`) while every other file uses Title Case (`Tax Year`); the year column is sometimes `Year` (number_nonprofits), sometimes `Tax Year` (everything else), and its dtype is sometimes `int32` (number_nonprofits), sometimes `double` (everything else); `Size` is an ordinal 0–6 code stored as `double`. Two panels documented in `R/nav_panel-visuals.R` of the dashboard (Government Grants, Program Related Investments) are not yet wired in `R/data_server_args.R`.

5. **Naming.** "dataexplorer" was always misleading. The repo serves exactly one consumer (the sector-in-brief Shiny dashboard); a separate dataexplorer API surface exists but is governed by [[0008-modernize-dataexplorer-api]] and is out of scope. Naming the producer after its consumer is clearer and aligns with the existing contract filename (`contracts/sector-in-brief.yml`).

## Decision

Stand up a fresh repository, **`UrbanInstitute/sector-in-brief-data`**, that replaces `nccs-dataexplorer-data` as the producer of the dashboard-facing artifact. Once the new repo publishes a vintage that matches the current `dataexplorer/visuals/v1.1/` outputs on a regression set, archive `nccs-dataexplorer-data` (GitHub archive flag + README redirect) and migrate the dashboard ([[0011-decouple-dashboard-from-committed-data]]) to read from the new prefix.

### Repo shape

The new repo is structured as an R package (or, at minimum, sourced functions in `R/` plus runnable scripts in `pipeline/`) with:

- **Configuration at the top.** A single `config.yml` (or `inst/config.yml`) holds input S3 paths, output S3 path, vintage tag, and year ranges. No hardcoded relative paths anywhere in the R code. The "must be run from the parent directory of the repo" footgun is eliminated.
- **Pure derivation functions, tested.** The four business-logic transforms (`derive_census_region`, `derive_organization_type`, `derive_subsector`, `derive_size`) and the EIN formatting helpers (`format_ein`, `derive_ein2`) move into `R/` as pure functions with fixture-backed tests. These encode correctness inherited from the old pipeline — port them verbatim and test them.
- **One canonical dimension schema** used by every output parquet (see "Output schema normalization" below).
- **Vintage manifest.** Every published vintage drops a sibling `_manifest.json` recording git SHA, input S3 paths + ETags, per-file row counts and sha256, and build timestamp. Replaces the ad-hoc current pattern of overwriting `latest`.
- **No vendored C++.** `rapidxml-1.13/` does not move to the new repo; the old XML benchmarking spike (`R/xml_microbenchmark.R`) does not move either.

### Output schema normalization

The new pipeline publishes six parquets and two dimension files. Every parquet shares the same dimension column names and types; only the metric and year columns differ.

**Shared dimension columns** (in every output parquet, exact strings — these must match `R/options_nogeo.R` and `nested_geographies.csv` in the dashboard verbatim):

| column | type | source |
|---|---|---|
| `Organization Type` | `string` | derived from BMF `subsection_code` + `nteev2_org_type` |
| `Subsector` | `string` | `substr(nteev2, 1, 3)` — 12 NTEE majors |
| `Size` | `int32` | ordinal 0–6 expense-bin code (was `double`) |
| `Census Region` | `string` | derived from state abbreviation |
| `Census State` | `string` | 2-letter postal code |
| `Census County` | `string` | county name |
| `Metro/Micro Area` | `string` | CBSA name (or NA if no CBSA) |

**Year column.** Single name `Year`, type `int32`, in every file that has a temporal dimension. Rename the dashboard's `Tax Year` references in one pass (a `R/data_server_args.R` patch) — there is no semantic reason for two different year-column names.

**Per-panel files** (matches dashboard panel → file mapping in `R/data_server_args.R`):

| file | rows | metric columns | year range | panels |
|---|---|---|---|---|
| `number_nonprofits.parquet` | ~7M | `Number of Nonprofits: int32` | 1989–2024 | Numbers |
| `finances.parquet` | ~3.7M | `Total Assets, Total Revenues, Total Expenses, Total Benefits: double` | 1989–2021 | Assets / Revenues / Expenses / Benefits |
| `gov_grants.parquet` | TBD (aggregate) | `Total Government Grants: double` | 1989–2021 | Government Grants (currently unwired) |
| `pf_grants.parquet` | ~2.9M | `Total Contributions: double` | 1989–2023 | PF Grants |
| `pf_pri.parquet` | TBD (aggregate) | `Total PRI: double` (renamed from `PRI_TOTAL`) | 1989–2023 | PRI (currently unwired) |
| `daf.parquet` | ~150K | `Number of DAFs, Total Contributions, Total Grants, Total Value, Has DAF: double` | 2020–2023 | all 5 DAF panels |

`gov_grants.parquet` moves from org-grain (current 323K rows with `EIN2`) to aggregate-grain to match the rest. If org-grain output is still needed for the API layer, it is a separate file outside this contract.

**Dimension files:**

- `nested_geographies.csv` — `Census State, Census County, Metro/Micro Area, Census Region` (verbatim Title Case, used by the dashboard's geo cascade). Republished each vintage but expected to change slowly.
- `data_dictionary.parquet` (replaces today's `panel_dd.csv` and the older `data_dictionary.xlsx`) — one row per column per file, with `file`, `column`, `type`, `description`, `derivation_source`. Becomes the source of truth for the contract entry.

### BMF input translation

The new pipeline reads `s3://nccsdata/geocoding/bmf-master/merged/bmf_master_geocoded.parquet` (per [[contracts/bmf-master-geocoded.yml]]) as its sole BMF source. A documented translation layer maps new-BMF columns to the pipeline's internal names. Where a 1:1 mapping does not exist, the derivation is explicit and centralized in one function:

| pipeline column | source in `bmf_master_geocoded` | derivation |
|---|---|---|
| `EIN2` | `ein` | `derive_ein2(ein)` (existing helper) |
| `NTEEV2` | `nteev2` | direct rename |
| `BMF_SUBSECTION_CODE` | `subsection_code` | direct rename, cast to integer |
| `F990_TOTAL_ASSETS_RECENT` | `asset_amount` | direct rename, cast to numeric |
| `CENSUS_STATE_ABBR` | `geo_state_abbr` | direct rename |
| `CENSUS_COUNTY_NAME` | `geo_county` | direct rename |
| `CENSUS_CBSA_NAME` | — | **derive** via state+county → CBSA crosswalk (Census Bureau delineation file); fall back to NA |
| `NCCS_LEVEL_1` | `nteev2_org_type` and/or `foundation_code` | **derive** the charity-vs-PF flag |
| `ORG_YEAR_FIRST` | `first_year_in_bmf` | direct rename |
| `ORG_YEAR_LAST` | `last_vintage_ym` | parse YYYY-MM, take YYYY |

The CBSA crosswalk is a small reference file that ships with the new repo (or, preferably, a tiny contracted lookup under `nccsdata/lookups/`). The exact source (OMB delineation vintage) gets recorded in the manifest.

### Canonical output prefix

Outputs publish to `s3://nccsdata/sector-in-brief/vYYYY.MM/` — renamed from `dataexplorer/visuals/` to match the consumer. To resolve the existing-prefix collision:

1. The current contents of `s3://nccsdata/sector-in-brief/` (16 files, frozen 2024-09) are server-side-copied to `s3://nccs-data-archive/superseded/sector-in-brief-2024-09/` and then deleted from the working bucket.
2. The current contents of `s3://nccsdata/dataexplorer/visuals/` and `dataexplorer/visuals/v1.1/` are server-side-copied to `s3://nccs-data-archive/superseded/dataexplorer-visuals-2025-05/` and the working-bucket prefix is left as a tombstone (empty prefix with a `README.txt` pointing at `sector-in-brief/`) for one deprecation window.
3. The new pipeline writes its first vintage to `s3://nccsdata/sector-in-brief/v2026.MM/` and a `s3://nccsdata/sector-in-brief/latest/` server-side mirror.

Both prefix moves happen before the dashboard cutover in [[0011-decouple-dashboard-from-committed-data]].

### Repo lifecycle for `nccs-dataexplorer-data`

The old repo is archived (GitHub "archived" flag, locked main, README rewritten to a one-paragraph redirect) once:

- the new repo has published one vintage to `s3://nccsdata/sector-in-brief/v2026.MM/`,
- a regression diff shows the new vintage matches `dataexplorer/visuals/v1.1/` on row counts and a held-out EIN2/state/year sample for `gov_grants` and `pf_pri` (the org-grain files where row-level comparison is feasible),
- aggregate-grain files (`finances`, `daf`, `pf_grants`, `number_nonprofits`) pass row-count and per-cell tolerance checks (BMF vintage drift makes exact equality unrealistic; document tolerance in the manifest),
- the dashboard PR for [[0011-decouple-dashboard-from-committed-data]] is merged and pointing at the new prefix.

The dataexplorer **API** outputs at `s3://nccsdata/dataexplorer/api/` are governed by [[0008-modernize-dataexplorer-api]] and are not affected by this archive — the new repo does not produce them. If the API pipeline's R code is still living in `nccs-dataexplorer-data` at archive time, lift it into a separate repo first (or into [[0008-modernize-dataexplorer-api]]'s successor).

## Migration plan

Sequenced; each step gates the next.

1. **Create `sector-in-brief-data` repo** with the scaffold and bootstrap doc (see the new repo's `BOOTSTRAP.md`). No transforms yet — just config, package skeleton, CI for `R CMD check`, and the contract reference.
2. **Port derivation functions verbatim** from `nccs-dataexplorer-data` origin/main, with tests against fixtures. Functions are `derive_census_region`, `derive_organization_type`, `derive_subsector`, `derive_size`, `format_ein`, `derive_ein2`. These are pure functions of BMF row data and are the only logic that must survive verbatim.
3. **Build the BMF translation layer** as a single `read_bmf()` function returning the canonical internal schema. Cover every column in the mapping table above. Add tests against a small fixture slice of `bmf_master_geocoded.parquet`.
4. **Port one panel end-to-end** (`number_nonprofits`) and publish to a sandbox S3 prefix. Validate row counts and per-state breakdowns against current `v1.1`. Land the manifest writer at the same time.
5. **Port the remaining five panels** (`finances`, `daf`, `pf_grants`, `gov_grants`, `pf_pri`). Wire the two currently-unwired panels (`gov_grants`, `pf_pri`) so the dashboard PR is purely wiring.
6. **Publish first real vintage** to `s3://nccsdata/sector-in-brief/v2026.MM/` after the S3 prefix migration (the two server-side copies + delete documented above) lands.
7. **Dashboard PR** ([[0011-decouple-dashboard-from-committed-data]]) flips reads to the new prefix and removes committed parquet.
8. **Archive `nccs-dataexplorer-data`** once the dashboard PR is merged and one downstream observation cycle has passed without incident.

## Scope NOT in this ADR

- The dataexplorer **API**-side outputs (`dataexplorer/api/data/...`) — governed by [[0008-modernize-dataexplorer-api]].
- Adding the SOI 990PF and DAF external sources as contracted upstreams — they remain HTTP/external inputs in the new repo too. Worth a separate ADR if their drift becomes a problem.
- Producer CI (auto-publish on input drift) — defer until the new repo stabilizes. Manual triggers are fine for the first vintages.
- The CBSA crosswalk's own contract — it is small enough to ship with the new repo initially; promote to a `nccsdata/lookups/` artifact later if it grows.

## Outcome (as of 2026-05-21, updated after prod cutover)

Migration steps 1–4, 6, 7, and 8 of this ADR shipped between 2026-05-19 and 2026-05-21. Step 5 (six panels) is partial — four of six panels shipped; the remaining two (`gov_grants`, `pf_pri`) are deferred pending a separate column-mapping investigation and will be tracked under a future ADR rather than as residual work here.

**Shipped:**

- `UrbanInstitute/sector-in-brief-data` exists as a fresh repo (initial commit 2026-05-19, not a fork of `nccs-dataexplorer-data`), structured as an R package per the "Repo shape" spec. `DESCRIPTION` declares `aws.s3` as a runtime dependency.
- `config.yml` centralizes all input and output S3 paths and vintage tag (no hardcoded paths in R code). Production prefix `sector-in-brief` and sandbox prefix `sector-in-brief-sandbox` are both addressable; `publish.R` selects via a `sandbox=TRUE/FALSE` argument.
- Four of six panels publish: `number_nonprofits`, `finances`, `daf`, `pf_grants`, plus `data_dictionary.parquet`, `nested_geographies.csv`, and `_manifest.json`.
- Column-naming normalization shipped (single `Year` int32 column; consistent Title Case dimensions). The dashboard side of the rename also landed (see [[0011-decouple-dashboard-from-committed-data]]).
- A vintage manifest is published alongside each batch as `_manifest.json` at the vintage prefix.
- **Prod cutover landed 2026-05-21.** First prod vintage published to `s3://nccsdata/sector-in-brief/v2026.05/` with a `latest/` mirror; the S3 prefix migration (archive bucket copies of the 2024-09 `sector-in-brief/` artifact and the older `dataexplorer/visuals/`) ran ahead of it.
- **Dashboard cutover landed 2026-05-21.** `S3_PREFIX` in `sector-in-brief/R/s3_sync.R:14` flipped from `sector-in-brief-sandbox` to `sector-in-brief`; vintage pinned to `v2026.05`. The `contracts/sector-in-brief.yml` flip out of `INTERIM` state was made in the same beat.
- **`nccs-dataexplorer-data` archived 2026-05-21.** GitHub `archived: true`; README rewritten as an archive redirect.

**Deferred (out of this ADR's residual scope):**

- **`gov_grants` and `pf_pri` panels.** Both panels remain unwired in the dashboard and unbuilt in `sector-in-brief-data` (`config.yml:34,36` carry year-range stubs but no `panel_gov_grants.R` / `panel_pf_pri.R`). The blocker is upstream: it is not yet known which columns in the new core / e-file artifacts carry the source values for government-grant totals and program-related-investment totals. That investigation is in progress; a separate ADR will document the column-mapping decision and the panel-build plan once the source columns are identified. Until that ADR opens, do not treat the panels as residual work on this one.

## Consequences

**Positive:**

- The producer becomes legible: package boundary, config-driven paths, tested derivations, manifest-tracked vintages, contracted schema. Future maintainers can see what is produced without reading 12 R scripts.
- Schema inconsistencies (`Tax Year` vs `Year`, `TAX_YEAR` vs `Tax Year`, `Size` as `double`) are fixed in one cut rather than tolerated forever.
- The dashboard cutover ([[0011]]) becomes a column-rename + path-flip patch, not a data-engineering project.
- The two currently-unwired dashboard panels (Government Grants, PRI) ship as part of the contract, not as a follow-up.
- The S3 prefix story stops being three half-occupied locations and becomes one canonical prefix with archives.

**Negative:**

- More upfront work than the 2026-05-15 draft of this ADR estimated (~3–4 weeks for the new repo, vs. ~1–2 weeks for an in-place fix). Justified by the structural debt the in-place fix would inherit.
- One window of "two producers exist" — the old repo's outputs and the new repo's outputs coexist on S3 during steps 4–7 of the migration plan. Documented; bounded by the archive step.
- Dashboard breakage risk during the column-rename pass (`Tax Year` → `Year`, etc.). Mitigated by doing it in one PR with a regression-rendered screenshot diff.

## Deprecation window

Old outputs at `s3://nccsdata/dataexplorer/visuals/` and `s3://nccsdata/sector-in-brief/` remain readable (via the archive bucket) for **90 days** after the dashboard cutover. Tombstone READMEs at the old prefixes point consumers at `s3://nccsdata/sector-in-brief/latest/` and the archive bucket.

## Follow-up

1. Update `contracts/sector-in-brief.yml` to reflect the new producer (`repo: UrbanInstitute/sector-in-brief-data`, `key_prefix: sector-in-brief/`, full per-file schemas). The 2026-05-15 stub of that file has `TODO` markers in `producer.publish_path`, `manifest.path`, and `schema.source` that this ADR's execution fills in.
2. [[0011-decouple-dashboard-from-committed-data]] is unblocked once step 6 of the migration plan ships.
3. Consider whether the CBSA crosswalk should be promoted to a contracted `nccsdata/lookups/` artifact (cross-referenced by anything else that needs state+county → CBSA). Out of scope for this ADR but a likely follow-up.
4. The clone hygiene lesson from the 2026-05-19 recon (51 commits behind, `core.autocrlf` unset, stale `git status`) is the same pattern as [[sibapp-state-2026-05-18]] in `nccs-contracts/` memory. Worth a one-paragraph repo-onboarding note added to the new repo's `BOOTSTRAP.md`: always `git fetch` before trusting `git status`; set `core.autocrlf=input` on first clone.
