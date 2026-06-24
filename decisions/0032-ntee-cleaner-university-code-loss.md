# 0032 — Correct NTEE Cleaning So `nteev2_subsector = UNI` Holds Actual Universities

- **Status:** Accepted (partially executed 2026-06-17) — measurement done, producer fix shipped in `nccs-data-bmf` (PR #23), `latest` republished as a **current-vintage-only** reprocess (legacy 1989–2022 deferred), and contracts reconciled against the published parquet. `UNI`/`HOS` corrected; `nteev2_code` `Z99` share still elevated (58.2%, vs ~30.7% full-fix target) pending the legacy batch. See Outcome.
- **Date:** 2026-06-16
- **Deciders:** sole maintainer; BMF data owner
- **Related:** [[0021-canonical-county-identity-via-fips-crosswalk]] (same consumer-investigation → producer-defect pattern), [[0009-sector-in-brief-dashboard-hygiene]], [[0016-no-canonical-cross-dataset-merge]], [[0010-sector-in-brief-data-replaces-dataexplorer-data]], [[0022-cross-repo-contract-change-guard]], [[0008-modernize-dataexplorer-api]], [[bmf-master-geocoded]], [[bmf-lookups]], [[nccsdata]], [[sector-in-brief]]

## Context

A consumer investigation — a dashboard user pulling Form 990 financials for
Pennsylvania universities — surfaced two stacked, independent producer-side
data-quality defects in the BMF NTEE transform, amplified by a downstream
dashboard UX problem. This is the same shape as
[[0021-canonical-county-identity-via-fips-crosswalk]]: a dashboard
over/under-count whose root cause is a **producer-side classification defect,
not the API**.

Filtering PA + "Universities" + 501(c)(3) returned **~387 rows** (vs. ~180
expected institutions), and **Carnegie Mellon (EIN 25-0969449) was missing**
despite being present in CORE. Running the real `transform_ntee_code()`
(`nccs-data-bmf` `R/transform_ntee_code.R`) on synthetic rows reproduces the
investigation byte-for-byte:

| org | `NTEE_CD` raw | `ntee_code_clean` | `nteev2_subsector` | `nteev2` |
|---|---|---|---|---|
| UPenn | `B430` (B43 = University) | `INVALID` | `EDU` | `EDU-Z99-RG` |
| Temple | `B430` | `INVALID` | `EDU` | `EDU-Z99-RG` |
| Lafayette | `B420` (B42 = Undergrad College) | `INVALID` | `EDU` | `EDU-Z99-RG` |
| CMU | _null_ (no IRS NTEE) | `INVALID` | `UNU` | `UNU-Z99-RG` |

`B43` ("University or Technological Institute") **is** a valid code in the
643-row `ntee_code` lookup ([[bmf-lookups]]). The cleaner still discards it.

### Root cause — two independent defects, the second structural

Two separate `data.table::fcase` blocks mishandle the `Bxy0` form (letter +
2-digit subgroup + trailing `0`), and the second makes the defect **structural**
rather than incidental:

1. **Clean-code mangle** (`transform_ntee_code.R:233`). A 4-char code ending in
   a digit is sent to `paste0(.first, .last, "0")`. For `B430` that keeps chars
   1 and 4 → `B00` (the `43` is discarded) → not in the lookup → stamped
   `INVALID` (`:238`). The sibling branch where `.last` is a *letter* (`:232`)
   correctly does `substr(1, 3)`; the digit branch does not. That **positional
   asymmetry** is the bug.

2. **Unreachable subsector codes** (`:26`, `:349`–`:357`). `nteev2_code` is
   derived **independently** of `ntee_code_clean`, from `.int23` (chars 2–3) and
   `.last` (char 4), and the formula `paste0(.first, .last, "0")` can only ever
   emit a code ending in `0`. So `B41`/`B42`/`B43` in the university set
   `c("B40","B41","B42","B43","B50")` **can never be produced by any input** —
   the true university NTEE codes are literally unreachable. `UNI` therefore
   collects only junk edge codes (`Bxx4`/`Bxx5` with chars 2–3 ≤ 19), which is
   why PA `UNI` holds 26 orgs that are foundations / booster clubs / PTOs, not
   the schools.

**Fixing only defect #1 would not fix the subsector** — `nteev2_code` would
still resolve to `Z99` and the subsector to `EDU`. Both blocks must change
together, and the subsector must be derived from the lookup-validated cleaned
code, not the parallel `nteev2_code` formula.

CMU is a **third, separate matter**: a genuine upstream gap — no IRS NTEE on
record → `UNU`. It is not fixable in the cleaner (there is nothing to clean) and
is out of scope for the structural fix; tracked as a follow-up handling note,
not part of this decision.

### Why this belongs in the contract repo

`nteev2_subsector` / `nteev2_subsector_definition` are a producer→consumer
contract surface:

- **Producer:** `UrbanInstitute/nccs-data-bmf` — `R/transform_ntee_code.R`
  (the legacy pipeline shares the same transform).
- **Carried by:** [[bmf-master-geocoded]] (and the lookup universe in
  [[bmf-lookups]]).
- **Consumers:** [[nccsdata]] bundles the column; `sector-in-brief-api`
  faithfully passes the subsector through (it only relabels: `UNU`/unmapped/NULL
  → "Other", `EDU` → "…(minus Universities)"). **The API is correct; the values
  it is handed are wrong** — per [[0008-modernize-dataexplorer-api]] the API is a
  pass-through of producer classifications.
- **Downstream UX:** the [[sector-in-brief]] dashboard exposes a "Universities"
  filter that holds no universities — see [[0009-sector-in-brief-dashboard-hygiene]].

A fix reclassifies a meaningful slice of ~1.9M records on a **published
column**, so it must be planned here before it ships downstream and reconciled
via the [[0022-cross-repo-contract-change-guard]] guard (`contracts-guard.yml`
already fires on `R/transform_*`-adjacent changes in the BMF repo).

## Decision (proposed)

1. **Correct the 4-char clean-code rule** so `Bxy0`-style codes resolve to their
   valid 3-char NTEE-CC code (e.g. `B430` → `B43`) instead of mangling to `B00`
   → `INVALID`. Remove the positional asymmetry between the letter-suffix and
   digit-suffix branches (`transform_ntee_code.R:232`/`:233`).

2. **Derive `nteev2_subsector` from the lookup-validated cleaned code**, not
   from the parallel `nteev2_code` formula. This makes the university set
   (`B40`–`B43`, `B50`) reachable, which #1 alone does not achieve. Eliminate or
   subordinate the independent `nteev2_code` derivation (`:26`, `:349`–`:357`)
   so there is a single source of truth: raw → cleaned-and-validated → subsector.

3. **Treat CMU-style null-NTEE orgs as a known gap, not a cleaner case.** They
   remain `UNU` (no code to validate); whether they warrant separate handling is
   a follow-up note, not part of this fix.

4. **Resolve INVALID/UNDEFINED to `UNU` (adopted 2026-06-16).** A row whose
   `ntee_code_clean` is `INVALID`/`UNDEFINED` must resolve to `UNU` ("unknown"),
   **not** inherit a real subsector from its raw first letter. If we could not
   validate a code, inferring `EDU` from a leading `B` is a fabricated
   classification. The measurement found **12,667** such rows previously
   mislabeled this way (4,885 `EDU`, 4,179 `HMS`, 1,679 `HEL`, 788 `PSB`,
   725 `ART`, …); they now fold into `UNU`. This is the correct policy and is
   implemented alongside #1–#3 (the prior "defer" stance is superseded).

### Open question to resolve first (cheapest decisive measurement)

> **RESOLVED 2026-06-16.** Measured over the full `2026-06-BMF.csv`
> (1,966,267 rows; `scripts/measure_ntee_fix_blast_radius.R`). Confirmed the
> 4-char layout is `[letter][2-digit subgroup at chars 2–3][trailing modifier
> at char 4]` (modifier usually a letter `Z` or `0`) — i.e. the inverse of what
> the old code assumed — and it is uniform enough that `substr(1,3)` is the
> correct rule. Blast radius: **+39,390** rows recovered `INVALID→valid` against
> **58** malformed-junk codes correctly invalidated; `UNI` 603→**3,589**, `HOS`
> 525→**5,621**; `nteev2_code == Z99` 69.4%→**30.7%**. The rule below is now
> locked; see Outcome.

**Instrument before committing to the exact rule.** Validate the 4-char-format
hypothesis against a real BMF: confirm that for 4-char `NTEE_CD` values the
meaningful subgroup sits at **chars 2–3 with a trailing modifier at char 4**
(not the inverse the current code assumes), and **quantify how many records
flip** under the proposed rule. The fix is an experiment (per the engineering
principles): we predict that correcting #1+#2 moves the PA `UNI` count from ~26
junk orgs toward the ~180 true institutions and drops the spurious `EDU`
over-count — measure the actual record delta across the full ~1.9M universe
before locking the rule. If the 4-char layout is not uniform (some vintages or
some `B`-subtrees encode the modifier differently), the rule must handle that
variation rather than assume one form.

This open question is **load-bearing**: the exact cleaning rule is deliberately
not specified beyond "resolve `Bxy0` to its valid 3-char code" until the
measurement confirms the format and the blast radius.

## Invariants (to assert once the fix lands)

- **Validity preservation.** Every raw `NTEE_CD` whose leading 3 chars are a
  valid `ntee_code` lookup key produces a non-`INVALID` `ntee_code_clean`. No
  valid code is discarded by the trailing-modifier handling.
- **Subsector reachability.** Every code in the university set
  (`B40`,`B41`,`B42`,`B43`,`B50`) is *producible* by some input — the subsector
  is derived from the validated cleaned code, so no member of the set is
  structurally unreachable.
- **Single derivation path.** `nteev2_subsector` is a function of
  `ntee_code_clean`; there is no parallel formula that can disagree with the
  lookup-validated code.
- **Null-NTEE orgs stay enumerable.** Orgs with no IRS NTEE (e.g. CMU) resolve
  to `UNU`/unmapped, not silently into a populated subsector.

## Rejected / deferred alternatives

- **Fix only the clean-code mangle (#1).** Insufficient — `nteev2_code` is
  derived independently, so the subsector would still resolve to `EDU`/`Z99`.
  Rejected as a complete fix; it is one of two required changes.
- **Patch the subsector at the consumer / in the API.** The API is a faithful
  pass-through ([[0008-modernize-dataexplorer-api]]); patching there would fork
  the classification away from the producer and violate
  [[0016-no-canonical-cross-dataset-merge]] (no consumer-side canonical
  reclassification). The defect is at the producer; fix it once at the source.
- **Hand-curate the university list.** Brittle and unmaintainable; reopens with
  every new institution. The lookup already contains the correct codes — the
  job is to stop discarding them, not to maintain a parallel list. Rejected.
- **Handle CMU-style null-NTEE orgs in this ADR.** Deferred — a genuine upstream
  data gap, separable from the structural cleaner bug; tracked as a follow-up.

## Consequences

- **A published column's values change for a meaningful record slice.**
  `nteev2_subsector` / `nteev2` shift for affected `B`-subtree orgs (and any
  other subtree the measurement shows is affected by the same `Bxy0`
  mishandling). This is a **value change on an existing column**, so it runs
  through the [[0022-cross-repo-contract-change-guard]] guard and a deprecation
  window (default 90 days) applies for consumers that pinned behavior on the old
  values.
- **Consumers inherit the fix on republish.** [[nccsdata]] and
  `sector-in-brief-api` need no code change — they carry/relabel the subsector
  as-is — but their *outputs* change once BMF republishes. Coordinate the
  republish vintage with downstream consumers.
- **The dashboard "Universities" filter becomes meaningful.** Once republished,
  `UNI` holds actual universities; the [[sector-in-brief]] dashboard fix
  (Follow-up) can then expose the filter honestly.
- **One source of truth for subsector.** Collapsing the parallel `nteev2_code`
  derivation removes a latent class of "two formulas disagree" bugs.

## Deprecation window

**Decided (2026-06-16): immediate cutover — overwrite `latest` in place, no
90-day window for this change.** The old `UNI`/`EDU` values are *wrong* (no real
university ever reached `UNI`), so preserving them for a window has negative
value — it would prolong a known-incorrect classification. The corrected build
overwrites the existing unversioned [[bmf-master-geocoded]]/[[bmf-master]]
`latest` paths directly; no versioned-subdir machinery is introduced here (that
remains the separate `bmf-master` Open item #2). Consumers ([[nccsdata]],
`sector-in-brief-api`) inherit the corrected values on the next republish.

The general default for a value-change *is* a 90-day window; skipping it here is
a deliberate exception justified by "the old values are a bug, not a contract."
[[0033-deprecation-window-policy-and-critical-bug-override]] formalizes this
override mechanism — a programmer may shorten or waive the window for a critical
correctness/data-corruption/security defect, recording the harm and the chosen
window (here: zero) — so this exception is not treated as the new default. This
change is the first invocation of that override. Consumers that aggregate on `nteev2_subsector`
(the dashboard "Universities" cut, any `EDU`/subsector roll-up) are notified that
`UNI`/`EDU`/`UNU` membership shifts at the cutover, effective immediately.

## Outcome

### Shipped (in `nccs-data-bmf`, 2026-06-16 — code only, not yet republished)

The locked rule, implemented in `R/transform_ntee_code.R` (commits carry an
`ADR 0032` breadcrumb):

1. **Clean-code:** both `.len == 4` branches collapse to `substr(1, 3)` — the
   positional asymmetry is gone. `B430 → B43`.
2. **`nteev2_code` rebuild:** middle component = the cleaned, lookup-validated
   NTEE-CC code; `Z99` only when invalid/undefined. (The old `.int23`-based
   formula is deleted — single source of truth, per the Invariants.)
3. **Subsector:** `UNI`/`HOS` key off `ntee_code_clean`, not the derived code.
4. **INVALID/UNDEFINED → `UNU`** (Decision 4, adopted): unvalidated codes no
   longer inherit a subsector from the raw first letter.

Verified by re-running the **real edited transform** over all 1,966,267 rows:
`UNI=3,589`, `HOS=5,621`, `Z99=30.7%`, and `UNU` 590,238 → **602,905** (+12,667
from the INVALID→UNU policy; `EDU` −4,885, `HMS` −4,179, …) — matches the
measurement projection exactly. Of the 3,589 orgs with a genuine university
code, **0 reached `UNI` before** (all in `EDU`). Regression guard
`scripts/check_ntee_university_coverage.R` added and passing (incl. an
INVALID→`UNU` fixture); it also asserts the Invariants.

### Republished (master `latest`)

- **Republish = overwrite `latest` in place** (Deprecation-window decision),
  rebuilt off the **newest raw BMF vintage** — scope is current-vintage
  reprocess → master refresh; the full legacy reprocess (1989–2022) is deferred
  to a follow-up batch.
- **`nccs-data-bmf` PR** — shipped (PR #23, merged); ADR 0022 guard fired on
  `R/transform_*` (`contracts-guard` green).
- **Published-artifact verification** (against the live `bmf-master-geocoded`
  parquet, published 2026-06-17 — the producer emits no `_manifest.json`, so
  provenance is the object's own digest): `nteev2_subsector` — UNI 4,189, HOS
  7,199, EDU 396,552, UNU 700,405; `nteev2_code` `Z99` share 58.2% (down from
  69.4%, not yet at the ~30.7% full-fix target — legacy 1989–2022 reprocess
  deferred). Provenance: sha256
  `82aec1278ff35a6da4abd12baa590d661390d93e1f040f9534d99f99dfdf9208`, row_count
  3,687,435, built_at `2026-06-17T17:43:38Z` (S3 `LastModified`). The
  immediate-cutover deprecation window (ADR 0033 override) starts at this
  republish. Manifest emission tracked as [[bmf-master-geocoded]] Open item #1.

### Diverged

- The INVALID→`UNU` policy (Decision 4) was promoted from deferred to adopted
  during implementation, after the measurement showed the `nteev2_code` defect
  dominated; shipped in the same PR rather than split out.

## Follow-up

1. ~~**Run the open measurement.**~~ **Done 2026-06-16** — see the RESOLVED note
   and Outcome. Confirmed format + blast radius before the rule was locked.
2. **Done 2026-06-16** (this reconcile) — [[bmf-master-geocoded]] records the
   corrected `nteev2_subsector`/`nteev2_code` semantics + the immediate-cutover
   window. [[bmf-lookups]] needs **no change**: the `ntee_code` lookup itself was
   never wrong — the transform discarded valid codes — so the lookup universe is
   unchanged. `ARCHITECTURE.md` unchanged (no producer-pattern or contract-shape
   change; values shifted within an existing column).
3. **Dashboard-side fix** — do not offer a "Universities" filter backed by an
   empty/garbage subsector; tracked against [[0009-sector-in-brief-dashboard-hygiene]].
4. **CMU-style null-NTEE orgs** — decide whether orgs with no IRS NTEE warrant a
   separate handling note (a distinct matter from the structural cleaner bug).
