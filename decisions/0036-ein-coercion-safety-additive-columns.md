# 0036 — EIN Coercion-Safety via Additive Columns (`ein_prefixed` + `EIN2`; canonical `ein` unchanged)

- **Status:** Reconciled (partial, 2026-07-01) — see Outcome; Executing (nccs-data-core PR #11 merge + CORE-tier contract reconcile pending). BMF scope is now **fully live**: the ntee-resolved crosswalk was republished 2026-06-30 (20 cols) and the Unified BMF publish landed 2026-07-01 (`ein_prefixed`/`EIN2` confirmed present in the published schema). The nccs-data-core twin is **shipped but not yet merged** — nccs-data-core PR #11 (`f94d21e`, still OPEN as of 2026-07-01), helpers verified byte-identical; CORE-tier contract reconcile follows on that merge. Convergence to a single canonical key / retirement of the dashed `ein` is **not pursued**; the four-rendering design below is the standing approach (updated 2026-06-29 — the earlier July deferral of the convergence question was dropped).
- **Date:** 2026-06-29
- **Deciders:** sole maintainer (DST), with advisory input from Jesse Lecy (taxonomy/research affiliate)
- **Related:** [[0034-ntee-resolved-crosswalk]] (**amended** — the crosswalk gains the two columns; its inline `ein` format pin is touched), [[0016-no-canonical-cross-dataset-merge]] (consumers compose joins on `ein`; these are courtesy columns, not a merge), [[0033-deprecation-window-policy-and-critical-bug-override]] (the 90-day window owed to any *future* `ein` format change), [[0007-efile-urban-owned-producer]] (the legacy/NODC `EIN2` ecosystem), [[0028-efile-wholesale-relational-extraction]] (the Urban e-file padded-9 `ein`), [[0035-retain-harmonized-core-frozen-surface]] (frozen harmonized CORE keyed on `EIN2`), [[0001-s3-as-contract-surface]], [[0022-cross-repo-contract-change-guard]] (producer reconcile), `conventions/ein-format.md` (the spec this ADR extends)

## Context

A research affiliate (Jesse Lecy) argued the dashed `ein` (`XX-XXXXXXX`) is not
*provably* safe against spreadsheet type-coercion, whereas a leading-alpha key
is. A read-only cross-repo investigation (2026-06-29) settled the facts:

1. **Dashed `ein` is externally load-bearing — it cannot be reformatted in
   place.** It is published on **five external surfaces**: anonymously-readable
   public S3 (`master/bmf/bmf_master.csv` returns HTTP 200 with no credentials,
   shipping `ein` in `XX-XXXXXXX`), the public website (which *instructs*
   researchers to "join … by `ein` (`XX-XXXXXXX`)"), the `nccsdata` package
   (vignettes `inner_join(…, by = "ein")`), the live sector-in-brief API
   (request param + response column + emailed download), and at least one CSV
   already delivered to an external requester. It has been live ~4–5 months and
   is continuously republished. A value-format or name change to `ein` would
   silently break external joins (the "absence is silent" failure mode).

2. **The earlier "ecosystem alignment" rationale was half-right and is
   corrected.** `XX-XXXXXXX` is the IRS **display/written** standard, **not** the
   data convention. In data files the ecosystem uses **no-dash 9-digit**: the IRS
   bulk EO BMF ships the EIN undashed (the dash is "optional"); ProPublica's data
   field is the 9-digit integer; our own `ein_raw` is exactly that 9-digit form.
   So dashed `ein` aligns with *display*, not *data*. (`nccs-data-bmf/docs/03-transforms-reference.qmd:56`
   records the original "align with IRS/Candid/ProPublica" decision; that holds
   only for the display sense. Candid's *data* format was not verified; GuideStar
   *displays* dashed.) The dash's real justification is **coercion-safety** —
   forcing text typing so leading zeros and CSV round-trips survive — which is
   *the same concern Jesse raised*.

3. **So the dash and an alpha prefix are two text-forcing decorations on one
   underlying 9-digit key, both for coercion-safety.** An alpha prefix is
   *strictly* safer (provably text in all cases, not just usually). Jesse's
   prefix argument is therefore technically strong; the dashed form's remaining
   claim is **incumbency** (already published on five surfaces), not external-data
   alignment.

The implication is forced: coercion-safety must be delivered **additively**, not
by mutating the live `ein`.

## Decision

**1. Keep canonical `ein` (`XX-XXXXXXX`) stable and unchanged** — not renamed,
not reformatted. It is externally load-bearing; incumbency is decisive.

**2. Add two columns** to the Unified BMF (the renamed master, [[0037-master-bmf-rename-unified-supersession-provenance]]), the new CORE tiers, and the ntee-resolved crosswalk:

- **`ein_prefixed`** — value `ein-XX-XXXXXXX` (lowercase `ein-` prefix; e.g.
  `ein-38-2787387`). The new legible, coercion-safe key. Lowercase keeps it
  snake_case / house-style; the leading alpha (`e`) is what makes it *provably*
  text. Self-documenting name.
- **`EIN2`** — value `EIN-XX-XXXXXXX` (uppercase legacy format; e.g.
  `EIN-38-2787387`). A **labeled legacy-compatibility alias** — the same key under
  the exact name and format the legacy ecosystem (harmonized CORE marts, NODC
  `efile_v2_1`, the old Unified BMF) and an affiliate's existing base-R `merge()`
  already join on. Dictionary text: *"legacy-compatibility alias; identical key to
  `ein_prefixed` in legacy `EIN-XX-XXXXXXX` format; retained for existing
  merges."*

**3. `ein_raw`** (the 9-digit source value) already exists and is unchanged.

Resulting key columns on the new products: **`ein`** (incumbent canonical,
dashed), **`ein_prefixed`** (new legible coercion-safe key), **`EIN2`**
(legacy-compat alias), **`ein_raw`** (9-digit source). All four are bijective
renderings of one 9-digit integer (`conventions/ein-format.md §7`).

**Properties.**
- **Purely additive** — adds columns; changes/removes nothing. The single
  non-additive piece is the ntee-resolved crosswalk's inline schema, which pins
  `ein`'s format (`contracts/ntee-resolved-crosswalk.yml:61`) and now gains two
  fields → this ADR **amends [[0034-ntee-resolved-crosswalk]]**.
- **Consumer bridge already exists:** `nccsdata/R/nccs_ein_bridge.R`
  (`nccs_ein_to_ein2()` / `nccs_ein2_to_ein()`, per `conventions/ein-format.md`).
  Producer-side *emission* of `ein_prefixed` / `EIN2` is **net-new** — neither
  producer writes an alpha prefix today.
- **Spec extension:** `conventions/ein-format.md` gains `ein_prefixed` as a sixth
  rendering (`→ ein_prefixed = paste0("ein-", ein)`), added at execution. The
  bijective-reformat property (§7) is preserved.

### Decided — multi-rendering is the standing design (no convergence, no migration)

The canonical key is **not** converged to a single prefixed form, and the dashed
`ein` is **not** retired. Carrying the key in four renderings — `ein` (dashed),
`ein_prefixed` (lowercase prefixed), `EIN2` (legacy format), `ein_raw` (source) —
and letting each consumer join on the one that fits is the chosen **standing
design**. Rationale: the marginal safety gain of forcing a single prefixed
canonical does not justify the **external-deprecation cost** of retiring a live,
five-surface published key; multi-rendering gives everyone a provably-safe key
(`ein_prefixed` / `EIN2`) now, with no migration and nothing broken. (This updates
the earlier plan, which deferred the convergence question to July; the EIN-format
question is settled here. A single house ID convention *across files* remains an
optional future group topic — not a committed migration, and nothing downstream
waits on it.)

## Consequences

- **External joins on `ein` stay unbroken** — the incumbent key is untouched.
- **The affiliate's base-R `merge()` works directly** against the new products via
  the `EIN2` column (exact legacy name+format).
- **Coercion-safety is available now** (`ein_prefixed` for the new house key,
  `EIN2` for legacy-format needs), without re-keying anything.
- **Four EIN renderings on the new products** — the data dictionary MUST
  disambiguate which to use: forward joins → `ein` / `ein_prefixed`; legacy merge
  → `EIN2`; provenance → `ein_raw`. Size cost is negligible: each added column is
  ~15 bytes/row (~55 MB, <2% on the 2.86 GB master CSV), and the master already
  exceeds Excel's row limit so Excel-openability is unaffected; on the smaller
  CORE marts the extra width is still trivial.
- **Contract + API reconciles:** amends `contracts/ntee-resolved-crosswalk.yml`
  (and ADR 0034); adding `ein_prefixed`/`EIN2` to the sector-in-brief API response
  is an API-schema version bump to coordinate (ADR 0013/0022/0031). Producer
  change reconciles per [[0022-cross-repo-contract-change-guard]]; new columns flow
  into the published data dictionaries and manifests.

## Deprecation window

- **The additive columns:** not applicable — purely additive; nothing is renamed,
  moved, retyped, or removed.
- **Any *future* change to the published `ein` value-format or column name**
  (should one ever be undertaken): standard **90-day** window +
  advance consumer notice per [[0033-deprecation-window-policy-and-critical-bug-override]],
  with the old form kept reachable — recorded here as a standing requirement
  because `ein` is externally load-bearing on five surfaces.

## Outcome

Reconciled **partial, 2026-06-30** against nccs-data-bmf PR #28 (commit
`fd0b366`).

**Shipped (BMF scope, E1).**
- `ein_prefixed` (`ein-XX-XXXXXXX`) + `EIN2` (`EIN-XX-XXXXXXX`) are emitted at the
  **derive layer**, both from the **unchanged** canonical dashed `ein`:
  - **ntee-resolved crosswalk — LIVE.** Republished to
    `s3://nccsdata/crosswalks/ntee-resolved/`: 3,613,958 rows × **20 cols**, `ein`
    byte-identical, the two columns at positions 2–3. CMU `25-0969449` →
    `ein-25-0969449` / `EIN-25-0969449`. Path unchanged → fully reconciled.
  - **Unified BMF — LIVE 2026-07-01.** Columns added in the `master_bmf_builder.R`
    final SELECT (`'ein-' || ein`, `'EIN-' || ein`, the latter quoted to preserve
    the uppercase identifier); published to `s3://nccsdata/unified/bmf/` alongside
    the ADR 0037 rename (commit `11380a2`) — see that ADR's Outcome for the
    publish details (3,687,435 rows).
- **Reference formatter (N1):** `R/ein.R::ein_to_prefixed()` / `ein_to_ein2()`;
  the DuckDB SQL mirrors the exact strings with a cross-reference comment so the
  two cannot drift. `transform_ein` was **deliberately not modified** — emitting
  there would push the columns onto the monthly `processed/bmf/` artifact, out of
  scope; this is a tactical refinement, not a divergence from the Decision.
- **F1a resolved by RELABEL, not retype.** `ein_raw` stays the lossy bare-integer
  surface; its data-dictionary/docs text now describes that reality. Retyping to
  padded-9 would have changed the contracted shape (`conventions/ein-format.md` §1
  bare-integer surface, §5 `000000004 → 4` vector) → that was the escalation path;
  relabel is the in-scope, convention-consistent fix, so **no escalation fired**.

**Shipped (contracts, this reconcile).**
- `conventions/ein-format.md`: `ein_prefixed` added as the **sixth** rendering
  (§1 table, §3 conversion, §5 test vectors, §6 emission-layer note, §7 bijection
  preserved); changelog entry.
- `contracts/ntee-resolved-crosswalk.yml`: the two columns added (20 cols),
  amendment to ADR 0034 recorded. (No `manifest.schema_version` bump — that field
  is the ADR 0014 *manifest-shape* version, unchanged; the data-column addition is
  recorded structurally instead.)
- `contracts/unified-bmf.yml`: the additive columns documented in the schema block.

**Shipped (CORE scope — discovered at this reconcile).**
- The nccs-data-core twin is **executed**: PR #11 (`f94d21e`, branch
  `feat/adr-0036-ein-additive-columns`, **OPEN**). `R/transforms/ein.R` defines
  `ein_to_prefixed()` / `ein_to_ein2()` **byte-identical** to the BMF reference
  (`paste0("ein-", ein)` / `paste0("EIN-", ein)`, NA-preserving — N1 parity met,
  verified), adds the columns at the derive layer (`R/04_derive_combined.R`), and
  documents them in `R/06_dictionary.R`. It inherits the shared
  `conventions/ein-format.md` addition that landed with this BMF reconcile (no
  duplicate edit).

**Diverged or pending.**
- **CORE-tier contract reconcile pending PR #11 merge.** When nccs-data-core PR
  #11 settles, reconcile the CORE-tier contract YAML(s) (`core-990` / `core-panel`
  / etc. — confirm which tier carries the columns from `R/04_derive_combined.R`)
  the same way the crosswalk was. Separate reconcile; this BMF order does not edit
  the CORE contracts.
- **Consumer-side col docs:** the website BMF catalog still documents the
  crosswalk at 18 columns; additive, so non-breaking, but the two EIN renderings
  should be added — folded into the ADR 0036/0037 consumer notice.
- **Sector-in-brief API** response-schema bump to expose `ein_prefixed`/`EIN2`
  remains a separate coordinated change (ADR 0013/0022/0031) — not done here.
