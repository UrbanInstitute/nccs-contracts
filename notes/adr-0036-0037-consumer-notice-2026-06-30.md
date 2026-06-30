# Advance notice — Unified BMF rename + additive EIN columns

**Draft for distribution to known consumers. Owed BEFORE the Unified BMF S3
publish** (ADR 0037 §3; architecture context §1: "Documentation is not
notification"). Drafted 2026-06-30 at the contracts reconcile of nccs-data-bmf
PR #28. Two changes ship together; one is non-breaking-additive, the other is a
non-silent path move with a 90-day fallback.

---

## Who needs this

| Consumer | What they do today | Action needed |
|---|---|---|
| `nccsdata` R package | reads/joins on `ein`; mtime-only cache | re-pin to `unified/bmf/` after publish; cache busts on manifest sha. New `ein_prefixed`/`EIN2` columns available (optional). |
| NCCS public website — join instructions + BMF data catalog | instructs "join … by `ein` (XX-XXXXXXX)"; documents the ntee-resolved crosswalk at 18 cols | update the BMF master path `master/bmf/` → `unified/bmf/` after publish; add the two EIN columns to the crosswalk docs (now 20 cols). `ein` guidance is unchanged. |
| sector-in-brief API | request param + response column + emailed download use `ein` | no break (`ein` unchanged). Optional: expose `ein_prefixed`/`EIN2` in a future response-schema bump. Re-pin BMF source path at cutover. |
| Affiliate base-R `merge()` workflows (Jesse / NODC) | join on `EIN2` legacy key | `EIN2` (`EIN-XX-XXXXXXX`) now physically present on the Unified BMF + crosswalk — merge directly, no reformat. |

---

## Change 1 — additive coercion-safe EIN columns (ADR 0036). NON-BREAKING.

The Unified BMF, the ntee-resolved crosswalk, and the CORE tiers now carry two
**additional** columns, both derived from the **unchanged** canonical `ein`:

- **`ein_prefixed`** = `ein-XX-XXXXXXX` (e.g. `ein-04-2104327`) — a legible,
  provably-text key (the leading `e` forces text typing, so leading zeros and CSV
  round-trips survive).
- **`EIN2`** = `EIN-XX-XXXXXXX` (e.g. `EIN-04-2104327`) — the legacy/NODC format,
  for existing `EIN2`-keyed merges.

**Nothing is renamed, moved, retyped, or removed.** The canonical dashed `ein`
(`XX-XXXXXXX`) is byte-for-byte unchanged — existing joins on `ein` keep working
untouched. The `ein_raw` column also keeps its current (lossy bare-integer) form;
its data-dictionary text was corrected to describe that reality.

Status: the ntee-resolved crosswalk is **already republished live** with these
columns (3,613,958 rows × 20 cols). The Unified BMF carries them as of the next
publish (below). The CORE tiers carry them via nccs-data-core PR #11.

## Change 2 — master → Unified BMF rename + non-silent supersession (ADR 0037)

The rolling un-geocoded BMF master is renamed back to its community name,
**Unified BMF**, and its published location moves:

```
old:  s3://nccsdata/master/bmf/bmf_master.{parquet,csv}
new:  s3://nccsdata/unified/bmf/bmf_unified.{parquet,csv}   (+ _manifest.json)
```

**This is a non-silent move with a fallback (ADR 0037 §2–3):**
- Both paths stay **live and reachable for 90 days** (until **2026-09-28**).
- After the window, the old `master/bmf/` path moves to the **retained, reachable
  archive** under `s3://nccs-data-archive/superseded/` — **never deleted**.
- Each build now ships a per-build `_manifest.json` (commit, input hashes, row
  counts) so every vintage is citable and reproducible. The manifest **sha256** is
  the cache-bust signal for mtime-only caches (e.g. `nccsdata`).

The geocoded master (`geocoding/bmf-master/…`) and the state marts are **not**
renamed; only the un-geocoded Unified BMF moves.

**What you must do:** re-pin any direct read of `master/bmf/…` to `unified/bmf/…`
within the 90-day window. If you pin via `nccsdata`, update the package after its
re-pin lands. No `ein`-join logic changes.

---

## Timeline

- **Now:** ntee-resolved crosswalk live with the new columns; Unified BMF staged
  (publish pending the producer adopting the ratified `unified/bmf/` prefix).
- **At publish:** both `master/bmf/` and `unified/bmf/` live; 90-day clock starts.
- **2026-09-28:** `master/bmf/` archived (reachable, not deleted).

Questions → the NCCS data system maintainer (DST). Decisions of record:
`nccs-contracts/decisions/0036-…` and `…/0037-…`.
