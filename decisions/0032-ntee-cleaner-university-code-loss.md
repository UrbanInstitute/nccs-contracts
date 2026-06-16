# 0032 — Correct NTEE Cleaning So `nteev2_subsector = UNI` Holds Actual Universities

- **Status:** Accepted (planning; not yet executed) — gated on the open measurement below
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

### Open question to resolve first (cheapest decisive measurement)

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

Value change on a published column → default **90-day** window from the
corrected republish, coordinated through the [[0022-cross-repo-contract-change-guard]]
guard. Consumers that filter or aggregate on `nteev2_subsector` (notably the
dashboard's "Universities" cut and any `EDU` roll-up) should be notified that
`UNI`/`EDU` membership shifts at the cutover.

## Follow-up

1. **Run the open measurement** (above) in `nccs-data-bmf` against a real BMF;
   record the confirmed 4-char format and the record-flip count before writing
   the fix. A concrete fix proposal + implementation plan for the producer repo
   is being drafted for review before any code lands.
2. **Reconcile the contracts** ([[bmf-master-geocoded]], [[bmf-lookups]]) and
   `ARCHITECTURE.md` once the rule is fixed and the blast radius is known; record
   the corrected `nteev2_subsector` semantics and the value-change window.
3. **Dashboard-side fix** — do not offer a "Universities" filter backed by an
   empty/garbage subsector; tracked against [[0009-sector-in-brief-dashboard-hygiene]].
4. **CMU-style null-NTEE orgs** — decide whether orgs with no IRS NTEE warrant a
   separate handling note (a distinct matter from the structural cleaner bug).
