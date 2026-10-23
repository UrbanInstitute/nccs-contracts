# NCCS E-File Release Note — efile_v3_1 and efilepf_v3_1

**Status:** DRAFT 2026-10-23 for committee review. Everything in this
note is verified from the published files except two items in Part 1
item 4 (the Schedule K refunding name and the Schedule D line 4b
label), which await the analyst decision in
[nccs-contracts #108](https://github.com/UrbanInstitute/nccs-contracts/issues/108).
The ten missing filings in Part 2 await the producer's reply on
[ef2 #31](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/31).

**Released by producer:** 2026-10-09 · **Location:**
`s3://nccs-efile/public/efile_v3_1/` (Form 990 and 990-EZ) and
`s3://nccs-efile/public/efilepf_v3_1/` (Form 990-PF)
· **Producer:** NODC (`ef2` 2.0.0, `concordance990` 2.0.1)
· **Documented by:** NCCS

**Previous announced release:** efile_v2_2 (2026-08-11). The interim
builds v2_3 and pf_v2_3 (2026-10-07) were never announced and are
not a baseline for users. This note therefore describes the change
from v2_2 to v3_1, which is larger than the producer's own release
note (v2_3 to v3_1) shows.

## Part 1. Defects confirmed in the retained v2_2 files

These are facts about the files at `public/efile_v2_2/` as they stand
today. Analyses built on v2_2 should be checked against this list.

1. **Pre-2013 Schedule R tables were cross-joined.** Schedule R Parts
   I and II for TY2009 to 2012 held a cartesian product of related
   organisations (producer defect EF2-6). The producer rewrote the
   affected files in place on 2026-09-23; the TY2012 Part I table went
   from 765,251 rows to 15,871. The August versions survive as S3
   noncurrent versions.
2. **Duplicate filings.** The same return appeared more than once
   across the stored archives (EF2-19). TY2020 Form 990 is the largest
   case: 343,789 header rows in v2_2 against 320,343 in v3_1, a 6.8
   percent drop that is removal of duplicates, not loss of coverage.
3. **The count sheet describes v2_1, not v2_2.** The file
   `COUNT-OF-ROWS-BY-TABLE-AND-FORMTYPE-EFILE_V2_2.CSV` is
   byte-identical to the v2_1 count sheet. 260 of the TY2022 to 2024
   tables therefore have more rows than the sheet says. (The v2_2 note
   flagged the stale file name; this is the resolution.)
4. **Mixed-content columns from version 1 variable names.** The v1
   concordance assigned one name to several IRS elements of different
   meaning. In v2_2 the affected columns hold mixed content. The ones
   with analytical consequence:
   - `F9_04_SCHED_B_REQ_X` mixes the "Schedule B required" and
     "Schedule B not required" checkboxes.
   - `SA_05_ASSET_MINIM_INDEPTED_CY` holds the prior-year amount, not
     the current-year amount.
   - `F9_00_TYPE_ORG_OTH_DESC` mixes description text with a
     checkbox value.
   - `F9_08_REV_OTH_GAMING` includes 2009-schema special events gross
     revenue.
   - `SD_12_RECO_EXP_ADD_L4AB` includes a revenue reconciliation line
     for 2009 to 2012 schemas. (Pending #108: the v3_1 label.)
   - `SF_01_GRANT_RECORD_MAINT_X` and `SF_99_FRGN_ORG_GRANT_LT_5K_X`
     are crossed for 2009 to 2011 schemas.
   - `SK_02_BOND_PROCEED_REFUND_ADVC_X` mixes advance, taxable and
     tax-exempt refunding. (Pending #108: the v3_1 name for taxable
     refunding.)
   The full list with element paths, schema versions and example
   filings is in nccs-contracts #108.
5. **The v2_2 files were rewritten after release.** All 1,792 CSV
   files were written again on 2026-09-23 and parquet copies added.
   254 tables changed size. The files at the prefix today are not the
   files announced on 2026-08-11. The August versions are retrievable
   by S3 version id. NCCS has asked the producer that announced
   releases not be rewritten at their prefix in future.
6. **SUMMARY table duplicate rows** (carried from the v2_2 note):
   about 2 million duplicate 990-EZ rows with null expenses; dedup on
   `OBJECTID` before joins. Resolved in v3_1 by the dedup in item 2.

## Part 2. What differs between the retained v2_2 and v3_1

**Coverage.**
- 184,165 filings that the GivingTuesday index never listed were
  fetched from the IRS and added (EF2-18). TY2024 gains about
  112,000 full-990 filings; TY2025 appears for the first time.
- Ten of those filings are missing from v3_1 because of a namespace
  prefix bug in the producer's patch reader (ef2 #31). They will
  arrive in a later version.
- Duplicates removed (item 2 above).
- Totals: v3_1 holds 6,307,836 Form 990 and 990-EZ filings across
  136 tables and 2,312 table-years (186 of them empty); efilepf_v3_1
  holds 1,234,785 Form 990-PF filings across 83 tables.
- **Form 990-PF is new to the catalog.** There was no announced PF
  release before this one.

**Columns and tables.** Compared by xpath between the v1 concordance
(used by v2_2) and concordance990 2.0.1 (used by v3_1): 6,864 to
7,075 mapped xpaths; 212 xpaths added; 1 dropped; 27 xpaths change
variable name for a reason of meaning (Part 1 item 4) and 35 change
only whitespace; 350 xpaths move to another table. Table moves follow
the rule that `T00` tables are one row per filing and `T01` and higher
are one row per repeated item, so some v2_2 tables are split or
renumbered (for example Schedule H facility policies moved from
`SH-P05-T00` to `SH-P05-T03`; Schedule G fundraising events from
`SG-P02-T01` to `SG-P02-T00`). Column names in the 990-PF tables did
not change between the interim pf_v2_3 and pf_v3_1 apart from the
Part IX restructure.

**New columns.** `F9_00_ORG_EXEMPT_TYPE` (exempt subsection, for
example `501c3`) in every header table (EF2-12).

**Schedule B.** Contributor name, address and number columns exist in
the schema. In the TY2023 files no contributor name is populated and
every contributor number is the literal `RESTRICTED`, for every
exempt type.

**Value revisions.** Not yet quantified on a shared field. The v2_2
note reported zero revisions on the government-grants field between
v2_1 and v2_2; the same check between v2_2 and v3_1 is pending
(review plan Step 6).

## Part 3. Identifiers and the cross-release join rule

- `OBJECTID` is unchanged: `OID-` plus the IRS object id, in both
  v2_2 and v3_1. **Join across releases on `OBJECTID`.**
- `TABLE_ID` changed format from `TID-00000` to fixed-width
  `TID-000-000-001` (EF2-17). One-row-per-filing (`T00`) tables carry
  no `TABLE_ID` in v3_1. `TABLE_ID` values are assigned per build and
  are not stable across releases: do not join repeated-item tables
  across releases on `TABLE_ID`. Match on `OBJECTID` plus the row's
  content.
- `EIN2` and `ORG_EIN` are unchanged.

**For users:** recompute rather than restate when moving from v2_2 to
v3_1. Totals for TY2020 fall (duplicates), totals for TY2024 and
TY2025 rise (coverage), and the columns in Part 1 item 4 change
meaning. v2_2 remains at its path but see Part 1 item 5 on what that
path now holds.

**Verification:** NCCS review 2026-10-21 (count sheets against every
parquet footer; header key uniqueness across 7,542,621 records;
patch index reconciliation; S3 object-version history; xpath-level
concordance diff; same-filing value comparison for every renamed
column). Evidence in `nccs-workspace/reviews/2026-10-21-efile-audit/`.
