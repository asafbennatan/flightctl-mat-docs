# 09: Match application workload outcomes to one reported snapshot

**What to build:** Application lastDelta is computed from recorded per-image
outcomes matching the complete workload image snapshot emitted in that report,
including applications with many workloads and mixed rollout versions.

**Status:** implemented

**Blocked by:** 06: Report verified Podman workload image identities;
07: Report verified CRI workload image identities.

- [x] Extend the existing persisted Store to retain verified per-image outcome
  associations scoped by application, reference, owner, and OCI type.
- [x] Extend the persisted format compatibly with the OS slice. This ticket can
  start without ticket 08: neither implementation assumes sole ownership of
  the shared persisted schema, and existing OS behavior continues to work.
- [x] Gather and emit workload digests together; select an owned aggregate
  from exactly that snapshot through the existing Store interface.
- [x] Shared scoped image identities reuse results; simultaneously observed
  old/new digests require separate matches, irrespective of replica count.
- [x] Missing expected observations, unknown identities, missing results, or
  incomplete collection suppress publication. Never silently omit required
  volumes or parents: those applications remain suppressed until ticket 10.
- [x] Combine matching results from different accepted attempts without
  recalculating delta work or caching an application aggregate.
- [x] Preserve Partial, NotRequired neutrality, and deterministic fallback
  reason semantics. No digest fields are added to lastDelta.
- [x] Preserve still-observed and completed active results across desired
  changes and restart. Reject stale completions and return owned copies.
- [x] Store and emitted-status tests cover complete workload sets, many images,
  shared images, mixed rollout, restart, unknown identity, and delayed reporting.
- [x] Exact verified digest matching requires no index/platform equivalence
  extension; mismatched representations withhold status.

Implementation retains verified per-image history in the existing version-2
state file, independently of active desired-target records. The application
collector selects an owned aggregate from its owned complete workload snapshot;
legacy desired-only prefetch outcomes are never published. Workload coverage is
captured from the installed provider, and unknown replicas cannot be covered by
another replica or by provider fallback. Parent/volume coverage remains
conservatively withheld until ticket 10; retention policy remains ticket 11.

Successful Podman pulls bind the immutable returned image ID to its registry
digest. CRI recording verifies selected platform membership in local repository
metadata. Failed operations do not bind an observed history entry. Immutable
operation snapshots prevent a reused task from inheriting a newer target or
generation, including worker completion and retry state.

Validation: the application, dependency, Store, and client unit suites passed;
the Store, dependency, and application suites also passed with race detection;
repository `make lint`, `make lint-docs`, `make spellcheck-docs`, and
`git diff --check` passed. Coverage includes twelve images, shared replicas,
mixed rollout, restart, owner/runtime separation, unknown identity, immutable
Podman pull results, verified CRI platform membership, stale reused-task
completion, and owned status copies. Full combined-spec validation remains with
the integration branch.
