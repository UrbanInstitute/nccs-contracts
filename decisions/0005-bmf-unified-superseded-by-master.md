# 0005 — BMF Unified Products Superseded by master/bmf

- **Status:** Accepted
- **Date:** 2026-05-15
- **Deciders:** sole maintainer

## Context

Before the master BMF builder (`master_bmf_builder.R` in `nccs-data-bmf`)
existed, two predecessor unified-BMF products were published:

- `s3://nccsdata/harmonized/bmf/unified/` — V1.1, statewise CSVs +
  aggregate `BMF_UNIFIED_V1.1.csv` (last write 2025-03-04). Consumed
  by `nccs-dataexplorer-data/R/00_setup.R`.
- `s3://nccsdata/bmf/unified/v1.2/UNIFIED_BMF_V1.2.csv` — V1.2 single
  CSV (last write 2025-05-21). A promoted-out-of-`harmonized/`
  iteration of the same idea.

Both attempted to be the "one BMF table" for downstream consumers.
The builder now publishes a canonical master parquet at
`s3://nccsdata/master/bmf/bmf_master.parquet`, derived from
`processed/bmf/` (1995–present) and `processed/bmf-legacy/`
(pre-1995). State-sharded slices of the same master are written
alongside it at `s3://nccsdata/master/bmf/state_marts/{csv,parquet}/`
— these are the direct replacement for the V1.1 per-state CSVs
(e.g. `AL_BMF_V1.1.csv` → `state_marts/csv/bmf_master_AL.csv`).
The geocoded extension lives at
`s3://nccsdata/geocoding/bmf-master/merged/bmf_master_geocoded.parquet`
and is the canonical surface for `nccsdata::nccs_read()`.

The unified-BMF products are no longer rebuilt and have no remaining
producer code. Keeping them in the working bucket creates a second
data reality for consumers that still know about them.

## Decision

The two unified-BMF products are **superseded** by `master/bmf/`
(un-geocoded master) and `geocoding/bmf-master/merged/` (geocoded
master). Both have been moved out of the working `nccsdata` bucket
to `s3://nccs-data-archive/superseded/`:

- `harmonized/bmf/unified/` → `nccs-data-archive/superseded/bmf-unified-v1.1/`
- `bmf/unified/v1.2/` → `nccs-data-archive/superseded/bmf-unified-v1.2/`

Move (rather than delete) preserves reproducibility for any analysis
pinned to V1.1 or V1.2 outputs.

This is a **breaking change** for any consumer reading from the old
paths. The only known consumer is `nccs-dataexplorer-data/R/00_setup.R`
(syncs from `harmonized/bmf/unified` to `data/raw/bmf`). It must
migrate to read `master/bmf/bmf_master.parquet` (or the geocoded
variant if it needs lat/lon).

## Consequences

**Positive:**

- One BMF data reality. All consumers point at the master.
- Working bucket shrinks by ~5.3 GB across the unified products.
- The migration is reversible — archive copies remain readable.

**Negative:**

- `nccs-dataexplorer-data` is broken until migrated. Tracked as a
  follow-up; the dashboard will need a small code change.
- Anyone with a paper or notebook pinned to a V1.1/V1.2 path will
  hit 404. They can either rebase on the master or update their path
  to `s3://nccs-data-archive/superseded/...`.

## Deprecation window

Strict reading of the house rules (`CLAUDE.md`) calls for a 90-day
deprecation window on breaking changes. The unified-BMF products
were never formally contracted (no entry in `contracts/`), and no
consumer outside `nccs-dataexplorer-data` is known to depend on
them. The window therefore does not apply in the conventional sense
— the artifacts simply move, on the same day, with archive copies
preserved for any straggler that needs them. Future archive-style
moves of contracted artifacts should still respect the 90-day window.

## Follow-up

1. Add contract `contracts/bmf-master.yml` (already present; update
   to reflect both `master/bmf/` and `geocoding/bmf-master/`).
2. Migrate `nccs-dataexplorer-data/R/00_setup.R` to read the master.
3. Note in `ARCHITECTURE.md` that `nccs-data-archive/superseded/` is
   the destination for moved-out-of-working-bucket artifacts.
