# 0046 — Three-Way Variable Concordance with External SOI Harmonizations (NODC `F9_*` reference case)

- **Status:** Proposed
- **Date:** 2026-08-06
- **Deciders:** sole maintainer
- **Related:** [[0036-ein-coercion-safety-additive-columns]] (EIN2 is the join key the external product uses; this ADR raises its priority), [[0016-no-canonical-cross-dataset-merge]] (interoperability via published lookups, not merged products), [[0023]] (lookup-artifact precedent), [[0014]] (manifests), [[0042-vintage-retention-latest-convention]] (publish layout)

## Context

Jesse Lecy (NODC) maintains
[`Nonprofit-Open-Data-Collective/soi-extract-harmonization`](https://github.com/Nonprofit-Open-Data-Collective/soi-extract-harmonization),
an independent harmonization of the same IRS SOI 990/990-EZ extracts
(2012-2024) that `nccs-data-core` processes. It renames raw SOI columns to
the NODC e-file convention (`F9_08_REV_TOT_TOT`, `SA_02_*`), builds an
EIN-by-taxyear sample frame with imputed missing years and revocation
flags, merges in our Unified BMF v1.1 (pinned CSV URL), and splits into
PC/PZ research files. His working data lives on Box/Dropbox; the repo
references one S3 landing at `raw/soi/processed_plus_bmf/` (uncontracted).

We have **no governance over that repo** and are not seeking any. But its
existence makes explicit that "harmonized SOI panel keyed to e-file names"
and "CORE" are treated as distinct data products by external researchers,
and users will need to move between the two namespaces (plus legacy CORE
names). All three namespaces pivot through the raw SOI extract variable
name, and both sides' crosswalks are public, so the bridge is mechanical.

A draft composition (2026-08-06, from his
`SOI-EXTRACT-CROSSWALKS-2012-2024-EZ-PC-VFINAL.CSV` × our
`soi_990{,ez}_crosswalk_FINAL.csv` × `legacy_pz_crosswalk_FINAL.csv`)
matches **344/344** unique (raw SOI variable, form) keys across both
harmonizations (990 +
EZ), 132 of which also carry legacy CORE names. Zero unmatched on either
side: both crosswalks exhaustively cover the same source files.

## Decision

**1. New published lookup: `lookups/variable-concordance/` (name final at
build time), produced by `nccs-data-core`.** One row per (raw SOI variable,
form) with columns approximately:
`soi_source_var, form, core_harmonized_name, nodc_efile_var,
legacy_core_names, nodc_vscope, descriptions, years_present` per side.
Published under the ADR 0042 `{vYYYY.MM, latest}` convention with an ADR
0014 manifest and data dictionary. The NODC column set is a snapshot of
their crosswalk at a recorded upstream commit SHA; if they rename, we
update one lookup and no NCCS product surface moves.

**2. Scope: 990 + 990-EZ, 2012-2024, plus legacy PZ names.** PF is a
documented future extension (our `soi_990pf` crosswalk exists; their
VFINAL covers only EZ+PC).

**3. EIN2/ein_prefixed (ADR 0036) is the companion ship.** The external
product joins on `EIN2` (`EIN-XX-XXXXXXX`); landing the pending
`nccs-data-core` implementation makes CORE joinable to NODC-keyed
workflows with no reformatting. No new decision, priority note only.

**4. Provenance note, not a contract, for the external dependency.**
Record in `DATA-LIFECYCLE.md` (workspace) and here: the external product
consumes `harmonized/bmf/unified/BMF_UNIFIED_V1.1.csv` (version-pinned)
and has referenced writes to `s3://nccsdata/raw/soi/processed_plus_bmf/`.
We do not contract external surfaces; we document them so a BMF version
bump or `raw/` prefix question has a paper trail.

## Rejected

- **Contracting the NODC output prefix or proposing changes to his
  workflow.** No authority, no leverage, and contracts should bind only
  repos in the reporting cycle.
- **A "which product when" user guidance page.** Premature while his
  product is Box-distributed and unversioned; revisit if it gets a public
  publish surface.

## Consequences

- Bridging becomes a solved problem unilaterally: any user can translate
  legacy CORE ↔ CORE snake_case ↔ NODC `F9_*` through one published table.
- Semantic non-equivalences (e.g. his `XX_REV_CONTR` notes EZ
  contributions exclude membership dues; his `XX_SALE_ASSETS_*` papers
  over the securities/other split we rejected) belong in the lookup's
  dictionary notes column, not silently merged.
- Draft artifacts for review: `notes/adr-0046-concordance-draft/`
  (builder script + composed CSV).
