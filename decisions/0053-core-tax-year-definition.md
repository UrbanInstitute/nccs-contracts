# 0053: What the CORE tax_year column means, and how it changes

- **Status:** Proposed (2026-11-03). For the data governance committee to accept, amend or reject. Nothing in `nccs-data-core` changes until this is accepted.
- **Date:** 2026-11-03
- **Deciders:** sole maintainer, with Jesse Lecy; to be confirmed by the governance committee
- **Related:** [[0015-core-contract-surface-restructure]], [[0027-core-990-parquet-promotion]], [[0046-external-soi-harmonization-concordance]], [[0048-nteev2-specialty-code-x00-rule]] (why rules need executable checks), governance charter (tax period is an essential field), contracts `core-990`, `core-legacy`, `core-panel`

## Context

CORE has a column named `tax_year`. Today it holds the first four digits
of `tax_period`, which is the month the accounting period ends. So a
return covering July 2022 to June 2023 is `tax_year` 2023 in CORE.

The IRS defines the tax year by the year the period begins. The Form 990
instructions assign the 2023 form to periods beginning in 2023, and the
e-file header carries that starting year. Our own e-file extraction
(`nccs-data-efile`) takes `tax_year` from that header, so the same return
is `tax_year` 2022 there. Jesse Lecy's harmonized SOI panel also uses the
starting year.

For returns with December year ends the two definitions agree. For every
other year end they differ by one year. In CORE's 2023 file that is
199,087 of 515,769 returns, about two in five. A user joining CORE to
e-file on EIN and year today gets the wrong row for those filers unless
they know this history.

Two further facts shape the fix:

1. The IRS SOI extracts that CORE is built from are grouped by the year
   the IRS processed the return, not by tax year. CORE already pulls
   those apart and re-sorts rows by `tax_period`. So "keep the files as
   they are" does not preserve anything the IRS defined. It preserves
   only our own earlier choice.
2. The extract carries the period end month (`tax_period`, YYYYMM) but
   not the start date, and no flag for first returns, final returns or a
   change of accounting period. The starting year can be inferred for
   ordinary twelve-month periods (December end means that year, any other
   end means the year before) but that rule is wrong for a short period
   that starts and ends in the same calendar year. The extract cannot tell
   those cases apart on its own. The BMF accounting-period month can flag
   some of them.

The governance charter lists tax period definitions as an essential
field whose change is architectural. That is why this is an ADR and not
a code change.

## Decision

1. **Target meaning.** `tax_year` in CORE means the year the accounting
   period begins, the same as the IRS and the e-file series. This is the
   join key across NCCS series.

2. **Three year columns, each named for what it holds.**
   - `tax_period` stays as it is (YYYYMM, period end). It is the raw
     evidence and must always be published.
   - `tax_year_end` is the four-digit year of `tax_period`. This is what
     `tax_year` holds today, under an honest name.
   - `tax_year` becomes the starting year. For now it is inferred from
     `tax_period` by the twelve-month rule above. A column
     `tax_year_inferred` is TRUE on every row where the start year was
     inferred rather than read from the return (all SOI-derived rows
     today). An end month alone cannot tell a full-year return from a
     short period, so the flag claims inference, not a short period.
     Where the BMF accounting period month for that EIN differs from the
     `tax_period` month, `accounting_period_mismatch` is TRUE as an
     advisory signal of a possible change of period; it is not proof.
   - Where a reported starting year exists (e-file rows in the merged
     panel), it is used and `tax_year_inferred` is FALSE.

3. **Staged change, not a rewrite.**
   - Stage 1, next CORE release: add `tax_year_end`, `tax_year_inferred`
     and `accounting_period_mismatch`. `tax_year` keeps its current meaning in
     this release. The dictionary and the release note say so.
   - Stage 2, the following release: `tax_year` switches to the starting
     year and rows move to the matching year directories. The legacy
     boundary clamp in `03_harmonize.R` (drops rows at or below 2011)
     changes in the same commit, otherwise non-December returns ending in
     2012 would be relabelled 2011 and dropped. The release note states
     the row movement per year so a fall in one year's count is not read
     as a change in the sector.
   - Earlier releases are not rewritten. They stay readable at their
     vintage paths (ADR 0013).

4. **Join contract.** EIN plus `tax_year` is still not unique: amendments
   and short periods can give one EIN two rows in a year. Consumers join
   on EIN, `tax_year` and `tax_period`, and use `is_amendment` to pick
   one. The `core-990` contract will say this.

5. **Executable rule.** The starting-year rule, and the short-period
   cases it cannot resolve, go in `conventions/tax-year.md` with a small
   fixture file of inputs and expected outputs (ordinary periods, a June
   year end, a short period inside one calendar year, an amendment).
   Each producer runs its own implementation against the fixture in CI.
   A shared R implementation may exist and is welcome, but the fixture is
   the standard, not the code (see 0048 for why prose alone did not hold).

## Consequences

- Users get one year column that means the same thing across CORE and
  e-file, and the raw end month to re-sort by if their other source
  differs.
- Every current reader of CORE by year is affected at Stage 2: nccsdata,
  sector-in-brief-data, the website catalogs. Each needs a contracts-guard
  acknowledgment and a note in its own release.
- Stage 1 is additive and safe. Stage 2 moves about two in five rows per
  year. The release note carries the count.
- The inferred flag is honest about what we know. Short periods remain
  imperfect until a source with the start date (e-file) covers the row.

## Evidence on what `tax_period` holds

The SOI extract field `tax_pd` is documented only as "Tax Period: Form
990 Header" and does not say start or end. It is the end. The BMF
documents its TAX_PERIOD field as the period ending, and the two agree
for the same return. Example: Centerstone of Tennessee, period July 2022
to June 2023, carries 202306 (from the 2026-10-30 email exchange). What
can be inferred from an end month: the start year for a twelve-month
period. What cannot: whether the period was twelve months.

## Open questions for the committee

- Should the panel tier (`core-panel`) flip in the same release as
  `core-990`, or one release later?
- Is `tax_year_end` the right name, or `period_end_year`?
- Does the legacy series (1989 to 2011) hold the starting year, the end
  year, or both? Jesse recalls STYEAR and partial-return flags appearing
  in some years and not others (2026-11-03), so nothing can be pinned on
  memory. Task: profile every legacy year for the presence and population
  of STYEAR, ENDYEAR, TAXPER and any partial-return indicator, and put
  the table here before the historical treatment is settled.
