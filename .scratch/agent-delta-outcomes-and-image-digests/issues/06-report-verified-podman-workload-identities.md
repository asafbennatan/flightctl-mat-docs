# 06: Report verified Podman workload image identities

**What to build:** Podman application status identifies the content actually
used by its running workloads, even when the original tag moves. Preserve a
verified index identity when available and otherwise report the verified
platform manifest digest, using the workload's owning store.

**Status:** implemented

**Blocked by:** None (can start immediately).

- [x] Inspect immutable workload image identity rather than resolving its
  mutable declared reference as evidence of running content.
- [x] Respect resolved RunAs and default agent-process storage ownership.
- [x] Report one verified registry digest per observed image; do not relabel
  config IDs or blindly attach a desired index to running content.
- [x] Maintain separate observed versions when workloads using the same
  reference run different content.
- [x] Existing application status tests cover moved tags, owner isolation,
  shared images, and unavailable identity without changing lastDelta shape.
- [x] Live Podman workloads verify tagged, index-pinned, and platform-pinned
  observations against registry objects and immutable running content.

## Validation

Application Status tests first reproduced reporting a moved tag's new digest
for an old running container, then passed with immutable container inspection.
Coverage includes separate running versions, shared images, resolved RunAs,
default agent-process ownership, failed inspection, and opaque IDs. Existing
VM health and event monitoring tests remain green.

Focused application and Podman client suites passed with the race detector.
A fresh rootless Podman 5.8.7 store repeated tagged, index-pinned, and
platform-pinned live workloads. Raw registry and local manifest hashes matched
the selected platform; container identity retained the index for tag/index
pulls and the platform digest for platform-pinned pulls. A separate live
moving-tag experiment replaced the original tag with a different Alpine
version while its old container remained running: the container retained its
original image and index digest, while reference inspection selected new
content. Both experiments confirmed removal of their containers and temporary
stores. Runtime evidence accompanies this ticket.

The shared architecture documentation is updated with the integration branch's
final status behavior. Full repository checks run after all slices are merged.
