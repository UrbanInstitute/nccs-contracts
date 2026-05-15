# 0011 — Decouple the Sector-In-Brief Dashboard from Committed Data

- **Status:** Accepted (planning; not yet executed)
- **Date:** 2026-05-15
- **Deciders:** sole maintainer

## Context

The sector-in-brief dashboard (`UrbanInstitute/sector-in-brief`,
`sibApp` locally) reads its visualization data from parquet files
**committed to the repo's `data/` directory**:

```
data/number_nonprofits.parquet
data/finances.parquet
data/daf.parquet
data/pf_grants.parquet
data/panel_dd.csv
data/nested_geographies.csv
```

These files are snapshots of `s3://nccsdata/sector-in-brief/`
(1 GB, last write 2024-09) — the previous output prefix of
`nccs-dataexplorer-data` (per ADR 0010). The current sync pattern
is **manual**: when underlying NCCS data refreshes, someone copies
the relevant parquet files from S3 into the repo, commits, and
redeploys.

Separately, the dashboard's download tab calls the dataexplorer
API at a **hardcoded URL ending in `/stg/`**
(`https://qf8i5d1vg2.execute-api.us-east-1.amazonaws.com/stg/data/`).
This inherits the prod/stg-environment-inversion problem diagnosed
in ADR 0008 — production traffic hits the staging URL because the
original cutover never happened.

Two consequences:

- **Data staleness is invisible.** The dashboard shows whatever
  was last copied into the repo, regardless of how fresh the
  underlying S3 data is. No automation surfaces drift.
- **Same data, two realities.** The S3 artifact (canonical) and
  the committed copy (rendered) can diverge silently. This is
  the same "two data realities" problem ADR 0002 solved at the
  producer/consumer scale, recreated at the dashboard layer.

The dashboard repo is also bloated by the committed parquet
(~100 MB across the four files plus historical versions in git
history). Clone size + storage cost compound with each refresh.

## Decision

Make the dashboard read its visualization data from S3 on app
startup (or first-use, with a local cache), not from committed
parquet. Concretely:

### Data plumbing

1. **Remove committed parquet/data from the repo:**
   - `data/number_nonprofits.parquet`
   - `data/finances.parquet`
   - `data/daf.parquet`
   - `data/pf_grants.parquet`
   - `data/panel_dd.csv`
   - Keep `data/nested_geographies.csv` (small, mostly static lookup;
     decide case-by-case).
2. **Read from the contracted artifact** per
   `contracts/sector-in-brief.yml` (ADR 0010):
   - On app startup, fetch the manifest from
     `s3://nccsdata/dataexplorer/visuals/latest/MANIFEST.json`.
   - Download referenced parquet to a local cache directory
     (e.g. `/tmp/sector-in-brief-cache/`) keyed by sha256.
   - Use `arrow::open_dataset()` / `arrow::read_parquet()` for the
     reads.
   - Skip downloads when the cached sha256 matches the manifest.
3. **Pin the contract version** in the dashboard repo: a small
   `data_pins.yml` or equivalent records the
   `sector-in-brief` contract tag the dashboard is built against.
   Refresh via PR when promoting to a new vintage.

### API URL fix

4. **Replace the hardcoded `/stg/` URL** with the new
   `nccs-data-api` endpoint (per ADR 0008) once it ships. Until
   then, leave the URL as-is — the existing URL works, it's just
   pointing at the inverted-name bucket per ADR 0008's context.
5. **Move the URL out of source code** into a config file or env
   var, so the prod/stg pointer is a deploy-time setting, not a
   code change.

### Local development

6. **Provide a local-dev path** that bypasses S3: a small script
   or function that downloads the parquet once and reads from
   local files for the rest of the session. Avoids dev-loop pain
   from cold S3 fetches.

### Deployment

7. **shinyapps.io deployment needs AWS credentials** scoped to
   `s3://nccsdata/dataexplorer/visuals/*` read-only. Add as
   deployment secret; update `deploy/` config accordingly.

## Consequences

**Positive:**

- Dashboard data is sourced from the same canonical surface every
  other consumer reads. Data refresh is automatic when the
  contracted artifact updates.
- Repo shrinks by ~100 MB on every fresh clone (more after history
  rewrite, optional).
- The "two data realities" failure mode goes away.
- API URL stops being a code-change to update; deploy-time config
  replaces it.

**Negative:**

- App startup latency increases by the time to fetch parquet from
  S3 on cold start. Mitigated by sha256-keyed local cache and
  arrow's lazy reads.
- shinyapps.io's filesystem is ephemeral; cold starts re-fetch.
  For production traffic this is fine (cold starts are rare); for
  dev it matters and is solved by §6.
- Requires AWS credential management for the deploy environment,
  which the current deploy does not.
- Soft breaking change for anyone running the dashboard locally
  without AWS credentials — must download the data first.

## Deprecation window

Not applicable; the dashboard is the only consumer of its own
committed `data/`, and the canonical source remains in S3
throughout.

## Follow-up

1. **Blocked by ADRs 0008 and 0010.** ADR 0008 fixes the API URL
   (so step §4 has a target); ADR 0010 contracts the data prep
   layer (so the dashboard reads a stable artifact).
2. Consider whether to rewrite the parquet files out of git
   history via `git-filter-repo`. Same tradeoff as ADR 0009:
   smaller fresh clone vs. fork breakage.
3. Once §3 (contract pin) is in place, the dashboard can advertise
   which `sector-in-brief` vintage it serves — useful for users
   asking about data currency.
