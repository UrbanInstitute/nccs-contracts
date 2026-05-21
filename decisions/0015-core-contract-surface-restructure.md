# 0015 — Restructure the Core Contract Surface

- **Status:** Accepted (planning; not yet executed)
- **Date:** 2026-05-21
- **Deciders:** sole maintainer
- **Related:** [[0001-s3-as-contract-surface]], [[0005-bmf-unified-superseded-by-master]], [[0010-sector-in-brief-data-replaces-dataexplorer-data]], [[0013-versioned-producer-outputs]], [[0014-standardize-manifest-shape]], [[0016-no-canonical-cross-dataset-merge]]

## Context

A 2026-05-21 recon to populate `contracts/core-harmonized.yml` and
`contracts/core-990.yml` against the live producer
(`nccs-data-core`) found that the contract surface laid out at v0
scaffolding time doesn't match what the producer publishes. Three
specific gaps:

1. **`core-harmonized` describes a path the producer doesn't
   write.** The contract YAML lists `key_prefix: harmonized/core/`
   with a `CORE-{YYYY}-{SUBSECTION_CLASS}-{FORM}-HRMN-V{N}.csv`
   filename pattern under `501c3-pc/`, `501c3-pf/`, etc. subdirs.
   That layout doesn't match anything `nccs-data-core/R/03_harmonize.R`
   currently produces. The modern harmonize stage writes
   `core_{tax_year}_{form}.csv` files under
   `intermediate/core/harmonized/{tax_year}/{form}/`. The YAML
   appears to describe an older pre-`intermediate/` layout.

   Crucially, *the modern harmonized tier is intermediate-only* —
   it exists as a build artifact for debugging and rehydration,
   but no downstream consumer (analyst, API, dashboard, or
   sibling repo) is supposed to read it. Promotion to the
   consumer-facing surface happens in `R/08_upload.R`'s
   `promote_harmonized_to_processed` step.

2. **`processed_legacy/core/` exists but is not contracted.**
   `nccs-data-core/R/run_legacy_pipeline.R` writes a parallel
   processed tier at `s3://nccsdata/processed_legacy/core/` from
   the pre-2012 NCCS legacy pipeline. It is uploaded "for parity
   and rehydration — not as the primary distribution path"
   (per `08_upload.R:255`). But it *is* a published, stable
   surface that the merged panel consumes, and drift here would
   silently break the merged build.

3. **`processed_merged/core/` exists but is not contracted.**
   `nccs-data-core/R/run_build_panel.R` writes
   `s3://nccsdata/processed_merged/core/` containing:
   - `990combined` files (per tax year) — 990 and 990-EZ unioned
     on the common variable set;
   - `990pf` files (per tax year) — separately, since PF columns
     don't align with 990/EZ.

   This is a *within-core form-type union*, not the cross-dataset
   BMF×core×efile merge that [[0002-canonical-merged-artifact]]
   envisioned. The canonical cross-dataset merge is dropped per
   [[0016-no-canonical-cross-dataset-merge]] — consumers compose
   joins per use case. But the within-core union at
   `processed_merged/core/` is a real artifact already consumed
   by `sector-in-brief-data` and deserves a contract under a name
   that doesn't misleadingly imply the abandoned cross-dataset
   merge.

   `contracts/merged.yml` is a stub describing the dropped 0002
   vision. It is renamed to `contracts/core-panel.yml` and
   repopulated against the actual within-core artifact.

### Affected downstream references

- `contracts/sector-in-brief.yml` declares `core-harmonized` as an
  upstream input (description on line 10, drift_detection event on
  line 78, notes link on line 84). With `core-harmonized` retired,
  this needs to repoint at whatever `nccs-data-bmf` and
  `sector-in-brief-data` actually consume — confirmed in code as
  the processed and processed-merged tiers, not the intermediate
  one.
- [[0013-versioned-producer-outputs]] and
  [[0014-standardize-manifest-shape]] list `core-harmonized` as
  in-scope for migration. Both need to drop it and add
  `core-legacy` / confirm `merged` in its place.
- The 2026-05-15 stub of `core-990.yml` carries a passing
  reference to `core-harmonized` in comments (lines 28, 42) that
  needs cleanup.
- The superseded draft of [[0010-dataexplorer-data-as-derived-producer]]
  references `core-harmonized` as a contract. Superseded
  documents are historical record; no edit there.

## Decision

Restructure the core contract surface to match what the producer
actually publishes. Four moves:

### 1. Retire `core-harmonized`

The harmonize stage (`R/03_harmonize.R`) is an intermediate-only
build artifact. It is uploaded to S3 conditionally (`ENABLE_UPLOAD_INTERMEDIATE`)
for rehydration and debugging, but it is **not a consumer-facing
contract surface** — no analyst, API, dashboard, or sibling repo
is supposed to read it. Promotion to the processed tier
(`R/08_upload.R promote_harmonized_to_processed`) is the contract
boundary.

`contracts/core-harmonized.yml` is retired:

- Replace its body with a one-paragraph tombstone explaining
  the retire and pointing readers to `core-990` (and to
  `intermediate/core/harmonized/` as a debugging tier with no
  contract).
- Keep the file (not delete) so the slug remains resolvable;
  set `name: core-harmonized` and `status: retired`.
- A separate "contract retirement" field convention is added —
  see Conventions below.

This is consistent with how [[0005-bmf-unified-superseded-by-master]]
retired the BMF unified artifacts and with how `0010` superseded
its own earlier draft: the YAML stays for slug resolution and
history; the body declares retirement.

### 2. Populate `core-990` against the processed tier

`contracts/core-990.yml` already correctly names
`key_prefix: processed/core/` and
`publish_path: R/08_upload.R`. Populate the remaining TODOs
(`compression`, `versioned_template`, `manifest`, `schema.source`,
external consumers) using the actual producer behavior:

- `format: csv` is correct today; flag parquet as a target via
  [[0009-…?]] follow-up or under the existing 0003 DuckDB ADR
  (`09_parquet.R` exists in the producer but the parquet output
  isn't yet contract-canonical).
- Schema source is the per-(tax_year, form) dictionary CSV:
  `processed/core/{tax_year}/{form}/core_{tax_year}_{form}_dictionary.csv`.
- Manifest is `null` today — flag under [[0014-standardize-manifest-shape]]
  Open items.
- Versioning is `null` today — flag under [[0013-versioned-producer-outputs]]
  Open items.

### 3. Rename `contracts/merged.yml` to `contracts/core-panel.yml`

The contract at `merged.yml` was a v0-scaffolding stub for the
canonical BMF×core×efile merge envisioned in 0002. That ambition
is dropped per [[0016-no-canonical-cross-dataset-merge]] — the
three datasets stay as separate contracted producers and
consumers compose joins for their specific use cases.

What does exist at `processed_merged/core/` is a *within-core*
form-type union, not a cross-dataset merge. The filename `merged`
misleads on what the artifact actually is, so we rename:

- File: `contracts/merged.yml` → `contracts/core-panel.yml`.
- `name:` field: `merged` → `core-panel`.

Populate `contracts/core-panel.yml` to describe the actual artifact
written by `nccs-data-core/R/run_build_panel.R`:

- Producer: `UrbanInstitute/nccs-data-core`. (No
  `producer.interim_note` — this is the producer, full stop.
  The 0002 future-repo plan is dropped per 0016.)
- `key_prefix: processed_merged/core/`
- Per-tax-year partitioning with two file families:
  - `990combined_{tax_year}.csv` (or equivalent — verify against
    actual S3 file naming during YAML population) — 990 + 990-EZ
    unioned on common variables.
  - `990pf_{tax_year}.csv` (or equivalent) — PF, separately
    (PF columns don't align with 990/990-EZ; the union is between
    990 and 990-EZ only).
- Consumers: `sector-in-brief-data` (confirmed upstream — reads
  this artifact for PF data per `sector-in-brief-data/config.yml`);
  potentially future API service tier and research notebooks.

Scope it explicitly as "within-core form-type union" in the
`description:`, so no future reader confuses it with the
abandoned cross-dataset merge.

### 4. Add `contracts/core-legacy.yml`

New contract for `processed_legacy/core/`:

- Producer: `UrbanInstitute/nccs-data-core`
- `publish_path: R/run_legacy_pipeline.R` (with `R/08_upload.R`
  `run_upload_legacy` as the upload step)
- `key_prefix: processed_legacy/core/`
- Same per-(tax_year, form) partition shape as
  `core-990` (deliberate parity per `08_upload.R:255`).
- Consumers: the merged-panel build (`run_build_panel.R`) is
  internal. Document as "rehydration tier; not a primary
  distribution path" — but contracted so drift here is detected.

### Conventions

Two small additions to the contract YAML shape (for cross-cutting
use, not core-specific):

- **`status:` field** on retired contracts. Values: `active`
  (default; omit when active), `retired` (still readable for the
  deprecation window, no new consumers), `deferred` (planned but
  not yet built). Tombstone YAMLs carry `status: retired` plus a
  short body explaining the retire and pointing to the active
  contract that replaces it (if any).
- **`producer.interim_note:` field** — optional, free-form. Used
  when the contract's current producer is expected to change
  (here: `nccs-data-core` is interim for `merged`). Records the
  expected long-term producer.

These are added to `contracts/_template.yml` in the follow-up.

## Migration plan

Single session of work; no inter-step gating since this is
internal contract-surface restructure (no producer or consumer
code changes):

1. **ADR follow-up edits.** Update the in-scope tables in
   [[0013-versioned-producer-outputs]] and
   [[0014-standardize-manifest-shape]] to drop `core-harmonized`,
   add `core-legacy`, confirm `merged` as in-scope.
2. **`contracts/core-harmonized.yml`** — replace body with
   retired-tombstone. Set `status: retired`.
3. **`contracts/core-990.yml`** — populate against
   `processed/core/`. Clean up the passing `core-harmonized`
   references in comments.
4. **`contracts/core-legacy.yml`** — new file from
   `contracts/_template.yml`, populated against
   `processed_legacy/core/`.
5. **Rename `contracts/merged.yml` → `contracts/core-panel.yml`**
   and populate against `processed_merged/core/`. Producer is
   `nccs-data-core` (full stop — the 0002 future-repo plan is
   dropped per [[0016-no-canonical-cross-dataset-merge]]). Scope
   explicitly to within-core form-type union.
6. **`contracts/sector-in-brief.yml`** — repoint upstream
   references from `core-harmonized` to the actual upstreams
   (verify against `sector-in-brief-data/config.yml`'s
   `inputs.core_legacy` / `inputs.core_modern` /
   `inputs.core_pf` paths — these point at
   `processed_legacy/core/`, `processed/core/`, and
   `processed_merged/core/`).
7. **`contracts/_template.yml`** — add `status:` and
   `producer.interim_note:` field documentation.
8. **`ARCHITECTURE.md`** — no changes needed; the system map's
   "Core 990 pipeline" row remains accurate, and the contract
   names listed in §10 follow naturally from the contracts/
   directory listing.

## Consequences

**Positive:**

- Contract surface matches actual producer behavior.
  `core-harmonized` was a phantom contract no consumer would have
  honored; retiring it removes the gap between spec and reality.
- `processed_legacy/core/` and `processed_merged/core/` are now
  contracted, so drift on either is detectable.
- The merged-panel question gets a concrete contract instead of a
  stub; consumers can pin against it.
- The `status: retired` convention generalizes — future
  retirements (e.g. of `bmf-master` if the geocoded variant
  eventually subsumes it) get a clean idiom.
- The `producer.interim_note:` convention names the
  multi-repo-evolution case without forcing a contract rewrite
  every time ownership moves.

**Negative:**

- Cross-references in [[0013]] and [[0014]] need touch-ups —
  fast, but a real edit.
- `sector-in-brief.yml`'s upstream list gets longer (three core
  tiers instead of one "harmonized") — more accurate but more
  verbose.
- The `nccs-data-merged` future-repo plan from
  [[0002-canonical-merged-artifact]] is partially diluted —
  not formally superseded, but the de facto producer is
  `nccs-data-core` for the foreseeable future. Note in 0002's
  follow-up section if/when the future repo is built.

## Deprecation window

`harmonized/core/` (the path the retired `core-harmonized.yml`
described) — to the extent that path still exists on S3 at all —
is *not* an active surface. No deprecation window applies to a
phantom contract.

The actual `intermediate/core/harmonized/` path stays as a
build artifact with no contract; consumers were never supposed
to read it.

## Follow-up

1. **Verify exact filename conventions** in `processed_merged/core/`
   during the `merged.yml` population (e.g.
   `core_{tax_year}_990combined.csv` vs. some other naming).
2. **Confirm `sector-in-brief-data/config.yml` input paths**
   against the rewritten `sector-in-brief.yml` upstream list to
   make sure the consumer-side and contract-side agree.
3. The future `nccs-data-merged` repo per
   [[0002-canonical-merged-artifact]] is still a valid target;
   when it lands, update `merged.yml`'s `producer.repo` and
   migrate the publish path. The contract's S3 surface (paths,
   schema) need not change at that time.
4. The `core-990` parquet target via `R/09_parquet.R` is not
   yet contract-canonical. Decide via a small follow-up note in
   `core-990.yml`'s Open items — promote-to-parquet, dual-publish,
   or hold.
