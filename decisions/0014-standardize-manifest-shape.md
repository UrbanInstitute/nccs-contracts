# 0014 — Standardize Manifest Shape Across Producers

- **Status:** Accepted (planning; not yet executed)
- **Date:** 2026-05-21
- **Deciders:** sole maintainer
- **Related:** [[0001-s3-as-contract-surface]], [[0004-cadence-aware-drift-detection]], [[0013-versioned-producer-outputs]]

## Context

`ARCHITECTURE.md` §3 "Producer Pattern" says every producer
publishes a manifest:

> **Manifest.** `MANIFEST.json` co-located with the artifact,
> listing files, sha256 sums, vintage, and generation timestamp.

Today two producers actually do, but their manifests **disagree on
shape**. A third producer (`bmf-master` and friends) doesn't emit a
manifest at all and writes a quality report instead. Net effect: the
ARCHITECTURE.md spec is aspirational; there is no single manifest
shape an agent or validator can rely on across producers.

### Current state, side by side

| Field | `sector-in-brief-data` `_manifest.json` | `bmf-lookups` `MANIFEST.json` |
|---|---|---|
| Filename | `_manifest.json` | `MANIFEST.json` |
| `vintage` | `"2026.05"` (dot) | `"2026_05"` (underscore) |
| Timestamp | `built_at`, local with tz offset | `generated_at`, UTC explicit |
| Build provenance | `git_sha` ✓ | absent |
| Input provenance | `inputs[]` array with `uri` + S3 ETag per input | `source.{workbook, extra_csv}` as filename strings |
| Per-file row count | `row_count` | `rows` |
| Per-file column count | absent | `cols` |
| Per-file schema info | `year_counts` (year breakdown) | `columns[]` (column names) |
| Per-file sha256 | ✓ | ✓ |
| Per-file bytes | ✓ | ✓ |

Each implementation has strengths the other lacks:
`sector-in-brief-data` carries `git_sha` + S3 ETags for inputs
(stronger lineage for debugging); `bmf-lookups` carries `columns[]`
per file (stronger schema validation for drift detection).
Neither is a strict superset.

Producers not yet emitting a manifest at all:

- `bmf-master` — writes `bmf_master_quality_report.json` instead
  (has row counts but no sha256 sums, no input provenance).
- `bmf-master-geocoded` — same pattern as `bmf-master`.
- `bmf-legacy` — same pattern.
- `core-990`, `core-legacy`, `core-panel` — write only quality reports today; manifests not yet emitted. `core-harmonized` is retired (intermediate-only build artifact, no contract per ADR 0015).
- `efile`, `merged` — not yet built.

### Why this matters

1. **Drift detection ([[0004-cadence-aware-drift-detection]])
   can't run cleanly across producers.** Each contract would need
   its own validator branch for whatever manifest shape (or
   absence of manifest) it happens to have. A unified shape lets
   one validator handle every contract.
2. **Idempotent re-publishing breaks down across producers.**
   `bmf-lookups` skips uploads whose sha256 is unchanged; the
   sector-in-brief pipeline doesn't read its own previous manifest
   for this purpose. Standardizing the manifest field set lets
   every producer adopt the same skip-decision logic.
3. **Cross-repo update agents ([[ARCHITECTURE.md]] §9 Loop 2) need
   a uniform target.** When a producer publishes a new vintage,
   the agent should be able to read one manifest schema and decide
   which consumers need pin bumps. Per-producer manifest shapes
   force per-producer agent prompts.
4. **The reference-implementation lesson from
   [[0013-versioned-producer-outputs]] generalizes.** Versioned
   subdirs without a per-vintage manifest leave the regression-
   checking question "are these the same bytes as last vintage?"
   answerable only by re-hashing. The manifest closes that loop
   cheaply.

## Decision

Standardize the manifest shape across all NCCS producers. Adopt the
union of the two current implementations' useful fields, resolve
name conflicts in favor of the more explicit version, and update
both reference implementations plus the unmigrated producers.

### Filename and location

```
s3://{bucket}/{key_prefix}/{vintage}/_manifest.json
s3://{bucket}/{key_prefix}/latest/_manifest.json
```

- **Filename: `_manifest.json`** (lowercase, underscore-prefixed).
  Rationale: the underscore prefix sorts metadata above data in
  `aws s3 ls` listings and visually distinguishes it from
  data files. `MANIFEST.json` (the uppercase form
  `ARCHITECTURE.md` §3 currently specifies) was an early
  convention; the newer producers settled on `_manifest.json`
  and the bias is to migrate the older one rather than push
  the newer two backward. `ARCHITECTURE.md` is updated in the
  follow-up of this ADR.
- **One manifest per vintage**, mirrored into `latest/` alongside
  the vintage data per [[0013-versioned-producer-outputs]]. The
  mirror is byte-identical.

### Schema

```json
{
  "vintage": "v2026.05",
  "built_at": "2026-05-21T13:09:18Z",
  "git_sha": "1b8ff6e",
  "inputs": [
    {"uri": "s3://nccsdata/geocoding/bmf-master/merged/bmf_master_geocoded.parquet", "etag": "\"abc...\""},
    {"uri": "repo://data/lookup/bmf_code_lookup.xlsx", "sha256": "def..."}
  ],
  "files": {
    "bmf_master.parquet": {
      "file": "bmf_master.parquet",
      "sha256": "...",
      "bytes": 12345678,
      "row_count": 1234567,
      "columns": ["ein", "name", "subsection_code", "..."],
      "year_counts": {"1989": 1234, "1990": 1235}
    }
  }
}
```

**Top-level fields:**

- `vintage` — string, the contract's vintage tag in the canonical
  format from [[0013-versioned-producer-outputs]] (e.g.
  `"v2026.05"`, `"v2026"`, `"v2026.05.21"`).
- `built_at` — string, ISO 8601 UTC with `Z` suffix
  (e.g. `"2026-05-21T13:09:18Z"`). Always UTC; no local-time
  offsets. Field name borrowed from `sector-in-brief-data`
  (active voice); UTC convention borrowed from `bmf-lookups`.
- `git_sha` — string, short git SHA of the producer repo at build
  time. NA-permitted only for builds that genuinely have no git
  context (rare; flag in the migration if a producer can't supply
  this).
- `inputs` — array of objects, each describing one input artifact
  the build consumed. Two shapes:
  - S3 input: `{"uri": "s3://...", "etag": "..."}` — the ETag is
    the S3 object's strong-consistency identifier for caching.
  - Local-repo input: `{"uri": "repo://path/inside/repo", "sha256": "..."}` —
    for producers that read files from their own repo (e.g.
    `bmf-lookups` reading `data/lookup/bmf_code_lookup.xlsx`).
  External HTTP inputs (e.g. the SOI 990PF xlsx in
  `sector-in-brief-data`) use the `uri` and a `sha256` of the
  fetched bytes. The validator differentiates by URI scheme; the
  contract YAML records expected input shapes per producer.
- `files` — object, one key per output artifact. The keys are the
  artifact filenames as they appear at the vintage prefix.

**Per-file fields:**

- `file` — string, redundant with the key but explicit for tools
  that consume the array form. Keep.
- `sha256` — string, sha256 of the file bytes.
- `bytes` — integer, byte size.
- `row_count` — integer, row count for tabular artifacts. NA for
  non-tabular files (a CSS file, a README).
- `columns` — array of strings, column names in publication order.
  For non-tabular files (manifests, READMEs), omit the field or
  set it to `null`.
- `year_counts` — object, `{"YYYY": int}` mapping. Optional;
  emit when the artifact has a temporal dimension and the
  producer knows the year column.

### Field-name decisions, where the two implementations disagreed

| Decision | Adopted | Rejected | Why |
|---|---|---|---|
| Timestamp key | `built_at` | `generated_at` | Active voice; "built" matches the build-step framing in CI |
| Timestamp tz | UTC `Z` | local with offset | One canonical interpretation; no DST math |
| Vintage format | `v{YYYY.MM}` per [[0013]] | `YYYY_MM` | See [[0013-versioned-producer-outputs]] |
| Row count | `row_count` | `rows` | Snake_case consistency with rest of schema |
| Column list field | `columns[]` (array of strings) | implicit / `year_counts` | Direct schema signal; drift detector compares column sets directly |
| Column count | derived from `len(columns)` | explicit `cols` | DRY — no redundant fields |
| Input provenance | `inputs[]` with `uri` | `source.{name: path}` | Uniform shape for any number of inputs of any kind |
| Filename | `_manifest.json` | `MANIFEST.json` | Sorts above data; signals metadata |

### What is *not* in the manifest (deliberately)

- **Schema types per column.** Parquet and CSV carry types
  inline; the manifest records column *names* and existence, not
  types. Type drift is detected by reading the file's own metadata,
  not the manifest.
- **Validation pass/fail.** Quality reports
  (`bmf_master_quality_report.json` etc.) stay as separate
  sibling files. The manifest is for byte-level identity +
  provenance; the quality report is for build correctness. They
  serve different agents.
- **External-consumer pins.** Consumers track their own pins in
  their own repos (and in the `consumers[]` block of the contract
  YAML). The manifest looks inward at what was built, not outward
  at who's using it.

### Scope

In-scope for this ADR:

- Migrate `bmf-lookups` from `MANIFEST.json` to `_manifest.json` and
  reshape the JSON to the unified schema.
- Migrate `sector-in-brief-data`'s `_manifest.json` to add the
  `columns[]` per file and switch `built_at` to UTC `Z` format.
- Add manifests to `bmf-master`, `bmf-master-geocoded`, `bmf-legacy`.
- Add manifests to `core-990`, `core-legacy`, and `core-panel`.

Out of scope:

- Producers not yet built (`efile`, `merged`). Apply the spec at
  build time.
- Per-column type schemas (deferred; revisit if drift detection
  needs them).

### Migration plan

Sequenced after [[0013-versioned-producer-outputs]] lands per
producer — vintage subdirectories are the precondition for
per-vintage manifests.

1. **`bmf-lookups`.** Rewrite `R/publish_lookups.R` to:
   (a) emit `_manifest.json` instead of `MANIFEST.json`;
   (b) rename `generated_at` → `built_at` with UTC `Z` formatting;
   (c) add `git_sha`;
   (d) restructure `source.{workbook, extra_csv}` to `inputs[]`
       with `repo://` URIs and sha256 of source files;
   (e) rename `rows` → `row_count`, drop `cols`;
   (f) keep `columns[]` as-is.
   The old `MANIFEST.json` stays readable for one deprecation
   window via a server-side copy on first migration publish.
2. **`sector-in-brief-data`.** Update `R/manifest.R`:
   (a) reformat `built_at` to UTC `Z`;
   (b) add `columns[]` per file (read from `arrow::schema()` of
       each output);
   (c) keep `year_counts` as the optional time-series breakdown.
3. **`bmf-master` + `bmf-master-geocoded`.** Extend
   `write_master_outputs()` and `master_geocoding.R`'s output
   write to emit `_manifest.json` alongside the parquet/CSV/dict.
   Reuse the (refactored) `bmf-lookups` helper logic.
4. **`bmf-legacy`.** Same pattern; piggyback on whatever helper
   the BMF master writes (the legacy pipeline reuses
   `nccs-data-bmf/R/config.R` helpers).
5. **`core-990`, `core-legacy`, `core-panel`.** Extend
   `R/08_upload.R` (and `R/run_build_panel.R` for the panel
   producer) to emit `_manifest.json` alongside the per-partition
   CSV outputs. All three share `R/08_upload.R`'s sync logic so a
   single helper covers them.

### Implementation notes

Worth lifting into a small shared helper *inside each producer
repo* (no cross-repo dependency — the helper is ~50 lines):

- `write_manifest(vintage, output_dir, outputs, inputs, ...)` —
  takes the local output directory, a named list of output
  metadata, and an input list; writes `_manifest.json`.
- `read_existing_manifest(s3_uri)` — fetches the existing vintage
  manifest for sha256-keyed skip decisions.
- `is_unchanged(existing_manifest, file, sha256)` — boolean for
  upload skip.

`bmf-lookups`'s `.read_remote_manifest` and `.hash_unchanged`
already cover (b) and (c); generalize them.

## Consequences

**Positive:**

- One manifest schema across all producers — one validator path,
  one agent prompt, one consumer-facing shape.
- Drift detection can check column-set equality directly from
  manifests rather than re-reading parquet schemas.
- Provenance is uniform: every artifact has git SHA + input
  identities recorded.
- Idempotent re-publish generalizes — every producer can adopt the
  same sha256-skip pattern.
- The contract YAML's `schema.source` field can point at
  `_manifest.json` consistently across producers (currently it
  varies — some point at a CSV dictionary, some at the manifest).

**Negative:**

- Each producer needs a publish-script edit. Reference
  implementations (post-migration `bmf-lookups`, post-migration
  `sector-in-brief-data`) make each one a small lift.
- `bmf-lookups`'s `MANIFEST.json` → `_manifest.json` rename is a
  soft break for any consumer reading the manifest path directly.
  Server-side copy keeps the old path alive during the deprecation
  window.

## Deprecation window

Per [[0001-s3-as-contract-surface]] default: 90 days. During
migration, producers can emit both `MANIFEST.json` and
`_manifest.json` (server-side copy) for one deprecation window.
After that, only `_manifest.json` is canonical.

## Follow-up

1. **Update `ARCHITECTURE.md` §3 Producer Pattern** to reference
   `_manifest.json` (lowercase, underscore-prefixed) and link to
   this ADR's schema. The current text references
   `MANIFEST.json` and predates the convergence work.
2. **Update each producer's contract YAML** `manifest.path` field
   to the new path (`{vintage}/_manifest.json` plus the
   `latest/_manifest.json` mirror) as that producer migrates.
   Replace the `null` placeholders in `bmf-master`,
   `bmf-master-geocoded`, and `bmf-legacy` once their manifests
   land.
3. **Schema for the manifest itself.** A JSON Schema (`_manifest.schema.json`)
   in this repo would let the validator type-check manifests
   before semantic-checking them. Defer until the validator is
   being built; not blocking.
4. The cross-cutting "Standardize manifest shape across producers"
   note in `contracts/bmf-master.yml`, `contracts/bmf-master-geocoded.yml`,
   `contracts/bmf-legacy.yml`, and `contracts/bmf-lookups.yml` Open
   items can be replaced with a `[[0014-standardize-manifest-shape]]`
   reference once this ADR is accepted. Same for any future core
   contracts.
