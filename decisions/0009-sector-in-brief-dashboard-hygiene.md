# 0009 — Sector-In-Brief Dashboard Hygiene Cleanup

- **Status:** Accepted (planning; not yet executed)
- **Date:** 2026-05-15, recon corrected 2026-05-18
- **Deciders:** sole maintainer

## Context

The `UrbanInstitute/sector-in-brief` repo (`sibApp` locally) ships
the dashboard mounted at
`https://nccs-urban.shinyapps.io/sector-in-brief/`. A 2026-05-15
recon flagged a set of low-risk hygiene issues. A 2026-05-18
follow-up — done against `git status`, `git ls-files`, and
`git diff --stat` rather than a directory listing — found the
original recon was substantially wrong about what is committed
versus what merely exists on disk. The corrected picture:

### Branch state

`sibApp` is checked out on `iss14`, not `main`. After `git fetch`:
`iss14` is **67 commits ahead of main** (main last moved
2025-04-08, commit `3f6af72`, the iss11 merge), and the local
`iss14` was **40 commits behind its remote** at the time of recon
— `git status`'s "up to date" was a stale-cache artifact. In this
repo, always `git fetch` before reading ahead/behind counts.

### Cruft is on disk but untracked

Every file the original recon listed as "committed binary cruft"
is in fact **untracked**, never present in any commit on this
branch:

- `bmf_state_subset.csv`, `.RDataTmp`,
  `shinycannon-1.2.0-85f280d.jar`, `run1/`, `run2/`, `run2.html`,
  `recording.log` — all untracked.
- `.RData` is not even on disk.

So `git rm` is a no-op for these files. The correct action is
`rm` (where the file exists on disk) plus a `.gitignore` entry to
keep them from re-accumulating.

Other untracked files live on disk and need a triage call rather
than a blanket delete: the parquet files in `data/`
(`daf.parquet`, `finances.parquet`, `number_nonprofits.parquet`,
`pf_grants.parquet`), `renv.lock`, `renv/`, `rsconnect/`,
`.Rprofile`, `.Rbuildignore`, `.gitignore` itself,
`sector-in-brief.Rproj`, `tests/`, `debug.R`,
`R/overlapping_col_plot.R`, `R/table_builder_median.R`. Some of
these (notably `renv.lock`, `.gitignore`, `.Rbuildignore`,
`tests/`) probably *should* be committed; the parquets are the
target of ADR 0011 and shouldn't be.

### The ~90-file modification pile is a CRLF mirage

`git diff --stat` shows 97 files / 9520 inserts / 9520 deletes,
with exact symmetry. `git diff --word-diff` returns zero word
changes. Working-tree files are CRLF; git blobs are LF.
`core.autocrlf` is unset on the WSL clone. There is no in-progress
R/ work to preserve. `git restore .` (or `autocrlf=input` +
`git add --renormalize .`) clears it.

### Issues that remain real

The non-state issues from the original recon stand:

- **`DESCRIPTION` is template boilerplate.** Title is literally
  `"What the Package Does (One Line, Title Case)"`, author is
  `"First Last"`, license is the unresolved `use_mit_license()`
  placeholder.
- **`README.md` is 45 bytes**, one sentence pointing at `deploy/`.
- **`.gitignore` is 44 bytes** and does not exclude the cruft
  categories above; nothing prevents re-accumulation.

The clone-size argument from the original recon is moot for the
untracked cruft (`.git/` doesn't contain those blobs) but may
still apply to any binary blobs actually in history — that needs
a separate `git log --stat` pass before deciding on
`git-filter-repo`.

## Decision

Execute a single half-day hygiene pass:

1. **Resolve the CRLF mirage first.** Set `core.autocrlf=input`
   on the WSL clone (or `git restore .`) so subsequent diffs are
   meaningful. Without this, every other step looks like it
   touched 97 files.
2. **Delete untracked cruft from disk** and add `.gitignore`
   entries so it can't return. Files to remove (where present):
   `bmf_state_subset.csv` (after confirming no runtime reference),
   `.RDataTmp`, `shinycannon-1.2.0-85f280d.jar`, `run1/`, `run2/`,
   `run2.html`, `recording.log`. Use `rm`, not `git rm`.
3. **Rewrite `.gitignore`** to exclude `.RData`, `.RDataTmp`,
   `.Rhistory`, `.Rproj.user/`, `*.log`, `run*/`, `*.jar`, and
   any other patterns that come up. Use a standard R `.gitignore`
   (e.g. via `usethis::use_git_ignore()`) as the base and add
   Shiny-specific entries.
4. **Triage the other untracked files.** Commit `renv.lock`,
   `.gitignore`, `.Rbuildignore`, `tests/`, and the
   `sector-in-brief.Rproj` if it represents real project state.
   Leave the `data/*.parquet` files untracked (they're the target
   of ADR 0011, which will move them out of the repo entirely).
   Decide case-by-case on `R/overlapping_col_plot.R`,
   `R/table_builder_median.R`, `debug.R`, `.Rprofile`,
   `rsconnect/`.
5. **Rewrite `DESCRIPTION`** with real title, author, description,
   and resolved license. Title example: "Nonprofit Sector In Brief
   Dashboard". MIT recommended for consistency with other Urban
   NCCS repos.
6. **Rewrite `README.md`** to cover at minimum: what the dashboard
   shows, where it's deployed, how to run locally, where the data
   comes from (per ADR 0011), how to deploy. ~50–100 lines.
7. **Optional, pending verification:** before considering
   `git-filter-repo`, run `git log --all --stat -- '*.parquet'
   '*.csv' '*.jar' '*.RData*'` to find blobs that are actually in
   history. The original ADR's clone-size argument assumed the
   cruft was tracked; in fact most of it never was, so history
   rewrite buys less than it appeared.

## Consequences

**Positive:**

- Cruft removed from the working tree and prevented from
  returning by `.gitignore`.
- The CRLF fix makes future diffs readable, which unblocks
  ADRs 0010–0012.
- New contributors can orient from `README.md` alone.
- A correct `DESCRIPTION` makes the repo legible as an R package
  if it ever gets installed as one.

**Negative:**

- The headline "repo shrinks from ~120 MB to ~5–10 MB" from the
  original recon was based on the wrong premise. Real disk-size
  win depends on what `git log --stat` finds; it may be modest.
- Any optional history rewrite (`git-filter-repo`) still breaks
  outstanding forks or clones; coordinate before doing it.
- Half-day of non-visible work; this ADR records that the work is
  deliberate.

## Deprecation window

Not applicable; no external surface changes.

## Follow-up

Ships before ADRs 0010 (data plumbing) and 0011 (data decoupling)
to keep those changes auditable against a clean repo. After this
ADR lands, run the validator workflow added in `nccs-contracts`'s
`c5a75fb` on the dashboard's own future CI to keep hygiene from
regressing.

The branch question — whether to do this work on `iss14` (and
fold into its eventual merge) or on a fresh branch off `main` —
is not resolved here. Default: do it on `iss14` since that's
where active dashboard work lives, and rebase/merge later.
