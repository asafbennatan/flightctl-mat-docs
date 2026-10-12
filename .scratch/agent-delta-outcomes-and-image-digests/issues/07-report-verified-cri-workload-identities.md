# 07: Report verified CRI workload image identities

**What to build:** CRI application status reports verified identities of running
pod images and treats failed runtime inspection as insufficient association
evidence. Preserve a verified index identity when supported, otherwise use the
verified platform manifest.

**Status:** implemented

**Blocked by:** None (can start immediately).

- [x] Obtain image identity from the configured CRI runtime and running pod
  content, without treating opaque runtime IDs as registry digests.
- [x] An immutable desired-reference fallback after inspection failure is not
  considered verified observation evidence by itself.
- [x] Retain simultaneous old/new workload digests and one digest per observed
  image; do not infer a unique parent index from a platform manifest alone.
- [x] Status tests cover inspection success/failure, repository matching,
  index/platform references, and unknown identity.
- [x] Live MicroShift/CRI-O workloads verify the selected observation path;
  record the tested versions and retain the existing measurements as prior art.
- [x] Exercise containerd separately when supported test access is available;
  record an unavailable environment as a verification gap, never as a pass.

## Validation

Application status tests first reproduced reporting the desired index after
failed CRI inspection, then passed with unknown observed identity. A second
red/green case reproduced selecting the first repository digest from an
ambiguous index/platform list. Status now withholds that observation instead
of interpreting list order as evidence. Coverage includes configured-runtime
inspection, matching repositories, init containers, absent identity, opaque
IDs, duplicate digests, verified index/platform identities, and simultaneous
old/new pods sharing one reference.

Focused application tests passed with the race detector, including after
merging the Podman and OS integration changes. Repository lint, documentation
lint, and documentation spelling checks passed. Full repository checks run
on the assembled integration branch.

A fresh isolated MINC cluster repeated actual workloads on MicroShift 4.19,
CRI-O 1.32.8, and cri-tools 1.32.0. Tagged, index-pinned, and platform-pinned
Alpine pods were Running and Ready. Each pod's repository-qualified image ID
and its CRI container imageRef matched the platform manifest's independently
hashed registry content. This verifies the direct observed runtime identity
path; it does not prove parent-index provenance. The isolated cluster,
storage volume, and newly pulled cluster image were removed; the existing
agent remained active. Runtime evidence accompanies this ticket.

Containerd access is unavailable and remains a verification gap. The tested
MicroShift 4.19 container does not establish behavior for the repository's
MicroShift 4.21 image. Opaque-ID inspection is covered by status tests; these
live CRI-O pods emitted repository-qualified image IDs. These limitations
are recorded as gaps, not passes for those environments.
