# 0059: Add the organization legal type and field columns to the Unified BMF

- **Status:** Proposed 2026-11-11
- **Date:** 2026-11-11
- **Deciders:** Thiyaghessan Poongundranar (tpoongundranar@urban.org)
- **Related:** [[0058-nccs-org-role-column-in-unified-bmf]] (the role column, formerly level 2; this record follows its pattern), [[0016-no-canonical-cross-dataset-merge]] (consumers join by EIN themselves), [[0048-nteev2-specialty-code-x00-rule]] (how the NTEE columns are built)

## Context

Older NCCS files sorted every organization with four columns, called
levels 1 to 4. ADR 0058 brought back level 2 as `nccs_org_role`. On
2026-11-11 the maintainer asked for levels 1 and 3 as well, under
descriptive names. The maintainer also asked where they should live: in
the Unified BMF, in CORE too, or in the table of NTEE codes. The aim is the fewest
places to maintain.

Nobody wrote down the rules behind levels 1 and 3. On 2026-11-11 we
worked them out by comparing the old columns with the other columns in
two older BMF files, read in full. The files are July 2013 (1,427,584
rows) and December 2017 (1,544,575 rows).

**Level 1** says what kind of tax-exempt organization this is. It comes
from two IRS codes, the subsection code and the foundation code:

| Old value | Meaning | Rule |
|---|---|---|
| PC | 501(c)(3) public charity | subsection code 3, foundation code not 2, 3 or 4 |
| PF | 501(c)(3) private foundation | subsection code 3, foundation code 2, 3 or 4 |
| O | Other tax-exempt organization | any other subsection code |
| U | Unknown | subsection code 0 |

This rule gives the old value on every row of both files.

**Level 3** says what field the organization works in, in 17 groups. It
comes from the NTEE code alone. The first line that fits wins:

| Old value | Meaning | Rule on the NTEE code |
|---|---|---|
| ZA | Single organization support | characters 2 and 3 are 11 |
| ZB | Fundraising within one field | characters 2 and 3 are 12 |
| ZC | Private grantmaking foundations | starts with T2 |
| ZD | Public foundations | starts with T3 |
| ZE | General fundraising | starts with T7 |
| ZF | Other supporting public benefit | starts with T9 |
| MR | Pension and retirement funds | Y30 |
| MO | Other mutual benefit | any other code starting with Y |
| AR | Arts, culture and humanities | starts with A |
| ED | Education | starts with B |
| EN | Environment and animals | starts with C or D |
| HE | Health | starts with E, F, G or H |
| HS | Human services | starts with I to P |
| IN | International, foreign affairs | starts with Q |
| PB | Public, societal benefit | starts with R to W |
| RE | Religion related | starts with X |
| UN | Unknown, unclassified | starts with Z |

This rule gives the old value on every row of both files.

**Level 4** is the first letter of the NTEE code. The Unified BMF already
has it as `ntee_code_major_group`.

The Unified BMF has no column that holds either grouping today.
`exempt_organization_type` describes the subsection code but does not
separate public charities from private foundations. `nteev2_subsector`
is a different grouping: it separates universities and hospitals, and it
has no groups for supporting organizations.

## Decision

1. **Four new columns in the Unified BMF.**
   - `nccs_org_legal_type`: "PC", "PF" or "O". Missing when unknown.
   - `nccs_org_legal_type_definition`: the same value in words ("Public
     charity", "Private foundation", "Other tax-exempt organization").
   - `nccs_org_field`: one of the 17 two-letter values in the table
     above. Missing when unknown.
   - `nccs_org_field_definition`: the same value in words, as in the
     table above.

2. **The Unified BMF is the only home.** The columns are not added to
   CORE and not added to the NTEE code tables.
   - CORE users get them by joining the Unified BMF on `ein`
     (ADR 0016). Adding them to CORE would put a second copy in 36 years
     of files, which the CORE pipeline would have to keep the same as
     the first.
   - The legal type cannot live in a table of NTEE codes, because it
     does not come from the NTEE code. The role (ADR 0058) cannot
     either, because since 2017 it also uses the foundation code.
   - The field does come from the NTEE code alone, so it could live in
     a table of NTEE codes. We keep it with the other two so that a user
     finds all three in one file and reads them the same way.

3. **The rules** are the two tables in the Context section. The inputs
   are the Unified BMF's own `subsection_code`, `foundation_code` and
   `ntee_code_raw`.

4. **Unknown stays unknown**, as in ADR 0058.
   - Legal type is missing when the subsection code is missing or 0.
   - Legal type is also missing for a 501(c)(3) whose foundation code is
     missing or 0, because nothing says whether it is a public charity
     or a private foundation. The older files marked such organizations
     as public charities (1,691 rows in December 2017). We do not,
     because that is a guess. In the current Unified BMF this is 76,600
     organizations.
   - Field is missing when the organization has no usable NTEE code.
   - The old value "U" for legal type and the old value "UN" for field
     are different things. We keep "UN": it means the IRS assigned an
     NTEE code starting with Z, which is itself "unclassified".

5. **The field rule ignores punctuation after an NTEE code**, as ADR
   0058 Decision 4 does for the role. Both use the same cleaning
   function.

6. **One place computes each column.** Two tested R functions in
   `nccs-data-bmf`, next to `derive_nccs_org_role()`, called once on the
   finished one-row-per-EIN table. The geocoded Unified BMF and the
   per-state files receive the columns unchanged.

7. **The names.** `nccs_org_legal_type` and `nccs_org_field` say what
   each column holds, and the `nccs_` prefix marks them as derived by
   NCCS. The data dictionary states once that they were formerly
   `NCCS_LEVEL_1` and `LEVEL1`, and `NCCS_LEVEL_3` and `LEVEL3`. The
   working name `nccs_org_class` from ADR 0058 is not used, because the
   Unified BMF already has `classification_code`, which is a different
   IRS code.

8. **Where the columns sit.** After the two role columns, at the end of
   the Unified BMF column list. In the geocoded Unified BMF and the
   per-state files they come before the geocode columns, as ADR 0058
   Decision 8 describes.

9. **No notice period.** No existing column is renamed, removed or
   changed in meaning, and the Unified BMF contract already says new
   columns may be added at any time. The release note for the build
   that first carries the columns announces them.

10. **Validation reports cover the derived columns from the next build
    on.** For `nccs_org_role`, `nccs_org_legal_type` and
    `nccs_org_field`, each build's report gives the count for every
    value, the count of missing values, and the change from the
    previous build. A value outside the allowed list, or a code column
    that disagrees with its definition column, stops the publish.

## Consequences

- People who used `NCCS_LEVEL_1` and `NCCS_LEVEL_3` can get the same
  groupings again from the current BMF, and join them to CORE by EIN.
- The legal type differs from the old column for 501(c)(3)
  organizations with no foundation code: the old column said public
  charity, the new one is missing.
- The field is only as complete as the NTEE code. In the current
  Unified BMF about 644,000 of 3.69 million organizations have no
  usable NTEE code.
- An organization can be supporting by role (through its foundation
  code) and still have a field such as Education. The older files did
  the same from September 2017 on.
- Anyone who reads the Unified BMF CSV by column position sees four
  more columns at the end and nothing moved. Anyone who reads the
  geocoded CSV or a per-state CSV by column position sees the geocode
  columns move four more places to the right. Reading by column name is
  not affected.
- If these columns go into the same build as the role columns, users
  see one change of column positions and one release note, not two.

## Options considered and not chosen

- **Add the columns to CORE as well.** Rejected: two copies of one
  answer, and the pre-2012 and harmonized CORE files are being frozen.
- **Put the field in the NTEE code table and the other two in the
  BMF.** Workable, because the field comes from the NTEE code alone.
  Rejected for now: users would look in two places for three columns
  that belong together. It stays open if the NTEE table later becomes
  the main way people read NTEE groupings.
- **Keep the old names `nccs_level_1` and `nccs_level_3`.** Rejected
  for the reason in ADR 0058: a level number says nothing about what
  the column holds.
- **Mark a 501(c)(3) with no foundation code as a public charity**, as
  the older files did. Rejected: it presents a guess as a fact.
- **Bring back level 4.** Not needed: `ntee_code_major_group` already
  holds it.

## How we will know it worked

- A check script in `nccs-data-bmf` reproduces the July 2013 and
  December 2017 older files: the field on every row, and the legal type
  on every row that has a foundation code or is not a 501(c)(3).
- In the first build with the columns, the counts are close to those
  from the Unified BMF as published on 2026-11-11 (3,687,435 rows):

  | Legal type | Organizations |
  |---|---|
  | Public charity | about 2,388,000 |
  | Private foundation | about 260,000 |
  | Other tax-exempt organization | about 775,000 |
  | Missing | about 264,000 |

  | Field | Organizations | Field | Organizations |
  |---|---|---|---|
  | HS | 904,776 | ZA | 96,241 |
  | PB | 391,917 | ZB | 91,032 |
  | ED | 342,802 | MO | 85,835 |
  | RE | 315,038 | UN | 44,232 |
  | AR | 236,936 | IN | 42,022 |
  | HE | 195,125 | ZD | 28,634 |
  | ZC | 129,464 | ZF | 16,805 |
  | EN | 116,306 | ZE | 6,533 |
  | MR | 230 | Missing | 643,507 |

- Row count and every existing column are unchanged by the added step.

## Follow-up

1. Maintainer decides: accept the names, and say whether the columns go
   into the November 2026 build or the one after.
2. Write the two functions, their tests and the check script in
   `nccs-data-bmf`.
3. Add the columns to the Unified BMF contract and the data dictionary.
4. Add the derived-column section to the build's validation report.

## Outcome

Written when the work is done.
