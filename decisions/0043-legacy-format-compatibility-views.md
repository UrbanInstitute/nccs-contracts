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

**6. Legacy-only column preservation (amended 2026-07-26 after full
crosswalk audit: 171 PZ + 82 PF unmapped legacy columns; narrowed
2026-07-28 to a single table).** ONE metadata table preserves the
per-(EIN, tax_year) curation worth carrying forward, published with the
standard vintage/latest layout and manifests:

- `core-legacy-classification-provenance`: reported NTEE per year,
  NTEESRC, confidence, OUTNCCS/OUTREAS scope flags (the time dimension
  ntee-resolved's per-EIN aggregate lacks). 22 PZ + 13 PF columns.

Explicitly NOT preserved (documented in the catalog):

- **Imputation-provenance pairs** (29 PZ `*Code`/`*Yr` columns plus
  GovGtEstimate). Historically authorized-users-only, so not publishing
  them continues the existing restriction rather than removing something
  users have. This retires the ADR 0043 Decision Point C: there is no
  publish-or-restrict question left to answer.
- **Filing provenance** (DLN/DOCLOCNO, SOURCE, DocCD/CODE990, RECCODE;
  6 PZ + 5 PF columns). These do not support CORE-to-e-file linkage and
  should not be preserved on that hope: DLN runs only 2000-2010 (PZ) and
  1999-2010 (PF), with 1997-1999 carrying it under the different name
  DOCLOCNO, so it stops at roughly the point 990 e-file XML begins.
  Linking CORE records to e-file filings requires a record-linkage
  procedure of our own, which is its own ADR, not a preserved column.
- BMF-duplicate descriptors (join the Unified BMF) and internal QA
  plumbing.
- **NTEE hierarchy derivables** (subsector, major group, division:
  lookup functions of the code). These belong in a dedicated NTEE
  metadata table rather than a CORE-legacy table, and are routed to
  their own ADR + PR. That ADR must reconcile with what already exists
  rather than duplicate it: `lookups/bmf/` already publishes
  `ntee_code`, `ntee_common_code`, `ntee_code_major_group` and
  `nteev2_subsector`, and `crosswalks/ntee-resolved/` already carries
  per-EIN resolved NTEE under ADR 0034. The open question it decides is
  ownership, since those artifacts are produced by `nccs-data-bmf`
  while the legacy NTEE columns here are CORE-side.

Unmapped PF form line items (P1GOODS, P6INVTAX, P6TXRFD, P2EYASST) are
a harmonization gap routed to the nccs-data-core crosswalk workflow,
not metadata.

**7. Consumer surface.** The CORE catalog's classic section gains a
"rebuilding the fully expanded record" join recipe; the nccsdata package
gains a thin reader for the metadata table, following the existing
`nccs_read_core()` conventions:

```r
nccs_read_core_metadata(tax_year, form, columns = NULL, cache = TRUE,
                        collect = TRUE)
```

It resolves the vintage/latest S3 path for
`core-legacy-classification-provenance`, fetches the parquet (through
the same cache as `nccs_read_core()`), and returns one row per
(EIN, tax_year) so the caller can join it onto a harmonized panel they
already hold. It does no joining, no reshaping and no scope filtering:
those stay the consumer's business per ADR 0016. A one-shot expand
helper that performs the join waits for demonstrated demand per the
ADR 0024 graduation rule.

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
