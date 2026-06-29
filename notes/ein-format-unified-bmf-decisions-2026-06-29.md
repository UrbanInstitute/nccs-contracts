# EIN format + Unified BMF — final decisions (2026-06-29)

Canonical record of the decisions reached on the Jesse Lecy EIN-format thread.
Source of truth for what was committed vs. deferred. Spawned ADRs:

- **ADR 0036** — EIN coercion-safety via additive `ein_prefixed` + `EIN2`
  (canonical `ein` unchanged). Amends ADR 0034. *(Decision 1 below; committed.)*
- **ADR 0037** — Master BMF → Unified BMF rename, non-silent supersession
  (90-day, archive-and-reachable), per-build provenance. *(Decisions 3 + 4;
  committed.)*

Deferred items (Decision 2, the all-join-IDs convention) are **NOT** drafted as
ADRs — they run through the July governance meeting. Decision 5 (Giving Tuesday)
is an ingestion note + July input. Flags + noted-background logged in `BACKLOG.md`.

Driving evidence is in `notes/jesse-bmf-feedback-factfinding-2026-06-26.md` and
the 2026-06-29 cross-repo EIN blast-radius investigation (external-load-bearing
verdict; IRS-display-vs-data correction).

---

## Context that drove these decisions

- The dashed `ein` (`XX-XXXXXXX`) is **externally load-bearing**: anon-readable
  public S3, the website (which tells researchers to join on it), the nccsdata
  package, the live sector-in-brief API, and at least one CSV already delivered to
  an external requester. Live ~4–5 months and continuously republished. Therefore
  a value-format change to `ein` **cannot be an in-place reformat** — it must be
  additive.
- Correction to the earlier "ecosystem alignment" rationale: `XX-XXXXXXX` is the
  IRS **display/written** standard, NOT the data convention. In data files the
  ecosystem uses **no-dash 9-digit** (IRS bulk EO BMF ships undashed, dash
  "optional"; ProPublica's data field is the 9-digit integer; our own `ein_raw` is
  the 9-digit form). So the dashed `ein` aligns with display, not data. The dash's
  real justification is coercion-safety (force text typing), which is the *same*
  concern Jesse raised. (Caveat: Candid's *data* format not verified; GuideStar
  *displays* dashed.)
- Net: the dash and an alpha prefix are two text-forcing decorations on the same
  underlying 9-digit key, both for coercion-safety. An alpha prefix is strictly
  safer (provably text in all cases, not just usually). This makes Jesse's prefix
  argument technically strong; the dashed form's main remaining claim is incumbency
  (already published on five surfaces), not external-data alignment.

## Decision 1 — Coercion-resistance: solved additively, now (committed → ADR 0036)

Keep canonical `ein` (`XX-XXXXXXX`) **stable and unchanged** — externally
load-bearing, not renamed or reformatted. Deliver coercion-safety **additively**
by adding two columns to the Unified BMF (renamed master, Decision 3), the new
CORE tiers, and the ntee-resolved crosswalk:

- **`ein_prefixed`** — value `ein-XX-XXXXXXX` (lowercase `ein-` prefix). New
  legible, coercion-safe key. Lowercase = snake_case/house-style; leading alpha
  (`e`) makes it provably text. Self-documenting name.
- **`EIN2`** — value `EIN-XX-XXXXXXX` (uppercase legacy format). Labeled
  legacy-compat alias — same key, exact name+format the legacy ecosystem
  (harmonized CORE, NODC e-file, old Unified BMF) and base-R `merge()` join on.
  Dictionary: "legacy-compatibility alias; identical key to `ein_prefixed` in
  legacy `EIN-XX-XXXXXXX` format; retained for existing merges."

Resulting key columns: `ein` (incumbent canonical, dashed, unchanged),
`ein_prefixed` (new legible coercion-safe key), `EIN2` (legacy-compat alias),
`ein_raw` (9-digit source, already exists).

- Purely additive. One non-additive piece: `ntee-resolved-crosswalk.yml:61` pins
  the format inline → contract amend (amends ADR 0034).
- Consumer bridge exists (`nccsdata/R/nccs_ein_bridge.R`). Producer-side emission
  of `ein_prefixed` / `EIN2` is net-new.

## Decision 2 — Canonical-format convergence: SETTLED (no convergence; permanent multi-rendering)

**Updated 2026-06-29.** Convergence is **not pursued.** The canonical key is not
moved to a single prefixed form and the dashed `ein` is not retired. The four
renderings (`ein`, `ein_prefixed`, `EIN2`, `ein_raw`) are the permanent design;
each consumer joins on the one that fits. (Supersedes the earlier plan to defer
this to July — the EIN-format question is settled.)

- Rationale: the data ecosystem uses no-dash 9-digit (`ein_raw`); dashed `ein` is a
  coercion-safety display choice with no strong external-data backing; a prefixed
  key (`ein_prefixed`/`EIN2`) is strictly safer. But the **marginal safety gain** of
  forcing a single canonical does not justify the **external-deprecation cost** of
  retiring a live, five-surface published key. Multi-rendering gives everyone a
  provably-safe key now, with no migration and nothing broken — the safer path.
- A single house ID convention *across files* remains an **optional** future group
  topic, NOT a committed migration; nothing downstream waits on it.
- The July meeting stands for the broader execution-vs-governance split, not for
  the EIN format (now settled).

## Decision 3 — Master BMF → Unified BMF rename + supersession (committed → ADR 0037)

- The new "master" BMF **is** the Unified BMF replacement and currently carries
  dashed `ein` (no prefix). The earlier email's "the Unified BMF still carries
  EIN2 and merges as it did" described the **archived original**, not the
  replacement. Conceded cleanly in the reply.
- Rename master → **Unified BMF** so the known name carries forward; supersede the
  prior file.
- Both available **90 days**; after, prior version → **retained archive —
  reachable and citable, not deleted**.
- Standing rule: supersession always with notice + fallback (deprecation-windowed
  path move, not silent).
- Renamed Unified BMF carries the additive `ein_prefixed` + `EIN2` (Decision 1).

## Decision 4 — Provenance on the Unified BMF (committed → ADR 0037)

Each build carries a manifest (commit, input hashes, row counts); prior builds
retained → every version citable and reproducible. Consistent with the
versioning/`/latest` direction in flight.

## Decision 5 — Giving Tuesday EIN format (ingestion note + July input)

NCCS data engineering depends on the Giving Tuesday data lake. GT renders EIN as
**bare 9-digit `XXXXXXXXX`** (CONFIRM: zero-padded? always 9? any prefix?). This
is an **ingestion-normalization** concern (consume GT, normalize on intake via the
existing dash insert/remove bridge — likely the same island as the padded-9
e-file), NOT an output-compatibility concern. Material input to the July
canonical-format decision: a *fourth* external EIN rendering (IRS/Candid/ProPublica
display-dashed, IRS/ProPublica data-no-dash, legacy NCCS prefixed, GT bare-9) —
itself evidence that no single canonical format is consistent with everything and
the robust design is "canonical key + deterministic bridges." **Keep GT OUT of the
Jesse reply** (internal context; strengthens the July position, not a new thread
for him).

## Governance hygiene flags (not Jesse-facing now)

- Promote `conventions/ein-format.md` to an ADR-gated / CI-governed surface.
- sector-in-brief-api: adding `ein_prefixed`/`EIN2` response columns is an
  API-schema version bump (coordinate ADR 0013/0022/0031).

## Noted, not now (background)

- Two duplicate `transform_ein` formatters (nccs-data-bmf + nccs-data-core) —
  consolidate to prevent drift.
- nccsdata cache is mtime-only (30-day) — won't see an upstream rename/reformat;
  needs manifest/sha or version-tagged path busting.
- nccs-data-efile producer `ein` is padded-9, already divergent; any change is an
  S3 producer-output contract change, must move in lockstep with the API
  normalizer.
