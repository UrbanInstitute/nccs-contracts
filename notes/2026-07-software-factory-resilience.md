# Assessment: NCCS vs. "Why Software Factories Fail" (2026-07-26)

Prompted by the maintainer against HumanLayer's WSFF essay
(github.com/humanlayer/advanced-context-engineering-for-coding-agents,
`wsff.md`): agent-heavy codebases rot because models optimize fast
feedback (tests) while architectural damage has a cost function
measured in months; incident rates climb 3-6 months into heavy agent
use.

**Disclosure**: drafted by the coding agent whose own output is the
subject. Discount and spot-audit accordingly.

## Defenses NCCS already has (converged before the essay was read)

1. **Planning phases are institutionalized.** The reporting cycle (ADR
   in this repo -> execute downstream -> reconcile) IS the essay's
   product-review/architecture/design pipeline; contracts are the data
   schemas; vertical slices are house doctrine (efile Phase 0, API
   Phase-0 spike).
2. **Slow cost functions get converted to fast detectors.** The legacy
   street-address loss was a textbook slow-cost defect (plausible
   crosswalk decision, latent for months, found by an external user).
   The response pattern: by-source completeness tripwire, standing
   source-vs-output validation gate (ADR 0042 §4), drop+alias crosswalk
   gate, contracts guard: is the essay's remedy made mechanical.
   Notably the worst latent defects found in 2026-07 (ADDRESS drop,
   manifest byte overflow, upload-success-on-403) predate agent
   authorship: the failure class is universal; machinery is the
   differentiator.
3. **Bounded blast radius.** S3-only contract surface, no cross-repo
   code imports: shotgun surgery cannot ripple beyond guarded data
   contracts.

## Exposures

1. **Single-reviewer throughput (the dominant risk).** One maintainer
   reviewed ~15 agent PRs across 5 repos in 3 days, merging in batches.
   Review depth thins toward rubber-stamping at that rate; trivial
   diagnostic: style-rule violations passed review repeatedly. This is
   the vector for the essay's compound-cost decay.
2. **Test asymmetry.** `nccs-data-bmf` (highest-consequence repo) has
   no test harness; enforcement is run-time gates plus maintainer
   attention. A flag-clobber bug was caught only because a validation
   run nearly wrote to production.
3. **Agent-authored guardrails are agent-audited.** Gates and tripwires
   were written by the same agent they constrain; simple + evidence-
   logged, but "who validates the validator" is open.
4. **Governance velocity.** Four ADRs in three days is factory-speed
   decision-making; reconcile debt is already visible (0041 Outcome
   pending, BACKLOG rows accumulating).

## Recommendations (tracked in the maintainer's resilience tasklist)

- Throttle merges to review capacity; track review debt explicitly.
- Seed a minimal test harness in nccs-data-bmf (transform units +
  crosswalk-disposition tests first).
- Doctrine: every slow-cost defect found leaves behind a fast detector
  (post-mortem tripwire rule).
- Second human on contract-shape review (Jesse already functions as
  consumer sign-off; formalize).
- Quarterly architecture pass against this note.
