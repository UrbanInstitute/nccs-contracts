# 0017 — E-file Phase 0 Vertical Slice and Transition to NCCS-Owned Concordance

- **Status:** Executed (Phase 0 shipped; current vintage `v2026.06` as of 2026-06-09; Phase 0.5 executed 2026-06-09; Phase 1+ planned)
- **Date:** 2026-05-22 (executed 2026-05-29)
- **Deciders:** sole maintainer
- **Related:** [[0001-s3-as-contract-surface]], [[0004-cadence-aware-drift-detection]], [[0007-efile-urban-owned-producer]], [[0010-sector-in-brief-data-replaces-dataexplorer-data]], [[0013-versioned-producer-outputs]], [[0014-standardize-manifest-shape]], [[0016-no-canonical-cross-dataset-merge]]
- **Amends:** [[0007-efile-urban-owned-producer]] (inserts Phase 0 ahead of original Phase 1; shifts concordance posture from "adapt NODC with attribution" to "vendor NODC during a bounded transition window, then transition to an NCCS-owned XSD-driven concordance"; corrects license claim)
- **Amended by:** [[0028-efile-wholesale-relational-extraction]] (2026-06-09) — inverts §3's end-state: Layer 1 now **drives wholesale extraction** to a normalized relational tier (header + child tables, incremental, scalar-first); Layer 2 becomes demand-driven curated views on top, which remain the contracted surface.

## Context

[[0010]]'s 2026-05-19 to 2026-05-21 execution shipped six of eight
sector-in-brief panels and deferred two — `gov_grants` and `pf_pri` —
pending an upstream column-mapping investigation. That investigation
is now resolved:

- **Government Grants** (dashboard panel "Government Grants") is
  sourced from Form 990 Part VIII line 1e, *Government grants
  (contributions)* — a single USD value per filing, revenue
  received from federal/state/local government. (Distinct from
  Schedule I, which lists grants paid *to* governments.)
- **Program-Related Investments** (dashboard panel "PRI") is sourced
  from Form 990-PF Part IX-B, *Summary of Program-Related
  Investments*, aggregate row — a single USD total per private
  foundation filing.

Both fields live in the IRS e-file XML surface, not in the NCCS
annual SOI core extract. The SOI extracts that `nccs-data-core`
consumes do not carry Part VIII line 1e at usable fidelity and do
not carry 990-PF Part IX-B at all. The two panels therefore cannot
ship without an e-file data tier.

[[0007]] anticipated this need and laid out the Urban-owned
`nccs-data-efile` producer, but its phasing put headline 990 first
(Phase 1), schedules and 990EZ second (Phase 2), and full 990PF
third (Phase 3) — the order in which a general e-file extract is
conventionally built, not the order that serves the only contracted
consumer with a concrete demand.

A 2026-05-22 recon against the actual upstream resources, performed
to populate this ADR, revealed several facts that change the planning
defaults established in [[0007]]:

1. **NODC's concordance is ODC-By licensed, not MIT.** [[0007]]'s
   "MIT-licensed, may be adapted with attribution" framing is
   factually wrong. The Open Data Commons Attribution License
   applies to derivative databases and carries an ongoing attribution
   obligation on any artifact derived from the concordance.
2. **NODC covers 990PF comprehensively.** The repository's
   `02-concordance-foundations/` directory contains 2,231 rows
   spanning all 17 parts of Form 990-PF plus 707 auxiliary-schedule
   rows. The Part IX-B PRI aggregate is present and the XPath drift
   across IRS schema versions is documented. [[0007]]'s
   "NODC does not cover 990PF" framing is also wrong.
3. **NODC's mapping is sophisticated, not naive.** Each variable
   carries a `versions` column listing every (tax_year × sub-version)
   in which its XPath was valid; XPath drift is captured per-variable
   across the full 2009–present range.
4. **NODC's naming convention is 2020-anchored.** Location codes
   (`F990-PC-PART-08-LINE-01E` etc.) and the `form_part`/`form_line`
   columns reference the 2020 Form 990 layout. When the IRS
   reorganizes a form, the location codes shift but the
   `variable_name` remains stable. The convention is *position-
   anchored to a reference year*, not form-agnostic.
5. **The GivingTuesday data lake is genuinely free and frictionless.**
   `s3://gt990datalake-rawdata/` is anonymous-readable
   (`--no-sign-request`), no AWS account required, no credit card,
   no rate limit. The lake includes JSON indices under
   `Indices/990xmls/` listing every filing — these alone save weeks
   of upstream pipeline work. Raw XMLs are at `EfileData/XmlFiles/`.
6. **IRS direct downloads still work** as a fallback. Per-year ZIPs
   with monthly subdivision are downloadable from the IRS website,
   2019–2026, with a CSV index per year. No registration, no rate
   limit, no AWS account. Heavier to consume than GT (no object-level
   index; everything is inside monthly ZIPs) but a viable contingency.
7. **NODC has no upstream review process.** Concordance updates land
   irregularly (one substantive update in 2025; quarterly housekeeping
   commits otherwise). The NCCS maintainer is in fact the de facto
   author of NODC concordance updates on Jesse's behalf — i.e.,
   "depending on NODC" and "doing concordance maintenance labor" are
   the same activity for this maintainer.
8. **GT's parser depends on NODC's concordance too.** The two
   ecosystems are downstream of the same artifact; there is no
   independent third option to fall back to. Sovereignty over the
   concordance is therefore not just about Jesse — it's about not
   having a single point of failure across the whole 990 e-file
   ecosystem.

These findings narrow the case for an NCCS-built XPath walker for
Phase 0 (NODC's existing mapping is correct for the two target
fields and verified by inspection), and *strengthen* the case for
an NCCS-owned concordance over the longer arc (the artifact is
labor the current maintainer is already doing, with no review
process and no Urban control).

## Decision

Five coupled decisions, executed in the sequence below:

### 1. Phase 0 vertical slice ships first

`nccs-data-efile`'s first published vintage covers only the two
columns the `sector-in-brief` dashboard needs. No headline 990
extract, no general columnar e-file surface, no Phase 1/2/3 scope.

**Scope:**

- Forms covered: 990 (for `government_grants`) and 990-PF (for
  `program_related_investments_total`).
- Tax years: 2020 onward.
- Output grain: per-filing (`ein`, `tax_year`, `form_type`,
  `filing_receipt_id`, value column). Aggregation to the
  sector-in-brief dimension grain stays in `sector-in-brief-data`'s
  panel builder, joining EIN against `bmf-master-geocoded` (same
  pattern as the six panels already shipping).

**Output shape under `s3://nccsdata/processed/efile/phase0/{vintage}/`:**

- `government_grants.parquet`, `program_related_investments.parquet`
- `government_grants_dictionary.csv`,
  `program_related_investments_dictionary.csv`
- `government_grants_quality.json`,
  `program_related_investments_quality.json`
- `_manifest.json` (per [[0014]])
- `latest/` mirror

### 2. Phase 0 ships off vendored NODC concordance, with build-time verification

NODC's `concordance.csv` is used as a build input for Phase 0, but
under explicit vendoring discipline rather than as a live upstream:

- **Vendor at pinned SHA.** At build time, the producer pulls
  NODC's `concordance.csv` at a specific commit SHA and mirrors it
  to `s3://nccsdata/processed/efile/concordance/{nodc_sha}_{YYYY-MM-DD}.csv`.
  The producer pins to the S3 mirror, not to GitHub. This both
  decouples the build from GitHub uptime and creates a permanent
  audit trail per [[0001-s3-as-contract-surface]].
- **Manifest pins the SHA.** The Phase 0 vintage `_manifest.json`
  records `nodc_concordance_sha` and `nodc_concordance_s3_path`.
  Every published parquet is traceable to the exact concordance row
  set used to extract it.
- **Drift check, not auto-bump.** A scheduled job
  (per [[0004]]) compares NODC master against the last pinned SHA.
  On diff, it opens a GitHub issue against `nccs-data-efile`
  listing the changed rows. **Adoption is always explicit.** A
  human (the maintainer) decides whether to absorb the change in
  the next vintage. This makes the "irregular updates" risk a
  *feature*: NODC moves on its cadence, NCCS moves on its.

**Trust verification runs at every build.** Because NODC has no
upstream review process, NCCS verifies the rows it depends on
against the IRS XSDs — the authoritative artifact for what each
element actually is:

1. **XSD existence check.** For each NODC XPath variant in use,
   walk the corresponding (tax_year, version) IRS XSD and assert
   the element exists at that path with the declared type. Fails
   the build on mismatch. Catches XPath typos, schema drift NODC
   missed, and silent renames.
2. **Value-distribution sanity check.** Assert each value is numeric
   where claimed numeric, that **min/max over the full population**
   fall within empirically-pinned value bands, and that the per-form
   null rate matches expectation. min/max are order statistics, so
   they are checked against the population, not a sample — a sample
   cannot bound them; the null rate stays on a stratified sample,
   where a proportion is robust. The bands are pinned from observed
   vintages and widened to admit the verified-real tail
   (`government_grants` USD in [-1e8, 5e10]; `program_related_investments_total`
   in [-1e8, 1e10] — the GG max ≈ $13.2B is a real Battelle-class
   federal-lab manager, and negative values pair with contribution
   clawbacks/restatements; both verified against source XML, not
   extraction defects). Heavy-tail diagnostics (an order-statistic
   ladder + Pareto tail-mass shares) are recorded in `quality.json`
   and the manifest; egregious breaches fail the build. (Population
   method + widened bands finalized in the producer ADR
   `nccs-data-efile/decisions/0002` Outcome / PR #5; see this ADR's
   Outcome.)
3. **IRS instruction spot-check (one-time per field).** At
   adoption, the maintainer manually cross-references NODC's
   `description` against IRS form instructions for that field,
   documents the source instruction page/line in the producer's
   NCCS-owned crosswalk, and signs off. Redone only when NCCS
   bumps the pinned SHA *for that row*.

The XSD-existence checker built for Phase 0 is the seed for the
Phase 0.5 layer-1 inventory (decision §3) — same code, smaller
scope.

### 3. Transition to NCCS-owned, XSD-driven concordance (Phase 0.5 workstream)

> **Executed 2026-06-09** — see the Outcome subsection "Phase 0.5 — two-layer
> concordance" below and the producer build record
> `nccs-data-efile/decisions/0003-two-layer-concordance.md` (authoritative).
> The decision text below is the original Phase 0.5 framing, left intact.

In parallel with or immediately following Phase 0 shipping, NCCS
builds its own concordance infrastructure. The architecture is
deliberately two-layer:

**Layer 1 — mechanical XSD inventory.** Per (tax_year, sub-version)
of every IRS form schema NCCS targets, the full XPath inventory
derived purely from the XSD. Each row records the full XPath, the
declared XSD type, cardinality, parent path, and any
`xsd:annotation/xsd:documentation` the IRS shipped. Generated
mechanically by an XSD walker; regenerated on every IRS release;
never hand-edited. Big files but boring (≈10K rows per version ×
~20 versions ≈ 200K rows over 2020+). Lives as a build artifact in
the producer repo.

**Layer 2 — NCCS semantic dictionary.** A small hand-maintained
file mapping NCCS-owned `snake_case` names to lists of
(tax_year, version, xpath) claims. Each row is a deliberate,
reviewable assertion; the file is small enough to actually review
end-to-end. Estimated size: 2 rows at Phase 0, ~200 at Phase 1,
~1500 at full coverage. This is the file that carries NCCS's
naming sovereignty and the per-field IRS instruction citations
from §2.3.

**Cadence.** Layer 1 regenerates on every IRS XSD release
(quarterly within a tax year for TY2025; previously annual).
Layer 2 is updated by the maintainer when expanding the contracted
field set or when an IRS rename forces a decision about variable
identity. Per [[0004]], the layer 1 regeneration is a cron event;
layer 2 edits are PRs.

**Repo placement.** The concordance infrastructure lives inside
`nccs-data-efile/` as producer-internal machinery. The producer
repo is public on GitHub, so the concordance source is inspectable
by external researchers. No separate contract YAML is created in
`nccs-contracts/` — the contract surface remains the parquet
outputs in `efile.yml`. If external consumer demand for direct
concordance access emerges, the artifact can be promoted to its
own contract or its own repo at that point.

**End-state for the NODC dependency.** Phase 1+ extracts run
natively off NCCS's layer-2 dictionary, with layer 1 as the
XPath ground truth. NODC drops from "vendored build input" to
"comparison artifact" — at each NCCS release, an automated diff
report compares NCCS's layer-2 claims against NODC's
`concordance.csv` for the overlap, and flags discrepancies in both
directions. The diff is informational, not blocking.

### 4. GivingTuesday data lake as primary upstream; IRS direct as documented fallback

The producer reads from `s3://gt990datalake-rawdata/` anonymously
(`--no-sign-request`):

- `Indices/990xmls/` provides JSON manifests listing every filing
  in the lake (EIN, form type, year, S3 key). The producer reads
  these first, filters to (form_type ∈ {990, 990PF}, tax_year ≥
  2020), and uses the resulting key list to drive parallel XML
  fetches.
- `EfileData/XmlFiles/` holds the raw filings. The producer never
  holds an XML in memory beyond the duration of a single
  extraction — small RAM footprint, large parallelism.

**Fallback to IRS direct.** The producer carries a fallback adapter
that reads from the IRS per-year ZIP downloads
(`https://www.irs.gov/charities-non-profits/form-990-series-downloads`).
The adapter is not the default path because IRS publishes ZIPs
without object-level indices — consumption requires download +
decompression + per-XML walking, materially heavier than the GT
indexed path. The fallback is tested but dormant. Activation
criteria: GT data lake unavailability for >7 days, or a known
discrepancy between GT's mirror and IRS canonical filings for
fields NCCS depends on.

### 5. Sector-in-brief panels remain unwired until Phase 0 ships

The two deferred panels (`gov_grants`, `pf_pri`) stay unwired in
the `sector-in-brief` dashboard codebase and `sector-in-brief-data`
producer until the first Phase 0 vintage publishes. Once it does:

1. `sector-in-brief-data` adds `panel_gov_grants.R` and
   `panel_pf_pri.R`, reading the two Phase 0 parquets and
   aggregating to the dashboard's dimension grain.
2. The dashboard wires the two panels in `R/data_server_args.R`
   (the navigation stubs at `R/nav_panel-visuals.R` are
   pre-existing per [[0010]] Context §4).
3. `contracts/sector-in-brief.yml` updates the published-file list
   and removes the "Not yet published" annotation.

**Interim wiring to NODC's CSV outputs is rejected.** Pointing the
dashboard temporarily at `s3://nccs-efile/` would: (a) breach
[[0007]]'s contracted-tier model (NODC outputs are not manifest-
shipping, not parquet, and use 2020-anchored column names);
(b) force a cutover migration later touching the dashboard,
`sector-in-brief-data`, and the contract YAML simultaneously;
(c) couple a contracted consumer to a non-contracted producer,
which is the failure mode `nccs-contracts` exists to prevent.

The cost of deferral is two known-empty panel slots in the
dashboard for the Phase 0 build window (estimated 1–3 weeks).
That cost is documented openly in `contracts/sector-in-brief.yml`.

## Why these decisions (rationale)

The decisions above pivot on eight underlying judgment calls.
Documenting them here so the reasoning is auditable and so future
readers can identify which leg, if any, has broken if the plan
needs to be re-opened.

### A. Why Phase 0 vertical slice instead of [[0007]]'s original phasing

**Beats:** holding [[0007]]'s "Phase 1 = headline 990 first" ordering
(which would leave sector-in-brief panels empty for months while
the producer ships fields no contracted consumer currently
demands), and skipping straight to full 990PF (closer to the need
but multi-month build before any panel shows up).

**Why:** phasing should follow real consumer demand. The only
contracted consumer with a concrete blocking need today is
sector-in-brief, and it needs exactly two fields. Anything else is
speculative consumer service. **Cost accepted:** Phase 1's
headline-990 surface lands later than [[0007]] originally implied.

### B. Why ship Phase 0 off vendored NODC instead of building from XSDs first

**Beats:** writing the XSD-driven extractor for the two fields
before any sector-in-brief panel ships.

**Why:** NODC's mapping is verifiably correct for these specific
fields (the rows were inspected during this ADR's preparation —
PF_09_PROG_RLTD_INVEST_AMT_TOT and F9_08_REV_CONTR_GOVT_GRANT,
both with cross-version XPath drift documented). Re-deriving a
mapping that already passes verification is yak-shaving. **Cost
accepted:** Phase 0 has a temporary external dependency, mitigated
by the SHA pin + S3 mirror + drift check + build-time verification
in decision §2.

### C. Why an NCCS-owned concordance eventually, not permanent NODC dependency

**Beats:** staying on NODC indefinitely as the long-term mapping
source.

**Why:** NODC has no upstream review process; the artifact updates
irregularly; the current NCCS maintainer is in fact the de facto
upstream contributor, so "depending on NODC" and "doing concordance
maintenance labor" are the same activity. The same hours spent
maintaining NODC's concordance can produce an NCCS-owned artifact
on NCCS's review process. Relocates labor without increasing it;
bounds the dependency window. **Cost accepted:** Phase 0.5 is real
engineering work (estimated 4–8 weeks). If the work doesn't
happen, the dependency persists.

### D. Why a two-layer concordance instead of NODC's monolithic shape

**Beats:** replicating NODC's single-CSV structure (one file
mixing machine-derivable XPath inventory with human curation
decisions).

**Why:** NODC's mixing of machine and human content in one artifact
is precisely why it has no review process — there's no clean line
between "regenerate from XSD" and "decide whether a renamed
element is the same variable." Separating the layers makes layer 1
fully reproducible from XSDs (audit trail = the XSDs themselves)
and makes layer 2 small enough to review end-to-end. Production-
grade pipeline requirement met. **Cost accepted:** more files to
maintain than NODC's single CSV, but each is simpler and only
layer 2 requires curation labor.

### E. Why GT data lake primary, IRS direct fallback

**Beats:** consuming IRS direct as the default upstream.

**Why:** GT's pre-built JSON indices remove an entire pipeline
stage worth of work (no need to download, decompress, and walk
monthly ZIPs to find specific filings). Anonymous
`--no-sign-request` access removes auth/onboarding friction.
Free, currently maintained. **Cost accepted:** real external
dependency on GT's continued operation. Mitigated by the IRS-direct
fallback adapter (tested but dormant) and explicit activation
criteria.

### F. Why build-time trust verification instead of accepting NODC's claims

**Beats:** trusting NODC's XPath mappings without independent
verification.

**Why:** NODC has no upstream review process, the maintainer
cannot rely on upstream review for correctness, and the IRS XSDs
exist as an authoritative ground truth NCCS can use unilaterally.
Verification at extraction time catches XPath typos, schema drift
NODC missed, semantic mismatches, and value-distribution anomalies
before they propagate into contracted outputs. The XSD-existence
checker doubles as the seed for Phase 0.5 layer 1, so the
verification cost is paid down by being the start of the
transition. **Cost accepted:** small per-build CPU cost; one-time
30-minute human spot-check per field at adoption.

### G. Why concordance lives in `nccs-data-efile`, not a separate repo or contract

**Beats:** standing up a `nccs-efile-concordance` repo or
publishing the concordance as its own contracted artifact now.

**Why:** current demand is producer-internal — the concordance
exists to drive the producer's extraction. No external consumer
has asked to pin against it. Externalizing prematurely commits to
a stability surface no one is currently using. Externalization is
a one-day move if a forcing function emerges later;
un-externalization is much harder. **Cost accepted:** if external
researchers want to pin against the dictionary today, they can
read the source on GitHub but cannot subscribe to a contracted
version.

### H. Why reject NODC-interim wiring for sector-in-brief

**Beats:** wiring the two dashboard panels to NODC's existing CSV
outputs at `s3://nccs-efile/` for the Phase 0 build window.

**Why:** the interim wiring would breach [[0007]]'s contracted-tier
model (NODC outputs lack manifests, parquet, form-agnostic naming),
force a cutover migration later, and couple a contracted consumer
to a non-contracted producer — the exact failure mode
`nccs-contracts` exists to prevent. The cost of deferral (~1–3
weeks of empty panels) is bounded and visible; the cost of an
interim wiring is a forced migration plus an erosion of the
contracted-tier discipline that the rest of this repo's ADR
corpus took months to establish.

## Rejected alternatives

Beyond the eight pairwise alternatives examined above, two
larger framings were considered and rejected:

1. **Stand up `nccs-data-efile` for full 0007 Phase 1+ scope before
   any sector-in-brief panel ships.** Faithful to 0007 but yields
   no contracted-consumer benefit for months. Phase 0 collapses
   that delay to 1–3 weeks for the panels that actually need it,
   without changing the long-term Phase 1+ scope.
2. **Adopt NODC's concordance and naming wholesale; don't build an
   NCCS layer 2.** Fastest path to a full producer, but locks NCCS
   into NODC's 2020-anchored naming convention and into a labor
   relationship where the NCCS maintainer continues to author
   NODC's updates as the de facto upstream. Sovereignty argument
   in §C applies.

## Migration plan

This ADR is a planning artifact. Concrete execution is downstream
in `nccs-data-efile` (to be created when Phase 0 build begins) and
in `sector-in-brief-data`. The contracts-side work here is
sequenced as follows:

1. **Amend [[0007]] in place.** Header amendment note; inline
   edits to the affected Decision bullets (phasing, concordance
   posture, license correction from MIT to ODC-By). Context,
   Coexistence, Consequences sections untouched.
2. **Rewrite `contracts/efile.yml`.** Phase 0 output shape (the
   two parquets, the `phase0/` prefix, the two semantic column
   names); the layer-1/layer-2 concordance posture; the GT-primary
   / IRS-fallback upstream split; the manifest fields recording the
   vendored NODC SHA. Phases 1–3 stay described as planned future
   state.
3. **Update `contracts/sector-in-brief.yml`.** Point the deferred-
   panels comment block at this ADR. Add `efile` to the upstream
   input list with a note that it activates when Phase 0 ships.
4. **No `ARCHITECTURE.md` change yet.** Phase 0 is planned, not
   executed; the system-map row for e-file remains "producer not
   yet built" until first publish.
5. **No `nccs-data-efile` repo creation yet.** Repo stands up when
   Phase 0 build work begins, per [[0007]] Follow-up #1.

## Outcome (2026-05-29)

Phase 0 executed. `nccs-data-efile` was built and published its first
vintage `v2026.05` to `s3://nccsdata/processed/efile/phase0/` (with a
`latest/` mirror) on 2026-05-29, producer git SHA `0a7048d`. Realized
against the plan:

- **Decision §1 (vertical slice):** shipped as two single-metric flat
  tables, each filtered to its applicable form — `government_grants`
  (990, 1,412,695 rows) and `program_related_investments` (990PF,
  526,807 rows), tax years 2020-2024. Per-filing grain as specified.
- **Decision §2 (vendored NODC + verification):** NODC SHA
  `49f62af015ad56c4857273eff633166ba6c1a4da` pinned and mirrored to
  `processed/efile/concordance/`; manifest records it under
  `inputs.nodc_concordance_sha`. The realized manifest field names
  diverge from the §2 sketch (`nodc_concordance_s3_prefix`,
  `gt_lake_snapshot_timestamp_utc`, nested `xsd_verification.passed`,
  `value_distribution`) — `contracts/efile.yml` documents the as-built
  shape.
- **Decision §4 (GT primary):** GT data lake used as upstream; IRS
  XSDs mirrored to `processed/efile/schemas/{tax_year}/` for the
  existence check. 2024 v5.1/v5.2 XSDs were unavailable from TEOS and
  aliased to v5.0 (recorded in `manifest.xsd_verification.aliases`).
- **`ARCHITECTURE.md` flipped** the e-file row from "producer not yet
  built" to LIVE (Phase 0) — the trigger condition (first vintage
  published) in Migration plan step 4 is now met.

Open at execution (tracked in `contracts/efile.yml` Open items, not
reopening this ADR): the §2.3 IRS-instruction spot-check is not yet
finalized (dictionaries still carry "(CONFIRM PAGE)"); value-range
gates passed despite a >1e10 government_grants max and negative
minimums; and `xsd_verification.passed` is true alongside ~60
`found:false` mismatch rows that target bare-element XPath variants
rather than the `...Amt` leaves actually extracted.

Phase 0.5 (NCCS-owned two-layer concordance, §3) is **executed**
(2026-06-09 — see the subsection below); Phase 1+ remains planned.
Decision §5's sector-in-brief panels (`gov_grants`, `pf_pri`) are not
yet built — the upstream blocker is now cleared.

### v2026.06 — perf-only re-extract + population-wide gate (2026-06-09)

The current published vintage is now **`v2026.06`** (producer git SHA
`22b131b`, manifest `build_timestamp_utc` 2026-06-08T20:18:00Z),
superseding v2026.05 in `phase0/latest/`. It is a **perf-only
re-extract** — namespace-aware XPath replacing `xml_ns_strip` (producer
commit `c3673ae`) — and is **behavior-preserving**: row counts
(`government_grants` 1,412,695; PRI 526,807) and per-column null rates
(0.6417 / 0.6178) are identical to v2026.05 to four decimals, confirming
the parse-cost refactor changed only cost, not extraction semantics. The
**contract surface (schema, names, grain) is unchanged**; `contracts/efile.yml`
is bumped to v2026.06 but its field set and `schema_version` are not.

**Build-time value-distribution gate method changed** (decision §2 item 2,
amended above). v2026.06 was the first vintage built under the strict
gate with thresholds pinned from v2026.05, but it was *accepted*
(producer ADR `nccs-data-efile/decisions/0002` Outcome, 2026-06-09) with
a non-blocking follow-up: the gate evaluated min/max on a stratified
sample (which cannot bound order statistics), and the configured bands
were too tight for the verified-real tail. That follow-up landed in
producer **PR #5** (commit `a3dcdde`): min/max are now evaluated over the
**full population**, the bands were widened (`government_grants`
[-1e8, 5e10]; `program_related_investments_total` [-1e8, 1e10]), the
null-rate check stays on the sample, and heavy-tail diagnostics (order-
statistic ladder + Pareto tail-mass shares) were added. This is a
producer-code change effective from the **next rebuild** — v2026.06's
*published* manifest (SHA `22b131b`) predates PR #5 and still carries the
sample-based `value_distribution` block.

This resolves two items left open at v2026.05 execution (above): the
">1e10 `government_grants` max and negative minimums" were investigated
against source XML and **accepted as real-as-filed** (Battelle-class
federal-lab grants; contribution clawbacks/restatements), with the bands
widened accordingly; and the §2.3 IRS-instruction spot-check was
**finalized 2026-05-29** (producer ADR 0002 gate-5 record — citations
landed, "(CONFIRM PAGE)" placeholders removed). The `found:false`
`xsd_verification` rows are the expected dead XPath variants (one variant
per (field, year, version) resolves — the pass condition), not a defect.

### Phase 0.5 — two-layer concordance (executed 2026-06-09)

The §3 transition to an NCCS-owned, XSD-driven concordance shipped (producer
PRs #6 / #7 / #8 / #9 / #11). Authoritative build record:
`nccs-data-efile/decisions/0003-two-layer-concordance.md`.

- **Layer 1 — mechanical XSD inventory.** `build_xsd_inventory()` enumerates
  every element per `(tax_year, version)` from the in-scope form roots
  (990 + 990PF + ReturnHeader), never hand-edited, published to
  `s3://nccsdata/processed/efile/concordance/layer1/{date}/` + `latest/`
  (23,699 rows over 16 cells). Producer-internal — **not** a contract surface,
  per §3.
- **Layer 2 — curated dictionary, now the single source of truth.**
  `inst/concordance/nccs_dictionary.csv` drives schema verification directly;
  the parallel hand-maintained `phase0_claims` list was retired. The gate
  (`verify_dictionary_against_inventory`) checks each claim resolves to a leaf
  with a type-class-consistent XSD type — 34/34 verify, 0 mismatches (down from
  the ~80 dead-variant rows of the old per-claim re-walk). The manifest's
  `xsd_verification` **shape is unchanged** — no contract change.
- **NODC demoted to a comparison artifact.** `compare_dictionary_to_nodc()` is
  an informational, non-blocking diff of Layer 2 against the full NODC
  concordance; NODC stays vendored at a pinned SHA for provenance +
  `drift_check`. This fulfils §3's end-state: correctness now rests on NCCS's
  own checks against the IRS XSDs (Layer 1), not on trusting NODC.

**Deferred (tracked in producer ADR 0003 Open items, not reopened here):** widen
the inventory roots to schedules / 990EZ before Layer 2 claims fields on them
(Phase 1+); enforce the type-class check for non-numeric `data_type`s; and
republish Layer 1 to S3 to include the `2023v6.0` cell added after the last
publish (a freshness fix — the build's gate rebuilds the inventory and is
unaffected).

## Consequences

**Positive:**

- The two sector-in-brief panels get a credible, contracted-tier
  path to ship.
- NCCS's naming sovereignty is established from the first column
  rather than retrofitted later.
- The hardest concordance work (cross-version XPath survival from
  XSDs) is front-loaded on the smallest possible field set; the
  Phase 0 XSD-existence checker is the seed for Phase 0.5 layer 1.
- The NODC dependency window is bounded and explicitly transitional,
  with a credible exit path rather than an aspiration.
- The labor the maintainer currently does on NODC's concordance
  redirects into an NCCS-owned artifact at no increase in
  recurring effort.
- The two-catalog framing from [[0007]] becomes a sharper story
  once Phase 1+ ships: NODC (researcher catalog, 2020-anchored
  names, no own review process) vs. NCCS (general-purpose, form-
  agnostic names, XSD-derived layer 1, reviewed layer 2).

**Negative:**

- Two known-empty dashboard panels for the Phase 0 build window
  (~1–3 weeks, visible to dashboard users).
- Phase 0.5 is real engineering work. The estimate of 4–8 weeks is
  rough; the actual number depends on how much of the cross-version
  XPath survival map needs human judgment vs. clean heuristics, and
  cannot be pinned until layer 1 is built and discrepancies
  quantified.
- An additional ADR in the chain (0007 → 0017 → producer-repo
  ADRs) for future readers to traverse. Mitigated by 0007's header
  amendment pointing forward.
- The trust-verification machinery adds a small per-build cost and
  a one-time human cost per field; both are bounded but non-zero.
- The maintenance of layer 2 (the NCCS semantic dictionary) is the
  same kind of curation labor as updating NODC's concordance —
  smaller in size but not eliminated. The argument is that the
  labor is redirected to an NCCS-owned artifact, not that it
  disappears.

## Deprecation window

Not applicable. No contracted artifact is being replaced or
removed; this ADR introduces a new producer output.

## Follow-up

1. **`nccs-data-efile/decisions/0001`** (in the producer repo when
   it lands): producer-internal design — XSD walker implementation,
   exact layer-2 CSV schema, exact value-distribution thresholds,
   IRS-direct fallback adapter implementation. Out of scope here
   per [[0007]] Follow-up #2.
2. **Pin XPath selectors against IRS XSDs** during Phase 0
   implementation, for both target fields, across tax years 2020+
   and all in-year sub-versions. Spot-check against NODC's
   `versions` column for parity (where they disagree, NCCS's
   XSD-derived claim is canonical).
3. **Sector-in-brief data-dictionary update.** When the two panels
   wire in, `data_dictionary.parquet` in `sector-in-brief-data`
   gains rows for `Total Government Grants` and `Total PRI`;
   confirm those rows are present in the panel-builder output, not
   hand-added.
4. **Drift-detection for Phase 0** under [[0004]]. Two cron events:
   (a) NODC concordance drift (compare master against pinned SHA;
   open issue on diff); (b) sector-in-brief input publish-event
   (Phase 0 vintage triggers sector-in-brief rebuild).
5. **Phase 0.5 effort recalibration.** After Phase 0 ships and the
   narrow XSD checker is built, re-estimate the layer 1 build cost
   against the actual XSD complexity observed. The 4–8 week
   estimate is a placeholder.
6. **Long-term: graduate the concordance to its own contract?**
   Currently producer-internal. If external consumers begin pinning
   against it directly, promote to a contracted artifact with its
   own YAML and (if usage warrants) its own repo. No defined
   trigger; sole-maintainer judgment.
