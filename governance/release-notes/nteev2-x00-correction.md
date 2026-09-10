# NCCS Release Note — NTEE-V2 code correction (x00 rule) — DRAFT

**Status:** DRAFT — do not publish to the website changelog until the ADR 0048
republish completes and live verification passes.
**Products:** Unified BMF, geocoded Unified BMF, state marts, NTEE-resolved
crosswalk, per-vintage processed BMF files (legacy + current-monthly).

**What changes:** the `nteev2_code` and `nteev2` columns. In NTEE-V2, digits
01-19 encode *organization type*, carried by the suffix; the activity slot is
`x00`. Our pipeline emitted the type in both slots (`B11` published as
`EDU-B11-MS` instead of `EDU-B00-MS`) on 313,662 Unified BMF rows (8.48%). A
second correction fixes 177,374 rows carrying stale pre-June-2026 values from
monthly vintages that predate the ADR 0032 NTEE cleaner fix. **No columns are
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

_(fill at publication: vintage, git_sha, per-vintage changed-row table link,
manifest hashes)_
