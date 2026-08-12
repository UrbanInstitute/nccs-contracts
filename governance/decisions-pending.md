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
