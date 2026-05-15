# 0009 — Sector-In-Brief Dashboard Hygiene Cleanup

- **Status:** Accepted (planning; not yet executed)
- **Date:** 2026-05-15
- **Deciders:** sole maintainer

## Context

The `UrbanInstitute/sector-in-brief` repo (`sibApp` locally) ships
the dashboard mounted at
`https://nccs-urban.shinyapps.io/sector-in-brief/`. A 2026-05-15
recon found a set of low-risk hygiene issues that compound over
time and embarrass the repo to anyone reading it cold:

- **~110 MB of binary and session-state cruft committed:**
  `bmf_state_subset.csv` (66 MB at the repo root, no R code
  references it), `.RData` (16 MB), `.RDataTmp` (12 MB),
  `shinycannon-1.2.0-85f280d.jar` (9 MB), `run1/`, `run2/`,
  `run2.html` (5.6 MB total load-test outputs), `recording.log`
  (77 KB).
- **`DESCRIPTION` is template boilerplate.** Title is literally
  `"What the Package Does (One Line, Title Case)"`, author is
  `"First Last"`, license is the unresolved `use_mit_license()`
  placeholder. Treated as an R package but not maintained as one.
- **`README.md` is 45 bytes**, one sentence pointing at `deploy/`.
  Conveys nothing about what the app does, how to run it, or where
  the data comes from.
- **`.gitignore` is 44 bytes** and does not exclude the categories
  of cruft listed above; nothing prevents the same files from
  re-accumulating after cleanup.

None of these issues affect runtime correctness. All become
high-leverage to fix because the same cleanup also makes the harder
work (ADRs 0010–0012) tractable: a repo at 10 MB is reviewable;
the same repo at 120 MB scares off contributors and slows clone.

## Decision

Execute a single half-day hygiene pass:

1. **Delete committed binary cruft** (via `git rm`, not just
   `.gitignore`):
   - `bmf_state_subset.csv` (after confirming no runtime reference)
   - `.RData`, `.RDataTmp`, `.Rhistory`
   - `shinycannon-1.2.0-85f280d.jar`
   - `run1/`, `run2/`, `run2.html`
   - `recording.log`
2. **Update `.gitignore`** to exclude `.RData`, `.RDataTmp`,
   `.Rhistory`, `.Rproj.user/`, `*.log`, `run*/`, `*.jar`, and any
   other patterns that come up during the pass. Use a standard R
   `.gitignore` (e.g. via `usethis::use_git_ignore()`) as the base
   and add Shiny-specific entries.
3. **Rewrite `DESCRIPTION`** with real title, author, description,
   and resolved license. Title example: "Nonprofit Sector In Brief
   Dashboard". Decide license (MIT recommended for consistency
   with other Urban NCCS repos).
4. **Rewrite `README.md`** to cover at minimum: what the dashboard
   shows, where it's deployed, how to run locally, where the data
   comes from (per ADR 0011), how to deploy. ~50–100 lines.
5. **Optional but recommended:** consider whether to rewrite the
   committed parquet files in `data/` out of git history via
   `git-filter-repo`. Without history rewrite, the binary blobs
   remain in `.git/` indefinitely; the clone size advantage is
   blunted. Decide based on whether the repo has external
   contributors who'd be affected by a forced history rewrite.

## Consequences

**Positive:**

- Repo shrinks from ~120 MB to ~5–10 MB on fresh clone (or much
  less if history is rewritten).
- New contributors can orient from `README.md` alone.
- `.gitignore` prevents the same cruft from re-accumulating.
- A correct `DESCRIPTION` makes the repo legible as an R package
  if it ever gets installed as one.

**Negative:**

- Optional history rewrite (`git-filter-repo`) breaks every
  outstanding fork or local clone; coordinate before doing it.
- A few hours of work for a non-visible improvement; can feel
  unrewarding to anyone who measures progress by features shipped.
  This ADR exists partly to record that the work is deliberate.

## Deprecation window

Not applicable; no external surface changes.

## Follow-up

Ships before ADRs 0010 (data plumbing) and 0011 (data decoupling)
to keep those changes auditable against a clean repo. After this
ADR lands, run the validator workflow added in `nccs-contracts`'s
`c5a75fb` on the dashboard's own future CI to keep hygiene from
regressing.
