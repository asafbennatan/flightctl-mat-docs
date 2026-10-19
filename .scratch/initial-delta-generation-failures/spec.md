Status: ready-for-agent

# Initial delta-generation failures fail open

## Problem Statement

Fleet operators can configure a delta storage target whose credentials do not
permit referrer lookup. The initial delta-generation existence check then
fails, but the generation is released to pending and the owning prepare keeps
reporting delta generation in progress. The rollout waits for the deadline
sweep or a newer prepare even though the failure is already known. Operators
need a known delta-generation failure to resume the normal rollout
immediately.

## Solution

Treat the initial existence check as having three outcomes. When it finds a
matching delta artifact, reuse that artifact. When it finds no matching
artifact, generate one. When the check returns an error, treat the result as
inconclusive, mark the generation failed for the current prepare, emit terminal
generation progress, and resume the normal rollout. A later prepare that needs
the same source image digest and desired target digest can retry the failed
generation.

## User Stories

1. As a fleet operator, I want an initial delta-generation failure to resume the normal rollout, so that devices are not blocked behind an unavailable optimization.
2. As a fleet operator, I want a terminal failed generation event, so that the fleet no longer appears stuck in delta-generation progress.
3. As a fleet operator, I want incorrect delta storage target permissions to fail the current delta attempt, so that the rollout continues with a full image update.
4. As a fleet operator, I want a registry timeout to fail the current delta attempt, so that a transient optimization failure does not delay the rollout.
5. As a fleet operator, I want a registry error not to be interpreted as a missing delta artifact, so that Flight Control does not generate work based on an unknown result.
6. As a fleet operator, I want an existing matching delta artifact to be reused, so that Flight Control avoids unnecessary generation and registry writes.
7. As a fleet operator, I want a confirmed missing delta artifact to trigger generation, so that eligible updates can benefit from a delta.
8. As a fleet operator, I want the current prepare to complete when one of its generations becomes terminally failed, so that the normal rollout can resume without waiting for the deadline sweep.
9. As a fleet operator, I want a later prepare that requires the same image pair to retry a failed generation, so that corrected permissions or recovered registry access can produce a delta in a later update.
10. As a service administrator, I want the initial failure policy to apply consistently to access denial, timeouts, registry failures, and network failures, so that I do not need to reason about status-code-specific behavior.
11. As a service administrator, I want successful delta artifacts to remain reusable, so that a transient failure of one prepare does not discard useful registry content.
12. As a Flight Control engineer, I want terminal generation completion to use the existing prepare fan-out, so that concurrent prepares and duplicate delivery remain idempotent.
13. As a Flight Control engineer, I want failed generation rows to use the existing later-prepare requeue path, so that this policy does not add a new retry state machine.
14. As a Flight Control engineer, I want initial generation and periodic validation treated separately, so that transient errors do not invalidate successful records that can be checked again later.
15. As an API consumer, I want the public generation progress status to become terminal when the current attempt fails, so that automation can distinguish active work from a completed fallback decision.

## Implementation Decisions

- Keep the initial existence-check outcome model at found, not found, and inconclusive.
- Reuse a matching delta artifact, generate after a confirmed miss, and fail the current generation after any inconclusive check error.
- Apply the inconclusive-error policy uniformly; do not classify initial failures by HTTP status.
- Mark the current generation failed through the existing terminal-generation path, including compare-and-set status persistence and terminal completion fan-out.
- Return successful queue handling after the terminal state is committed, so the delta-generation message is not placed in the retry set for the current prepare.
- Keep the current prepare’s no-same-prepare-retry behavior.
- Requeue a failed generation only when a later prepare requires the same image pair.
- Keep generation-stage failures terminal and fail-open.
- Do not change the periodic validation policy for already-successful generation records; transient validation failures remain retried by later periodic checks.
- Do not add a public API, schema change, event reason, or new queue.
- Do not add same-prepare retry scheduling or transient-error classification.
- Do not change the image-management glossary.

## Testing Decisions

- Good tests assert externally visible generation state, emitted terminal progress, generation invocation, and queue handling. They do not test private helper names or database implementation details.
- Use the existing delta-generation task-handler seam as the primary test boundary.
- Cover an inconclusive existence check by asserting that the generation becomes failed, a terminal completion event is emitted with the correct image pair and status, delta generation is not invoked, and queue handling succeeds.
- Preserve existing tests for a found delta artifact, a confirmed miss, successful generation, and generation-stage failure.
- Rely on existing generation-completion tests for prepare fan-out, terminal progress, rollout resumption, and idempotent join completion.
- Prior art is the existing delta-generation handler tests and generation-completion tests.

## Out of Scope

- Adding retries within the same prepare.
- Adding delta-queue failed-message maintenance or bounded retry scheduling.
- Distinguishing permanent authorization failures from transient registry errors during initial generation.
- Changing how source and target images are pulled or how generated delta artifacts are pushed.
- Changing periodic validation of successful generation records.
- Changing fleet rollout selection, disruption budgets, or full-image update behavior.
- Adding a new public status, API field, event reason, or schema.
- Updating the image-management glossary.

## Further Notes

- A full image update remains the safe fallback for the current rollout.
- An inconclusive existence check is not evidence that a delta artifact is absent.
- The decision is recorded separately from periodic validation because successful generation records are last-known references, not permanent proof of artifact availability.
