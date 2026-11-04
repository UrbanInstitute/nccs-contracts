# Convention: tax year, tax period, and the year columns

**Status:** Convention, proposed 2026-11-04 under ADR 0053 and ADR 0054. The
written rule here is the standard. The fixture file
`conventions/fixtures/tax-year.csv` is the test every implementation must
pass. Any function, in any language, that produces these columns is one
implementation of this rule.

**Scope:** every NCCS series that carries a year for a return: CORE
(`core-990`, `core-legacy`, `core-panel`), the e-file series, and anything
derived from them.

## 1. The three facts a return carries

| Column | Meaning | Source |
|---|---|---|
| `tax_period` | The month the accounting period **ends**, as six characters `YYYYMM`. | SOI extract `tax_pd`; BMF `TAX_PERIOD`; legacy CORE `TAXPER`; e-file `TaxPeriodEndDt`. All are the period end. |
| `tax_year` | The year the accounting period **begins**. This is the IRS definition (the 2023 Form 990 covers periods beginning in 2023) and the e-file header's `TaxYr`. It is the join key across NCCS series. | Read from the return when a start date exists; otherwise inferred, see section 3. |
| `tax_year_end` | The year the accounting period ends: the first four characters of `tax_period`. | Derived. This is what CORE's `tax_year` held before ADR 0053. |

For a December year end the two years are the same. For any other year
end they differ by one.

## 2. Accepted input and validation

`tax_period` is accepted when all of these hold:

- exactly six characters, all digits;
- month `01` to `12`;
- year inside the series' plausibility window (CORE: `tax_year_range()` in
  `nccs-data-core/R/data.R`).

Legacy files before 1997 carry a four-character `YYMM`. The legacy
harmonizer converts those to six characters before this rule applies;
a four-character value reaching this rule is invalid.

When `tax_period` is invalid: `tax_period`, `tax_year`, `tax_year_end`
and `tax_month` are all `NA`, the row is kept, and the producer logs a
count of invalid rows. A producer must not drop the row or guess.

## 3. Deriving `tax_year`

1. **A start date is available** (e-file `TaxPeriodBeginDt`, or the
   header `TaxYr`): `tax_year` is the year of that date and
   `tax_year_inferred` is `FALSE`.
2. **Only the end month is available** (SOI extracts, BMF, legacy CORE):
   if the end month is `12`, `tax_year` is the end year; otherwise it is
   the end year minus one. `tax_year_inferred` is `TRUE`.

Rule 2 is exact for twelve-month periods. It is wrong for a short period
that begins and ends in the same calendar year (for example January to
June 2023, which rule 2 labels 2022). An end month alone cannot tell a
full-year return from a short one, so the flag says the year was
inferred. It does not claim to identify short periods.

## 4. The advisory signal for a change of period

Where the BMF accounting-period month for the EIN (`ACCT_PD`) differs
from the month of `tax_period`, `accounting_period_mismatch` is `TRUE`.
It is advisory: a mismatch means the filer may have changed its fiscal
year around this return, so the inferred `tax_year` deserves a look. It
is not proof of a short period and a match is not proof of a full one.
When no BMF row exists for the EIN the column is `NA`.

## 5. Amendments and the join key

One EIN can carry two rows for the same `tax_period` when a return was
amended (the same period appears in two extracts). `is_amendment` is
`TRUE` on every row after the first extract in which the pair appeared.
`ein` plus `tax_year` is therefore not unique. Consumers join on `ein`,
`tax_year` and `tax_period`, and use `is_amendment` to pick one row.

## 6. The fixture

`conventions/fixtures/tax-year.csv` holds one row per case. Columns:

| Column | Meaning |
|---|---|
| `case` | short name |
| `tax_period` | input, as published |
| `period_begin` | input, `YYYY-MM-DD` when a start date is available, else empty |
| `bmf_accounting_month` | input, `MM` from the BMF when available, else empty |
| `expected_valid` | `TRUE` or `FALSE` |
| `expected_tax_year` | integer or empty for `NA` |
| `expected_tax_year_end` | integer or empty for `NA` |
| `expected_tax_year_inferred` | `TRUE`, `FALSE` or empty for `NA` |
| `expected_accounting_period_mismatch` | `TRUE`, `FALSE` or empty for `NA` |
| `note` | why the case exists |

An implementation passes when every row matches on every `expected_`
column. A new edge case found in production is added here first, with
its expected answer, and every producer picks it up on its next run.

## 7. Implementations

- CORE: `nccs-data-core/R/transforms/tax_period.R` (`transform_tax_period`).
  Produces `tax_period`, `tax_year_end` and `tax_month` today; `tax_year`
  as the start year arrives with ADR 0053 Stage 2.
- E-file: `nccs-data-efile` reads `TaxYr` from the return header.
- Each producer runs its implementation against the fixture in CI.
