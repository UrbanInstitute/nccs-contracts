# NCCS Release Note — 12 NTEE codes restored (lookup gap)

**Status:** FINAL. Reprocessed 2026-09-17, published 2026-09-21 (vintage
2026_09). Numbers below come from the run's per-file check and manifests.
**Products:** Unified BMF, geocoded Unified BMF, state marts, NTEE-resolved
crosswalk, lookup tables, per-vintage processed BMF files (legacy +
current-monthly).

**What changes:** organizations whose IRS NTEE code is one of B29 (charter
schools), E6A, F31, K2A, K2B, K2C, L4A, L4B, M99, P76, P7A or P83 were
published as "unknown" (`Z99`, `UNU-Z99-RG`) in every NTEE column, because
those 12 codes were missing from the NCCS lookup sheet the pipeline uses to
validate raw codes. All 12 are in the IRS's own code list (Instructions for
Form 1023, Appendix D, revised 12/2024). After this build they resolve to
their real codes. Affected columns: `ntee_code_clean`, `ntee_code_definition`,
`naics_code`, `nteev2`, `nteev2_code`, `nteev2_subsector`,
`nteev2_subsector_definition`. **No columns are added, renamed, or removed;
row membership is unchanged.**

**How many rows:** in the July 2026 monthly file, 5,521 organizations (0.28%)
got a real NTEE code instead of "unknown". Counting every organization in
every one of the 121 monthly files, 379,258 rows changed (208,458 in the
1989-2011 legacy files, 170,800 in the 2012-2026 monthly files). The same
organization appears in many monthly files, so this is a count of rows, not
of distinct organizations. B29 charter schools account for more than half.
In the Unified BMF (one row per organization), 8,184 rows changed: every one
of them was "unknown" (`Z99`) before and has a real code now, so the share of
organizations with an unknown code fell from 19.03% to 18.81%. The changed-row
count for each monthly file is in
`s3://nccsdata/intermediate/tmp/z18_scripts/vintage_diff.psv`.

An earlier estimate of about 511,000 changed rows, quoted in the draft of this
note and in BACKLOG Z18, was too high: the folder holding each month's working
files contained two copies of the data, an old one from January 2026 and the
current one, and the measurement counted both (BACKLOG Z28).

**History:** four of the codes have been in the IRS data since 1989 (B29, F31,
M99, P83), P76 since 2008, and the other seven were added by the IRS in 2021
and appear from January 2022. The gap was found during the ADR 0048
acceptance tests (2026-08-28) and measured on 2026-09-17.

**For users:** any count or grouping by NTEE code that treated these
organizations as unclassified will move them into their proper groups, most
visibly education (B) and human services (M, P, K, L). Numbers previously
published for the `Z99` group will fall accordingly.

**Also in this build:** the IRS code list is now kept in the producer repo
(`data/lookup/irs_ntee_codes.csv`) and checked against the IRS every January
(BACKLOG Z25).

**Details:** nccs-data-bmf PR #54; BACKLOG Z18; ADR 0048 side finding.
Deprecation window waived under the ADR 0033 critical-bug clause (values
corrected in place, same row counts, same precedent as the ADR 0032 and ADR
0048 corrections).

**Published data sets (2026-09-21):** `s3://nccsdata/unified/bmf/`
(3,698,197 rows), `s3://nccsdata/geocoding/unified-bmf/v2026_09/` and
`latest/` (3,698,197 rows, 3,077,405 with coordinates), 63 state marts, `s3://nccsdata/lookups/bmf/latest/`,
`s3://nccsdata/crosswalks/ntee-resolved/`, and every monthly and legacy file
under `processed/bmf/` and `processed/bmf-legacy/`. Manifests carry git_sha
`1b1f8a9`.
