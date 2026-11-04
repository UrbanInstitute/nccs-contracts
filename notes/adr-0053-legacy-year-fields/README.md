# Legacy CORE year fields, profiled in full (2026-11-04)

Evidence for ADR 0053's open question: what year columns the legacy
CORE files (1989 to 2011) hold, how fully they are populated, and
whether the start year they carry adds anything to the period end.

**How.** Every file at `s3://nccsdata/legacy/core/CORE-{1989..2011}-*.csv`
(68 files, three scopes, 11,347,844 rows) was read in full with DuckDB on
a temporary EC2 instance (`profile_legacy_year_fields.py`, then
`followup_file_year_and_1999.py`). Nothing was sampled. The instance was
terminated afterwards. There is no 1993 private-foundation file on S3.

**Tables.** `legacy-year-fields-2026-11-04.csv` (one row per file:
population and agreement counts), `legacy-file-year-alignment-2026-11-04.csv`
(which year each file's rows belong to), and
`core-1999-charities-pz-taxper-vs-styear.txt` (the 1999 anomaly).

## Findings

1. **STYEAR, FISYR and TAXPER are present and fully populated in every
   file**, all 23 years and all three scopes. The only field that comes
   and goes is SOIYR (12 of 23 years, and only some scopes). No
   partial-return, initial-return, final-return or short-period flag
   exists in any file.

2. **TAXPER is six characters (YYYYMM) in every file**, including 1989
   to 1996. The old dictionary note that early years use a two-digit
   year does not describe the files on S3.

3. **STYEAR carries no information beyond TAXPER.** Applying the
   inference rule in `conventions/tax-year.md` (December end means that
   year, otherwise the year before) to TAXPER reproduces STYEAR on every
   row except 32 across all files, plus the 1999 anomaly below. The
   legacy "starting year" was derived from the period end by the same
   rule we now write down. It is not a reported start date, so at ADR
   0053 Stage 2 the legacy tier gets `tax_year_inferred = TRUE` like the
   SOI rows, not FALSE.

4. **FISYR equals the TAXPER year on every row** (again except the 1999
   anomaly). FISYR is the period-end year under another name.

5. **The legacy files are not organized by tax year.** In each file only
   52 to 85 percent of rows have a period-end year equal to the file
   year; the rest end in the year before or the year after. This
   confirms that the legacy files were processing batches that mix tax
   years, as Jesse Lecy said, and it is why the legacy harmonizer
   re-sorts rows by TAXPER rather than trusting the filename.

6. **CORE-1999-501C3-CHARITIES-PZ.csv has a broken TAXPER.** TAXPER is
   blank on 4.4 percent of rows (11,071) and on most of the rest it is
   one year behind STYEAR and FISYR (for example TAXPER year 1998 with
   STYEAR 1998 and FISYR 1999 on 80,768 rows, and TAXPER 1998 with
   STYEAR 1999 and FISYR 1999 on 64,331 rows). STYEAR and FISYR are
   consistent with each other; TAXPER looks like the prior period's end
   date. Only 6.6 percent of rows have a TAXPER year equal to the file
   year, against 70 to 74 percent in the neighbouring years. The other
   two 1999 files are fine.

   Consequence for `nccs-data-core`: the legacy harmonizer derives
   `tax_period` and `tax_year` from TAXPER, so most of this file's rows
   are currently published under the wrong year in `processed_legacy/`.
   Backlog U13. The fix is to derive `tax_period` for this file from
   FISYR and ACCPER (end year and end month), which are intact.

## What this settles for ADR 0053

- The legacy tier can switch to the start year by the same inference
  rule as the modern tier, with the inferred flag TRUE. No seam.
- There is no legacy short-period flag to carry forward.
- The 1999 charities file needs its own correction before Stage 2,
  otherwise the row movement at Stage 2 would be confounded with it.
