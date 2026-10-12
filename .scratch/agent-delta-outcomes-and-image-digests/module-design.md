# Associate lastDelta with reported image identities

Status: proposed module design. This document applies the codebase-design skill
to the decisions in [the proposed ADR](../../docs/adr/0001-image-digests-and-delta-outcomes.md).
It does not authorize implementation or settle the open policies below.

## Recommended module and seam

Deepen the existing concrete `deltastatus.Store`. Its interface should let the OS
and application callers record verified per-image outcomes and select an outcome
for a complete observed image snapshot. Its implementation owns persistence,
matching, protected retention, LRU eviction, and application aggregation.

Keep runtime observation and identity verification with the existing bootc,
Podman, and CRI modules. They provide evidence about images they own. The store
does not inspect containers, resolve registry indexes, or perform delta work.
This seam separates runtime evidence from outcome-history policy without adding
a generic cache interface or another wrapper around the existing store.

The depth comes from hiding the rules callers otherwise have to coordinate:
which records survive an update, which records can be evicted, how missing
observations suppress publication, and how multiple image outcomes combine.
Deleting this module would distribute those rules across OS, dependency, and
status callers. Keeping them together provides leverage and locality.

## Interface responsibilities

These are conceptual operations, not final Go method signatures. Evolve the
existing methods where possible and preserve the current constructor and
`fileio.ReadWriter` dependency.

| Operation | Caller supplies | Store guarantees |
| --- | --- | --- |
| Reconcile desired scope | Scope lifetime, active attempt identities, discovered image targets, collection completeness | Reject superseded completions; retain still-relevant history; protect active results; avoid pruning from incomplete discovery |
| Record image result | Scope, attempt identity, image reference, storage owner, OCI type, verified associated digest, recorded outcome | Persist a scoped per-image result; ignore stale completions; retain completed active results before observation |
| Select observed result | Scope lifetime and an owned, complete observed image snapshot with verified identities | Match every required image, protect selected records, return an owned outcome or no outcome; aggregate application results under the same lock |

Application removal is handled by reconciliation. Recreating an application
invalidates observations and completions from its previous lifetime. Ordinary
desired-spec changes advance the active attempt without deleting outcomes still
needed by observed images. Attempt identity and application lifetime serve
different purposes and must not be conflated.

Callers do not manage LRU entries, pin individual records, choose eviction
victims, or assemble an aggregate from separate cache lookups. Unknown identity
or incomplete observations produce no publishable result. Persistence failures
remain explicit errors to the recording/reconciliation callers; status selection
uses memory and does not require disk or runtime I/O.

## Per-image history

Each record belongs to an OS or application scope and associates an outcome
with one verified digest plus the image reference, storage owner, and OCI type.
An opaque fingerprint may index this tuple internally, but it must not replace
the digest association needed for matching. Do not use a digest alone as a
global key: the same image can have different recorded outcomes in different
applications or storage owners.

Keep update-attempt metadata for rejecting stale writes separate from the
identity used to match an observed image. A result from an earlier legitimate
attempt can therefore describe an image still running during the next update.
Multiple workloads using the same scoped image share a result; old and new
digests running together require separate matches. Conflicting results for the
same scoped identity need a deterministic recording rule; the proposed rule is
that the latest accepted completion replaces its previous result.

Retain one associated digest per record. Prefer a verified index identity when
available; use an observed platform manifest when index provenance is absent.
Config IDs, generation source/target digests, and reconstructed manifest digests
are not extra history keys. Index-to-platform resolution, when needed, happens
outside the store. Matching different digest representations requires verified
equivalence evidence; reference equality alone never establishes it.

## Collection and publication

1. Existing runtime modules collect image observations using immutable workload
   identity. A moving Podman tag cannot establish a running container's identity.
2. Application collection gathers workload images, image-backed volumes, and
   applicable parent artifacts into one owned snapshot. Track completeness and
   application lifetime; independently updated pods may yield a valid mixed
   rollout snapshot. Artifact identity remains distinct from executable-image
   platform identity.
3. Pass that snapshot to the store once. Under its lock, validate lifetime,
   match every required image, update retention protection, and combine the
   recorded outcomes. No cached aggregate or aggregate key is needed.
4. Publish the digests from that same snapshot alongside the returned outcome.
   Return owned copies so later cache mutation cannot alter the selected status.

Current monitor collection alone does not establish this whole snapshot:
volumes and parent images are merged separately by the application manager.
The final collector needs to validate its lifetime after gathering those inputs
and mark missing expected observations incomplete. Do not perform registry
verification while holding the monitor or store lock.

Aggregation preserves the existing outcome rules and deterministic fallback
reason selection. It combines recorded outcomes without recalculating delta
work. Results from different accepted attempts may participate when they match
the reported images. `Partial` describes mixed delta usage, not rollout progress.

Once selection returns, eviction cannot invalidate its copied status even if
network reporting is delayed or fails. Until a new complete snapshot replaces
the protected observation set, keep records required by the previous complete
snapshot. Keep completed active-update results protected before their first
observation. A partial collection must not release that protection.

## Capacity and eviction

Application history holds at most `2 × max(complete observed image count,
active-update image count)` unprotected records. Count distinct scoped images,
including required image-backed volumes and parent artifacts; replicas sharing
the same scoped digest count once. A complete status collection replaces the
protected observed set and is the only evidence that can trigger shrinkage.
Incomplete discovery or observation preserves the last complete set.

Protect the last complete observed set, active-update results, and completed
results that have not yet been selected into a complete application outcome.
Protected records may temporarily overflow the capacity. Evict the least
recently used eligible records after a complete collection, with digest key as
the deterministic tie-breaker. Recency advances during collection even if the
status send later fails. Collection changes remain in memory and are persisted
with the next normal store write; status selection performs no disk writes.

OS history retains two records, protecting the current booted image and the
active result, with temporary overflow for other protected results. Preserve
the first accepted outcome for a scoped digest when that identity is recorded
again. Application removal clears its entire history and protection state.

## Persistence and verification

Version the changed persisted state. Version-1 records do not contain the digest
evidence required by this design, so they cannot be published solely because a
desired fingerprint still matches. Corrupt or unsupported state remains
nonfatal to agent startup. Persist result association and retention information
needed to protect completed but unreported work across restart.

The current store mutates memory before writing its state file. A failed write
does not prove durability or roll back that mutation. Preserve explicit error
handling and define retry behavior; do not promise transactional writes without
implementing them through the existing file I/O mechanisms.

Test through the store's interface using the existing file I/O test facilities:

- Preparing B while observing A returns A's outcome; observing B later returns
  B's outcome. A stale attempt cannot overwrite either accepted result.
- An application with many images, shared images, and mixed old/new workloads
  aggregates only the outcomes matching its complete emitted snapshot.
- Missing images, unknown identities, or unverified index/platform equivalence
  suppress publication; verified equivalence follows the accepted policy.
- Pending and previously observed results survive pressure and restart; only
  eligible history is evicted, following the accepted capacity/recency rules.
- Removal/recreation rejects an obsolete snapshot, while an ordinary update
  preserves a still-observed previous result.
- Returned copies remain unchanged after eviction or replacement. Legacy and
  failed persistence never imply verified, durable association.

Runtime tests exercise the existing observation modules against actual bootc,
Podman, and CRI workloads. The saved probe evidence covers ordinary pulls on
the tested versions; reconstructed delta images and multi-platform bootc remain
unverified. Unit fixtures cannot close those gaps.

This design changes the existing store and its callers in place. It does not
introduce a separate LRU module, cache application aggregates, or add interfaces
solely to make mocks possible.
