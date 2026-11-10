# 0057: One row per return in the pre-2012 CORE

- **Status:** Proposed (2026-11-09)
- **Date:** 2026-11-09
- **Deciders:** Thiyaghessan Poongundranar (tpoongundranar@urban.org); decided 2026-11-09 to fix at the source rather than in a consumer
- **Related:** [[0056-harmonized-format-compatibility-files]] (where the repeats were found), [[0053-core-tax-year-definition]] (rows are assigned to years by period end), [[0033-deprecation-window-policy-and-critical-bug-override]], contract `core-legacy`, contract `core-panel`

## Context

The pre-2012 CORE files at `processed_legacy/core/{year}/990combined/`
are built from the yearly NCCS CORE files (`legacy/core/CORE-{year}-...`).
Each row is assigned to a year by the end of its own accounting period,
not by the NCCS file it came from.

Each yearly NCCS file carried returns forward: an organization that had
not filed again kept its previous return in the next year's file. So the
same return (same EIN, same period end) sits in two or three consecutive
NCCS files, and the pipeline lands every copy in the same output year.

Measured on 2005 (2026-11-09):

- The raw 2005 NCCS charities file has 315,224 rows and no repeated
  return.
- The published 2005 file has 490,488 rows; 97,593 of them repeat an
  EIN plus period end. In the charities part, 60,293 rows repeat, and
  43,729 of those are identical to another row in every value.
- Of the repeated charity returns, 16,545 also sit in the 2004 NCCS file
  and 33,507 in the 2006 NCCS file.

The merged panel (`processed_merged/core/`) already keeps one row per
(EIN, period end) on each side before merging, so its row counts are
not affected. Its values can be: today it keeps the first copy it
meets, while this decision keeps the newest NCCS file's copy, and
repeated copies do not always agree (16,564 of the repeated 2005 charity
rows differ somewhere). The pre-2012 CORE files themselves have the
repeats, and `sector-in-brief-data` reads them.

## Decision

1. **One return, one row.** In `processed_legacy/core/`, each
   (`ein`, `tax_period`) appears once per year file. Rows with no
   `tax_period` are not treated as repeats.
2. **The newest NCCS file wins.** When a return sits in more than one
   NCCS file, the copy from the latest file is kept, since a later file
   carries any correction NCCS made.
3. **The source file year is published.** A new column
   `source_file_year` holds the year of the NCCS file each row came
   from, so the choice can be audited. It is described in the per-year
   dictionary.
4. **The rule lives in one place:** `R/transforms/repeated_returns.R`
   in `nccs-data-core`, applied once in the legacy harmonize step, with
   a unit test. Consumers do not deduplicate.
5. **Keep what is there before replacing it.** Before any upload, the
   current published files of every affected year in
   `processed_legacy/core/` and `processed_merged/core/` are copied to
   `processed_legacy/core/_superseded-2026-11/` and
   `processed_merged/core/_superseded-2026-11/`, same relative paths,
   each with a manifest (ADR 0014) recording sha256 per file. The copies
   are written once, verified, never rewritten, and retained
   indefinitely under the same rule as ADR 0056 Decision 2. The upload
   runs only after the copy's manifest verifies, and a retry reuses the
   copy rather than remaking it (ADR 0056 Decision 13). The release note
   links to the copies.
6. **Republish.** The pre-2012 years are rebuilt and republished at the
   same paths. The merged panel is rebuilt after, since it reads them.
   The merged rebuild's acceptance evidence includes, per year, the
   count of rows whose values changed and which columns changed most,
   taken from the before copy; the release note reports them.

## Consequences

- Row counts in every pre-2012 year file fall. For 2005 the charities
  file goes from 324,768 rows to about 264,000.
- `sector-in-brief-data` and any other reader of the pre-2012 CORE files see fewer
  rows and one new column. Aggregates that summed over the repeats were
  too high and will change.
- Readers of the merged panel see the same row counts but, where
  repeated copies disagreed, different values for some rows.
- The ADR 0056 rewrite of the harmonized files inherits clean rows with
  no logic of its own.

## Deprecation window

We will not be providing 90-day notice since this is a defective file
which falls under the rule's exception (ADR 0033): the repeats are a
correctness defect (double counting), the fix removes rows rather than
changing their meaning, and the one added column is additive. Skipping
the notice does not mean skipping the copy: the old files are copied
aside first (Decision 5), so anyone who used them can still get them.
Readers are told in the release note.

## Follow-up

1. Rerun the legacy pipeline on EC2 (ADR 0056 Follow-up item 3 uses the
   same EC2 instance); copy the current published years aside per Decision 5; then
   republish `processed_legacy/core/`.
2. Rebuild the merged panel, measure the value changes against the
   before copy for correctness, then republish.
3. Record the per-year dropped counts in the contract's notes and in the
   release note.
4. Sector in Brief does not update on its own. After the republish:
   rerun `sector-in-brief-data` to produce a new dated version of its
   tables (pre-2012 counts will fall), check the new numbers, then
   repoint the dashboard to that version.
5. Review the CORE processing code (`nccs-data-core`) for brittleness:
   the maintainer reads it by hand with the `ub-mode` skill applied
   (tests first, one decision in one place, root causes). The two
   defects found this month, the carried-forward repeats and the 2025
   damage, both came from stacking steps that no test covered.
6. Update [`contracts/core-legacy.yml`](../contracts/core-legacy.yml)
   (the `one_row_is` block and the new column) and
   [`contracts/core-panel.yml`](../contracts/core-panel.yml).

## Outcome

Written when the work is done. It will state: the date the pre-2012
files and the merged panel were republished, the per-year rows dropped,
the per-year value changes in the merged panel, where the before copies
are, the link to the release note, and the dates the Sector in Brief
tables were rerun and the dashboard repointed. Until then this decision
stays Proposed or Executing.
