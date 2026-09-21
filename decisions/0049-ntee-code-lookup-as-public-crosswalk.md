# 0049 — The `ntee_code` lookup is the public NTEE-NAICS crosswalk: add long descriptions, fill NAICS, website reads it

- **Status:** Accepted, executing (2026-09-21): producer half shipped (nccs-data-bmf #56 merged, lookups vintage 2026_09 published 2026-09-21 with the new column and 17 NAICS values); website half in nccs #102
- **Date:** 2026-09-21
- **Deciders:** sole maintainer
- **Relates:** [[bmf-lookups]] contract, ADR 0014 (manifests), ADR 0033 (deprecation window; not triggered, change is additive), ADR 0016 (no code dependencies between repos), BACKLOG Z18 / Z25 / Z26 / Z29

## Context

The website's "NTEE Code Descriptions (IRS Version) with NAICS Crosswalk"
page is the most-visited NTEE reference we publish. Until nccs #101
(2026-09-21) it was built from a Nonprofit Open Data Collective (NODC)
crosswalk that predates the 24 codes the IRS added in 2021, so those codes
were absent. There was no download: the table lived only as an
interactive widget, and the only downloadable copy on S3 is an
unmanifested file from May 2023 under `legacy/misc/`.

Meanwhile the producer already publishes a contracted, manifested,
vintaged file with almost the same content: `lookups/bmf/latest/ntee_code.csv`
(columns `ntee_code`, `naics_code`, `ntee_code_definition`,
`effective_date`; 655 rows, one per IRS code including retired ones, per
the Z18 decision). Two gaps keep it from replacing the website's file:

1. **17 codes have `naics_code = UNDEFINED`** (the food-retail codes
   K6A-K6F and K90-K98, and the camp codes N2A/N2B). The website script
   now carries a NAICS 2022 match for each (nccs #101, reviewed by the
   maintainer). `Z99` is also UNDEFINED and stays so.
2. **It has no long description.** The website table shows a paragraph
   per code (NODC's `definition` column, up to 736 characters). NODC
   has a paragraph for 640 of the 655 codes in the sheet; 15 of the codes
   the IRS added in 2021 have none (the NODC table holds the word
   `NULL` there: E6A, K2A-K2C, K6A-K6F, L4A, L4B, N2A, N2B, P7A), so
   those stay blank until someone writes the text.

Keeping two copies (producer sheet and website CSV) is the kind of drift
Z18 was about: the website list went stale for five years because nothing
tied it to the pipeline's list.

## Decision

1. **`ntee_code.csv` gains one column, `ntee_code_description`** (long
   text, NODC wording, vendored into the `ntee_code` sheet of
   `data/lookup/bmf_code_lookup.xlsx`). Additive: no column is renamed,
   removed, or reordered ahead of it; row count unchanged. Blank for the
   15 codes without NODC text. The ADR 0033 deprecation window does not
   apply.
2. **The 17 UNDEFINED NAICS values are filled** with the NAICS 2022 codes
   from the website's `naics_for_newer_irs_codes.csv` (nccs #101). Their
   `effective_date` becomes the publish date. These values flow into the
   published BMF `naics_code` column at the next monthly build; that is a
   value correction, not a shape change.
3. **The website becomes a consumer of `bmf-lookups`.** Its NTEE page and
   crosswalk widget read `lookups/bmf/latest/ntee_code.csv` and
   `ntee_code_major_group.csv` at render time, and offer the same URL as
   the download. The website's own copy (`data-raw/NTEE-NAICS-XWALK.csv`,
   `data-raw/data.R`, `data-raw/naics_for_newer_irs_codes.csv`) is
   deleted once the widget reads S3. The NODC dependency moves from the
   website to the producer sheet, where the yearly IRS check (Z25)
   already lives.
4. **The NTEE reference gets a dataset page** on the website (Data grid,
   next to BMF, CORE, Census) with the download as the primary
   call-to-action, the interactive table as a linked page, and the
   existing NTEE resource page kept for the explanatory text.
5. `legacy/misc/NTEE-NAICS-CROSSWALK.csv` (2023) is left in place, listed
   in the legacy catalog, and not refreshed.

## Consequences

- One source for the code list, NAICS match, short and long
  descriptions: the producer sheet. The yearly IRS check covers the
  website automatically.
- `nccsdata` bundles four lookups into `R/sysdata.rda`; `ntee_code` is
  not one of them, so nothing there changes.
- The producer republishes `lookups/bmf/` as vintage 2026_09 (or the
  month of publish); only `ntee_code.csv` and the manifests change.
- Website render still happens locally (Quarto); a refresh of the widget
  after each lookup publish is a manual step, recorded in the runbook.

## Execution

| Step | Repo | Work |
|---|---|---|
| 1 | nccs-data-bmf | Script that adds `ntee_code_description` from NODC and fills the 17 NAICS values; tests; republish lookups. Breadcrumb `ADR 0049`. |
| 2 | nccs | Widget re-reads S3; site-themed table with download button and major-group filter; `_datasets/ntee.md`; remove `data-raw` copies. |
| 3 | nccs-contracts | Mark Accepted; reconcile numbers; contract YAML consumer entry (done in this PR). |

## Acceptance

- `lookups/bmf/latest/_manifest.json` lists `ntee_code.csv` with columns
  `ntee_code, naics_code, ntee_code_definition, ntee_code_description, effective_date`
  and 655 rows; `naics_code == "UNDEFINED"` only for `Z99`.
- The website table shows 655 code rows, K6A through N2B included, and
  its download link is the `latest/` URL above.
