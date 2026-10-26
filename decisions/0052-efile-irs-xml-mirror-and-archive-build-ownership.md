# 0052: An NCCS mirror of the IRS e-file XML, and who builds the e-file archives

- **Status:** Proposed (2026-10-26). For the maintainer to accept, amend or reject. Nothing in `nccs-data-efile` changes until this is accepted.
- **Date:** 2026-10-26
- **Deciders:** sole maintainer, after the planning discussion with Laura Tomasko and Jesse Lecy
- **Related:** [[0017-efile-phase-0-vertical-slice]] (our own Phase 0 build and its coverage check), [[0028-efile-wholesale-relational-extraction]] (our own table extraction, built and not yet run at scale), [[0046-nodc-soi-harmonization-interoperability]] (how we relate to NODC products), contracts `efile-duckdb-archives` and `efile-nodc-panels` (the NODC products this is about), backlog rows Z23 (this decision), U1 (the monthly coverage check), U3 (the GivingTuesday dependency, 2027), #15 and #16 (e-file deprecation and parallel build)

## Context

Two sets of e-file products reach users through NCCS today. The first is
ours: the Phase 0 tables from `nccs-data-efile` (two fields, feeding Sector
in Brief). The second is NODC's: the per-table CSV and parquet releases
(`efile_v3_1`, `efilepf_v3_1`) and the per-year DuckDB archives, built by
Jesse Lecy's ef2 package, published into the nccs-efile bucket, and listed
on the NCCS website. NCCS hosts and catalogs the second set and does not
build or check it (decision of 2026-09-16, recorded in both contracts).

Both sets have the same upstream problem. Neither build reads the IRS
directly. Both read the GivingTuesday data lake, a third party's mirror of
the IRS monthly releases. In 2026 that mirror skipped whole IRS releases
(2025_09A, 2025_10A, part of 2026_05A, and 2026_08A as of October). Our
June Phase 0 build is short 37,211 filings the IRS had already published.
NODC's v3_1 release is complete only because Jesse keeps a separate store of
filings fetched from the IRS directly (`xml2/v2_3_patch/`, 184,165 filings)
and merges it in by hand. Release 08A reached v3_1 entirely through that
store. Nothing on either side records which IRS releases have been fetched.

On 2026-10-26 Jesse wrote, in reply to our coverage finding, that ef2 has a
push-button update workflow but that retrieving IRS files and updating the
NCCS catalog "are not wired into the workflow"; that he would not want to
mix internal NCCS steps with generic ef2 functionality; that build scripts
and logs could live in `nccs-data-efile`; that "nothing tracks IRS batch
IDs currently"; and, on the question of hosting the XML, that it is cheap
but the question of people building applications on a public lake is
"above my data engineering paygrade". That is the first time the producer
has drawn the line between research tooling and data infrastructure in
writing, and he drew it where we would: the infrastructure is ours.

Backlog row Z23 asked for a decision record comparing three options for the
archives: (a) run ef2 under NCCS control, (b) build the same files from our
own relational extraction (ADR 0028), (c) leave them a hosted external
product. This record answers Z23, but it reframes the question first,
because the archives are the last step of a chain whose first step is
missing on both sides.

## Decision

### 1. NCCS keeps a direct mirror of the IRS e-file XML, keyed by IRS release

NCCS fetches every IRS monthly release (the `XML_BATCH_ID` ZIPs listed in
the IRS annual index files) from the IRS itself and stores the extracted
XML under an NCCS prefix, one folder per IRS release id, with a log of
what was fetched and when. The IRS annual index files are mirrored beside
it. This is the raw tier of the e-file lifecycle and it is NCCS data
infrastructure, not a research product.

What it is: the record of what the IRS has published, under our control,
with a release id on every file. What it is not: a parsed product, a
replacement for GivingTuesday in anyone else's pipeline, or a public lake.

Decided here:

- Location: a new prefix in the nccsdata bucket, `raw/efile-irs/`, laid
  out as `raw/efile-irs/{XML_BATCH_ID}/{ObjectId}_public.xml`, with
  `raw/efile-irs/index/index_{YYYY}.csv` (the IRS files, byte for byte)
  and `raw/efile-irs/_fetch_log.csv` (one row per release: release id,
  IRS publication date, fetched at, ZIP size and checksum, file count).
  The patch store Jesse already keeps (`nccs-efile/xml2/v2_3_patch/`)
  is the seed; its filings are re-keyed by release id from the IRS index.
- Read access: not anonymous at first. The mirror is readable by NCCS
  roles and by the producer's build role. Jesse's concern about
  applications served from a public lake is real and is a governance
  question (who may read raw XML at scale from our bucket, and at whose
  cost), so anonymous read is a separate decision for the committee, not
  a default. The nccs-efile bucket stays as it is.
- The monthly coverage check (backlog U1, `nccs-data-efile` PR #19) is
  extended to report the mirror as a third source beside GivingTuesday
  and the patch store, and to say which IRS releases the mirror holds.
- Fetching is a scheduled job in `nccs-data-efile`, run after each IRS
  release, with the log as its only output besides the files. It does
  not trigger any build.

### 2. The producer's build reads from the mirror, with the build script and logs in `nccs-data-efile`

Jesse proposed exactly this and it is accepted as proposed: ef2 stays
generic research tooling in his repository; the script that runs ef2
against NCCS inputs, records the IRS release cutoff, and writes the
change log lives in `nccs-data-efile`, beside its logs. The script's
inputs are the mirror and the IRS index files, not the GivingTuesday
lake. Its outputs are what the producer publishes today, plus a release
note line "complete through IRS release NNN" produced from the fetch
log rather than written by hand (the guarantee list in
`efile-nodc-panels`, item 2).

This does not change who owns the tables. NODC remains the producer of
`efile_v*` and the archives; NCCS hosts and catalogs them; the
guarantees in `efile-nodc-panels` still need his agreement (pending
decision 7). What changes is that the inputs to his build become an NCCS
surface with a record, so a short release can be seen before it is
published.

### 3. Who parses the XML into tables: decide in early 2027, with a year of evidence

The chain has three layers. First, the raw XML the IRS publishes each
month. Second, the parsing: turning that XML into tables with named
columns. Today ef2 does this with Jesse's concordance; our own extractor
from ADR 0028 would do it with our dictionary, but it has never been run
across all filings. Third, the published files: the per-table CSVs and
the per-year DuckDB archives, which are just the parsed tables written to
disk. Z23 asked who should build the third layer. Whoever parses owns the
archives, so the real question is who parses.

Z23 listed three answers:

- (a) NCCS runs ef2 itself. We would be answerable for a parser we did
  not write and have not reviewed line by line, while its author is
  reorganizing his packages.
- (b) NCCS builds the same files from its own extractor (ADR 0028). The
  code exists, but we do not yet know whether it gives the same answers
  as ef2, how long a full run takes, or what it costs.
- (c) The archives stay Jesse's product, hosted by NCCS. This is the
  status quo. Its weakness was that his inputs came from a third party's
  copy with silent gaps, and nobody could see a short release before it
  went out.

Step 2 removes that weakness without changing ownership. So (c) is how
things stay for now, and (a) against (b) is decided in the first quarter
of 2027, together with U3, on two kinds of evidence we do not have today:

- A year of the monthly check, showing release by release whether
  Jesse's tables hold what the IRS listed. A clean year makes the case
  for taking over the parsing weak; repeated gaps or rewrites make it
  strong, with numbers rather than an impression.
- Whether ADR 0028's extractor has run at scale by then. If it has, its
  output can be compared with ef2's on the same filings, value by value,
  which is the only honest basis for choosing (b). If it has not, (b) is
  not yet a real option and the choice is between (a) and (c).

U3 (whether to keep reading GivingTuesday at all) collapses into the same
question: the mirror makes the lake unnecessary for both builds, so in
2027 there is one decision, not two. The risk of deferring is drift. The
record pins the decision to a quarter and to this evidence so it comes
back on its own, which works only if the monthly check runs every month
and someone reads it.

## Rejected for now

- **Doing nothing beyond this week's check.** Our Phase 0 build still
  takes its list of filings from the GivingTuesday lake. Since
  `nccs-data-efile` #17 and #18 it compares that list with the IRS's own
  list before it starts, and stops if an IRS release is missing. Stopping
  is all it does. The missing filings are still missing and nothing in
  our pipeline goes to get them. Every gap so far was closed by Jesse
  fetching the releases from the IRS himself, by hand, into his patch
  store; our June build has no patch store and is still short. With a
  mirror, fetching from the IRS becomes the ordinary way filings arrive,
  for both builds, and every fetch is logged by IRS release number. The
  check tells you that you are short; the mirror is what makes you not
  short.
- **A mirror anyone on the internet can read.** The nccs-efile bucket
  allows reads without logging in, which is how the website links and
  the DuckDB users reach Jesse's files. If the XML copy worked the same
  way, anyone could point a program at it and pull every filing,
  repeatedly, at our expense. That is the concern Jesse raised: a site
  like ProPublica could serve raw XML straight from our bucket, so the
  traffic and the bill land on NCCS while the product is someone else's.
  The IRS serves the same files, so nothing would be leaked, but NCCS
  would become the origin for other people's applications. The mirror
  therefore starts private: readable by NCCS roles and by the role
  Jesse's build runs under. Opening it to the public is a separate
  decision for the committee, with the cost question answered first.
- **Taking over the ef2 build now (option a).** It would make NCCS
  responsible for a parser it has not reviewed, during the same quarter
  in which the producer is reorganizing his packages. Step 2 gets the
  record-keeping benefit without the ownership transfer.

## Contract impact

- New contract `efile-irs-mirror.yml` (producer `nccs-data-efile`; format
  xml; partitioned by IRS release id; manifest = the fetch log; consumers:
  the producer's build script, the coverage check). Written when this is
  accepted, before the first fetch.
- `efile-nodc-panels.yml`: producer section gains the build script and
  its log location; guarantee item 2 gains the mechanical "complete
  through" line. Only after Jesse agrees to step 2 in writing.
- `efile-duckdb-archives.yml`: no change until 2027.
- Governance: anonymous read on the mirror added to `decisions-pending.md`
  as its own item; the committee hears it with the release-note cutoff
  line (backlog U2).

## Consequences

- NCCS holds its own copy of what the IRS has published, with a record.
  A missing release becomes a line in a log rather than a finding in a
  data request.
- Storage: the IRS releases since 2019 are a few hundred gigabytes of
  XML at most; the exact figure is measured from the ZIP sizes in the
  fetch log before the first full fetch, and recorded in the Outcome.
  Jesse's reading is that hosting is cheap, and nothing here contradicts
  it, but the number is to be measured, not assumed.
- The producer's build gets a reliable input without a change to ef2.
- A standing monthly job in `nccs-data-efile` (fetch, log, coverage
  report) that someone has to watch. The coverage check is the watcher.
- The 2027 decision is written into the calendar with U3, so it does not
  drift.

## Execution

Nothing until Accepted. Then, in order:

1. `nccs-contracts`: `efile-irs-mirror.yml`; pending-decision item for
   anonymous read; U2 governance note gains this record.
2. `nccs-data-efile`: fetch job (IRS index files, release ZIPs, extract,
   upload, log), seeded by re-keying the existing patch store. Runs on
   EC2, not the laptop. First full fetch sized from the ZIP headers
   before it runs.
3. `nccs-data-efile`: extend the coverage check to read the mirror.
4. With Jesse: the build script and its logs, reading from the mirror.
   His agreement by email is enough.
5. Outcome note here: mirror size, first fetch date, which releases it
   holds, and whether the producer's next release was built from it.

## Acceptance

- The fetch log lists every `XML_BATCH_ID` in the IRS index files from
  2024 on, with a fetched-at date, and the file count per release equals
  the IRS index count for that release.
- The coverage check reports no release held by the IRS and absent from
  the mirror, for any release published more than seven days before the
  check.
- The producer's next release note carries the "complete through"
  line, produced from the log.
