# 08: Tie OS lastDelta to the booted image across restart

**What to build:** OS lastDelta describes the booted digest while a different
image is staged, then changes when that image is observed booted. The association
survives agent restart using per-image history in the existing status file.

**Status:** implemented

**Blocked by:** None (can start immediately).

- [x] Record an OS outcome with a verified associated digest instead of only
  its desired-target fingerprint; preserve the public lastDelta shape.
- [x] Evolve the persisted format and existing concrete Store in place without
  clearing unrelated application records or breaking unmigrated callers.
- [x] Preparing B while A is booted retains A's matching result. B's completed
  result remains unpublished and protected until bootc observes B.
- [x] Restart preserves both relevant associations; unknown or mismatched
  booted identity withholds the outcome.
- [x] Legacy records without verifiable digest association remain unpublished;
  corrupt state is nonfatal and persistence errors do not imply durability.
- [x] Reject superseded completions while keeping still-observed old results;
  hint-only changes do not erase a valid association.
- [x] Store and OS status tests cover staging, observation change, restart,
  stale writes, and failed persistence. Do not claim an OS eviction limit until
  the retention policy is settled in ticket 11.

Implementation retains verified OS image history in the existing versioned state file and selects the exact booted reference/digest for status. Legacy OS results remain unpublished while application records are preserved. Focused OS and Store tests passed with race detection, including staged-to-booted changes across restart, stale writes, corrupt/legacy state, and failed persistence retries. Capacity and eviction remain delegated to ticket 11.
