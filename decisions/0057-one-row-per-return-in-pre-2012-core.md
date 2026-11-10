# 0057: One row per return in the pre-2012 CORE

- **Status:** Proposed (2026-11-09)
- **Date:** 2026-11-09
- **Deciders:** sole maintainer (decided 2026-11-09 to fix at the source rather than in a consumer)
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
(EIN, period end) on each side before merging, so it is not affected.
The pre-2012 tier itself is, and `sector-in-brief-data` reads it.

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
5. **Republish.** The pre-2012 years are rebuilt and republished at the
   same paths. The merged panel is rebuilt after, since it reads them.

## Consequences

- Row counts in every pre-2012 year file fall. For 2005 the charities
  file goes from 324,768 rows to about 264,000.
- `sector-in-brief-data` and any other reader of the tier see fewer
  rows and one new column. Aggregates that summed over the repeats were
  too high and will change.
- The ADR 0056 rewrite of the harmonized files inherits clean rows with
  no logic of its own.

## Deprecation window

Waived under ADR 0033: the repeats are a correctness defect (double
counting), the fix removes rows rather than changing their meaning, and
the one added column is additive. Readers are told in the release note.

## Follow-up

1. Rerun the legacy pipeline on EC2 and republish `processed_legacy/core/`
   (ADR 0056 Follow-up 3 shares the box).
2. Rebuild and republish the merged panel.
3. Record the per-year dropped counts in the contract's notes and in the
   release note; tell the `sector-in-brief-data` maintainer.
4. Update the `core-legacy` contract (row grain, new column).

## Outcome

_To be filled at reconcile._
