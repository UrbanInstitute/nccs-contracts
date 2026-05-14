# 0001 — S3 as the Contract Surface

- **Status:** Accepted
- **Date:** 2026-05-14
- **Deciders:** sole maintainer

## Context

The NCCS data system has three producer pipelines (BMF, core 990,
e-file) and a growing set of consumers (R package, dashboard, API,
future apps). Producers and consumers need to agree on a contract:
where data lives, what shape it's in, and when it updates.

Three plausible contract surfaces:

1. **S3 as the contract surface.** Producers publish artifacts +
   manifests; consumers read directly or through a service tier.
2. **A message bus / event stream** (e.g. SNS/SQS, Kafka) carrying
   change events; consumers subscribe.
3. **An API as the spine.** Producers write to a service; consumers
   read through it.

## Decision

S3 is the contract surface. Every published artifact lives at a
canonical S3 path with a co-located `MANIFEST.json` carrying sha256,
vintage, and generation timestamp.

## Consequences

**Positive:**

- Zero new infrastructure. The pipelines write S3 either way.
- Asynchronous decoupling. Producers and consumers have independent
  cadences and don't share uptime requirements.
- Language-agnostic. Every consumer language has good parquet + S3
  support.
- Deterministically validatable. Agents can diff "promised" against
  "on disk" without operating a queue.

**Negative:**

- No push notifications. Consumers either poll or are triggered by
  external mechanisms (GH Actions on producer publish). Acceptable
  given current cadences.
- Path stability matters. Renaming an S3 path is a breaking change
  for every consumer; mitigated by versioned URLs + deprecation
  policy (see [0002](0002-canonical-merged-artifact.md) and the
  versioning section of `ARCHITECTURE.md`).

## Alternatives Considered

- **Message bus.** Rejected: adds infrastructure to operate (broker,
  consumer offsets, dead-letter queues) for a problem the current
  cadences don't have. Revisit if a consumer ever needs sub-minute
  reactions to e-file batches.
- **API as spine.** Rejected as the *contract surface* — the API
  exists, but it's a consumer of S3, not the source of truth.
  Putting the API on the spine would couple every producer's
  uptime to the API's, and bake an HTTP request path into pipeline
  publishing.

## Revisit trigger

Sub-minute consumer reaction times, cross-pipeline transactional
requirements, or any need for guaranteed-delivery semantics.
