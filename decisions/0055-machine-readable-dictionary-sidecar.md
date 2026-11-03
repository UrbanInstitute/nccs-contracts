# 0055: Provenance stays in the manifest; a machine-readable dictionary may be added as a sidecar, not as columns in the data

- **Status:** Proposed (2026-11-03), and deferred until the parquet transition (0027) has settled. For the data governance committee.
- **Date:** 2026-11-03
- **Deciders:** sole maintainer; raised by Jesse Lecy's csvschema proposal of 2026-11-03
- **Related:** [[0013-versioned-producer-outputs]], [[0014-standardize-manifest-shape]], [[0027-core-990-parquet-promotion]], [[0054-cross-series-rules-as-fixtures]]

## Context

Jesse Lecy has proposed adding his `csvschema` R package to NCCS CSV
files. It writes two extra columns into every CSV: a `_schema` column
carrying the data dictionary in small checksummed pieces spread across
rows, and a `_canary` column holding sample values that show whether a
reader mangled the file (lost leading zeros, numbers read as dates). It
can also write an optional sidecar file in the Frictionless Data Package
format. Reading the embedded schema needs the package. The proposal is to
add a `get_provenance()` and `get_dd()` function to `nccsdata` that call
it.

What the system already does:

- **Provenance is published.** Every artifact carries a `_manifest.json`
  (0014) with the git commit that built it, input hashes, row counts,
  column names, bytes and a sha256 per file. Earlier releases are kept at
  vintage paths (0013).
- **Dictionaries are published.** Every CORE partition has a
  `_dictionary.csv` beside it; BMF lookups carry column lists in the
  manifest.
- **Types are moving into the file format.** The per-form CORE files are
  parquet (0027), which carries column types and can carry key-value
  metadata inside the file. CSV is a mirror for a transition window.
  The loss of leading zeros and dates that the canary detects is a CSV
  problem, and parquet removes it.

The package was created on 2026-10-31 (version 0.1.0, one author). Its
own site lists Python and spreadsheets as not yet tested. It has no
provenance section; the proposal says one would have to be added.

## Decision

1. **No columns are added to published data files** for schema,
   provenance or integrity. Every user sees every column, and the shape
   of a file is a promise to every consumer (0022). Provenance and
   dictionary information live beside the data, not inside it.

2. **Provenance stays in the manifest.** A `get_provenance()` function in
   `nccsdata`, if wanted, reads `_manifest.json`. It needs no new
   dependency.

3. **A machine-readable dictionary may be added as a sidecar**, in the
   Frictionless Data Package format (`datapackage.json`), beside the
   manifest. This is a standard other tools read, it is not tied to one
   package, and it is where the good part of the proposal lands. It is
   deferred until the parquet transition has settled, and then comes
   back to the committee as its own proposal with a producer named to
   build it.

4. **`nccsdata` takes no dependency on `csvschema`.** `nccsdata` imports
   `arrow`, `dplyr` and `utils` only, by design.

## Consequences

- Nothing changes in any published file now.
- The canary idea is noted as useful for internal quality checks on CSV
  mirrors, where a producer may use it in its own tests. It is not part
  of any published surface.
- When the sidecar is built, the dictionary CSV and the sidecar must be
  generated from the same source so they cannot disagree (0054 pattern).

## Rejected

- Embedding the schema in `_schema` and `_canary` columns.
- Adding `csvschema` as a dependency of `nccsdata` or any producer.
