# ADR 0046 draft concordance (2026-08-06)

- `build_concordance.R` composes the three-way variable concordance
  (raw SOI var ↔ core snake_case ↔ NODC `F9_*` ↔ legacy CORE names).
- `core-variable-concordance-DRAFT.csv` is its output: 345 rows
  (990 + 990-EZ, 2012-2024), 132 with legacy PZ names attached.
- Upstream inputs:
  - NODC `soi-extract-harmonization` at commit `8632a5fe3064a103483401bfa4094e7f5ec59672`
    (file `00_crosswalks/SOI-EXTRACT-CROSSWALKS-2012-2024-EZ-PC-VFINAL.CSV`).
  - `nccs-data-core/data/crosswalks/soi_990_crosswalk_FINAL.csv`,
    `soi_990ez_crosswalk_FINAL.csv`, `legacy_pz_crosswalk_FINAL.csv`
    (local working tree, 2026-08-06).
- The script's paths are session-local; the production version moves to
  `nccs-data-core/scripts/` when ADR 0046 is accepted (task C2 in BACKLOG).
