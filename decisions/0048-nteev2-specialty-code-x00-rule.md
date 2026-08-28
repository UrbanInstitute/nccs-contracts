# 0048 — Apply the NTEE-V2 x00 rule: specialty/common codes 01-19 must not appear in the activity slot

- **Status:** Accepted (maintainer approved 2026-08-28; executing in `nccs-data-bmf` on `fix/0048-nteev2-x00`)
- **Date:** 2026-08-28
- **Deciders:** sole maintainer
- **Relates:** ADR 0032 (NTEE cleaner; this amends its Outcome), ADR 0034 (NTEE-resolved crosswalk), ADR 0014 (manifests), ADR 0033 (deprecation window), BACKLOG Z16 / Z6 / Z2
- **Pilot:** first task run under the Claude-implements / Codex-reviews workflow. Acceptance criteria below are written to be reproduced by a reviewer who has NOT read the implementer's summary.

## Context

### The defect

NTEE-V2 is a three-part code `INDUSTRY-CODE-TYPE`. Our published spec
(`nccs/_resources/ntee.md`, "Major Group and Divisions") states the rule
for the middle slot:

> These will be the same as the traditional NTEE codes except specialty
> organizations (x01-x19) are replaced with zeroes (x00) and the common
> codes (01-19) have been recoded as organizational types.

So `B01` (advocacy for the education sector) is `EDU-B00-AA`, and `B11`
(single-organization support) is `EDU-B00-MS`. The digits 01-19 encode
*organization type*, which the suffix carries; the activity slot becomes
`x00`.

The producer does not apply this rule. `nccs-data-bmf/R/transform_ntee_code.R`,
`.nteev2_code_transform()` (lines 354-357 at commit of drafting):

```r
dt[, nteev2_code := data.table::fcase(
  ntee_code_clean %chin% c(NTEE_INVALID, NTEE_UNDEFINED), "Z99",
  default = ntee_code_clean
)]
```

and separately derives `nteev2_org_type` from the same digits (`"11" -> "MS"`,
lines 386-395), then concatenates. Result: `B11` publishes as `EDU-B11-MS`,
carrying the type in both slots. Observed variants: `D11 -> ENV-D11-MS`,
`S11 -> PSB-S11-MS`, `N12 -> HMS-N12-MM`, `X19 -> REL-X19-NS`.

Three independent sources on our own side agree the output is wrong:

1. The website spec quoted above.
2. ADR 0032's "single derivation path" invariant: `nteev2_*` is a function
   of `ntee_code_clean`. That invariant holds, but the function is incomplete.
3. Our vendored legacy crosswalk `nccs-data-bmf/data/lookup/ntee_legacy_5char_lookup.csv`
   (1,597 rows) maps every 3-char specialty code to `x00`: `A01 -> ART-A00-AA`,
   `A11 -> ART-A00-MS`, `B01 -> EDU-B00-AA`. Zero rows in that table carry
   01-19 in the middle slot. The pipeline's own lookup contradicts the
   pipeline's output.

### How it was found

Externally, by NODC (Jesse Lecy), recorded in
`Nonprofit-Open-Data-Collective/matchdb` commit `faa4fe8` (2026-08-21) and
`pfmatch/dev/SCHEDI-ALIAS-FINDINGS.md` §6d. His measurement: 21,983 of a
400,000-row sample of the geocoded Unified BMF (5.5%) carry a 10-19 org-type
code and are affected. He patched a private copy
(`bmf_unified_geocoded-nteev2fix.csv`) and recomputes with
`fiscal::get_nteev2()`; the defect was not reported to us. It reached us by
reading his commit log. The credit belongs in the release note.

`fiscal::get_clean_ntee()` (`fiscal/R/panel-nteev2.R:17-34`) is the reference
semantics: a 3-char code whose digits are <= 19 becomes `x00`; a 5-char
legacy code (`B8443`) takes positions 4-5 (`B43`).

### Why ADR 0032 missed it

ADR 0032 (2026-06-16) fixed two defects: a 4-char cleaning bug that collapsed
~69% of rows to `Z99`, and a subsector derivation that made universities
unreachable. Its Decision #2 subordinated `nteev2_code` to `ntee_code_clean`
("single source of truth"), which was correct as far as it went, but the
x00 collapse was never part of the formula it replaced or the one it
introduced. The full legacy reprocess (BACKLOG L1, 2026-07-02, 85 vintages)
propagated the incomplete rule everywhere.

### Which columns are wrong, and which are not

| column | status |
|---|---|
| `nteev2_code` | WRONG for rows whose `ntee_code_clean` digits are 01-19 |
| `nteev2` (composite) | WRONG for the same rows (inherits the middle slot) |
| `nteev2_subsector` | correct (derived from the letter / UNI / HOS sets, unaffected) |
| `nteev2_org_type` | correct (already carries the type) |
| `ntee_code_clean`, `ntee_common_code`, `ntee_code_major_group` | correct (NTEE-CC, not V2) |

Consumers keying on `nteev2_subsector` (sector-in-brief, most nccsdata
users) are unaffected. Consumers keying on `nteev2` or `nteev2_code`
(NODC `matchdb`/`fiscal`, anyone grouping by V2 code) see a value change
on ~5% of rows.

### Where the wrong values live

Every published surface that carries `nteev2_code` / `nteev2`, all produced by
`nccs-data-bmf` (contracts in this repo):

- `lookups/bmf/` (`bmf-lookups.yml`): the NTEE lookup table, if it carries a V2 rendering (verify at implementation)
- `unified/bmf/` (`unified-bmf.yml`)
- `geocoding/unified-bmf/latest/` and `v{YYYY_MM}/` (`unified-bmf-geocoded.yml`)
- `unified/bmf/state_marts/` (per-state marts, derived from the geocoded Unified BMF)
- `crosswalks/ntee-resolved/` (`ntee-resolved-crosswalk.yml`): `ntee_current_nteev2`, `ntee_most_recent_nteev2`, `ntee_modal_nteev2`
- the per-vintage processed CSVs of both pipelines (current monthly + 85 legacy vintages), which are the Unified BMF's inputs

## Decision (proposed)

1. **Apply the x00 rule inside the single derivation path.** In
   `.nteev2_code_transform()`, `nteev2_code` becomes `paste0(letter, "00")`
   when `ntee_code_clean` is valid and its two digits are in 01-19; `Z99`
   for invalid/undefined; otherwise `ntee_code_clean` unchanged. The
   ADR 0032 invariant (a function of `ntee_code_clean`, no parallel
   formula) is preserved: this is the same function, completed.
   Implement the rule ONCE as a named, exported-in-spirit helper
   (e.g. `nteev2_code_from_clean()`) so it can be unit-tested in isolation
   and reused by the consolidation step in #3.

2. **Leave `nteev2_org_type` and `nteev2_subsector` untouched.** Both are
   already correct; changing them widens the blast radius for no gain.
   The legacy 5-char crosswalk path (`.apply_legacy_5char_crosswalk`) is
   already x00-consistent (measured: 0/1,597 contradictions) and its
   formulaic fallback uses positions 4-5, which are the activity, not the
   type; it needs no change but is covered by the invariant tests.

3. **Correct published artifacts by a full reprocess through the pipeline,
   not by patching files or by recomputing at the consolidation step.**
   After #1 merges: reprocess every legacy vintage (85, the BACKLOG L1
   shape, `scripts/` EC2 batch runner) and the current monthly vintage,
   then rebuild the Unified BMF, the geocoded Unified BMF, the state marts,
   and the NTEE-resolved crosswalk (which cleans distinct raw codes through
   `transform_ntee_code()` and therefore picks the fix up automatically),
   and publish via the ADR 0042 / Z13 publisher (`v{YYYY_MM}/` then
   `latest/`). Maintainer-reported runtime for the full legacy reprocess:
   about one day of EC2 (verified by prior runs; the "~2 weeks" in an
   earlier draft was inferred from L1's calendar dates and was wrong).
   At that cost there is no reason to leave per-vintage files stale or to
   add a recompute at the Unified BMF build, which would be a second
   derivation path and exactly what ADR 0032 forbids. Every published
   surface and every per-vintage file is correct after one cycle.

4. **Introduce a test suite in `nccs-data-bmf`.** The repo has no
   `tests/` directory at all (verified 2026-08-28). This ADR requires a
   minimal `tests/testthat/` runnable with
   `Rscript -e 'testthat::test_dir("tests/testthat")'`, containing at least
   the NTEE tests in the acceptance criteria. Keeping the pipeline
   test-free is what let ADR 0032's fix ship incomplete.

5. **Deprecation window: waived** (ADR 0033 critical-bug clause). This is a
   correctness defect in a classification column; the schema, row
   membership, and all other columns are unchanged, and keeping the wrong
   values live prolongs the harm to anyone grouping by V2 code. Same
   posture as the ADR 0032 republish (values corrected in place, same row
   count). Recorded harm: ~5% of rows carry a V2 code that does not exist
   in the V2 scheme.

6. **Amend ADR 0032** with an Outcome note pointing here ("x00 rule
   omitted; corrected by 0048"). Do not rewrite 0032's text.

7. **Release note** in `governance/release-notes/`, crediting the NODC
   finding (`matchdb` `faa4fe8`) by name and link. Website changelog derives
   from it (house rule).

## Acceptance criteria (reviewer-reproducible)

A reviewer should be able to verify each of these from the diff, the
tests, and (where marked LIVE) the published artifacts, without reading
the implementer's summary. Each item names its verification level.

**A. Unit (code review level).** `nteev2_code_from_clean()` on the fixed
vector below yields exactly the expected output. Test file must contain
this table verbatim.

| input `ntee_code_clean` | expected `nteev2_code` | why |
|---|---|---|
| `B11` | `B00` | specialty, type MS |
| `B01` | `B00` | common code, type AA |
| `B19` | `B00` | upper bound of the 01-19 range |
| `B20` | `B20` | first real division |
| `B29` | `B29` | unchanged activity code |
| `B43` | `B43` | university set, unchanged |
| `A115` cleaned -> `A11` | `A00` | (cleaning is upstream; this row tests the clean code) |
| `INVALID` | `Z99` | ADR 0032 rule preserved |
| `UNDEFINED` | `Z99` | ADR 0032 rule preserved |
| `Z99` | `Z99` | unclassified stays |

**B. Oracle against our own lookup (code review level).** For every
3-character `NTEE` in `data/lookup/ntee_legacy_5char_lookup.csv`, running
the full `transform_ntee_code()` path on that code and concatenating
`nteev2_subsector-nteev2_code-nteev2_org_type` equals the table's `NTEE2`
column. Report the count tested and the count of mismatches; expected
mismatches: 0. (Any residual mismatch must be listed and explained, not
excluded.)

**C. Invariants (code review level, asserted in tests and in
`.ntee_output_validation()`):**
- No row has `nteev2_code` matching `^[A-Z](0[1-9]|1[0-9])$`.
- `nteev2 == paste(nteev2_subsector, nteev2_code, nteev2_org_type, sep = "-")` for all rows.
- `nteev2_org_type != "RG"` if and only if the raw code's digits 2-3 are in `{01,02,03,05,11,12,19}` (pre-existing behaviour, now pinned).
- `nteev2_subsector` and `nteev2_org_type` are byte-identical before and after the change on the same input.

**D. Before/after on the Unified BMF (artifact or LIVE level).** Also
report, per reprocessed legacy vintage, the count of rows changed in
`nteev2_code` (a single table, 85 rows + current), so the reviewer can see
the fix landed everywhere and nowhere else. On the
current published geocoded Unified BMF (`latest/`, record the manifest
`vintage` and `git_sha`):
- rows matching invariant C.1 BEFORE: report count and share (expected on
  the order of 5%; NODC measured 5.5% on a sample);
- AFTER: 0;
- row count unchanged; `ein` set identical;
- every column other than `nteev2_code` and `nteev2` byte-identical
  (compare per-column hashes, not a diff).
- **Reconciliation:** the number of rows whose `nteev2_code` changed must
  EQUAL the number of rows assessed as defective beforehand (rows matching
  `^[A-Z](0[1-9]|1[0-9])$` in the BEFORE artifact, identified by `ein`).
  Report both counts and the delta. A non-zero delta is a finding to
  investigate before publication, not a rounding note: rows changed but not
  flagged means the fix touched something outside the rule; rows flagged
  but not changed means the rule missed a case. Apply the same check per
  reprocessed vintage.

**E. Publication (LIVE level, separate gate).** New `v{YYYY_MM}/` written
first, verified (manifest `row_count`, per-file sha256, columns), then
`latest/` updated; prior vintages untouched; `_manifest.json` records the
new `git_sha` and input hashes. Same for `crosswalks/ntee-resolved/`.
This gate is authorized separately from merge.

**F. Documents.** ADR 0032 Outcome amended; this ADR flipped to
`Executing` at PR open and `Reconciled` after E; release note drafted;
`contracts/unified-bmf*.yml` and `ntee-resolved-crosswalk.yml` field notes
updated where they describe `nteev2_code`; BACKLOG Z16 closed, Z2 and Z6
annotated.

## Rejected / deferred alternatives

- **Patch the published parquet in place with a one-off script.** Fastest,
  but bypasses the pipeline and the manifest's input-hash provenance; the
  next pipeline run would silently regress. Rejected.
- **Recompute `nteev2_code` at the Unified BMF consolidation step and let
  per-vintage files lag.** Considered when the full reprocess was
  (wrongly) estimated at ~2 weeks. Rejected once the maintainer corrected
  the runtime to about a day: it would introduce a second derivation path
  (ADR 0032 invariant) and leave the 85 legacy processed files carrying
  wrong values for consumers who read them directly.
- **Adopt `fiscal::get_nteev2()` as a dependency.** Same rule, but a
  producer must not depend on an external package for a published
  column's definition. Reimplement, test against the vendored crosswalk
  oracle, and cite `fiscal` as corroborating semantics.
- **Also decide the per-EIN NTEE resolution rule here.** NODC's finding
  that `ntee_agreement = mixed` for ~21-31% of EINs is real and argues for
  a stated rule (his: bmf_current / modal / most_recent / bmf_only with an
  `ntee_rule` column). That is a contract-shape decision on the resolved
  crosswalk and belongs in Z6 (NTEE metadata ADR), not in a correctness
  fix. Noted, not decided.

## Consequences

- `nteev2_code` / `nteev2` values change on ~5% of rows across every
  Unified BMF surface and the NTEE-resolved crosswalk; no schema change,
  no row-membership change.
- `nccs-data-bmf` gains a `tests/` directory and a test-run command in its
  instructions; future NTEE changes have a regression harness.
- The NCCS-published V2 code and NODC's `fiscal` rendering converge, which
  removes the reason for NODC's private `-nteev2fix` fork.
- All per-vintage processed files (legacy + current) are reprocessed;
  their manifests and quality reports regenerate.

## Side finding during implementation (out of scope, routed to BACKLOG Z18)

Acceptance test B surfaced 12 NTEE-CC codes present in the vendored NODC
crosswalk but absent from `data/lookup/bmf_code_lookup.xlsx` sheet
`ntee_code` (643 rows): `B29, E6A, F31, K2A, K2B, K2C, L4A, L4B, M99, P76,
P7A, P83`. Any BMF row carrying one cleans to `INVALID` and publishes as
`UNU-Z99-RG`. `B29` (charter schools) is the worked example on our own
NTEE-V2 spec page. Verified 2026-08-28 against the workbook; prevalence in
live data unverified (needs S3). The test pins the list by name so a lookup
update fails loudly and the list shrinks. Not fixed here: a lookup change
alters classification on an unknown number of rows and deserves its own
measurement and row.

## Outcome

_(to be filled at reconcile)_

### Shipped

### Diverged or pending
