# 13: Periodically validate generated delta artifacts

## Problem Statement

Fleet operators can delete or recreate an external delta artifact repository, but
Flight Control currently retains a successful delta-generation record and cached
delta hints for the same image pair. Later prepares can therefore reuse a stale
artifact reference instead of regenerating the missing delta, leaving devices to
encounter an unusable hint and fall back to a full image pull.

The short-lived hint cache is not sufficient because the durable generation
record remains successful after the cache expires. Flight Control needs a bounded,
periodic way to distinguish a genuinely unavailable artifact from a transient
registry problem, while preserving usable references when the configured delta
storage target changes.

## Solution

Add a periodic validation task that checks successful delta-generation records
against their exact stored artifact references. Confirmed absence or access denial
marks the generation failed, clears its stored artifact metadata, and evicts both
delta hint caches. A later prepare that requires the same image pair uses the
existing failed-to-pending retry path to regenerate the delta against the current
delta storage target.

Transient registry failures and references whose registry credentials cannot be
resolved leave the generation succeeded for a later check. Prepare may briefly use
a last-known successful reference while validation is in progress; if that
artifact is unusable, the device uses its existing full-image fallback.

## User Stories

1. As a fleet operator, I want deleted delta artifacts to be detected, so that a
   later prepare regenerates the missing delta instead of reusing a stale hint.
2. As a fleet operator, I want access-denied artifact references to be marked
   failed, so that generation can retry against a reachable delta storage target.
3. As a fleet operator, I want transient registry timeouts and 5xx responses to
   leave a successful generation unchanged, so that a temporary registry problem
   does not discard a still-usable artifact.
4. As a fleet operator, I want validation to check the exact stored artifact
   reference, so that changing the configured delta storage target alone does not
   invalidate an artifact that remains available at its original location.
5. As a fleet operator, I want a later prepare to requeue a failed generation,
   so that the same image pair can be regenerated after the artifact disappears.
6. As a fleet operator, I want the validation interval to be configurable, so
   that I can balance registry load against how quickly stale references are
   detected.
7. As a service administrator, I want validation to run in bounded batches, so
   that a large history of successful generations cannot monopolize the periodic
   worker.
8. As a service administrator, I want each artifact check to have a timeout, so
   that one slow registry cannot block validation of unrelated image pairs.
9. As a service administrator, I want validation to use compare-and-set updates,
   so that concurrent generation or prepare work is not overwritten by a stale
   validation result.
10. As a service administrator, I want both delta hint caches to be evicted after
    a record is invalidated, so that rendering does not continue to receive a
    stale successful hint for longer than necessary.
11. As a service administrator, I want cache eviction to remain bounded by the
    existing hint TTL if eviction fails, so that a cache outage cannot undo the
    durable generation-state transition.
12. As a device agent, I want to fall back to a full image pull when a supplied
    delta hint is unusable, so that rollout can complete even during the accepted
    validation race.
13. As a device agent, I want successful hints to continue to be published only
    from successful generation records, so that I do not receive hints for
    artifacts known to be missing.
14. As a registry administrator, I want Flight Control to authenticate before
    classifying access denial, so that a missing credential is not reported as a
    deleted artifact.
15. As a registry administrator, I want Flight Control to avoid deriving a new
    artifact path from the current delta storage target during validation, so
    that target changes are not confused with artifact deletion.
16. As a security operator, I want Flight Control to provide no artifact
    deletion API, so that artifact lifecycle management remains the OCI
    registry's responsibility.
17. As a maintainer, I want periodic validation hidden behind one task entry
    point, so that the periodic executor does not need to understand registry
    classification, state transitions, or cache keys.
18. As a maintainer, I want registry and cache dependencies to remain private
    seams of the validation task, so that the resource-oriented generation
    service does not gain unrelated I/O responsibilities.
19. As a test engineer, I want validation behavior observable through the task's
    public entry point, so that tests survive internal implementation changes.
20. As an operator, I want the delta artifact, delta artifact repository, and
    delta storage target terms used consistently, so that validation behavior is
    unambiguous in documentation and discussions.

## Implementation Decisions

- Add a periodic `DeltaGenerationValidator` task whose external interface is a
  single `Poll` operation.
- Keep batching, availability classification, state transitions, and cache
  eviction inside that task; the periodic executor only constructs and runs it.
- Use private seams for successful-generation lookup and updates, artifact
  availability checks, and delta hint eviction. Do not expose those seams through
  the resource-oriented delta-generation service.
- Validate the exact stored artifact reference. Do not derive a new reference from
  the current delta storage target.
- Classify results as available, missing, access-denied, or unknown. Unknown
  covers transient failures and references for which registry credentials cannot
  be resolved.
- Treat a registry 404, no matching referrer, or authenticated 401/403 as
  confirmed invalidation. Treat timeouts, 5xx responses, and unresolvable
  credentials as unknown.
- On confirmed invalidation, compare-and-set the generation to failed, clear its
  artifact reference and size, clear any phase, and record the verification time.
- On availability, update only the verification time under the expected resource
  version.
- Discard stale snapshots when a compare-and-set update misses.
- Evict both delta hint caches only after a successful invalidating write. Cache
  eviction is best effort because both caches already have a bounded TTL.
- Leave prepare behavior unchanged: it may use a last-known successful reference
  while validation is in progress, and the device falls back to a full image pull
  if that reference is unusable.
- Do not add an artifact deletion API. Artifact deletion remains the OCI
  registry's responsibility.
- Do not add a verification lease or otherwise make prepare wait for periodic
  validation.

## Testing Decisions

- Test the validation task through its public `Poll` entry point.
- Use fake or local adapters for successful-generation storage, artifact
  availability, and hint-cache eviction.
- Assert externally observable generation state, resource-version behavior, and
  cache eviction. Do not assert private batching order or internal helper calls.
- Cover available artifacts, confirmed absence, authenticated access denial,
  transient failures, unresolvable credentials, target changes, compare-and-set
  misses, cache eviction failure, batching continuation, and rows without usable
  references.
- Keep OCI registry protocol behavior in adapter-level contract tests, including
  referrer listing, manifest validation, and HTTP status classification.
- Follow the existing table-driven test naming convention: "When … it should …".
- Use existing delta-generation handler, generation-store, and periodic-task
  tests as prior art for state transitions and task wiring.

## Out of Scope

- Adding an API for deleting delta artifacts.
- Changing how the device agent falls back to a full image pull.
- Adding a verification lease or serializing prepare behind validation.
- Invalidating an accessible artifact solely because the delta storage target
  changed.
- Broadening the delta-generation service interface with registry or cache
  concerns.
- Introducing a generic cache abstraction.
- Changing the public delta-generation status model or API.

## Further Notes

- ADR 0012 records the accepted validation policy and implementation seam.
- The periodic validator should use the image-management glossary's distinction
  among a delta artifact, the external delta artifact repository, and Flight
  Control's configured delta storage target.
