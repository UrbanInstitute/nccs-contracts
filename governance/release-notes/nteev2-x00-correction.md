# NCCS Release Note — NTEE-V2 code correction (x00 rule)

**Status:** FINAL — published 2026-09-15 (Unified BMF vintage 2026_09,
git_sha `dbf33ae`).
**Products:** Unified BMF, geocoded Unified BMF, state marts, NTEE-resolved
crosswalk, per-vintage processed BMF files (legacy + current-monthly).

**What changes:** the `nteev2_code` and `nteev2` columns. In NTEE-V2, digits
01-19 encode *organization type*, carried by the suffix; the activity slot is
`x00`. Our pipeline emitted the type in both slots (`B11` published as
`EDU-B11-MS` instead of `EDU-B00-MS`) on 313,662 Unified BMF rows (8.48%). A
second correction fixes pre-existing stale values (201,265 rows, largely from
processed vintages predating the June-2026 ADR 0032 cleaner fix, across both
current-monthly and legacy files). Net: 488,754 Unified BMF rows change
(script-verified class reconciliation, ADR 0048 criterion D). **No columns are
added, renamed, or removed; row membership and `nteev2_subsector` /
`nteev2_org_type` are unchanged.** Users filtering or grouping by `nteev2_code`
or full `nteev2` will see corrected group assignments.

**Credit:** the double-encoding defect was identified by Jesse Lecy /
Nonprofit Open Data Collective
(`Nonprofit-Open-Data-Collective/matchdb`, commit `faa4fe8`;
`pfmatch/dev/SCHEDI-ALIAS-FINDINGS.md` §6d). The corrected values converge
with `fiscal::get_nteev2()`.

**Details:** ADR 0048 in `decisions/`; deprecation window waived under the
ADR 0033 critical-bug clause (values corrected in place, same row counts, per
ADR 0032 precedent).

**Published artifacts (2026-09-15):** `s3://nccsdata/unified/bmf/` (3,698,197
rows), `s3://nccsdata/geocoding/unified-bmf/v2026_09/` and `latest/`,
state marts, `s3://nccsdata/lookups/bmf/latest/`,
`s3://nccsdata/crosswalks/ntee-resolved/`, and every per-vintage file under
`processed/bmf/` and `processed/bmf-legacy/`. Manifests carry git_sha
`dbf33ae` and vintage `2026_09`. Per-vintage changed-row table: ADR 0048
Outcome (`vintage_diff.psv`).

**Also in this build:** the 31 current-monthly processed files from 2023-06
through 2026-05 receive the June-2026 NTEE cleaner correction (ADR 0032) for
the first time, so on those per-vintage files `ntee_code_clean`,
`ntee_code_major_group`, `naics_code`, `nteev2_subsector` and the definition
columns also change, and `nteev2_subsector_definition` is added. The Unified
BMF already carried those corrections for active EINs. Files for 2024-09 and
2024-10 are published for the first time.
