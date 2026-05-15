# 0006 — Deduplicate nccs-data-archive Against nccsdata/legacy

- **Status:** Accepted
- **Date:** 2026-05-15
- **Deciders:** sole maintainer

## Context

The 2026-05-15 audit found that `s3://nccs-data-archive/` held six
top-level prefixes (`bmf/`, `core/`, `digitizeddata/`, `misc/`,
`soi/`, `trend/`) whose contents were renamed copies of files
already canonical at `s3://nccsdata/legacy/`:

| Archive prefix | Canonical location |
|---|---|
| `bmf/{YYYY}/bmf.bmYYMM.csv` (90 files) | `legacy/bmf/BMF-YYYY-MM-501CX-NONPROFIT-PX.csv` |
| `core/{YYYY}/{coreco,nccs}.core{YYYY}{co,pc,pf}.csv` (110 files) | `legacy/core/CORE-YYYY-{class}-{form}.csv` |
| `digitizeddata/digdata.*2005b.csv` (13 + index.html) | `legacy/digitized/DIG-*-1998-2003-501C3-CHARITIES-PZ.csv` |
| `misc/{classif,lookup,nccs,nccs.SC}.*.csv` (9 files) | `legacy/misc/{ALLEINS, ALLNTEE, FIPS-MSA-CROSSWALK, NTEE-NAICS-CROSSWALK, SUPPLEMENTAL-CORE-*}.csv` |
| `soi/{YYYY}/soi.soi*.csv` (108 files) | `legacy/soi-micro/{YYYY}/SOI-MICRODATA-*.csv` |
| `trend/{coreco,nccs}.corePcFyTrend*.csv` (3 + index.html) | `legacy/misc/TREND-1989-2013-*.csv` |

Total duplicated volume: roughly 57 GB.

The legacy pipelines (`nccs-data-bmf/R/run_legacy_pipeline.R`,
`nccs-data-core/R/run_legacy_pipeline.R`) read from
`nccsdata/legacy/`, not from `nccs-data-archive/`. No producer or
consumer code in the NCCS sibling repos references the archive copies
(verified by grep across `nccs-data-bmf`, `nccs-data-core`,
`nccsdata`, `nccs-dataexplorer-data`, `nccs-website`, `nccs-reports`).

Identity was verified by exact byte-size match across every file
in every prefix (one SOI 1982 pair was additionally verified by
identical MD5). One orphan was found — `soi/index.html` (7,248 B,
a 2019 static directory listing) — and retained.

Keeping both copies created:

- **Two data realities for the same data.** A future agent or
  contributor reading the archive bucket might believe they were
  looking at a distinct historical record.
- **Storage cost paid twice** for content that is reproducible from
  the canonical surface.
- **Ambiguity in the archive bucket's role.** ADR 0005 just
  established `nccs-data-archive/superseded/` as the home for
  artifacts moved out of the working bucket. Mixing that role with
  "renamed copies of `legacy/`" muddied the bucket's purpose.

## Decision

The six duplicate top-level prefixes were deleted from
`s3://nccs-data-archive/`. The `nccsdata/legacy/` surface is the
sole canonical location for this historical data.

To preserve the mapping from the 2019-era NCCS naming convention to
the 2023 NCCS-canonical names — for any paper, notebook, or external
citation that still references the old filenames — a manifest was
written at:

`s3://nccs-data-archive/MANIFEST-renames.md`

The manifest lists every (old name, new name, byte size) pairing for
all 423 deleted files. It is plain Markdown so it renders in the S3
web console and in any Markdown viewer.

The orphan `soi/index.html` was retained.

## Consequences

**Positive:**

- ~57 GB reclaimed from `nccs-data-archive/`.
- The archive bucket has a single coherent purpose: storing artifacts
  that have been moved out of the working `nccsdata` bucket. Today
  that means `superseded/` (per ADR 0005) and the rename manifest.
- One data reality for the legacy historical record.
- The bucket is browsable: the rename manifest sits at the root and
  is the first thing a reader encounters.

**Negative:**

- Anyone with a script pinned to the old filenames hits 404. The
  manifest tells them where to find the data; their script still
  needs updating.
- The byte-identical archival redundancy is gone. Recovery now
  depends on `nccsdata/legacy/` being durable; S3's eleven-nines
  durability makes this acceptable, but a periodic cross-region
  replication or Glacier copy of `nccsdata/legacy/` would be a
  defense-in-depth move worth considering separately.

## Deprecation window

No deprecation window applies. The archive copies were never
contracted (no entry in `contracts/`), no NCCS-repo code reads from
them, and the rename manifest provides a strictly better way to find
the canonical filename than the deleted file itself did.

## Follow-up

1. The `nccs-data-archive` bucket now serves two purposes:
   `superseded/` (per ADR 0005) and the rename manifest. Note this
   in `ARCHITECTURE.md` when describing the bucket layout.
2. Consider enabling versioning on `nccsdata/legacy/` (or a periodic
   Glacier snapshot) to compensate for the loss of the byte-identical
   archive copy. Defer until a real need surfaces.
