# 0013 — Versioned Producer Outputs

- **Status:** Accepted (planning; not yet executed)
- **Date:** 2026-05-21
- **Deciders:** sole maintainer
- **Related:** [[0001-s3-as-contract-surface]], [[0004-cadence-aware-drift-detection]], [[0010-sector-in-brief-data-replaces-dataexplorer-data]], [[0014-standardize-manifest-shape]]

## Context

Most NCCS producers overwrite their S3 outputs in place rather than
writing to vintage-stamped subdirectories. Concretely (as of
2026-05-21):

| Contract | Versioning today | Latest mirror |
|---|---|---|
| `bmf-master` | none — `master/bmf/bmf_master.parquet` is overwritten each run | n/a |
| `bmf-master-geocoded` | none — `geocoding/bmf-master/merged/bmf_master_geocoded.parquet` overwritten each run | n/a |
| `bmf-legacy` | per-vintage `processed/bmf-legacy/{YYYY_MM}/` ✓ | no `latest/` |
| `bmf-lookups` | per-vintage `lookups/bmf/{YYYY_MM}/` ✓ | `lookups/bmf/latest/` ✓ |
| `core-harmonized` | TBD (contract not yet populated) | TBD |
| `core-990` | TBD (contract not yet populated) | TBD |
| `sector-in-brief` | per-vintage `sector-in-brief/v{YYYY.MM}/` ✓ | `sector-in-brief/latest/` ✓ |
| `efile`, `merged` | not yet built | n/a |

Two of the seven producers we have today comply with a vintage +
`latest/` mirror pattern. The rest overwrite in place. The
consequences:

1. **No regression checking.** When a producer is re-run, the
   previous output is destroyed. A consumer that broke after the
   re-run has no way to diff yesterday's bytes against today's. The
   sole-maintainer model makes this even more painful — there's no
   second pair of eyes to catch a regression before the previous
   vintage is gone.
2. **No reproducibility.** A research notebook that ran against
   `bmf_master.parquet` last month cannot be replayed against the
   exact same bytes today. The artifact has the same URL but
   different contents.
3. **No safe migration path for breaking schema changes.** Producers
   that need to change a column type or rename a field must either
   coordinate a synchronous flip with every consumer or accept
   silent breakage. The 90-day deprecation window from
   [[0001-s3-as-contract-surface]] is meaningless when there's no
   previous vintage to deprecate against.
4. **Drift detection ([[0004-cadence-aware-drift-detection]]) is
   declawed.** The drift detector can only compare today against
   today. It cannot answer "did this vintage change row counts
   compared to last vintage?" — which is one of the most useful
   drift signals.

The pattern that works is already implemented twice in this system:

- `bmf-lookups` (`R/publish_lookups.R`): writes to
  `lookups/bmf/{YYYY_MM}/` and mirrors to `lookups/bmf/latest/`.
  Idempotent via sha256 — unchanged files skip upload.
- `sector-in-brief-data` (`R/publish.R`): writes to
  `sector-in-brief/v{YYYY.MM}/` and mirrors to
  `sector-in-brief/latest/` when `also_publish_latest` is set.
  Records vintage tag in `config.yml`.

Neither implementation was unprecedented — they followed the
"versioned URL + `_latest` pointer" line from
[[0001-s3-as-contract-surface]] §"Producer Pattern". The unversioned
producers are the holdouts.

## Decision

Every contracted producer publishes to a vintage-stamped
subdirectory and maintains a `latest/` mirror of the most recent
vintage. The vintage tag is part of the canonical contract URL;
the `latest/` mirror exists as a convenience for consumers that
always want the freshest bytes.

### Spec

**Path shape.**

```
s3://{bucket}/{key_prefix}/{vintage}/{file}
s3://{bucket}/{key_prefix}/latest/{file}
```

`{key_prefix}` is the contract's existing prefix (no change).
`{vintage}` is a per-contract tag — see "Vintage format" below.
`{file}` is the artifact's filename, unchanged from today's
in-place pattern. The `latest/` mirror contains identical bytes to
the most-recent `{vintage}/`.

**Vintage format.** Two formats coexist today:
`bmf-lookups` uses `YYYY_MM` (underscore), `sector-in-brief-data`
uses `v{YYYY.MM}` (dot, with `v` prefix). Pick one:

- **Adopt `v{YYYY.MM}` going forward** for all producers. Rationale:
  the `v` prefix makes vintage strings sort-distinct from prefix
  components (a future `s3 ls` will not confuse `2026_05/` with
  some other path segment), and the dot form is closer to common
  semver-style vintage conventions. `bmf-lookups` migrates at its
  next publish; its existing `YYYY_MM/` directories remain
  readable for the deprecation window.

  Producers whose vintage is not month-based (e.g. annual SOI
  releases) substitute the natural unit:
  `v{YYYY}` for annual artifacts, `v{YYYY.MM.DD}` for daily.
  Always prefix with `v`; always use `.` as separator.

**`latest/` mirror semantics.**

- Mirror is server-side copy of the most recent vintage, not a
  symlink (S3 has no symlinks). Atomicity is ensured by writing the
  vintage first, then the mirror — a partial write leaves `latest/`
  pointing at the *previous* good vintage.
- Mirror is identical-bytes, identical-paths within the prefix.
  Consumers reading `{key_prefix}/latest/{file}` get the same
  parquet as `{key_prefix}/{newest_vintage}/{file}`.
- Mirror is updated on every successful publish, even when no
  files changed (the timestamps refresh, which is the signal that
  a new vintage exists).

**Idempotency.** Re-publishing a vintage that already exists on S3
should be a no-op for unchanged files. Producers fetch the existing
vintage's manifest (per [[0014-standardize-manifest-shape]]), skip
uploads for files whose sha256 is unchanged, and re-upload only
files that differ. `bmf-lookups` does this today; the pattern
generalizes.

**Consumer pinning.**

- Default: consumers pin a specific vintage. The contract YAML's
  `consumers[].pin` field carries the pinned vintage as a string
  (e.g. `"v2026.05"`).
- Allowed: consumers pin `"latest"` when freshness matters more
  than reproducibility (e.g. operational dashboards). The contract
  YAML records this explicitly so it's auditable.
- Pin changes flow through a PR in the consumer repo. Drift
  detection ([[0004-cadence-aware-drift-detection]]) opens an issue
  when a new vintage is published; the cross-repo update agent
  ([[ARCHITECTURE.md]] §9 Loop 2) drafts the bump PRs.

### Scope

This ADR is in-scope for:

- `bmf-master` — migrate
- `bmf-master-geocoded` — migrate (in lockstep with `bmf-master`
  since the geocoded artifact depends on the un-geocoded master's
  vintage)
- `bmf-legacy` — migrate (add `latest/`; vintage subdirs already
  exist)
- `core-harmonized` — design in from the start (contract not yet
  populated)
- `core-990` — design in from the start

Out of scope (already compliant; cited as reference
implementations):

- `bmf-lookups` — already at `{YYYY_MM}/` + `latest/`; migrates to
  `v{YYYY.MM}/` at next publish per the vintage-format decision
- `sector-in-brief-data` — already at `v{YYYY.MM}/` + `latest/`

Deferred (not yet built):

- `efile`, `merged` — design in from the start when the producers
  ship.

### Migration plan

Per-producer; sequenced to minimize consumer churn.

1. **BMF master + geocoded (paired).** Producer dual-writes to
   the new versioned path *and* the old in-place path for one
   cadence cycle. Consumers update pins from `"latest"` (today's
   implicit pin) to a specific vintage in their next deploy.
   Then the producer drops the in-place write and the `latest/`
   mirror takes its place.
2. **BMF legacy.** `latest/` mirror added next time the legacy
   pipeline is re-run (rare). Vintage format flip from `YYYY_MM`
   to `v{YYYY.MM}` at the same time; old `YYYY_MM/` paths stay
   readable for the deprecation window.
3. **BMF lookups.** Vintage format flip from `YYYY_MM` to
   `v{YYYY.MM}` at next publish. `latest/` mirror is already in
   place; old `YYYY_MM/` directories are not deleted.
4. **Core (harmonized + 990).** Design in from the start when the
   contracts are populated and the publish scripts touched.

### Implementation notes

The reference implementations to copy:

- `nccs-data-bmf/R/publish_lookups.R` — sha256-keyed idempotent
  upload pattern, latest-mirror write, manifest fetch for skip
  decisions.
- `sector-in-brief-data/R/publish.R` — config-driven vintage from
  `config.yml`, `--also_publish_latest` flag, two-phase publish
  (vintage write, then mirror).

Each producer's `R/publish_*.R` (or equivalent) implements the
pattern. No new shared library — the two implementations are small
and the producers are loosely coupled, so copy-and-adapt is fine.

## Consequences

**Positive:**

- Regression checking becomes possible at the byte level. A
  consumer that broke between vintages can diff the two parquet
  files directly.
- Research reproducibility — notebooks pin a vintage, replay
  against identical bytes indefinitely (subject to the deprecation
  window).
- Breaking schema changes have a real migration path: producer
  publishes vintage N+1 with the new schema, consumers update pins
  on their own timeline, vintage N stays readable for the
  deprecation window.
- Drift detection gains the per-vintage diff signal (row count
  change, schema change, byte size delta).
- Contract YAML `consumers[].pin` becomes meaningful — currently
  most pins read "latest" or "n/a" because there's nothing to pin.

**Negative:**

- Storage cost grows with vintage count. Mitigated by S3 lifecycle
  policies (transition vintages older than the deprecation window
  to Glacier; delete older than 1y for high-churn producers). Not
  significant for the BMF artifacts (~1 GB / vintage).
- One-time migration work per producer (4 BMF + 2 core = ~6
  publish scripts to touch). Reference implementations make each
  one a copy-and-adapt.
- Consumers reading `latest/` get a small additional indirection
  (server-side copy lag — typically seconds). Not material for any
  current consumer.

## Deprecation window

Per [[0001-s3-as-contract-surface]] default: 90 days. Each
producer's old in-place path stays writable during the dual-write
phase and readable for 90 days after the migration completes.

## Follow-up

1. **[[0014-standardize-manifest-shape]]** is the companion ADR.
   Versioned subdirectories without a per-vintage manifest leave
   the question "are these the same bytes as last vintage?"
   answerable only by re-hashing. The manifest closes that loop
   cheaply. The two ADRs are tightly coupled and should ship
   together per producer.
2. **Update producer contract YAMLs** as each producer migrates:
   set `versioned_template` to the new path, set `latest_template`
   to the mirror, update consumer pins from `"latest"` to the
   specific vintage where applicable.
3. **S3 lifecycle policies** — set up after one full cadence
   cycle's worth of vintages exists, so the deprecation-window
   math is informed by real artifact sizes.
4. The drift-detection workflow per
   [[0004-cadence-aware-drift-detection]] should grow a "new
   vintage published" trigger that fires the cross-repo update
   agent (`ARCHITECTURE.md` §9 Loop 2) to draft consumer pin-bump
   PRs.
