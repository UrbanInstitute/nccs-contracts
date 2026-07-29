# 0044 — Restore Legacy ZIP Leading Zeros; Gate Destructive Transforms

- **Status:** Proposed
- **Date:** 2026-07-28
- **Deciders:** sole maintainer
- **Related:** [[0041-legacy-street-recovery-address-resolved-crosswalk]] (the campaign that missed this defect; the address-resolved crosswalk it damages), [[0042-vintage-retention-latest-convention]] (versioned re-publish paths the rebuild uses), [[0022]] (contracts guard), [[0014]] (manifest shape), Backlog Z1 (rebuild campaign this ADR unblocks)

## Context

Review of `nccs-data-bmf#32` (2026-07-28) surfaced a second ZIP defect the
ADR 0041 campaign missed. Legacy raw BMF files went through a numeric
round-trip upstream that stripped leading zeros, so a Boston ZIP arrives as
`2138` instead of `02138`. `.clean_zip()` extracts `^\d{5}`, which cannot
match a 4-digit string, and returned NA instead of padding.

Damage, all verified against live artifacts:

- **848,048 published address-log rows** carry a 3-4 character `zip5` that
  joins to nothing. **147,994 of them are phantom duplicates**: the address
  log records one row (a "spell") per continuous period an organization
  spends at an address, and because the legacy copy of an address lost its
  ZIP while the current copy kept it, the same real address shows up as two
  different spells instead of one.
- The same mechanism shows up in the cross-source match rate. A spell is
  *cross-source* when the same organization-plus-address is observed in
  both the legacy vintages and the current monthly BMF, which is the normal
  case for any long-lived organization that never moved. Nationally 15.8%
  of spells are cross-source; ME/NH/VT/MA/RI/CT/NJ/PR/VI show **0.00%**.
  A true rate of zero would mean every nonprofit in nine states changed
  address when the data source changed, which is impossible: it is the
  ZIP mismatch breaking every legacy-to-current match, and it makes the
  address history in those states show fake 2023 "moves".
- `org_addr_zip5`, `org_addr_zip`, and `org_addr_full` are empty for legacy
  rows in those states across **all 55 legacy vintages**, in the processed
  CSVs, the Unified BMF, and the state marts.
- **~124k organizations were geocoded with no ZIP** in the address string.

Why nothing caught it: the defect is stratified (whole states at 100% while
the national completeness figure barely moves), and the one metric that
would have flagged it, `generate_quality_report()`'s `report$passed`, is
computed and **never read by either pipeline**. `STRICT_QUALITY_GATES` only
ever bound the pre-checks (gating `report$passed` is Backlog Z9, kept
separate because flipping it on needs a dry run across the 55 vintages).

## Decision

**1. Fix (producer, branch `fix/legacy-zip-leading-zeros`).** In
`.clean_zip()`, repair by digit count before the `^\d{5}` extraction
(amended 2026-07-29, PR #40 review):

- **3-4 digits: pad to 5.** A US ZIP has at most two leading zeros (00501
  is the lowest in use), so a 1-2 digit value cannot be a stripped ZIP and
  is left to fail rather than be invented into a plausible-looking one.
- **8 digits: pad to 9.** An 8-digit undashed value can only be a ZIP+4
  that lost its leading zero (`02138-1234` stored as `21381234`). Without
  this pad the extraction returned `21381`, a wrong-but-plausible ZIP5 the
  integrity gate cannot detect because a 5-digit result was produced.
- **6, 7 and 10+ digits: force NA.** No unambiguous repair exists;
  extracting a 5-digit prefix would invent a plausible wrong ZIP. The
  gate's recoverable set (3/4/5/8/9 digits must clean to a ZIP5) mirrors
  this exactly, so the deliberate NAs are not violations.

**2. Guardrail: destructive-transform gate.** Two possible designs here:
make the pipelines finally read `generate_quality_report()`'s `report$passed`
(one general gate), or add a targeted hard gate for this defect class. This
ADR chooses the **targeted gate now**, and defers the general
`report$passed` gate to Backlog Z9: flipping `report$passed` on would
likely fail legacy vintages on pre-existing critical-field nulls unrelated
to this defect, and needs a dry run across all 55 vintages first. The two
are complements, not alternatives; Z9 remains open. Concretely: new
`assert_zip_integrity()` in `R/quality/post_checks.R`, wired into **both**
pipelines before the write/upload phases and bound to
`STRICT_QUALITY_GATES`. It compares raw against cleaned row by row: a raw
value holding at least 3 digits must clean to a 5-digit ZIP, and any
violation halts the run with per-state damage counts. Verified: the gate
halts on the unfixed 2013_07 vintage with per-state counts, and passes
after the fix.

**3. Rebuild (Backlog Z1, sequenced after this ADR merges).** Re-run the 55
legacy vintages, rebuild the Unified BMF and state marts, delta re-geocode
the ~124k ZIP-less addresses, rebuild and re-publish the address log, and
re-run `validate_address_crosswalk.R` (2 checks currently fail). Publishes
under the ADR 0042 versioned-vintage convention.

## Contract impact

No schema change: no columns added, removed, or renamed. **Published column
values change** for legacy-sourced rows in the 0-prefix states:
`org_addr_zip5`/`org_addr_zip`/`org_addr_full` go from empty to populated
across processed legacy CSVs, the Unified BMF, state marts, and the
address-resolved crosswalk (where phantom spells also collapse). Geocoded
coverage may move off 82.7%; the website catalog caveat added in nccs #92
comes out after the rebuild (Z2).

## Consequences

- The Z chain (Z1-Z5) unblocks once this merges and the producer PR lands.
- The gate makes the destructive-transform failure class (populated input
  cleaned to NA) a hard stop instead of a silent completeness dip.
- Consumers of the damaged states get real address history back; anyone who
  cached the 848k broken address-log rows sees them corrected in the next
  vintage, not mutated in place (ADR 0042 retention).

## Outcome

_To be filled at reconcile: rebuild counts, gate results across the 55
vintages, coverage delta, address-log spell correction counts._
