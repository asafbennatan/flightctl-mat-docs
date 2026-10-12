# 11: Bound history while protecting observed and unreported results

**What to build:** Retained outcome history uses LRU eviction proportional to
application image count, without losing previous observed or completed active
results during rollout, incomplete collection, restart, or reporting failure.

**Status:** implemented

**Blocked by:** 08: Tie OS lastDelta to the booted image across restart;
10: Include volumes and parent identities with lifecycle-safe collection.

**Policy:** Apply the confirmed counting, overflow, collection-recency, deferred recency persistence, two-record OS history, and original-outcome preservation rules in the spec.

- [x] Apply and document the confirmed policies without evicting protected records
  to satisfy a numeric limit or treating incomplete collections as shrinkage
  evidence.
- [x] Application capacity follows `2 × max(complete observed distinct scoped
  image count, active-update distinct image count)`;
  replicas sharing a scoped image do not consume independent history slots.
- [x] Protect the previous complete observed set and active results, including
  results completed before their first report; superseded unprotected history
  is eligible for LRU eviction.
- [x] Preserve required association and protection state across restart using
  the existing persisted file, with explicit persistence failure handling.
- [x] A selected owned status remains valid after later eviction and a failed
  network push. Incomplete discovery/observation does not release protection.
- [x] Store and emitted-status tests demonstrate applications larger than
  eight images, growth/shrink, overlapping versions, pending results, restart,
  and approved recency/overflow behavior.

Application recency and protection are persisted in state version 4. Complete
collection updates them in memory and returns an owned aggregate; the next
normal store write persists the change. Store tests cover 30 scoped identities,
the 12-image/24-record capacity, replica deduplication, LRU selection, restart,
incomplete collection, pending outcomes, write retry, and protected two-record
OS overflow. The application volume collection also brackets artifact identity
reads so an in-place update with unchanged `CreatedAt` withholds `lastDelta`.
An emitted-status test verifies the reported digest set and aggregate outcome
for a 12-workload application.
