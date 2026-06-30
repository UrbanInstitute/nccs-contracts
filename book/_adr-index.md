| ADR | Title | Status |
|:---:|-------|--------|
| [0001](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0001-s3-as-contract-surface.md) | S3 as the Contract Surface | Accepted |
| [0002](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0002-canonical-merged-artifact.md) | Canonical Merged Artifact as a First-Class Producer | Superseded |
| [0003](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0003-retire-athena-for-duckdb.md) | Retire Athena for API Runtime; Use DuckDB on Parquet | Accepted |
| [0004](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0004-cadence-aware-drift-detection.md) | Cadence-Aware Drift Detection | Accepted |
| [0005](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0005-bmf-unified-superseded-by-master.md) | BMF Unified Products Superseded by master/bmf | Accepted |
| [0006](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0006-deduplicate-legacy-archive.md) | Deduplicate nccs-data-archive Against nccsdata/legacy | Accepted |
| [0007](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0007-efile-urban-owned-producer.md) | E-file as a Contracted Urban-Owned Producer | Accepted; |
| [0008](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0008-modernize-dataexplorer-api.md) | Modernize the Dataexplorer API | Accepted |
| [0009](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0009-sector-in-brief-dashboard-hygiene.md) | Sector-In-Brief Dashboard Hygiene Cleanup | Accepted |
| [0010](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0010-sector-in-brief-data-replaces-dataexplorer-data.md) | `sector-in-brief-data` Replaces `nccs-dataexplorer-data` | Accepted |
| [0011](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0011-decouple-dashboard-from-committed-data.md) | Decouple the Sector-In-Brief Dashboard from Committed Data | Accepted |
| [0012](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0012-sector-in-brief-architecture-refactor.md) | Sector-In-Brief Dashboard Architecture Refactor | Accepted |
| [0013](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0013-versioned-producer-outputs.md) | Versioned Producer Outputs | Accepted |
| [0014](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0014-standardize-manifest-shape.md) | Standardize Manifest Shape Across Producers | Accepted |
| [0015](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0015-core-contract-surface-restructure.md) | Restructure the Core Contract Surface | Accepted |
| [0016](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0016-no-canonical-cross-dataset-merge.md) | No Canonical Cross-Dataset Merge | Accepted |
| [0017](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0017-efile-phase-0-vertical-slice.md) | E-file Phase 0 Vertical Slice and Transition to NCCS-Owned Concordance | Executed |
| [0018](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0018-standardize-efile-panel-names.md) | Standardize the sector-in-brief e-file panel names to the efile producer's names | Accepted |
| [0019](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0019-dataexplorer-data-as-derived-producer.md) | nccs-dataexplorer-data as a Contracted Derived Producer | Superseded |
| [0021](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0021-canonical-county-identity-via-fips-crosswalk.md) | Canonical Geography Identity via Published Crosswalks (County FIPS + CBSA) | Accepted |
| [0022](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0022-cross-repo-contract-change-guard.md) | Cross-Repo Contract-Change Awareness (the contracts-guard + breadcrumb enforcement) | Accepted |
| [0023](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0023-ct-planning-region-coordinate-resolution.md) | Connecticut Geography via a Coordinate-Keyed Planning-Region Crosswalk | Accepted |
| [0024](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0024-adhoc-data-requests-consumer-repo.md) | Ad-hoc Data Requests as a Thin Consumer Repo | Accepted |
| [0025](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0025-requests-graduate-to-data-stories.md) | Ad-hoc Requests Graduate to Public Data Stories | Accepted |
| [0026](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0026-data-download-durable-links-and-telemetry.md) | Data-Download UX: Durable Links, Email Receipt by Default, and Download Telemetry | Accepted |
| [0027](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0027-core-990-parquet-promotion.md) | Promote core-990 to Parquet-Canonical (Service Tier), with Documented Cross-Vintage Type Drift | Accepted |
| [0028](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0028-efile-wholesale-relational-extraction.md) | E-file: Wholesale Extraction to a Normalized Relational Tier | Accepted |
| [0029](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0029-bmf-org-level-query-mode.md) | BMF Org-Level Query Mode (`source=bmf`) with Lifespan-Overlap Filtering | Accepted |
| [0030](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0030-async-giant-export-worker.md) | Async Giant-Export Worker (Fargate) for the Data-Download Tail | Accepted |
| [0031](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0031-core-tier-routing-api-canonical.md) | CORE Tier Routing: the Download API is Canonical | Accepted |
| [0032](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0032-ntee-cleaner-university-code-loss.md) | Correct NTEE Cleaning So `nteev2_subsector = UNI` Holds Actual Universities | Accepted |
| [0033](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0033-deprecation-window-policy-and-critical-bug-override.md) | Deprecation-Window Policy + Critical-Bug Override | Accepted |
| [0034](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0034-ntee-resolved-crosswalk.md) | NTEE-Resolved Crosswalk (per-EIN, cross-vintage) | Accepted |
| [0035](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0035-retain-harmonized-core-frozen-surface.md) | Retain the Harmonized CORE Surface as a Frozen, Protected Artifact | Accepted |
| [0036](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0036-ein-coercion-safety-additive-columns.md) | EIN Coercion-Safety via Additive Columns (`ein_prefixed` + `EIN2`; canonical `ein` unchanged) | Accepted |
| [0037](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0037-master-bmf-rename-unified-supersession-provenance.md) | Master BMF → Unified BMF: Rename, Non-Silent Supersession, Per-Build Provenance | Accepted |
| [0038](https://github.com/UrbanInstitute/nccs-contracts/blob/main/decisions/0038-cross-repo-coordination-protocol.md) | Cross-Repo Coordination Protocol (the reporting cycle) | Accepted |
