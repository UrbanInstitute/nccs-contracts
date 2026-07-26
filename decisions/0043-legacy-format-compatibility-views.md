# 0043 - Legacy-Format Compatibility Views + Plug-and-Play Mapping Tables

- **Status:** Accepted (2026-07-26; maintainer decided after demand check)
- **Date:** 2026-07-26
- **Deciders:** sole maintainer (demand confirmed: Jesse Lecy and Lewis
  Faulk prefer the legacy formats; acknowledged minority of users)
- **Related:** [[0016-no-canonical-cross-dataset-merge]], [[0035]] (frozen
  harmonized surface for the same constituency), [[0036]] (EIN2 bridge
  precedent: compatibility bridges over parallel products), [[0042]]
  (vintage/latest layout these adopt), [[0014]] (manifests)

## Context

NCCS stopped producing new vintages in the legacy NCCS file formats
(e.g. CORE-YYYY-501C3-NONPROFIT-PC). Established researchers who built
long-lived code against those shapes prefer them, though they are a
minority of users and the formats embed the defects the harmonized
rewrite fixed. The house pattern for this constituency has been
compatibility bridges, not parallel products (EIN2, the frozen
harmonized surface). Resuming the legacy pipelines proper would sign a
permanently poorer schema up for contracts, drift, and retention.

## Decision

1. **Mechanical compatibility views, not a pipeline.** At each merged
   CORE panel publish, `nccs-data-core` auto-generates legacy-shaped
   files: legacy filenames and column names via the REVERSED
   `*_crosswalk_FINAL` mappings, legacy tscope/fscope splits derived as
   explicit predicates (subsector x form) on the harmonized panel. No
   per-release curation; the generator script is the product.
2. **Plug-and-play mapping tables, published as data** (parquet + CSV +
   manifest + v{YYYY_MM}/ + latest/ per [[0042]]):
   - `legacy-column-map`: legacy_name, harmonized_name, family, dtype,
     coverage years, transform notes (the FINAL crosswalks turned
     outward).
   - `legacy-scope-map`: each legacy tscope/fscope as a machine-readable
     filter predicate on the harmonized panel.
   Together with EIN2 ([[0036]]) these make old-vs-new merges a pure
   join exercise.
3. **Format-compatible, not bit-identical: stated loudly.** View values
   are the harmonized, quality-gated values under old names; they will
   NOT match pre-rewrite downloads byte-for-byte. Every view ships this
   note in its dictionary and catalog entry.
4. **Scope: CORE families only.** BMF legacy format is out of scope
   until a named consumer requests it.
5. Views pass the standing validation gate ([[0042]] §4) against the
   merged panel they project (row parity per scope predicate, no NA
   coercion through the rename).

## Consequences

- Jesse/Lewis-style consumers get new years in their preferred shape,
  carrying the harmonization fixes invisibly.
- Marginal cost per release is one script run; the poorer schema never
  re-enters the canonical surface (ADR 0016 intact).
- New contracts: `core-legacy-compat.yml` (views) + the two mapping
  tables; catalog page for the compat family.

## Deprecation window

None: purely additive.

## Outcome

_To be filled at reconcile: generator PR, first published views +
mapping tables, contract population, catalog entry, consumer notice to
Jesse/Lewis._
