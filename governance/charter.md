# NCCS Data Infrastructure Governance — Charter

*v0.2, 2026-08-12 — discussed and amended at the first governance
committee meeting (Thiya Poongundranar, Jesse Lecy, Lewis Faulk,
Erika Tyagi; minutes in `governance/minutes/2026-08-12.md`).
Nothing here is new machinery: this charter names and formalizes
practices already running. Policies roll out progressively rather
than being enforced all at once (committee note, 2026-08-12).*

## 1. Purpose

NCCS data serves external partners, researchers, and policy audiences
who need to trust what they download. This charter defines:

1. what counts as **essential infrastructure**, what **quality control** means for it,
2. how changes to it are **versioned, documented, and retained**, so that trust is systematic rather than reputational.

## 2. The layered ecosystem (per the NCCS strategic plan)

Governance obligations attach by **layer**, not by dataset:

| Layer | Examples | Governance touch |
|---|---|---|
| Raw | IRS releases, GT e-file lake | Provenance recorded; freshness monitored; never altered |
| Normalized | monthly BMF, e-file extractions (ef2 v2_x) | Release documented; versioned paths |
| Validated | Unified BMF, CORE (Harmonized SOI), quality reports | Ensuring data is trustworthy |
| Augmented | geocoded BMF, CORE (NCCS-enhanced) crosswalks, concordances, metadata tables | Full obligations + provenance to inputs |
| Packaged | R packages, dashboards, catalogs | Pinned to validated/augmented versions; updated deliberately when a new version is announced |

## 3. Essential infrastructure (key decision #1)

A dataset or field is **essential infrastructure** when external work
depends on it staying stable: concretely, when it is:

(a) published at a fixed and agreed upon (contracted) location - this makes finding, retrieving, and updating files easy
(b) consumed by a public-facing output (package, dashboard, partner, or publication)
(c) irreplaceable without breaking that output. 

Currently, data contract YAMLs are specified in the: `nccs-contracts` GitHub repo under `contracts/`.
One published file per specified contract, naming raw data origin, current location, schema, and consumers. 

**Included datasets** (committee vocabulary, 2026-08-12: "core" means
the 990 panel family — one dataset in several variants):

* 990 panel family: NCCS CORE (PZ / PC / PF scope files), SOI
  extracts, e-file panels (v2_x), 990-N postcards (not yet actively
  maintained)
* BMF (monthly releases + the Unified BMF)
* Geographic crosswalks
* Metadata tables (NTEE, address history)

Special projects (e.g. the trends survey, political-activity data)
sit outside this governance scope unless the committee elevates them
to a maintenance commitment.

**Proposal (agreed 2026-08-12):** add the Jesse-maintained e-file
v2_x datasets to the contract registry.

**Essential fields** (the test, per JL: anything whose change breaks
downstream dependencies). Changes to these are architectural:

* Org identifiers and join keys: `EIN2`, `ein_raw`, affiliation,
  classification codes
* Time: tax period — with explicit, consistently applied definitions
  of fiscal year vs. tax year vs. filing year
* Geographic definitions, including Census vintage (2010 vs. 2020
  FIPS)
* Sanitized addresses
* NTEE codes

**Known downstream dependencies** (tracked; grows as consumers are
named): Sector in Brief (dashboard), the download API, the NTEE and
address metadata tables, and the NODC R-package family.

## 4. Trustworthiness (key decision #2)

"Is the data trustworthy?" gets a systematic answer four ways:

1. **Manifests** — every published artifact carries `_manifest.json`
   (git SHA of the producing code, input provenance (source data), row counts,
   sha256 per file). If the manifest and the file disagree, the file
   is wrong.
2. **Quality reports** — per-build validation published beside the
   data with `quarto` via .html (number of NULLs, counts, presence of essential columns).
3. **Independent verification** — where two pipelines can produce the
   same number, they are compared and the comparison published (e.g.,
   the SOI Harmonized verified byte-exact against raw IRS SOI releases,
   Aug 2026; the e-file government-grants crosscheck). 
   
   **Proposal**   
   "NCCS-verified" stamp on the website appears in the catalog only where this has run.
4. **Decision records** — every structural choice gets a short
   written decision record (an "ADR" — architecture decision record:
   a one-page note saying what was decided, why, and what would
   trigger revisiting it). There are [46 to date](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions), so the "why"
   behind the data is transparent and not via individual conversations. Example: the
   [vintage-and-latest publishing convention](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0042-vintage-retention-latest-convention.md).

QC for committee purposes = points 1-2 mandatory for validated layer and above; 
mechanism 3 where a second source exists; mechanism 4 for every change to architecture/data processing.

## 5. Versioning and canonical locations (ADOPTED 2026-08-12)

**Three-tier semantic versioning, `vA.W.P_{YYYY_MM}`** — the version
components carry what changed; the `_{YYYY_MM}` suffix carries the
period of the underlying raw data, so filenames answer both "which
build?" and "data as of when?" (filename convention agreed in the
meeting):

- **A — architecture**: schema/structural changes; requires a
  written decision record and a deprecation window (default 90 days,
  per the [deprecation-window policy](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0033-deprecation-window-policy-and-critical-bug-override.md)).
- **W — wave**: new data added (new tax year, late-arriving filings);
  additive only; release note required.
- **P — patch**: corrections; release note states what changed.

**Canonical locations** (already live for BMF products — see the
[vintage-and-latest convention](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0042-vintage-retention-latest-convention.md)):
every rolling artifact publishes a permanent vintage prefix
(`v{YYYY_MM}/`) **and** a `latest/` mirror. Consumers and packages
defer to `latest/` for current data, and pin a dated vintage folder
for reproducible work (papers, replication code) — no date-guessing
(`find_latest_index()` becomes: read `latest/_manifest.json`).
**The manifest at `latest/` is the version registry**:
machine-readable, per-artifact, always current.
NEWS.md files rendered on the nccs website as a readable summary for
humans.

### Patches to rolling endpoints (e-file flow, agreed 2026-08-12)

Bug-fix (P) releases overwrite the same public endpoint so casual
downloaders always get the corrected data; BOTH versions are archived
under their version folders. An embedded version/fingerprint "receipt"
column inside the files is under design (due-out) to keep provenance
attached to the data itself, not only the filename.

## 6. Release documentation (ADOPTED 2026-08-12)

Every change to essential infrastructure is published with a dated release
note: what changed, whether existing records are revised or only added,
per-year changes in records, and verification status. The producer of
the change sends a one-paragraph heads-up before it goes live; NCCS
drafts, verifies, and publishes the note
(first instance: e-file v2_2, 2026-08-11).

## 7. Retention and attribution

- Every version of every dataset is retained — waves and patches
  alike; older versions may move to cheaper storage tiers
  (deep-freeze) but are never deleted (the [policy](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0037-master-bmf-rename-unified-supersession-provenance.md)).
- Only the latest version of a wave is exposed on public catalog
  pages (protecting users from superseded, buggy copies); older
  versions remain reachable via the changelog.
- Every catalog page cites the producing package/DOI where one exists
  (ef2, irs990efile, the concordance file, governance index) — 
  attribution is part of the release checklist
- Data license: ODC-BY per the site terms (§3.5, live 2026-08-11).

## 8. Prioritizing NCCS bandwidth

New-product effort is ranked by: 
(1) does it serve an existing named user; 
(2) does it augment essential infrastructure (verification, docs, automation) vs. adding a new dataset; 
(3) demonstrated demand (download metrics now exist: ~23K/month, 8x in two years). 

The committee reviews the ranked backlog (`nccs-contracts/BACKLOG.md`) quarterly; the backlog is public.

## 9. The committee

Meets monthly (30 min). Standing agenda: what is published each side;
release notes due; registry changes (needs a decision record?);
verification results; priority check. Decisions that change essential
infrastructure are recorded as decision records; everything else is
minutes.

---
*Settled at the first meeting (2026-08-12): §3 scope + fields, §5
versioning + filename convention, §6 release flow (incl. the
producer heads-up policy), §7 retention. Pending (see
`governance/decisions-pending.md`): what constitutes validation;
DOI/citation machinery; the embedded-receipt design; a website
changelog / NEWS page.*
