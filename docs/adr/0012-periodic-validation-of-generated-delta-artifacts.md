---
status: proposed
---

# Periodically validate generated delta artifacts

A successful delta-generation record is a last-known reference, not permanent proof
that its artifact remains available. A configurable `flightctl-periodic` task
checks successful records every 15 minutes by default.

Confirmed absence (a registry 404 or no matching referrer) and access denial
(401/403 using credentials Flight Control can resolve for the stored artifact's
registry) mark the generation failed, clear its artifact reference and size, and
evict both success-hint caches. Timeouts, 5xx responses, and unresolvable
credentials leave it succeeded for a later check.

A later prepare that requires the same image pair uses the existing
failed-to-pending retry path to queue generation against the current delta
storage target. Changing the target alone does not invalidate an accessible
artifact reference. Artifact deletion remains the OCI registry's responsibility;
Flight Control adds no delete API.

Prepare may use the last successful reference while a registry check is in
progress. This brief race is accepted; if the artifact is unusable, the device
falls back to a full image pull. Prepare does not wait behind a verification
lease.

## Design

`flightctl-periodic` delegates to a `DeltaGenerationValidator` task whose
external interface is `Poll(context.Context)`. The validator owns batching,
availability classification, compare-and-set state changes, and eviction of both
delta hint caches. Registry access and cache eviction remain private seams used
by the task's implementation and tests; they are not added to the
resource-oriented delta-generation service.

Validation checks the exact stored artifact reference. It does not derive a new
reference from the current delta storage target. If Flight Control cannot
resolve credentials for the stored reference's registry, the result is unknown
and the generation remains succeeded; changing the storage target alone does not
invalidate the reference.
