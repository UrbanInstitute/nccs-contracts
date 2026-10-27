# Note for the committee: checking the e-file releases against the IRS

**Date:** 2026-10-27 · **From:** Thiya Poongundranar (chair) · **For:** the
next committee meeting · **Decision asked:** one small one (section 4).

## 1. What this is about

The IRS publishes electronically filed Form 990 returns once a month, in
a numbered batch. The NODC e-file releases that NCCS hosts and catalogs
are built from those returns, but not directly: the returns reach the
release by way of a third party's copy (the GivingTuesday data lake)
plus a store of files the producer fetched from the IRS himself. Until
this month there was no routine way to say whether a release held
everything the IRS had published by the time it was built.

NCCS now runs that check once a month, after each IRS batch. The result
is a small table published beside each release:

    s3://nccs-efile/public/efile_v3_1/IRS-BATCH-COVERAGE.CSV
    s3://nccs-efile/public/efilepf_v3_1/IRS-BATCH-COVERAGE.CSV

Each row is one IRS batch as seen by one run of the check. It says how
many filings the IRS listed in that batch, how many of them are in the
release, how many are missing, and where the release got the files from
(the GivingTuesday copy or the producer's own IRS downloads). Every row
carries the date the check ran and the date the release was built. Each
monthly run adds its rows to the bottom of the file, so the file is also
the history of the release. The producer agreed to the file and its
location on 2026-10-27.

## 2. What the first run found (2026-10-27)

Both current releases were built on 2026-10-09. Measured against the
2026 IRS batches:

| | Form 990 and 990-EZ (efile_v3_1) | Form 990-PF (efilepf_v3_1) |
|---|---|---|
| IRS batches published before the build | 01A to 08A (Feb to Sep 2026) | same |
| Filings the IRS listed in those batches | 343,886 | 79,686 |
| Of which in the release | 343,882 | 79,686 |
| Missing | 4 | 0 |
| Batch published after the build | 09A (21 Oct 2026), 29,850 filings | 09A, 5,382 filings |

Three things worth knowing.

- **The releases are complete through the September batch.** The four
  missing Form 990 filings are among the ten already reported to the
  producer (ef2 issue 31, a bug in reading filings with a namespace
  prefix). The October batch is absent because it came out after the
  build; it should appear in the producer's next build.
- **The GivingTuesday copy is running two to three months behind the
  IRS.** Of the 343,886 filings in batches 01A to 08A, 104,914 (30
  percent) reached the release only because the producer fetched them
  from the IRS himself. The whole of the September batch (41,622
  filings) came that way, and as of late October the GivingTuesday copy
  still did not have it. The 990-PF side shows the same pattern (25,083
  of 79,686).
- **Our own June build had the same gap.** NCCS's first extraction of
  government-grants fields (June 2026) was also built from the
  GivingTuesday index and lacked 37,211 filings the IRS had published
  before the build. A check that stops a build when IRS batches are
  missing has since been added to that pipeline, and the build record
  now states which batches were covered.

## 3. What NCCS will do from here

- Run the check after every IRS batch and append the result to the two
  files. Nothing else changes for users.
- Report in the standing "verification results" item each meeting,
  in one line per release: "complete through IRS batch NNN".
- Keep a direct NCCS copy of the IRS files, keyed by IRS batch, as the
  long-term fix for the lag (proposed in decision record 0052; the
  producer has said he would rather NCCS owned this than add it to
  his own package). That is a separate proposal and is not on the
  table in this note.

## 4. Decision asked

That every e-file release note state the last IRS batch the release
is complete through, in one line, using the check above as the source.
For the current release that line is: "Complete through IRS batch
2026_TEOS_XML_08A (published by the IRS 2026-09-16); the four filings
missing from that span are listed in ef2 issue 31." This changes the
release-note practice adopted in August (charter section 6), not the
charter itself.

## 5. For the record, no decision needed

The question of whether to keep relying on the GivingTuesday copy at
all, or to read IRS releases directly as the producer's own patch store
and ProPublica do, is deferred to 2027, when a year of these monthly
counts is in hand. Logged as backlog U3.

Evidence: the two published files above; nccs-data-efile pull requests
19 and 20; the audit record in nccs-workspace under
reviews/2026-10-21-efile-audit (batch-09a-coverage.md and the two
u1 evidence folders).
