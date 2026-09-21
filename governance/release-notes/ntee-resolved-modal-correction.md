# NCCS Release Note — NTEE-resolved crosswalk: modal view corrected

**Status:** DRAFT (2026-09-21); FINAL once the corrected files are published.
**Product:** NTEE-resolved crosswalk (`s3://nccsdata/crosswalks/ntee-resolved/`).

**What was wrong.** The crosswalk build read every parquet file under
`intermediate/bmf/`. For 30 of the 35 monthly vintages from June 2023 to
January 2026 that folder held two copies of the same month's data: the
pipeline's current file and an older copy left behind when the file name
changed in January 2026. Those 30 months were therefore counted twice.

**What it affected.** Only the columns that count vintages. In the
version published on the morning of 2026-09-21 (vintage 2026_09):

- `ntee_modal` (with its subsector and version 2 forms) was a different
  code for 82,945 of 3,624,536 organizations. Because the doubled months
  were the recent ones, the published modal leaned toward an
  organization's most recent code; the corrected modal is the code that
  appears in the most vintages overall.
- `ntee_modal_n`, `n_vintages_with_ntee` and `ntee_code_distribution`
  carried inflated counts for about 1.4 to 1.5 million organizations.
- `ntee_agreement` changed for 560 organizations.
- `ntee_current`, `ntee_most_recent` and their vintage columns were not
  affected. No rows were added or removed.

**Other products.** The Unified BMF, its geocoded form, the state marts and
the address-resolved crosswalk are not affected: they either read the
processed CSVs or count distinct vintages.

**Fix.** The build now reads only the pipeline's own file in each vintage
folder and stops if a folder holds more than one; the 30 stale copies were
deleted on 2026-09-21. The corrected crosswalk replaces the published one
in place under the same vintage (ADR 0033 critical-bug clause: same rows,
values corrected).

**Details:** nccs-data-bmf PR #60; BACKLOG Z28; found while closing Z18
(whose first row-count estimate was inflated by the same double count).
