# ADR 0046 draft concordance (2026-08-06)

- `build_concordance.R` composes the three-way variable concordance
  (raw SOI var ↔ core snake_case ↔ NODC `F9_*` ↔ legacy CORE names).
- `core-variable-concordance-DRAFT.csv` is its output: 344 rows,
  exactly one per (raw SOI variable, form) — year-split crosswalk rows
  are collapsed, enforced by a shape gate in the builder (990 + 990-EZ,
  2012-2024); 131 rows carry legacy PZ names.
- Upstream inputs:
  - NODC `soi-extract-harmonization` at commit `8632a5fe3064a103483401bfa4094e7f5ec59672`
    (file `00_crosswalks/SOI-EXTRACT-CROSSWALKS-2012-2024-EZ-PC-VFINAL.CSV`).
  - `nccs-data-core/data/crosswalks/soi_990_crosswalk_FINAL.csv`,
    `soi_990ez_crosswalk_FINAL.csv`, `legacy_pz_crosswalk_FINAL.csv`
    (local working tree, 2026-08-06).
- Inputs are supplied via env vars (`CORE_XW_DIR`, `NODC_VFINAL_CSV`);
  output lands beside the script. The production version moves to
  `nccs-data-core/scripts/` when ADR 0046 is accepted (task C2 in BACKLOG).
