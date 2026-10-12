# Proposed tickets for observed-image delta association

Status: draft — awaiting breakdown approval.

Source: the current feature spec, domain glossary, proposed digest/outcome ADR,
and module design. These tickets add the observed-image association work to the
existing tracker. Preserve the parent issue, existing tickets 02–05, and the
implemented status and comments on ticket 05. Publish approved additions as
individual issue files numbered 06–12; this draft is not a combined ticket.

Existing candidate selection, delta application, and recovery contracts remain
covered by their existing tickets. Every new ticket includes behavior tests at
the confirmed existing seams. No separate prefactoring ticket is proposed:
the first association slice evolves the existing Store in place while keeping
unmigrated callers working.

## 06: Report verified Podman workload image identities

**What to build:** Podman application status identifies the content actually
used by its running workloads, even when the original tag moves. Preserve a
verified index identity when available and otherwise report the verified
platform manifest digest, using the workload's owning store.

**Blocked by:** None (can start immediately).

- [ ] Inspect immutable workload image identity rather than resolving its
  mutable declared reference as evidence of running content.
- [ ] Respect resolved RunAs and default agent-process storage ownership.
- [ ] Report one verified registry digest per observed image; do not relabel
  config IDs or blindly attach a desired index to running content.
- [ ] Maintain separate observed versions when workloads using the same
  reference run different content.
- [ ] Existing application status tests cover moved tags, owner isolation,
  shared images, and unavailable identity without changing lastDelta shape.
- [ ] Live Podman workloads verify tagged, index-pinned, and platform-pinned
  observations against registry objects and immutable running content.

## 07: Report verified CRI workload image identities

**What to build:** CRI application status reports verified identities of running
pod images and treats failed runtime inspection as insufficient association
evidence. Preserve a verified index identity when supported, otherwise use the
verified platform manifest.

**Blocked by:** None (can start immediately).

- [ ] Obtain image identity from the configured CRI runtime and running pod
  content, without treating opaque runtime IDs as registry digests.
- [ ] An immutable desired-reference fallback after inspection failure is not
  considered verified observation evidence by itself.
- [ ] Retain simultaneous old/new workload digests and one digest per observed
  image; do not infer a unique parent index from a platform manifest alone.
- [ ] Status tests cover inspection success/failure, repository matching,
  index/platform references, and unknown identity.
- [ ] Live MicroShift/CRI-O workloads verify the selected observation path;
  record the tested versions and retain the existing measurements as prior art.
- [ ] Exercise containerd separately when supported test access is available;
  record an unavailable environment as a verification gap, never as a pass.

## 08: Tie OS lastDelta to the booted image across restart

**What to build:** OS lastDelta describes the booted digest while a different
image is staged, then changes when that image is observed booted. The association
survives agent restart using per-image history in the existing status file.

**Blocked by:** None (can start immediately).

- [ ] Record an OS outcome with a verified associated digest instead of only
  its desired-target fingerprint; preserve the public lastDelta shape.
- [ ] Evolve the persisted format and existing concrete Store in place without
  clearing unrelated application records or breaking unmigrated callers.
- [ ] Preparing B while A is booted retains A's matching result. B's completed
  result remains unpublished and protected until bootc observes B.
- [ ] Restart preserves both relevant associations; unknown or mismatched
  booted identity withholds the outcome.
- [ ] Legacy records without verifiable digest association remain unpublished;
  corrupt state is nonfatal and persistence errors do not imply durability.
- [ ] Reject superseded completions while keeping still-observed old results;
  hint-only changes do not erase a valid association.
- [ ] Store and OS status tests cover staging, observation change, restart,
  stale writes, and failed persistence. Do not claim an OS eviction limit until
  the retention policy is settled in ticket 11.

## 09: Match application workload outcomes to one reported snapshot

**What to build:** Application lastDelta is computed from recorded per-image
outcomes matching the complete workload image snapshot emitted in that report,
including applications with many workloads and mixed rollout versions.

**Blocked by:** 06: Report verified Podman workload image identities;
07: Report verified CRI workload image identities.

- [ ] Extend the existing persisted Store to retain verified per-image outcome
  associations scoped by application, reference, owner, and OCI type.
- [ ] Extend the persisted format compatibly with the OS slice. This ticket can
  start without ticket 08: neither implementation assumes sole ownership of
  the shared persisted schema, and existing OS behavior continues to work.
- [ ] Gather and emit workload digests together; select an owned aggregate
  from exactly that snapshot through the existing Store interface.
- [ ] Shared scoped image identities reuse results; simultaneously observed
  old/new digests require separate matches, irrespective of replica count.
- [ ] Missing expected observations, unknown identities, missing results, or
  incomplete collection suppress publication. Never silently omit required
  volumes or parents: those applications remain suppressed until ticket 10.
- [ ] Combine matching results from different accepted attempts without
  recalculating delta work or caching an application aggregate.
- [ ] Preserve Partial, NotRequired neutrality, and deterministic fallback
  reason semantics. No digest fields are added to lastDelta.
- [ ] Preserve still-observed and completed active results across desired
  changes and restart. Reject stale completions and return owned copies.
- [ ] Store and emitted-status tests cover complete workload sets, many images,
  shared images, mixed rollout, restart, unknown identity, and delayed reporting.
- [ ] Exact verified digest matching works independently of the unresolved
  index/platform equivalence policy; unverified equivalence withholds status.

## 10: Include volumes and parent identities with lifecycle-safe collection

**What to build:** Applications with image-backed volumes and reported parent
artifacts receive lastDelta only when the full reported image set matches
recorded outcomes from the same application lifetime.

**Blocked by:** 09: Match application workload outcomes to one reported snapshot.

- [ ] Gather workload, image-backed volume, and applicable parent observations
  into an owned application snapshot with explicit completeness.
- [ ] Preserve artifact manifest identities and their existing full-artifact
  behavior; do not reinterpret them as executable-image platform manifests.
- [ ] Record and match outcomes for required reported parents and volume images
  using their correct storage ownership and OCI type.
- [ ] Validate application lifetime after separately gathered inputs; ordinary
  desired updates retain old matching results, while removal clears history.
- [ ] Recreated application names reject obsolete observations/completions;
  missing observations, including unobservable expected workloads, suppress
  the complete aggregate rather than mixing different lifetimes.
- [ ] Existing Store, application status, and volume/parent collection tests
  exercise updates during collection, restart, removal/recreation, and mixed
  workload/volume results without adding new mock-only interfaces.

## 11: Bound history while protecting observed and unreported results

**What to build:** Retained outcome history uses LRU eviction proportional to
application image count, without losing previous observed or completed active
results during rollout, incomplete collection, restart, or reporting failure.

**Blocked by:** 08: Tie OS lastDelta to the booted image across restart;
10: Include volumes and parent identities with lifecycle-safe collection.

**Confirmed policy:** Application capacity is `2 × max(complete observed
distinct scoped image count, active-update distinct image count)`. Count
required image-backed volumes and parent artifacts, and deduplicate replicas.
Complete status collection refreshes recency even if sending later fails;
persist that recency with the next normal state write. Keep two OS records and
allow protected overflow. Preserve the first accepted outcome for a scoped
digest.

- [x] Enforce the confirmed counting and overflow policies without evicting
  protected records or treating incomplete collections as shrinkage evidence.
- [x] Protect the previous complete observed set, exact active-update results,
  and completed outcomes not yet selected into a complete application result.
- [x] Persist recency and protection in the existing state file with retry after
  a failed write; status selection performs no disk write.
- [x] Return owned status values so eviction cannot alter a prepared report.
- [x] Store tests cover 12 distinct images plus replicas, proportional capacity,
  LRU, incomplete collection, pending results, restart, deferred writes, write
  retry, and the two-record OS retention rule.

## 12: Preserve verified identity through reconstructed-image reporting

**What to build:** A successful delta update reports a verified observed identity
and matching lastDelta through the actual OS, Podman, and CRI paths, while
multi-platform generation continues to use platform manifests internally.

**Blocked by:** 08: Tie OS lastDelta to the booted image across restart;
10: Include volumes and parent identities with lifecycle-safe collection.

**Decision gate:** Confirm the index/platform equivalence evidence policy before
enabling matches across different digest representations. Verified exact matches
remain usable without that extension.

- [ ] Exercise actual reconstructed delta images, including canonical refresh,
  instead of deriving runtime identity behavior from ordinary-pull fixtures.
- [ ] Where reconstructed and canonical manifests differ, retain only an
  association verified against the content actually observed; otherwise
  withhold lastDelta rather than claiming canonical identity.
- [ ] Preserve a verified index when retained for observed content; report the
  verified platform manifest when index provenance is unavailable.
- [ ] Validate any permitted cross-representation match against the selected
  platform relationship outside Store/monitor locks, without adding redundant
  digest aliases to history.
- [ ] Verify that a reported source index plus device platform resolves to
  source/target platform manifests in generation; do not change the public
  status shape or introduce a new server generation workflow.
- [ ] Live verification covers reconstructed Podman and CRI content and a
  bootc update, including multi-platform bootc when the environment supports it.
  Record tested versions, measurements, and unresolved environment gaps.
- [ ] Extend existing behavior tests for any fixes revealed by those workloads;
  runtime measurements and emitted digest/outcome pairs are acceptance evidence.

## Review questions

Does this granularity feel right? Are the blocking edges limited to genuine
prerequisites? Should any tickets be merged or split before publication?

Tickets 06, 07, and 08 form the initial frontier. Ticket 09 follows 06 and 07;
10 follows 09; 11 and 12 can run independently once 08 and 10 are complete and
their respective decision gates are satisfied. Policy resolution can happen
earlier; implementation must not invent acceptance of open proposals.
