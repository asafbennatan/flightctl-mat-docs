# 02: Report runtime-observed image digests separately

**What to build:** Device status reports image digests observed by the subsystem that owns each image, independently from the desired target and delta apply outcome.

**Blocked by:** None (can start immediately).

Status: ready-for-agent

- [ ] OS image status uses the digest observed by bootc.
- [ ] Application image status uses the relevant Podman store for Podman images and the configured CRI runtime for CRI workload images.
- [ ] Podman image digest inspection uses the application's resolved RunAs identity; targets without RunAs use the existing agent-process user context.
- [ ] Nested workload images and image-backed volumes that are currently reported continue to appear with their observed registry digests.
- [ ] Desired image identity remains in its existing representation, separate from lastDelta.
- [ ] Image index digests, selected platform manifest digests, and opaque runtime image IDs follow the existing status contract and are not conflated.
- [ ] lastDelta contains only the delta outcome and optional fallback reason.
- [ ] Existing OS and application status tests assert the runtime-observed digests, including Podman owner, CRI, nested workload, and volume cases.
