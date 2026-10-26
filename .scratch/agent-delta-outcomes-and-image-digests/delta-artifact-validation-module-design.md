# Validate generated delta artifacts through a periodic task

Status: proposed module design. This document applies the codebase-design skill
to [ADR 0012](../../docs/adr/0012-periodic-validation-of-generated-delta-artifacts.md).
It does not authorize implementation or change the accepted policy.

## Recommended module and seam

Create a `DeltaGenerationValidator` task in `internal/tasks`. Its external
interface should be the existing periodic-task shape:

```go
func (v *DeltaGenerationValidator) Poll(ctx context.Context)
```

The periodic checker constructs the task and calls `Poll`; it does not learn
the validation policy. The implementation owns batching, availability
classification, compare-and-set invalidation, successful-verification updates,
and eviction of both delta hint caches.

This is a deep module because one small interface hides a workflow that would
otherwise spread across the periodic executor. Applying the deletion test: if
the module were removed, confirmed-absence handling, transient-error handling,
state transitions, and cache-key invalidation would reappear in the executor and
eventually in prepare or generation callers.

Keep the validator separate from `deltageneration.Service`. That service is a
resource-oriented persistence module. Adding registry I/O and cache eviction to
it would make its interface broader while coupling prepare and generation
callers to periodic-validation concerns.

## Internal seams

The task may use private interfaces for its implementation and tests. They are
not part of the module's external interface.

| Seam | Responsibility | Production adapter | Test adapter |
| --- | --- | --- | --- |
| Successful generations | List succeeded rows with a nonempty artifact reference; update a row under its expected resource version | Existing generation store/service backed by Postgres | In-memory or SQLite-backed store |
| Artifact availability | Check the exact stored artifact reference and classify the result | ORAS registry adapter | Fake availability results |
| Delta hint cache | Evict the worker-owned success hint and the device-render lookup memo for one generation key | Existing KV store | Fake cache |

The availability interface should expose a classified result rather than a raw
error:

```go
type ArtifactAvailability int

const (
    ArtifactAvailable ArtifactAvailability = iota
    ArtifactMissing
    ArtifactAccessDenied
    ArtifactUnknown
)
```

`ArtifactUnknown` covers timeouts, 5xx responses, and references for which
Flight Control cannot resolve registry credentials. It leaves the generation
succeeded for a later check.

The availability adapter checks the exact stored `DeltaRef`. It must not derive
a new push path from the current delta storage target, because changing that
target alone must not invalidate an otherwise accessible artifact. If Flight
Control cannot authenticate to the stored reference's registry, the result is
unknown rather than access-denied.

## State and ordering rules

1. Process succeeded rows in bounded batches with a per-artifact timeout. A
   transient failure must not prevent later rows in the batch from being checked.
2. For an available artifact, update only `LastVerifiedAt` under the row's
   expected resource version. A compare-and-set miss means the row changed and
   the stale snapshot must not be written.
3. For confirmed absence or access denial, compare-and-set the row to `failed`,
   clear `DeltaRef`, `SizeBytes`, and `Phase`, and record the verification time.
   A compare-and-set miss means another writer owns the row; do not evict from
   that stale snapshot.
4. Only after a successful invalidating write, evict both hint-cache keys. Cache
   eviction is best effort and logged: the record is already failed, and both
   caches have a bounded TTL. Prepare relies on the failed-to-pending retry path,
   not on cache eviction, to regenerate the artifact.
5. Keep prepare unchanged. It may briefly use a last-known successful reference
   while validation is in progress. If that reference is unusable, the device
   falls back to a full image pull.

## Rejected designs

- **Validate in the periodic executor.** The executor would become a shallow
  module with a large interface: callers would need to supply the generation
  store, repository service, registry checker, and KV store, then understand
  state transitions and cache keys.
- **Add validation to `deltageneration.Service`.** This couples the persistence
  module to registry I/O and cache policy and exposes the behavior to callers
  that do not participate in periodic validation.
- **Make prepare wait behind a verification lease.** This was rejected in ADR
  0012. The device full-image fallback already bounds the consequence of the
  accepted race.
- **Expose a generic cache invalidation interface.** The validator needs one
  domain-specific eviction operation, not a general cache abstraction.

## Testing

Test `Poll` through its external interface with fake or local adapters. Assert
the resulting generation state, resource-version behavior, and hint-cache
evictions; do not assert private batch ordering or internal helper calls.

Cover:

- available artifacts update only the verification time;
- confirmed absence and access denial invalidate the row and both caches;
- timeouts, 5xx responses, and unresolvable registry credentials leave it
  succeeded;
- compare-and-set misses discard stale snapshots;
- cache eviction failure does not undo invalidation;
- target changes do not turn an unauthenticated old-reference check into
  confirmed absence;
- batching continues after an individual artifact fails;
- rows without a usable artifact reference are not treated as available.

Keep the ORAS adapter's protocol behavior behind its own contract tests,
including referrer fallback, manifest validation, 401/403 classification, and
transient network failures. Those tests should not leak into `Poll` tests.
