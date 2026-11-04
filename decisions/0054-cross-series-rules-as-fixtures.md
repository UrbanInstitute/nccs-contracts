# 0054: Cross-series rules are written rules with test fixtures, not a shared code library

- **Status:** Proposed (2026-11-03). For the data governance committee to accept, amend or reject.
- **Date:** 2026-11-03
- **Deciders:** sole maintainer; raised by Jesse Lecy's proposal to centralise standards in the `nccstools` R package
- **Related:** [[0001-s3-as-contract-surface]], [[0016-no-canonical-cross-dataset-merge]], [[0022-cross-repo-contract-change-guard]], [[0048-nteev2-specialty-code-x00-rule]], [[0053-core-tax-year-definition]], `conventions/ein-format.md`

## Context

Some rules apply to every data series NCCS publishes: how an EIN is
written, what the tax year means, how NTEE codes are resolved, how a
state or county is coded. If two pipelines apply two versions of the same
rule, the files disagree and the users find out last.

Jesse Lecy has proposed, at onboarding and again on 2026-11-03, that
these rules live in one shared R package (`nccstools`) that every
pipeline imports. The argument is that one implementation cannot drift
from itself and a bug fixed once is fixed everywhere.

The concern is right. ADR 0048 records a case where the NTEE rule
written in prose was implemented wrongly in code, against both the
published specification and the vendored crosswalk, and nothing caught
it until a user did. Prose alone did not hold.

The mechanism proposed is not right for this system, for reasons that
have nothing to do with R:

- **Repos share data, not code.** ADR 0001 makes S3 the only contract
  between repos, and ADR 0016 keeps it that way on purpose. A shared
  runtime library is a code dependency between every producer and one
  repo. ADR 0022 already draws this line: a shared CI check is accepted,
  a shared runtime dependency is not.
- **One library couples every release.** A change to the shared package
  forces every pipeline to re-test and re-release, or to pin an old
  version and drift anyway, which is the same drift in a form that is
  harder to see.
- **The rule would live inside code.** A user of the files, a Python
  consumer, or the download API cannot read a standard that exists only
  as an R function. A written rule with examples can be read by anyone
  and tested by anything.
- **Code changes are commits; rule changes are decisions.** The legacy
  CORE files carry a year definition nobody can now explain because it
  was a choice made in code. The system keeps decisions in ADRs so that
  does not happen again.
- **The proposed package is not yet a package.** At its current commit
  `nccstools` has no `DESCRIPTION` or `NAMESPACE`; its tax-year file is a
  working script that does not parse; its NTEE tests have two failures;
  and the harmonization repo that proposes it as the standard does not
  import it. None of this is a reason to reject the idea, but it is the
  state of the thing on offer.

## Decision

1. **Each cross-series rule is written down once**, in
   `conventions/<rule>.md`, in plain language, with the edge cases it
   does and does not resolve. `conventions/ein-format.md` is the model.

2. **Each rule carries a fixture file** next to it:
   `conventions/fixtures/<rule>.csv`, a small table of inputs and the
   expected outputs, including the hard cases (for tax year: a June year
   end, a short period inside one calendar year, an amendment; for EIN:
   leading zeros, hyphenated and unhyphenated input).

3. **Each producer tests its own implementation against the fixture in
   CI.** The test is small: read the fixture, run the producer's
   function, compare. A producer that fails the fixture does not publish.
   The fixture is the standard. The code is an implementation of it.

4. **A shared implementation may exist and is welcome.** An R package
   that passes every fixture can be used by any producer that chooses to,
   as an ordinary pinned dependency, the same as `data.table`. It gets no
   special status and no producer is required to use it. `nccstools` can
   be that package once it is packaged, versioned and passing.

5. **Changing a rule is an ADR**, which changes the convention and the
   fixture together. The contracts guard (0022) already requires the
   breadcrumb.

## Consequences

- Drift is caught by a test in every producer, which is where it would
  do damage, rather than prevented by a dependency that moves the damage
  elsewhere.
- Rules are readable by every consumer regardless of language.
- The first two fixtures are EIN format (rule already written) and tax
  year (0053). NTEE resolution follows, using the cases in 0048.
- Cost: one small test per producer per rule. The fixtures are tiny.

## Rejected

- A shared R package imported by every pipeline, for the reasons above.
- Leaving rules as prose only, which 0048 shows does not hold.
