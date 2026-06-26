# Convention: EIN formats and the `ein` ↔ `EIN2` bridge

**Status:** Convention / reference spec. NOT an ADR — may be promoted to or cited by
one if/when governance formalizes ID conventions (see `decisions/` and the governance
proposal). Discretionary to adopt; documented here so the producer transform and any
consumer helper are two implementations of *one* spec, not independent logic that can
drift.

**Implementation status: IMPLEMENTED.** Producer side: `nccs-data-bmf/R/ein.R::transform_ein`
(pre-existing, unchanged). Consumer side: **shipped 2026-06-26** —
`nccsdata/R/nccs_ein_bridge.R` (`nccs_ein_to_ein2()` / `nccs_ein2_to_ein()`), merged via
[nccsdata PR #22](https://github.com/UrbanInstitute/nccsdata/pull/22). **Not gated by an
ADR:** `conventions/` is outside the `adr-required` CI scope and this convention carries no
contract version/pin — it is tracked solely by this doc, the executable nccsdata tests (§5),
and PR #22. Promote to / cite from an ADR only if governance later formalizes ID conventions.

**Scope:** the Employer Identification Number (EIN) as a join key across the NCCS data
ecosystem — the new contracted products (Master BMF, CORE, Phase-0 e-file), the legacy
/ NODC products (harmonized CORE marts, Unified BMF, NODC `efile_v2_1`), and the
consumer `nccsdata` package. This spec defines the canonical formats, the deterministic
conversions between them, validation rules, and shared test vectors.

---

## 1. The formats in the wild (all verified against live S3, 2026-06-26)

A US EIN is exactly **9 digits**. The same EIN appears in five surface renderings:

| Name | Pattern | Example | Where it appears |
|---|---|---|---|
| **`ein`** (canonical clean) | `^\d{2}-\d{7}$` | `04-2104327` | new Master BMF, new CORE, ntee-resolved crosswalk, geocoded master |
| **`EIN2`** (legacy/NODC key) | `^EIN-\d{2}-\d{7}$` | `EIN-04-2104327` | harmonized CORE marts, Unified BMF, NODC `efile_v2_1` (website e-file) |
| **padded-9** | `^\d{9}$` | `042104327` | raw legacy CORE/BMF, Phase-0 e-file `ein`, NODC `ORG_EIN` |
| **bare integer** (lossy surface) | `^\d{1,9}$` | `42104327` | Unified BMF col-2 `EIN`, Master BMF `ein_raw` — leading zeros dropped |
| **9-digit core** (internal) | `^\d{9}$` | `042104327` | not published; the normalization target below |

`ein` is the **canonical published key** for all new products. `EIN2` is the legacy
ecosystem's key (and is *Jesse Lecy / NODC's* `irs990efile` convention — the `EIN-`
prefix is literal, uppercase). `EIN2` carries no information beyond `ein`: it is exactly
`ein` with a literal `EIN-` prepended.

---

## 2. Canonical normalization (single source of truth)

Every conversion goes through one step: reduce any input to the **9-digit core**, then
emit the target format. This is the same logic as the producer's
`nccs-data-bmf/R/ein.R::transform_ein` and MUST stay consistent with it.

```
core(x):
  d <- remove all non-digit characters from x      # "EIN-04-2104327" -> "042104327"
                                                    # "42104327"       -> "42104327"
  if nchar(d) > 9:  -> INVALID (do not truncate)
  d <- left-zero-pad d to width 9                   # "42104327"       -> "042104327"
  if d does not match ^\d{9}$ or d == "000000000":  -> INVALID
  return d
```

Left-zero-padding is what makes the **bare-integer** surface recoverable: `42104327`
→ `042104327`. The pitfall is not the padding — it is a **naive string join without
padding** (an 8-char bare integer will not equal a 9-char padded key). Always normalize
both sides through `core()` before comparing or converting.

---

## 3. Conversions (deterministic; no lookup table)

Let `c = core(x)`, with `aa = c[1:2]`, `bbbbbbb = c[3:9]`.

| Function | Output | Rule |
|---|---|---|
| → `ein` | `aa-bbbbbbb` | `paste0(aa, "-", bbbbbbb)` |
| → `EIN2` | `EIN-aa-bbbbbbb` | `paste0("EIN-", aa, "-", bbbbbbb)` |
| → padded-9 | `aabbbbbbb` | `c` |

The two headline helpers `nccsdata` ships (`nccsdata/R/nccs_ein_bridge.R`, PR #22 —
both route through one internal `.ein_core()` implementing §2 exactly):

- **`nccs_ein_to_ein2(ein)`** = `paste0("EIN-", ein)` when `ein` already matches
  `^\d{2}-\d{7}$`; otherwise normalize via `core()` first. Output `EIN-aa-bbbbbbb`.
- **`nccs_ein2_to_ein(ein2)`** = strip a leading literal `EIN-`, then ensure
  `^\d{2}-\d{7}$` (normalize via `core()` if the remainder is unpadded). Output
  `aa-bbbbbbb`.

Round-trip MUST be lossless: `nccs_ein2_to_ein(nccs_ein_to_ein2(e)) == e` for every
valid `ein` `e`, and the reverse for every valid `EIN2`.

(Optional, only if you choose to expose it: `nccs_ein_to_padded9()` /
`nccs_padded9_to_ein()`. Punt unless a consumer actually needs the padded-9 form — keep
the shipped surface minimal.)

---

## 4. Validation & malformed-input behavior

- Validate **input** against its declared pattern before converting; validate **output**
  against the target pattern after. The function decides one of two contracts — pick one
  and document it in the roxygen:
  - **strict:** error on any input that fails `core()` (recommended for a pipeline join key), or
  - **lenient:** return `NA` for un-normalizable inputs (recommended for a vectorized
    consumer helper over messy real data) — but then also return a count/flag of how many
    were dropped, so silent loss is visible (Engineering-Reasoning principle 5).

  **Resolved (consumer side, 2026-06-26):** `nccsdata` chose **lenient** — un-normalizable
  input returns `NA` and the call emits a `warning()` reporting the count of non-empty
  values dropped, so silent loss stays visible (principle 5). Rationale: a vectorized
  consumer helper over messy real-world data, which is the case §4 itself recommends
  lenient for. **Strict remains the recommendation for a pipeline join key** (e.g. the
  producer transform), where an un-normalizable EIN should halt rather than vanish.
- **Reject, do not coerce:** inputs with >9 digits, all-zeros (`000000000`), or known
  placeholder rows. These are not EINs.
- **Vectorize** (the `nccsdata` use is column-wide): operate on a character vector; never
  rely on numeric typing (numeric storage is what drops the leading zeros in the first
  place — keep EINs as strings end to end).
- **Never** read the join key from the **bare-integer** surface (`ein_raw`, Unified BMF
  col-2 `EIN`) without `core()` normalization. Prefer `ein` / `EIN2` / padded-9, which
  are already 9-recoverable.

---

## 5. Reference test vectors (the shared contract)

Both implementations (producer `transform_ein`, consumer `nccs_ein_*`) MUST satisfy
these. Examples are drawn from live data so they double as provenance. Includes a
leading-zero case (the one that breaks naive joins).

| 9-digit core | `ein` | `EIN2` | padded-9 | bare integer | source seen |
|---|---|---|---|---|---|
| `042104327` | `04-2104327` | `EIN-04-2104327` | `042104327` | `42104327` | Unified BMF |
| `363686904` | `36-3686904` | `EIN-36-3686904` | `363686904` | `363686904` | NODC `efile_v2_1` HEADER |
| `382787387` | `38-2787387` | `EIN-38-2787387` | `382787387` | `382787387` | harmonized CORE mart |
| `000000004` | `00-0000004` | `EIN-00-0000004` | `000000004` | `4` | Master BMF `ein_raw` |

Round-trip assertions:
- `nccs_ein_to_ein2("04-2104327") == "EIN-04-2104327"`
- `nccs_ein2_to_ein("EIN-04-2104327") == "04-2104327"`
- `nccs_ein2_to_ein("EIN-00-0000004") == "00-0000004"`  *(leading zeros preserved)*
- `nccs_ein_to_ein2(nccs_ein2_to_ein("EIN-36-3686904")) == "EIN-36-3686904"`
- malformed: `nccs_ein2_to_ein("EIN-4")` → normalizes to `00-0000004` *(strict)* or the
  declared NA behavior *(lenient)* — pick one and test it. *(Consumer resolved lenient:
  un-normalizable → `NA` + warning.)*

**Now mechanically enforced.** These vectors are encoded as executable tests in
`nccsdata/tests/testthat/test-nccs_ein_bridge.R` — all four contract rows plus round-trip,
leading-zero, bare-integer, and reject cases; suite green as of PR #22. That test file is
what now mechanically guards the consumer impl against drift from this spec: if the §5
vectors change, those tests must change with them (and the producer's `transform_ein`
should be checked against the same rows).

---

## 6. Implementations (one spec, two impls)

- **Producer (definition of `ein`):** `nccs-data-bmf/R/ein.R::transform_ein`
  (strip non-digits → zfill 9 → dash after position 2). The canonical `ein` published by
  every new product is produced here.
- **Consumer (shipped 2026-06-26):** `nccsdata/R/nccs_ein_bridge.R` exports
  `nccs_ein_to_ein2()` / `nccs_ein2_to_ein()`, both routing through one internal
  `.ein_core()` that implements §2 exactly (strip non-digits → reject >9 → left-zero-pad
  to 9 → reject the all-zeros placeholder). Pure base-R, vectorized over character, no new
  dependencies; lenient contract (§4). Merged via PR #22; pkgdown `ein_bridge` reference
  page published. Because S3 — not code — is the inter-repo contract (no cross-repo
  imports), `nccsdata` re-implements the logic; this doc + the §5 tests are what keep the
  two from drifting. If the producer's EIN format ever changes, update this spec and both
  impls together.

---

## 7. Why this is bridged by reformat, not a crosswalk

`EIN2` ≡ `"EIN-" + ein` and padded-9 ≡ `gsub("-","",ein)` — all five surfaces are
bijective renderings of the same 9-digit integer. So the legacy (`EIN2`) and new (`ein`)
ecosystems reconcile by **deterministic string reformat**; no published lookup/crosswalk
is needed or exists. This is the protection a research consumer wants: the two ID
conventions are formally, losslessly reconcilable, and now documented as such.

---

## Changelog

- **2026-06-26 — spec'd → implemented.** Spec authored; consumer impl shipped
  (`nccsdata/R/nccs_ein_bridge.R`, lenient mode, [PR #22](https://github.com/UrbanInstitute/nccsdata/pull/22))
  and the §5 vectors encoded as `nccsdata` tests. Producer impl (`transform_ein`)
  unchanged. Normative logic (§1–§3) unchanged from the original draft — this was a
  status/traceability update.

---

*Provenance: formats verified against live S3 (`--profile thiya`) on 2026-06-26 —
harmonized CORE marts (`harmonized/core/.../marts/…-HRMN-V1.csv`), NODC `efile_v2_1`
(`s3://nccs-efile/public/efile_v2_1/F9-P00-T00-HEADER-2024.CSV`), Unified BMF
(`master/bmf/archive/unified-v1.2/`), Master BMF / new CORE (`ein` + `ein_raw`).
Consumer implementation status verified against `../nccsdata` (PR #22 merged
`bf9511e`, 2026-06-26).*
