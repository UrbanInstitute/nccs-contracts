# 0019 — nccs-dataexplorer-data as a Contracted Derived Producer

- **Status:** Superseded by [0010 — `sector-in-brief-data` Replaces `nccs-dataexplorer-data`](0010-sector-in-brief-data-replaces-dataexplorer-data.md) (2026-05-19 revision)
- **Date:** 2026-05-15
- **Note:** Originally filed as ADR 0010 (this was the 10th decision). Renumbered to 0019 on 2026-06-03 to honor the monotonic-unique-number convention after its 2026-05-19 revision reused the 0010 slot; the supersession relationship is carried by the Status link above and the successor's `Supersedes:` field, not by the number.
- **Deciders:** sole maintainer

> **Superseded.** This draft proposed promoting `nccs-dataexplorer-data` to a contracted derived producer *in place*. On-disk recon on 2026-05-19 found the repo's structural debt makes in-place repair the wrong call. The successor ADR stands up a fresh repo (`sector-in-brief-data`) instead. Read the successor for the current decision; this draft remains as the audit trail of why the in-place approach was abandoned.

## Context

`UrbanInstitute/nccs-dataexplorer-data` sits between the canonical
NCCS producers (`nccs-data-bmf`, `nccs-data-core`) and the
sector-in-brief dashboard. It reads from `s3://nccsdata/`,
aggregates and reshapes for dashboard consumption, and writes back
to S3.

State as of the 2026-05-15 recon:

- **Inputs** (from `R/00_setup.R`):
  - `s3://nccsdata/harmonized/bmf/unified` — **archived in ADR 0005**.
    The path no longer exists in `nccsdata`; the data lives at
    `s3://nccs-data-archive/superseded/bmf-unified-v1.1/`. The
    pipeline will fail on next run.
  - `s3://nccsdata/harmonized/core` — current; contracted as
    `contracts/core-harmonized.yml`.
  - `s3://nccsdata/legacy/core` — current; read-only archival input.
  - IRS SOI 990PF `.xlsx` files (HTTP downloads from irs.gov).
  - DAF e-file tax return data (sourced separately).
- **Outputs** (from various script comments):
  - `s3://nccsdata/dataexplorer/visuals/` — parquet for the
    sector-in-brief dashboard.
  - `s3://nccsdata/dataexplorer/api/data/intermediate/` and
    `.../processed/`, `.../test/` — data the dataexplorer-api
    serves (Athena-style).
- **Suspicious duplication:** the audit also found
  `s3://nccsdata/sector-in-brief/` (1 GB, 2024-09) containing
  parquet files that match the names the dashboard reads from its
  committed `data/` directory. Whether `sector-in-brief/` is a
  manual copy of `dataexplorer/visuals/`, an obsolete predecessor,
  or both is not documented.
- **No contract entry.** The pipeline has no entry in
  `nccs-contracts/contracts/`, no manifest, no schema doc, no
  versioning scheme. The `README.md` is 82 bytes.

Structurally, this pipeline matches the **derived-producer
pattern** established in ADR 0002 for the merged BMF+core artifact:
it consumes canonical contracted upstream, transforms, and
publishes a new artifact that other consumers depend on. It is not
a private implementation detail of the dashboard; it is a
first-class data product.

## Decision

Promote `nccs-dataexplorer-data` to a first-class **contracted
derived producer**, on the same footing as `nccs-data-bmf` and the
future `merged` artifact. Concretely:

### Pipeline fixes (required before anything else)

1. **Repoint `R/00_setup.R`** off the archived
   `harmonized/bmf/unified/` to a current contracted source:
   - For BMF data, read from
     `s3://nccsdata/geocoding/bmf-master/merged/bmf_master_geocoded.parquet`
     (per `contracts/bmf-master-geocoded.yml`) if geographic
     coordinates are needed, else
     `s3://nccsdata/master/bmf/bmf_master.parquet` (per
     `contracts/bmf-master.yml`).
   - Update any column references that were anchored to the V1.1
     unified BMF naming.

### Canonical output prefix

2. **Consolidate to a single output prefix.** Today the pipeline
   writes to two locations (`dataexplorer/visuals/` and
   implicitly `sector-in-brief/`). Pick one canonical location;
   archive the other or stop writing to it.
   - Recommended: keep `s3://nccsdata/dataexplorer/visuals/` as
     the dashboard-facing output (matches the producer code's
     intent); investigate and retire `sector-in-brief/` as part
     of this ADR's execution.

### Contract entry

3. **Add `contracts/sector-in-brief.yml`** describing the
   dashboard-facing artifact (versioned URL, vintage, per-file
   schema, consumers). See the stub committed alongside this ADR.
4. **Manifest discipline:** producer writes a sibling
   `MANIFEST.json` per published vintage, listing files with
   sha256 and row counts.
5. **Vintage scheme:** parquet files published under
   `s3://nccsdata/dataexplorer/visuals/{YYYY_MM}/` with a
   `latest/` alias mirror, matching the `bmf-lookups` pattern.

### Repo hygiene (smaller than ADR 0009 since the repo is less bloated)

6. **Rewrite the 82-byte README** to document inputs, outputs,
   how to run the pipeline, and the contract reference.
7. **Decide on `rapidxml-1.13/`** vendoring (the C++ XML parser
   currently checked into the repo). If only used for SOI .xlsx
   parsing, switch to an R-native package and delete the vendored
   tree; if performance-critical, document why.

### Scope NOT in this ADR

- The dataexplorer **API**-side outputs
  (`dataexplorer/api/data/...`) are governed by ADR 0008. This ADR
  covers only the dashboard-facing visuals outputs.
- Adding the SOI 990PF and DAF inputs as contracted upstreams is
  out of scope; they remain HTTP-download / external sources
  consumed by this pipeline.

## Consequences

**Positive:**

- The data prep layer becomes legible: contract entry, manifest,
  schema, vintage. Future maintainers (or future-you) can see what
  the pipeline produces without reading 12 R scripts.
- The dashboard (ADR 0011) can read from a contracted artifact
  rather than committed snapshots, fixing the "two data realities"
  problem at the dashboard layer.
- The broken upstream reference gets fixed before next pipeline run.
- The duplicate output-prefix question gets resolved.

**Negative:**

- Real engineering work: ~1–2 weeks to repoint, consolidate
  prefixes, add manifest writing, and write the contract.
- Touches column names if the V1.1 → master schema differs;
  downstream tables may need name updates.

## Deprecation window

The current outputs at `s3://nccsdata/dataexplorer/visuals/` and
`s3://nccsdata/sector-in-brief/` remain in place during the
transition. Dashboard cutover to the new contracted artifact
happens in ADR 0011. Old outputs are archived to
`nccs-data-archive/superseded/` after the dashboard has migrated.

## Follow-up

1. Execute pipeline fixes (Decision §1) immediately, regardless of
   when the rest of this ADR ships — the broken upstream reference
   is silent technical debt.
2. ADR 0011 (dashboard data decoupling) depends on this ADR's
   contract being populated.
3. Consider promoting `nccs-dataexplorer-data` itself to follow the
   producer pattern (CI on publish, etc.) — defer the producer-CI
   work until after the rewrite stabilizes.
