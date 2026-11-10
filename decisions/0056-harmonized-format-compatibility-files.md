# 0056: Correct the frozen "harmonized" CORE files once, in place, from the current CORE, and keep the damaged originals aside

- **Status:** Accepted 2026-11-10, now Executing (decided by the maintainer on merge of PR #126)
- **Date:** 2026-11-09
- **Deciders:** Thiyaghessan Poongundranar (tpoongundranar@urban.org); raised by an outside user's report through the website contact form (2026-11-09)
- **Related:** [[0035-retain-harmonized-core-frozen-surface]] (amends: a frozen file can hold a defect), [[0033-deprecation-window-policy-and-critical-bug-override]] (the correctness-defect override used here), [[0043-legacy-format-compatibility-views]] (same renaming pattern, different old format), [[0014-standardize-manifest-shape]], [[0053-core-tax-year-definition]]

## Context

**What the older format is.** Between 2023 and April 2025 NCCS published
CORE files in a "harmonized" format at `s3://nccsdata/harmonized/core/`.
Its column names start with `F9_`, `SA_`, `SC_` and so on (for example
`F9_09_EXP_INFO_TECH_TOT`), and its key is `EIN2`. ADR 0035 froze those
files: they are kept and protected from deletion, and no longer updated.
The current CORE files live at `processed*/core/` and use different,
plain column names (for example `information_technology`).

**What was found on 2026-11-09.** A user reported that dollar amounts in
`CORE-2022-501C3-CHARITIES-PZ-HRMN-V1.csv` had turned into the value
1.11e-308. Checks against the live files showed:

- A full scan of that file: 47 of 298 columns are damaged. Total assets
  is damaged in 439,859 of 443,601 rows.
- 3 MB samples of the same yearly files for 2012, 2015, 2018, 2019, 2020
  and 2021, and of the 2022 files for `501c3-pc`, `501ce-pz` and
  `501ce-pc`, show the same damage. The private foundation sample (V0)
  was clean.
- The yearly files were last written on 2025-04-10. The bucket keeps no
  earlier version of them: an overwrite would destroy the only copy.
- The base files in the same folders are clean, but they are only an
  input to the yearly files. For 2022 the base file has 50,844 rows and
  the yearly file has 443,601.
- The damaged values cannot be reliably turned back into dollars.
- A second defect in the same file: it has 443,601 rows but only
  392,795 distinct returns (EIN plus period end). 50,806 returns appear
  twice. These are the base-file rows, stacked on top of the same
  returns from the newer IRS extract.
- Likely cause: the old build script (`R/core_update.R`, commit
  `f4cb15a`) stacked columns stored as 64-bit whole numbers on top of
  columns stored as decimals. This has not been proven by a re-run.
- Not yet checked: the five large `full/` parquet files written the same
  day (one per family, private foundations included), and every year in
  full.

**ADR 0035 assumed this could not happen.** Its text reads: "a frozen
artifact cannot acquire a correctness/corruption defect", and on that
basis it ruled out the ADR 0033 override for a correctness defect. The
files were already damaged when they were frozen. Freezing protects
files from change. It does not show they were right. The promise in ADR
0035 exists to protect the people who read these files, and for them
the files are broken at the address they use.

**Can the format be rebuilt from the current CORE?** Yes, for most
columns. The old pipeline renamed IRS source columns to `F9_` names with
one table (`XWALK-990-V2.csv`, in the repo history). The current pipeline
renames the same IRS source columns to the current names with the
`*_crosswalk_FINAL` tables. Linking the two through the IRS source name:

- Form 990 and Form 990-EZ each have exactly one current column for
  every old name that links (246 and 72 old names).
- The pre-2012 files have 100 old names with one source and 17 with
  more than one, because the old table sent several different fields to
  one `F9_` name (for example beginning and end of year net assets both
  to `F9_10_NAFB_TOT_BOY`).
- 20 old names link to nothing in any form. Two of them (`TAX_YEAR`,
  `EIN2`) are simple to derive.
- The column list of each file family is the same in every year (checked
  2012, 2017 and 2022 for the charities PZ family).

**Who uses the format.** The website catalog links to it. The outside
contacts recorded under ADR 0035 are Jesse Lecy, Lewis Faulk and Mirae
Kim.

## Decision

1. **The damaged files are replaced once, in place, at the same paths.**
   The replacement is the current CORE's values, renamed to the old
   column names, written to exactly the keys being replaced: same
   folder, same file name, same `V1` token (a parquet copy is added
   beside each CSV). Nobody has to change a link or a path. This uses the
   ADR 0033 override for a correctness defect, with no waiting period:
   every day the damaged files stay at those paths, someone can download
   wrong numbers.

2. **The damaged originals are copied aside first, before any
   overwrite.** Every object under `harmonized/core/` that will be
   replaced is copied to `harmonized/core/_superseded-2025-04/` with the
   same relative path, and a manifest is written for that copy. The
   bucket keeps no earlier versions, so this copy is the only record of
   what was published between April 2025 and the rewrite. It is kept
   under the same non-deletion protection as the rest of the folder.
   The overwrite does not start until the copy's manifest verifies.
   The copy is retained indefinitely. If the `harmonized/core/` paths
   are ever retired, the copy moves with the rest to a reachable archive
   under the ADR 0005 pattern; notice alone does not discharge it.

3. **After the rewrite the folder is frozen again, and not updated.**
   No ongoing generation, no yearly review, no new surface. The rebuilt
   files stop at the newest tax year the current CORE has at rewrite
   time. Anyone who wants newer years, or corrections after this one,
   uses the current CORE. The website says so beside the links.

4. **What is rewritten, from which source.** "PC" means full Form 990
   filers only. "PZ" means Form 990 and Form 990-EZ filers together.

   | Family | Years | Source | Which rows | Stage |
   |---|---|---|---|---|
   | 501C3-CHARITIES-PC | 2012 to newest | `processed/core/{year}/990` | `is_501c3` is TRUE | 1 |
   | 501CE-NONPROFIT-PC | 2012 to newest | `processed/core/{year}/990` | `is_501c3` is FALSE | 1 |
   | 501C3-CHARITIES-PZ | 2012 to newest | `processed/core/{year}/990` and `/990ez`, stacked | `is_501c3` is TRUE | 1 |
   | 501CE-NONPROFIT-PZ | 2012 to newest | same | `is_501c3` is FALSE | 1 |
   | 501C3-CHARITIES-PZ | 1989 to 2011 | `processed_legacy/core/{year}/990combined` | `source_subsection_class` is 501C3-CHARITIES | 2 |
   | 501CE-NONPROFIT-PZ | 1989 to 2011 | same | `source_subsection_class` is 501CE-NONPROFIT | 2 |
   | the `full/` parquet file and `dd/` dictionary of each of the four families above | all | the rewritten yearly files | all | with their family |
   | 501C3-PRIVFOUND-PF, including its `full/` and `dd/` | all | not covered | | own decision if its full check finds damage |

   Notes on the table:
   - The yearly files (`marts/`) are rewritten. The base CSVs
     (`CORE-{year}-{CLASS}-HRMN.csv`) are clean and are left as they are.
   - The combined 990 plus 990-EZ file in `processed/core/` is not used
     for 2012 on. It keeps only the columns the two forms share, so it
     lacks 990-only items such as technology expenses.
   - `is_501c3` is never missing. A row with no subsection code counts as
     FALSE and lands in the NONPROFIT family. No row is dropped by the
     split.
   - Before 2012 the split uses `source_subsection_class`, the class the
     row carried in the original NCCS file, because about 1% of those
     rows have no subsection code (0.78% in 2005).
   - There are no PC files before 2012. The frozen files never had them,
     and the pre-2012 source does not mark which form a row came from.
   - Stage 1 and stage 2 are built, checked and uploaded in one rewrite.
     Stage 2 waits on the 17-column review in Decision 6. S3 replaces
     one object at a time, so the folder is mixed for the length of the
     upload. How that is handled is Decision 13.

5. **Every old column is kept, in the old order.** Each family's header
   is exactly the frozen header (263 columns for the PC families, 298
   and 296 for the PZ families). A column the source cannot fill is
   present and empty, and the dictionary says so, rather than missing.
   Old code written against the files keeps running. After the old
   columns come five current-CORE columns, added at the end: `ein`,
   `tax_period`, `source_form` (`990`, `990ez` or `legacy_pz`),
   `is_amendment` and `extract_year` (the year of the IRS extract the
   row came from).

6. **The name mapping is kept as data and published beside the files.**
   One table, `harmonized/core/dd/HARMONIZED-COLUMN-MAP.csv`: one row
   per old name, source form and span of years, with the current name,
   a transform (blank means copied unchanged), a status (`mapped`,
   `empty`) and a note. The source for an old name can differ by form
   (for example `F9_08_REV_OTH_SALE_GAIN_NET_TOT` comes from
   `net_gain_loss_sales` on Form 990 and `gain_loss_sales_other_assets`
   on Form 990-EZ); the rename is applied to each form's rows before the
   forms are stacked. The 17 pre-2012 names with more than one possible
   source each get one source per span of years from a reviewed
   overrides file in `nccs-data-core`, the same way the current
   crosswalks handle overrides. No column is filled by guesswork.

7. **What one row is.** One row is one filing, exactly as in the source
   file. Nothing is selected or removed. `EIN2` plus `TAX_YEAR` is NOT a
   unique key: an organization can have two filings whose periods end in
   the same calendar year. Measured on 2022, `ein` plus `tax_period`
   identifies every row in the two charities files and all but one pair
   of rows in the two nonprofit files. The dictionary states this in its
   first lines, and the manifest records the count of repeated `ein`
   plus `tax_period` per file.

8. **The year in the file name keeps its old meaning.** `TAX_YEAR` is
   the year the accounting period ends, as in the frozen files. The
   generator does not trust the source folder's year for this. It reads
   every year folder of the source, derives the period-end year from
   `tax_period` on each row, and groups rows by that. So a return ending
   June 2023 goes into the 2023 file whether the source keeps it under
   `2023/` (today) or under `2022/` (if [[0053-core-tax-year-definition]]
   is accepted and rows move to starting-year folders). The check in
   Decision 10 counts source rows the same way.

9. **Same format, not the same values.** The numbers are the current
   CORE's checked values under the old names. They will not match the
   damaged files or earlier downloads exactly: row counts differ (the
   damaged files double-counted) and some values differ (the current
   CORE's own corrections). The dictionary, the notice file and the
   catalog entry say so.

10. **Checks before the overwrite. Any failure stops it.**
    - Values: every output column equals its source column, row for
      row, after the transform the name table records for it. This
      catches two columns being swapped, which counts alone would miss.
    - Rows: each family's row count equals the source row count under
      the rule in the table above, and the families of one source
      together hold every source row.
    - Columns and types: each file's header equals the frozen header
      plus the five carried columns, and types match the name table.
    - No numeric column holds a value that is not zero but smaller in
      size than 1e-300 (the signature of this defect).
    - The CSV and the parquet of each file hold the same rows and values.
    - The copy of the originals (Decision 2) verifies against its
      manifest.
    - Returns: for each yearly file, the set of returns (`ein` plus
      `tax_period`) in the file being replaced is compared with the set
      in its replacement. Returns only in the replacement must be
      accounted for by their IRS extract year (returns the IRS released
      after the old files were built) or by the old file's doubled rows.
      Returns only in the old file are listed with their count. Both
      lists and counts go into the manifest. An unexplained set stops
      the publish. For 2022 the result is in the trial section below.
    - Columns: every old column whose values differ from the old file
      for a material share of matched organizations has a written
      disposition in the name table's note column before the publish
      (for 2022 that is `F9_08_REV_MISC_OTH_TOT`, see below).
    - As a further check, not a substitute: for years with a clean base
      file, a sample of organizations is compared against it.

11. **Rule for defects in frozen files (amends ADR 0035).** A frozen
    file can hold a defect it was frozen with. When one is found: copy
    the originals aside, correct the files once in place under ADR
    0033's correctness-defect override, record the defect and the
    correction in the contract, and freeze again. ADR 0035's sentence
    "a frozen artifact cannot acquire a correctness/corruption defect"
    no longer holds, and ADR 0035 gets a pointer to this ADR.

12. **Telling people.** A notice file `harmonized/core/README.txt`
    states what was corrected, when, where the originals are, and that
    the current CORE is the place for newer years. The three outside
    contacts are written to on the day of the rewrite. The website CORE
    catalog gets the same note. A release note goes in `governance/`.

13. **How the upload runs, and how a reader can tell where it is.** S3
    replaces one object at a time, so there is a window in which some
    files are old and some new. The window is kept short and visible:
    - Everything is built and passes Decision 10 before the first
      upload. Nothing is built during the upload.
    - Order: the copy-aside and its manifest first; then
      `harmonized/core/README.txt` saying a rewrite is in progress and
      listing the files to be replaced; then the yearly files, one
      family at a time, oldest year first; then the `full/` parquet
      files; then the `dd/` dictionaries and the name table; then the
      folder manifest (ADR 0014, with per-file sha256); then
      `README.txt` rewritten to say the rewrite is complete.
    - Any reader can tell the state from `README.txt` and from the
      folder manifest: a file whose sha256 matches the new manifest is
      new; one that matches the copy-aside manifest is old.
    - **The copy-aside is written once and never rewritten.** Before
      the first upload, the copy-aside manifest records the sha256 of
      every original. On a retry after an interruption, the copy step
      is not rerun: the copy-aside is verified against its own manifest
      and reused. A retry never copies a live key into the copy-aside,
      because some live keys already hold replacement bytes. The
      replacement manifest (built before the first upload, with the
      sha256 of every replacement file) is the only list the retry
      works from: a live key whose sha256 matches the replacement is
      skipped, one that matches the original is uploaded, and one that
      matches neither stops the run for a person to look at. Delete
      protection on the folder does not prevent overwrites, so this rule
      is the only thing that keeps the originals intact; it is enforced
      in the upload script, not by bucket permissions.
    - The website note and the notices to outside contacts go out after
      `README.txt` says complete.

## Trial on 2022 (2026-11-09, not published)

The generator was run on the current 2022 Form 990 and 990-EZ files
(332,015 and 193,060 rows).

- Every output column equals its source column, row for row, on both
  forms.
- No value carries the defect signature in any of the four families.
- No row is lost in the split. The two PC files hold 332,015 rows
  together and the two PZ files hold 525,075, the same as their sources.
- Row counts: charities PC 257,128; charities PZ 408,774; nonprofit PC
  74,887; nonprofit PZ 116,301.
- Repeated `EIN2` within a file: 385, 581, 98 and 150 rows. Repeated
  `ein` plus `tax_period`: 0, 0, 1 and 1. No row is flagged as an
  amendment in the 2022 source.
- Against the clean 2022 base file, for about 51,000 matched
  organizations and 156 numeric columns, the median column matches
  exactly in 99.9% of rows.
- 256 of the 298 old columns of the charities PZ file are filled,
  counting `TAX_YEAR` and `EIN2`. Of the 42 that are not, 15 have no
  link to a current column and 27 link only to pre-2012 source names
  (mostly beginning-of-year balances), which the current 2022 file does
  not have. Under Decision 5 all 42 are present and empty.
- Returns, compared as `ein` plus `tax_period`: the damaged charities
  PZ file has 392,795 distinct returns; the rebuilt file has 408,774.
  16,017 returns are only in the rebuilt file, and every one of them
  comes from the 2024 IRS extract, which the old pipeline never took in.
  38 returns are only in the damaged file; they have not been explained
  (Follow-up 1a). The rest, 392,757 returns, are in both.
- `F9_08_REV_MISC_OTH_TOT` matches the base file in only 68% of rows.
  The old format carried the Part VIII line 11a amount under two names,
  this one for rows from the IRS extract and `F9_08_REV_MISC_TOT_A` for
  rows from the base files. The overrides review settles which names
  carry it.

## Trial on 2005 (2026-11-09, not published)

The build-and-check step was run on the current pre-2012 file for 2005
(`processed_legacy/core/2005/990combined`, 490,488 rows), with the
reviewed picks for the 17 columns applied.

- Every check passed: values equal source, no rows lost in the split
  (324,768 charities plus 165,720 other nonprofits), headers equal the
  frozen headers, no damaged values, CSV and parquet read back the same.
- Finding on the source, not on the rename: the current pre-2012 CORE
  file for 2005 repeats `ein` plus `tax_period` in 97,593 of its 490,488
  rows. In the charities file 43,729 of the repeated rows are identical
  to another row in every old column (plain duplicates); the rest differ
  in at least one value. This ADR carries rows as the source has them
  (Decision 7). Whether the current pre-2012 CORE should hold these
  duplicates is a question for `nccs-data-core` and its contract
  (`core-legacy`), not decided here. It is recorded in the backlog.

## Options not taken

- **Publish the rebuilt files in a new location and keep generating
  them at every CORE publish.** This was the first draft of this ADR.
  It keeps the damaged files at the address everyone links to, adds a
  second surface to run and review for as long as anyone uses it, and
  makes every reader change their links. Replacing once in place fixes
  the harm where people meet it and ends the obligation.
- **Warn only, build nothing.** Cheapest. Leaves users of the older
  format with no working files and a rename job of their own.
- **Re-run the 2024 pipeline with the bug fixed.** Brings back a retired
  pipeline and its other known problems, to produce values the current
  CORE already has in checked form.
- **Overwrite without copying the originals aside.** The bucket keeps no
  versions, so this would erase the only record of what people
  downloaded for eighteen months.
- **Drop the 42 columns the source cannot fill.** Keeps the header
  honest but breaks any code that names those columns. Empty columns
  with a stated reason break nothing.

## Consequences

- Users of the older format get working files at the paths they already
  use, for 1989 to the newest year, with the same headers.
- The format then stays frozen for good. No new years will be added to
  it. The current CORE is the only maintained CORE.
- Rows and some values differ from earlier downloads. Anyone who built
  on the damaged files between April 2025 and the rewrite is told, and
  can still fetch what they used from `_superseded-2025-04/`.
- One contract changes (`core-harmonized-frozen.yml`: defects, the
  copy-aside path, new hashes and counts). No new contracts.
- The generator, name table and checks live in `nccs-data-core` and are
  run once. They stay in the repo so the rewrite can be repeated or
  audited.

## Deprecation window

We will not be providing 90-day notice before overwriting the damaged
yearly files, since they are defective and fall under the rule's
exception (ADR 0033): every day they stay, readers download meaningless
numbers from the published address. The originals are copied aside
first and `_superseded-2025-04/` is never removed (Decision 2), so
nothing is lost.

## Follow-up

1. Check all five `full/` parquet files and every yearly file in full
   (EC2 job), private foundations included, and record the exact list of
   damaged files in the contract.
1a. Explain the 38 returns that are in the damaged 2022 charities PZ
   file and not in the current CORE.
2. Review the 17 pre-2012 multi-source columns and write the overrides
   file (stage 2).
3. Build the write step, the dictionary step and the `full/` parquet
   step in `nccs-data-core`; run the full rewrite on EC2 against the
   checks in Decision 10.
4. Copy the originals aside, verify, overwrite, write the notice file,
   update the contract's inventory and manifest.
5. Notices to Jesse Lecy, Lewis Faulk and Mirae Kim; release note in
   `governance/`; website note.
6. Add the pointer to ADR 0035.

## Outcome

Written when the work is done. It will state: the date of the rewrite,
the list of files replaced with their new sizes and hashes, where the
copy-aside is, the results of every check in Decision 10 per year, the
38 returns explained, and the dates of the notices. Until then this
decision stays Proposed or Executing.
