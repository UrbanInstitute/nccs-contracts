# 0034 — NTEE-Resolved Crosswalk (per-EIN, cross-vintage)

- **Status:** Accepted — built & first-published 2026-06-24 (nccs-data-bmf `50c4d08` build/publish, `1e1290d` docs+contract)
- **Date:** 2026-06-17
- **Deciders:** sole maintainer
- **Related:** [[0032-ntee-cleaner-university-code-loss]] (the fix this completes), [[0016-no-canonical-cross-dataset-merge]] (consumer-composes; why a separate artifact, not a master column), [[0014-standardize-manifest-shape]] (manifest), [[0001-s3-as-contract-surface]] (S3 path is the contract), [[0022-cross-repo-contract-change-guard]] (this new surface runs through the guard)

## Context

[[0032-ntee-cleaner-university-code-loss]] fixed the cleaner so valid NTEE
codes (e.g. `B43`) reach `nteev2_subsector = UNI`. But verification against the
republished data found a **second, distinct** failure mode that the cleaner
cannot touch: orgs whose IRS `NTEE_CD` is **NULL at source**.

The motivating record is the one the original report named — **Carnegie Mellon
(EIN 25-0969449)**. Its `ntee_code_raw` is empty in the current BMF
(`2023_06`, `2025_12`, …) → `ntee_code_clean = UNDEFINED` → `UNU`/`Z99`. So the
literal org reported as missing from a "Universities" filter is *still* absent
after the cleaner fix. No amount of cleaning classifies a null.

The decisive observation: CMU is **`B43` (University) in the legacy vintages**
(`2010_07`, `2022_08`) — the IRS later nulled a code NCCS's own history still
holds. A classification is recoverable; it just isn't in the *latest current*
vintage. This generalizes — the master keeps the most-recent vintage's value
per EIN, which silently discards a known older code when the newest is null or
a one-off miscode.

A related, separate issue surfaced in the same verification (not addressed
here): public-university *flagships* are often governmental instrumentalities
absent from the 501(c)(3) BMF, or carry non-university source codes (Penn State
flagship's only-ever code is `B844`); and the `UNI` bucket legitimately
contains source-miscoded small orgs (any `B40`–`B50`). Those are upstream
source facts, not recoverable by cross-vintage resolution.

## Decision

Publish a new, separate **NTEE-resolved crosswalk**: one row per EIN, the NTEE
code resolved across **every** vintage (current + legacy), built from **raw**
codes and cleaned once with the current `transform_ntee_code`.

**1. New contracted S3 surface.**
`s3://nccsdata/crosswalks/ntee-resolved/` holding
`ntee_resolved_crosswalk.parquet` + `.csv` + `_manifest.json` (ADR 0014),
published via the shared idempotent `publish_crosswalk()`.

**2. Built from RAW codes — so no reprocessing is required.** The 0032 bug only
ever affected `ntee_code_clean`/`nteev2_*`; `ntee_code_raw` is the verbatim
source and is **vintage-invariant**. The build aggregates raw codes across all
intermediate parquets and applies the *fixed* cleaner at build time. It
therefore needs **no** legacy reprocess, and for NTEE purposes **supersedes**
one. (Reprocessing legacy remains worthwhile for the master's *other* fields,
but is not a prerequisite here.)

**3. Expose all resolutions; take no opinionated single pick** (per
[[0016-no-canonical-cross-dataset-merge]]). Columns, per EIN:
- `ntee_current` (+`_subsector`, +`_nteev2`, +`current_vintage`) — value in the
  most-recent **current** vintage; may be NULL (this is CMU's state today).
- `ntee_most_recent` (+`_subsector`, +`_nteev2`, +`_vintage`, +`_source`) —
  most-recent vintage with a **non-null** code (CMU → `B43`/`UNI`).
- `ntee_modal` (+`_subsector`, +`_nteev2`, +`_n`) — modal code across vintages
  (one-off-miscode resistant; ties broken by recency).
- `ntee_code_distribution` — JSON `{clean_code: {n, first, last}}`.
- `n_vintages_with_ntee`, `n_distinct_codes`, `ntee_agreement`
  (`single`/`unanimous`/`mixed`) — a transparency/confidence signal.

**4. Separate artifact, NOT master columns** (per
[[0016-no-canonical-cross-dataset-merge]]). The Master BMF stays
"as-reported per most-recent vintage"; consumers `LEFT JOIN` this crosswalk on
`ein` and choose the resolution policy that fits their use (e.g. a
"Universities" filter uses `ntee_most_recent_subsector = 'UNI'`). This avoids
pinning the master to one resolution policy and keeps the change additive.

## Consequences

- **The reported org is recoverable.** CMU resolves to `B43`/`UNI` via
  `ntee_most_recent`; consumers gain a documented way to classify NULL-source
  orgs that have history.
- **Honest limits, recorded.** Orgs with *no* usable code in any vintage (Penn
  State flagship's `B844`; never-coded EINs) remain unclassified — the crosswalk
  surfaces that (`single`/NULL), it does not invent codes.
- **New contract surface → guard applies.** Per
  [[0022-cross-repo-contract-change-guard]], the producer change reconciles the
  contract YAML + `ARCHITECTURE.md`; consumers are notified before they pin.
- **No reprocessing dependency.** Decoupled from the deferred legacy reprocess.
- **Additive.** Nothing existing changes shape; the master is untouched.

## Deprecation window

Not applicable — purely additive (a new artifact + manifest). Nothing is renamed,
moved, retyped, or removed, so no consumer migration window is owed. Standard
[[0014-standardize-manifest-shape]] manifest from first publish.

## Outcome

Built and first-published **2026-06-24** to
`s3://nccsdata/crosswalks/ntee-resolved/` (`ntee_resolved_crosswalk.parquet` +
`.csv` + ADR 0014 `_manifest.json`). Contract: `contracts/ntee-resolved-crosswalk.yml`.

- **Scale:** 3,613,958 EINs (one row per EIN with ≥1 observed NTEE), built over
  the current + legacy intermediate parquets (114 vintages, vintage tag `2026_06`).
- **Recovery (the point of the artifact):** of **2,054,414** EINs with a
  NULL/blank `ntee_current`, **2,031,485** recovered a usable code via
  `ntee_most_recent`. CMU `25-0969449` confirmed: `ntee_current=NA`,
  `ntee_most_recent=B43` (`UNI`), `ntee_modal=B43`.
- **Agreement:** unanimous 2,585,156 (71.5 %) / mixed 777,236 (21.5 %) /
  single 251,566 (7.0 %).
- **Run profile:** runs locally (DuckDB column-projected read of only
  `(ein, ntee_code_raw)` + disk spill), ~55 min; no EC2, as designed.

First full-scale run required three producer fixes (committed in `50c4d08`):
1. `INSTALL`/`LOAD` the DuckDB `aws` extension — the `credential_chain` S3
   secret needs it (only `httpfs` was loaded → autoload error).
2. Enable spill-to-disk (`temp_directory` + `preserve_insertion_order=false` +
   env-overridable `memory_limit`/`threads`) so the per-`(ein,src,raw)` hash
   aggregate streams to disk instead of OOM-ing on a RAM-limited host.
3. `clean_codes()` dummy grain column `EIN` → `ein` (the post-0032
   `transform_ntee_code` validation requires a lowercase `ein`).

The 640 MB CSV is gitignored in the producer repo; both files distribute via
S3 only. The published `_manifest.json` records the two input prefixes and the
sha256 of `transform_ntee_code.R` + the legacy 5-char lookup, so a change to
the cleaner or that lookup is visible in published provenance.
