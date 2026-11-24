# Convention: column names

**Rule:** a new column gets a lower-case name with underscores between
words, for example `tax_period`. A column name that is already published
stays exactly as published.

**Status:** Convention, written down 2026-11-24. It records what the
producers already do. It changes no published file.

**Scope:** every column in every file an NCCS producer publishes to
`s3://nccsdata`, including data dictionaries.

## 1. New columns

| Rule | Right | Wrong |
|---|---|---|
| Lower-case letters, digits and underscores only | `total_assets_eoy` | `TOTAL_ASSETS_EOY`, `TotalAssetsEoy` |
| One underscore between words | `nccs_org_role` | `nccsOrgRole`, `nccs.org.role`, `nccs-org-role` |
| Starts with a letter | `form_990_part` | `990_part`, `_part` |

A column is new when no published file has carried it under that name.

## 2. Names already published

A published name is not renamed, whatever letters it uses. Renaming a
column breaks every program a user has written against the file.

This covers two groups of names in capital letters:

| Where | Examples | Why they stay |
|---|---|---|
| The harmonized CORE files (`harmonized/core/`) | `TAX_YEAR`, `F9_10_ASSET_TOT_EOY` | The files are frozen. ADR 0056 Decision 5 keeps each old header whole. |
| The harmonized CORE dictionaries | `VAR_NAME_NEW`, `DESCRIPTION` | Same files, same reason. |

## 3. A new column added to an older file

A new column follows section 1 even when every column beside it is in
capital letters. The five columns that ADR 0056 adds to the harmonized
CORE files are the example: `ein`, `tax_period`, `source_form`,
`is_amendment` and `extract_year` sit after 263 or more names in capital
letters.

## 4. The one named exception: `EIN2`

`EIN2` is in capital letters wherever it appears, including files that
first carried it after this rule, such as the Unified BMF, where it
is the only name in capital letters among 88 columns. It is the key the older NCCS files and
the NODC e-file tables share, so it keeps one spelling everywhere (ADR
0036, `conventions/ein-format.md`).

Any further exception needs a decision record that names the column and
gives the reason.
