# Governance — pending decisions

Deferred by the committee (2026-08-12), queued for future meetings:

1. **Validation definition** — what makes a build "publication-ready";
   which checks must pass; who runs them. (Dedicated session.)
2. **DOI / citation machinery** — registry choice (Zenodo-per-version
   vs DataCite membership), who administers, landing-page design.
   Background: JL's citation-standards deck.
3. **Embedded version "receipt"** — a version/fingerprint column (or
   equivalent) inside published files so provenance travels with the
   data. Design due-out with JL.
4. **Website changelog / NEWS page** — human-readable release history
   on the site (annotation, 2026-08-12). **Design settled 2026-08-12
   (PR review): fully DERIVED, no new authoring surface** — the page
   is generated at site build from `governance/release-notes/*.md`
   (the §6 flow's only output location), reverse-chronological, with
   links into the decision-record index; same generation pattern as
   the existing ADR index. Implementation = one script + page in the
   website repo.
5. **npmatch independent validation** — NCCS blind re-validation of
   the benchmark (offer stands; convert "self-validated 95%" to
   "NCCS-verified").
6. **SOI-harmonization concordance direction** — producer intent
   question outstanding (relates to decision record 0046).

## Recorded for the September 2026 meeting (no decision needed)

Registry additions made 2026-09-16 under "register, don't ask"
(backlog Z17). To be read into the minutes as **recorded**:

- **`npmatch-sources`** — the folder `s3://nccsdata/crosswalks/npmatch/`
  that NODC's npmatch package reads its pinned source files from
  (copies of our BMF files, a SAM extract, training pairs; 10 files,
  6.2 GB). Owner NODC; NCCS hosts it and will give 90 days' notice
  before touching it.
- **`efile-duckdb-archives`** — the per-year DuckDB files under
  `s3://nccs-efile/duckdb/` built by NODC's ef2 package (three
  versions, about 800 GB in total). Owner NODC; NCCS hosts them.
  **Chair's decision 2026-09-16:** these are not an NCCS product,
  because NCCS does not own the process that makes them; NCCS intends
  to bring that process in-house at some point (backlog Z23, no date).
- **Column stability for the Unified BMF** — a statement added to the
  `unified-bmf` contract: existing column names are not renamed or
  removed without the standard 90-day notice, because outside packages
  write our column names into their code.
- **panel990 moved off the retiring geocoded folder on 2026-09-02** —
  closes the August action "JL to swap". Recorded as a consumer on the
  `unified-bmf-geocoded` contract. One old file name remains in its
  per-state fallback (`bmf_master_XX.csv`, which stops being written
  after 2026-12-15).

