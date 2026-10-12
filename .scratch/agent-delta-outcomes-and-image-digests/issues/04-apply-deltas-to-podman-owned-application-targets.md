# 04: Apply deltas to Podman-owned application targets

**What to build:** Podman application image targets use the store belonging to the application's resolved RunAs user, apply only deltas whose source image exists in that store, refresh the canonical desired reference, and recover through the existing full-target path when delta use fails.

**Blocked by:** 03: Select and apply locally usable OS deltas.

Status: ready-for-agent

- [ ] Container and Quadlet image targets use the Podman store for the resolved RunAs user; an unset RunAs uses the existing agent-process user context.
- [ ] A hinted delta's OCI subject digest matches the resolved target platform manifest; its source image digest comes from artifact metadata and is checked in the target's owning Podman store.
- [ ] Discovery lists OCI 1.1 referrers for the exact resolved target platform manifest digest in the desired image's repository, filters by local source availability in that Podman store, and selects the smallest total downloadable delta with deterministic tie-breaking.
- [ ] Delta archives and apply intermediates remain temporary; reconstructed images and refreshed canonical desired references land in the same Podman store as the source and workload.
- [ ] A successful delta refreshes the canonical desired image reference through Podman before reporting Applied.
- [ ] Delta download, reconstruction, import, or refresh failures report Fallback with a reason and attempt a full Podman pull; reconciliation continues if that pull succeeds.
- [ ] Native Quadlet image targets and image-backed volume targets, including VM targets rendered as native Quadlet, remain eligible for deltas and carry the resolved RunAs owner.
- [ ] Nested Compose workload images remain eligible for deltas. The top-level Podman artifact stays on full artifact handling; without a failed hint it reports NotUsed, and an unusable supplied hint reports Fallback with a reason before the full artifact pull.
- [ ] Application outcome aggregation reports Partial only when at least one target is Applied and another is NotUsed or Fallback. NotRequired targets remain neutral.
- [ ] When multiple targets fall back, the application reports the lexically first fallback reason.
- [ ] Application outcomes survive restart for unchanged target identities, reset for changed image targets, and remain for hint-only changes.
- [ ] PrefetchManager and existing Quadlet collection tests cover RunAs storage, nested images, image-backed volumes, native VM Quadlet targets, artifact hints, fallback, aggregation, and persistence.
