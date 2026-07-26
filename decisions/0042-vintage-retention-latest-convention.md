# 0042 - Vintage Retention + latest/ Convention for Rolling Artifacts; Address-History Table Shape; Docs Automation

- **Status:** Accepted (2026-07-25; both decision points resolved by maintainer, see below)
- **Date:** 2026-07-25
- **Deciders:** sole maintainer
- **Related:** [[0013-versioned-producer-outputs]] (the deferral this partially un-defers), [[0037-master-bmf-rename-unified-supersession-provenance]] + [[0039-unified-bmf-geocoded-extension-rename]] (rolling INTERIM-flat publishes this versions), [[0041-legacy-street-recovery-address-resolved-crosswalk]] (§4 amended here), [[0014]] (manifest shape), [[0006]] (archive discipline), [[0034]] (ntee-resolved precedent)

## Context

Three triggers, arriving together on 2026-07-24/25:

1. **The maintainer's working assumption ("all latest datasets live under
   latest/ folders so links always point to the latest data") is false.**
   Actual state is two coexisting conventions: (a) vintage dirs plus a
   latest/ mirror for `lookups/bmf/`, `processed/efile/phase0/`, and
   `sector-in-brief/`; (b) flat rolling artifacts overwritten in place,
   vintage carried only in the ADR 0014 manifest, for the Unified BMF,
   its geocoded extension, and every crosswalk. Convention (b) does keep
   URLs stable (the flat path always serves the newest build), but it
   retains **no prior builds at all**: full-lineage retention currently
   does not exist for these artifacts. ADR 0013 deferred versioning for
   exactly these; the maintainer now requires lineage ("all vintages ...
   are never deleted"), which un-defers it.
2. **A live consumer breakage proves the stakes.** An external data team
   (Capital One) reported access-denied on `BMF_UNIFIED_V1.1.csv` since
   June 2026: the v1.1 family was moved to the private
   `nccs-data-archive/superseded/bmf-unified-v1.1/` on 2026-05-15, and an
   unknown consumer with a pinned URL broke with no notice. Stable
   latest/ URLs plus retained vintages are the structural mitigation for
   unknown consumers we cannot notify.
3. **ADR 0041 §4's address-table shape needs amending** to match the
   maintainer's requirement of a current-plus-prior address log, and the
   maintainer requested automatic refresh of data-processing guides on
   dataset changes.

## Decision

**1. Vintage retention + latest/ for the rolling artifacts.** The Unified
BMF (`unified/bmf/`), the geocoded Unified BMF
(`geocoding/unified-bmf/merged/`), and the per-EIN metadata tables
(`crosswalks/ntee-resolved/`, `crosswalks/address-resolved/`) adopt, at
their next publish:

- `.../v{YYYY_MM}/` per-build vintage folders, retained permanently
  (never deleted; extends the [[0006]]/[[0037]] never-delete doctrine
  from superseded *paths* to every *build*).
- `.../latest/` holding a full copy of the newest build; all
  consumer-facing links (website, package defaults, docs) point at
  latest/ so they are permanently stable AND current.
- Existing flat keys remain live as deprecated aliases for one standard
  90-day window ([[0033]]) after the first versioned publish, then
  archive per [[0006]].
- **DECISION A (resolved 2026-07-25): vintage folders retain parquet
  only.** latest/ always carries both parquet and CSV. (The rejected
  alternative, CSV in every vintage, would add roughly 40 GB per year
  for the geocoded artifact alone.)

**2. Address-history table shape (amends [[0041]] §4).** The
address-resolved table is a per-spell **long-format log**: one row per
(EIN, address spell), ordered by recency:

- Key: `EIN2`, with `ein` and `ein_prefixed` alongside ([[0036]]).
- `spell_rank` (0 = current/most recent, 1 = immediately prior, ...),
  `street`, `city`, `state`, `zip`, `first_vintage`, `last_vintage`,
  `n_vintages`, `source` (current/legacy), plus per-EIN
  `n_distinct_addresses`.
- Published as parquet + CSV + ADR 0014 manifest under
  `crosswalks/address-resolved/` with the §1 vintage/latest layout, plus
  an **HTML quality report** in the style of the BMF vintages.
  Supersedes the ad-hoc 2024 `meta/metadata-address*` tables.
- **DECISION B (resolved 2026-07-25): long format ratified.** The wide
  repeating-column-set sketch is rejected: spells per EIN are unbounded,
  so wide is ragged and schema-unstable; wide views are pivot-derivable
  from long in one line.

**3. Docs automation (machinery note, no contract surface).** Producer
repos add a CI workflow rendering their Quarto guidebook on merge to
main (nccs-data-bmf first), so dataset-affecting merges refresh the
processing guides without a manual render step.

**4. Validation gate (recording the maintainer's non-negotiable).** Any
re-published or newly published dataset must pass a source-vs-output
diff: identical row counts, exactly-unchanged non-null profiles on all
columns not intentionally changed, and no unintended recodes. The
ADR 0041 legacy re-publish is the first artifact held to this gate.

## Consequences

- Stable consumer URLs (latest/) plus complete build lineage, at modest
  storage cost (parquet-only vintages: under 10 GB per year across all
  four artifacts).
- Unknown consumers stop breaking silently on supersession; known ones
  get the standard window.
- One-time consumer migration: repoint `nccsdata::nccs_read()` and the
  website at latest/ paths (folds into the existing ADR 0039 follow-ups).
- The nccs website catalog manifests need regeneration after the first
  versioned publish (already queued as the ADR 0041 S6 website PR).

## Deprecation window

Standard 90 days ([[0033]]) for the flat-key aliases after each
artifact's first versioned publish. Nothing else moves or breaks.

## Outcome

_To be filled at reconcile: first versioned publishes with manifest
verification, decision points A/B as resolved, consumer repoints, and
the Capital One reply linking the canonical latest/ URL._
