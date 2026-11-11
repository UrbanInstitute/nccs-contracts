# Full scan of the frozen harmonized CORE files (2026-11-11)

Evidence for ADR 0056 Follow-up 1 and 1a: which files under
`s3://nccsdata/harmonized/core/` are damaged, and where the 38 returns
found only in the old 2022 charities file went.

## Result

All 231 files were read in full from a local copy on a temporary EC2
instance. None failed to read. 98 files are damaged and 133 are clean.

| File group | Files | Damaged |
|---|---|---|
| Yearly files, charities, 990 and 990-EZ filers (`501c3-pz/marts/`), 1989 to 2023 | 35 | 35 |
| Yearly files, other nonprofits, 990 and 990-EZ filers (`501ce-pz/marts/`), 1989 to 2023 | 35 | 35 |
| Yearly files, charities, full 990 filers (`501c3-pc/marts/`), 2012 to 2023 | 12 | 12 |
| Yearly files, other nonprofits, full 990 filers (`501ce-pc/marts/`), 2012 to 2023 | 12 | 12 |
| All-years parquet files of those four groups (`full/`) | 4 | 4 |
| Private foundation files (37 yearly, 1 all-years, 1 dictionary) | 39 | 0 |
| Base files (`CORE-{year}-{CLASS}-HRMN.csv`) | 90 | 0 |
| Dictionaries of the four damaged groups (`dd/`) | 4 | 0 |

In most damaged files the worst column is wrong on 98 to 100 percent of
rows. A file has between 16 and 73 damaged columns.

## What counts as a damaged cell

A number that is not zero and is smaller than 1e-300 in size. The files
show these as values such as 1.11e-308. They appear when a whole number
stored in 64 bits is read back as a decimal number. In a CSV file the
scan looks for text of that form; in a parquet file it tests the decimal
columns.

## The 38 returns

The old 2022 charities file has 38 returns (EIN plus period end) that
the rebuilt 2022 charities file does not. All 38 are in the current
CORE for 2022 under subsection codes 4, 5, 6 or 7, so the rebuilt files
place them in the 2022 nonprofit file. No return is lost.

## Files

- `scan_frozen.R`: the scan. It was run once, for this evidence, and is
  written for speed and not to the repo's R style.
- `frozen_scan_by_file.csv`: one row per file, with rows, columns,
  damaged columns and damaged cells.
- `frozen_scan_by_column.csv`: one row per damaged column of each file.
- `returns_only_in_old_2022_charities_pz.csv`: the 38 returns and the
  subsection code the current CORE gives each one.
