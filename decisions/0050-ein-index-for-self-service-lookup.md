# 0050 — EIN index: sharded JSON so the website can look up one organization without a server

- **Status:** Proposed (2026-09-21)
- **Date:** 2026-09-21
- **Deciders:** sole maintainer
- **Relates:** [[unified-bmf-geocoded]] (source), [[bmf-lookups]] and ADR 0049 (the website already reads bucket files in the browser; bucket CORS), ADR 0026 (API rewrite; the long-term home for richer queries), ADR 0014 (manifests), ADR 0016 (no code dependencies between repos), ADR 0036 (EIN forms)

## Context

Nonprofits arrive at the NTEE guide asking "what is my code?" The guide sends
them to the IRS Business Master File download, a 100 MB file, or to
ProPublica. NCCS already holds the answer in the Unified BMF, one row per EIN,
but the published file is 640 MB as parquet and 3.6 GB as CSV, so a web page
cannot read it, and the download API that could serve one row is decided but
not built (ADR 0026).

The maintainer chose on 2026-09-21: give the website a serverless lookup by
EIN now, and leave name search to the API later.

## Decision

1. **New contracted artifact `bmf-ein-index`**, produced by nccs-data-bmf
   from the geocoded Unified BMF at the end of every Unified build:
   `s3://nccsdata/unified/bmf/ein-index/latest/{prefix}.json`, one file per
   four-digit EIN prefix (the first four digits of the nine-digit number).
   EINs cluster heavily by prefix: the first build (vintage 2026_09) gave
   4,420 shards, the largest 48,000 organizations (1.3 MB
   compressed), the 99th percentile 154 KB and the median 5 KB; 140 MB
   in all. Three digits would have left the largest shard at 6 MB. Plus
   `_manifest.json` (ADR 0014 shape, one entry per shard).
2. **Shard shape.** A small JSON object: `vintage`, `prefix`,
   `fields` (column names, once) and `records` (an array of arrays in that
   column order). Columns: `ein`, `org_name_display`, `org_addr_city`,
   `org_addr_state`, `org_addr_zip5`, `ntee_code_clean`,
   `ntee_code_definition`, `nteev2`, `ruling_date`, `subsection_code`,
   `exempt_organization_type`, `status_code_definition`,
   `first_vintage_ym`, `last_vintage_ym`. All values as they appear in the
   Unified BMF; no new derivations.
3. **Retention follows ADR 0042.** Every build is published twice: to
   `unified/bmf/ein-index/v{YYYY_MM}/` (retained permanently, never
   deleted) and mirrored to `unified/bmf/ein-index/latest/`. Consumers
   read `latest/`; anyone reproducing a past lookup pins a vintage folder.
   At about 140 MB per build this costs under 2 GB a year. (An earlier
   draft of this ADR kept `latest/` only; review on 2026-09-21 pointed out
   the conflict with the retention rule, and the rule wins.)
4. **The website page** `/datasets/ntee/lookup/` takes an EIN in any common
   form (with or without the hyphen), fetches the one shard, and shows the
   record with the IRS wording for the code, the NTEE version 2 form, and
   the standing line that the IRS is the authority and how to request a
   change. It never fetches more than one shard per lookup. Relies on the
   bucket CORS rule from ADR 0049.
5. **Not in scope:** name search, fuzzy matching, historical codes per EIN
   (the address-history and NTEE-resolved crosswalks already exist for
   researchers), any write path. These belong to the API (ADR 0026).

## Consequences

- One lookup costs one request, typically a few KB and at most
  1.3 MB compressed (S3 serves the gzip bytes with
  `Content-Encoding: gzip`, which the producer sets on upload).
- A full Unified rebuild writes up to about 4,500 objects to the vintage
  folder and the same to `latest/`; uploads are
  sha256-idempotent so an unchanged shard is skipped.
- `nccsdata`, the API and the dashboard are unaffected.
- The producer's monthly cycle gains one step after the geocoded merge and
  before the state marts.

## Execution

| Step | Repo | Work |
|---|---|---|
| 1 | nccs-data-bmf | `R/build_ein_index.R` + `R/run_ein_index.R`: read the geocoded Unified parquet, write shards gzipped, manifest, idempotent upload; hook into the master pipeline after the geocoded merge; runbook line. Breadcrumb `ADR 0050`. |
| 2 | nccs | `/datasets/ntee/lookup/` page; link from the NTEE guide and dataset page. |
| 3 | nccs-contracts | Contract `contracts/bmf-ein-index.yml` (this PR); mark Accepted, reconcile. |

## Acceptance

- `unified/bmf/ein-index/latest/_manifest.json` lists N shard files whose
  `row_count`s sum to the Unified BMF row count, with `vintage` equal to
  the Unified manifest's; `v{vintage}/` holds the same files.
- The builder stops, rather than publishing, if any source EIN is not
  `XX-XXXXXXX`, if any EIN repeats, or if the shard rows do not sum to
  the source rows.
- Building twice from the same source yields identical shard hashes.
- Typing `52-0880375` (Urban Institute) on the lookup page returns the
  organization with its NTEE code and the current vintage.
