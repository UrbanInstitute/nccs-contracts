# 0058: Add the organization role column to the Unified BMF

- **Status:** Accepted 2026-11-10, now Executing (decided by the maintainer on merge of PR #129)
- **Date:** 2026-11-10
- **Deciders:** Thiyaghessan Poongundranar (tpoongundranar@urban.org); decided 2026-11-10 to add the column in the November 2026 build
- **Related:** [[0036-ein-coercion-safety-additive-columns]] (the earlier case of adding columns without changing existing ones), [[0048-nteev2-specialty-code-x00-rule]] (how the NTEE columns are built), [[0016-no-canonical-cross-dataset-merge]] (consumers join by EIN themselves)

## Context

Older NCCS files sorted every organization into one of three roles:
operating, supporting or mutual benefit. The older BMF files called the
column `LEVEL2`; the older CORE files called it `NCCS_LEVEL_2`. The
current BMF and CORE files do not have it.

On 2026-11-10 a colleague asked how to get it back. The rule behind the
old column was never written down, so it was worked out by comparing the
old column with the other columns in eleven older BMF files (June 1989 to
August 2022). Two findings:

- The old column had two definitions. Files through August 2016 used the
  NTEE code alone. Files from September 2017 on also counted a 501(c)(3)
  as supporting when its foundation code was 4 (private non-operating
  foundation) or 17 (organization run for the benefit of another public
  charity). No file exists between those two dates.
- With the right definition for each file, the rebuilt value equals the
  original for every organization that has an NTEE code, except for 1 to
  3 organizations per file.

The rule is now one tested R function, `derive_nccs_org_role()`, in
`nccs-data-bmf` (`R/nccs_org_role.R`, merged in nccs-data-bmf PR #67). A
one-off file made with it was sent to the colleague (see
`ARCHITECTURE.md` section 3, temporary one-off files).

## Decision

1. **Two new columns in the Unified BMF**, from the November 2026 build
   on:
   - `nccs_org_role`: "O" (operating), "S" (supporting) or "M" (mutual
     benefit). Missing when the role is unknown.
   - `nccs_org_role_definition`: the same value in words ("Operating",
     "Supporting", "Mutual benefit").

2. **The rule**, where the first line that fits wins:
   1. Supporting: subsection code 3 and foundation code 4 or 17.
   2. Supporting: characters 2 and 3 of the NTEE code are 11 or 12.
   3. Mutual benefit: the NTEE code starts with Y.
   4. Supporting: the NTEE code starts with T, except T0x, T19, T40 and
      T50.
   5. Operating: every other NTEE code.

   This is the later of the two historical definitions (September 2017
   on). The inputs are the Unified BMF's own `ntee_code_raw`,
   `subsection_code` and `foundation_code`.

3. **Unknown stays unknown.** An organization with no usable NTEE code,
   where line 1 does not apply, gets a missing value. The 2019 to 2022
   older files marked such organizations as operating. We do not, because
   that is a guess. In the September 2026 Unified BMF this is about
   611,000 of 3.7 million organizations.

4. **Punctuation after an NTEE code is ignored when deriving the role.**
   Sixty organizations whose newest row comes from a 2010 to 2016 file
   have a raw NTEE code with a comma after it ("B12,"). The role is
   derived from "B12". `ntee_code_raw` itself is not changed: it holds
   what the source file says, and the cleaned NTEE columns already read
   these codes correctly.

5. **One place computes it.** The role is added once, to the finished
   one-row-per-EIN table, by calling `derive_nccs_org_role()`. The rule
   is not repeated in SQL or in the monthly files. Everything built from
   the Unified BMF (the geocoded Unified BMF and the per-state files)
   receives the two columns unchanged.

6. **The name.** `nccs_org_role` says what the column holds, and the
   `nccs_` prefix marks it as derived by NCCS, not supplied by the IRS.
   The data dictionary states once that it was formerly `NCCS_LEVEL_2`
   and `LEVEL2`. The old levels 1 and 3 are a later task; the working
   names `nccs_org_class` and `nccs_org_field` are placeholders, because
   either may turn out to repeat a column the BMF already has.

7. **No notice period.** No existing column is renamed, removed or
   changed in meaning, and the Unified BMF contract already says new
   columns may be added at any time. The release note for the November
   build announces the two columns and where they sit.

8. **Where the columns sit.** In the Unified BMF they are the last two
   columns. The geocoded Unified BMF and the per-state files add their
   geocode columns after all the Unified BMF columns, so there the two
   role columns come after the other BMF columns and before the geocode
   columns.

## Consequences

- People who used `NCCS_LEVEL_2` can get the same grouping again from the
  current BMF, and join it to CORE by EIN.
- The value is only as complete as the NTEE code. Organizations without
  one are unknown unless their foundation code settles it.
- A T code that never appeared in the older files follows the general
  pattern in line 4. That is an extension of what was observed, not
  something observed.
- Anyone who reads the Unified BMF CSV by column position sees two extra
  columns at the end and nothing moved. Anyone who reads the geocoded CSV
  or a per-state CSV by column position sees the geocode columns move two
  places to the right. Reading by column name is not affected.
- The monthly BMF files (`processed/bmf/`) do not get the columns. If a
  consumer needs the role per monthly file, that is a new decision.

## Options considered and not chosen

- **Keep the old name `nccs_level_2`.** Familiar to long-time users, but
  "level 2" only made sense beside the old levels 1, 3 and 4.
- **Use `nteev2_org_type` instead of a new column.** Tested on the
  September 2026 Unified BMF: it misses about 182,000 grantmaking
  organizations the old column counted as supporting and flags about
  19,000 it counted as operating. It answers a different question.
- **Mark organizations with no NTEE code as operating**, as the 2019 to
  2022 files did. Rejected: it presents a guess as a fact.
- **Compute the role in each monthly and older file.** Rejected for now:
  it would mean reprocessing every older file to give one answer per EIN,
  and it would put the same rule to work in many places.
- **Write the rule in SQL inside the Unified BMF build.** Rejected: the
  rule would then live in two places (SQL and the tested R function).

## How we will know it worked

- `scripts/check_nccs_org_role.R` in `nccs-data-bmf` still reproduces the
  July 2013 and December 2017 older files.
- In the November build, every row has either one of O, S, M or a missing
  value; the two columns agree with each other; and the counts by role
  are close to the September 2026 figures (Operating about 2.48 million,
  Supporting about 517,000, Mutual benefit about 85,000).
- Row count and every existing column are unchanged by the added step.
