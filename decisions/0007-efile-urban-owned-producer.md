# 0007 — E-file as a Contracted Urban-Owned Producer

- **Status:** Accepted (planning; pipeline not yet built)
- **Date:** 2026-05-15
- **Deciders:** sole maintainer

## Context

Form 990 e-file data is a higher-fidelity surface than the annual
SOI core 990 extracts: continuous trickle, full schedule coverage,
line-item financials, narrative text. NCCS needs this data on a
contracted footing comparable to bmf-master and core-990.

Today, NCCS's e-file presence is anchored to a parallel pipeline
maintained by Nonprofit Open Data Collective (NODC):

- Code: `Nonprofit-Open-Data-Collective/irs990efile` (R package).
- Concordance: `Nonprofit-Open-Data-Collective/irs-efile-master-concordance-file`,
  anchored to the 2020 IRS Form 990 schema; per-field XPath →
  column-name mapping.
- Data dictionary:
  `https://nonprofit-open-data-collective.github.io/irs990efile/data-dictionary/data-dictionary.html`.
- Catalog page on the NCCS website:
  `https://nccs.urban.org/nccs/catalogs/catalog-efile.html`.
- Output: processed CSV, hosted at `s3://nccs-efile/`.
- Upstream raw XML: GivingTuesday data lake
  (`https://990data.givingtuesday.org/`).

The NODC pipeline is valuable as a researcher tool with deep IRS
domain knowledge embedded in its concordance. It is **not** a
contracted artifact in the nccs-contracts sense: no co-located
manifest, no sha256 integrity surface, no versioning scheme,
form-version-anchored column naming that ages with each IRS schema
revision, no 990PF coverage. It is owned by NODC, not by Urban
Institute, and operates outside the contracts-and-ADR model that
governs `nccs-data-bmf`, `nccs-data-core`, and the BMF/core
artifacts under `s3://nccsdata/`.

NCCS data engineering responsibilities have transferred to a single
Urban-owned maintainer. Bringing e-file into the same contracted,
parquet, manifest-shipping model as the other producers is part of
filling out the contracts surface to cover all four data tiers
(bmf, core, lookups, efile).

## Decision

Stand up a new Urban-owned producer for the e-file data tier. It
follows the same shape as `nccs-data-bmf` and `nccs-data-core`:

- **Repo:** `UrbanInstitute/nccs-data-efile` (to be created when the
  pipeline work starts; not created today).
- **Upstream source:** GivingTuesday data lake
  (`https://990data.givingtuesday.org/`) is the canonical raw XML
  source. `s3://nccs-efile/` is acknowledged as an existing parallel
  surface but is not the upstream for this producer.
- **Contracted output:** parquet, manifest-shipping, form-agnostic
  semantic column names (independent of any specific IRS form
  revision year). Published under `s3://nccsdata/processed/efile/`
  to live alongside `processed/bmf/` and `processed/core/`.
- **Concordance handling:** the NODC concordance file (MIT-licensed,
  under `Nonprofit-Open-Data-Collective/irs-efile-master-concordance-file`)
  may be adapted with attribution as the XPath → field source. A
  translation layer maps NODC's form-version-anchored column names
  to NCCS form-agnostic names. 990PF concordance is built from IRS
  XSD (NODC does not cover 990PF).
- **Cadence:** monthly. IRS publishes batches monthly; downstream
  consumers do not need sub-monthly latency.
- **Implementation language:** R, matching `nccs-data-bmf` and
  `nccs-data-core` to share patterns and infrastructure code.

**MVP scope** (Phase 1, ~4–6 weeks of focused work):

- Form type: 990 only.
- Tax years: 2020 onward.
- Fields: headline only (revenue, expenses, assets, executive
  compensation, top-level narratives). Detailed schedules deferred
  to Phase 2.
- Output: parquet partitioned by `filing_year × form_type`,
  manifest with per-file sha256.

**Phase 2:** add detailed schedules, 990EZ coverage, full historical
backfill to 2009. **Phase 3:** add 990PF. Each phase ships
independently with its own ADR if scope or shape changes.

## Coexistence with the NODC pipeline

The NODC pipeline continues to operate as a parallel researcher tool
under its existing ownership. The NCCS website will present this as
two products for two audiences:

- **General-user catalog** (new): the Urban-owned, contracted
  parquet surface. Form-agnostic naming, 990PF included over time,
  manifest-shipping, suitable for dashboards and the API service tier.
- **Researcher catalog** (existing): the NODC CSV surface. Form-
  version-anchored naming, deep concordance reference, suitable for
  IRS-form-line-item research.

This framing is honest — the products have different design choices
and serve different audiences. It is not a deprecation of the NODC
pipeline, which remains valuable as a researcher reference.

## Consequences

**Positive:**

- E-file becomes a first-class contracted tier, addressable from the
  same drift-detection and validation tooling as bmf-master and
  core-990.
- Form-agnostic column naming insulates downstream consumers from
  IRS form revisions.
- 990PF coverage closes a gap in NCCS's e-file presence.
- Parquet output is what the API service tier (per ADR 0003) and
  the merged producer (per ADR 0002) need.
- Two-catalog presentation gives users a clear choice between
  general-purpose and research-focused access patterns.

**Negative:**

- Real multi-month engineering investment (Phase 1 alone is 4–6
  weeks; full coverage is 3–4 months).
- A second e-file dataset on the NCCS website may briefly confuse
  users; the dual-catalog framing should be paired with clear copy
  on each catalog page explaining the audience.
- The concordance translation layer is ongoing maintenance — when
  NODC's concordance updates for new IRS schemas, NCCS's
  translation table needs review.

## Deprecation window

No deprecation window applies. The new producer creates a new
artifact; it does not replace any contracted artifact. The NODC
pipeline is not under nccs-contracts governance and continues
unchanged.

## Follow-up

1. Defer pipeline build until a near-term consumer needs it. The
   contract stub + this ADR are sufficient to make the engineering
   plan real on paper.
2. When work begins, create `UrbanInstitute/nccs-data-efile` and
   open ADR 0008 if any design defaults shift (language, upstream
   source, MVP scope).
3. Update `ARCHITECTURE.md` once Phase 1 ships to add efile to the
   system map table.
4. Resolve the relationship between `nccs-efile/xml/` and
   `nccsdata/xml/` as a separate audit item — neither is the
   upstream this producer will use, so the open question is whether
   to keep, archive, or delete `nccsdata/xml/`.
