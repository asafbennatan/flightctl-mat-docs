# 12: Preserve verified identity through reconstructed-image reporting

**What to build:** A successful delta update reports a verified observed identity
and matching lastDelta through the actual OS, Podman, and CRI paths, while
multi-platform generation continues to use platform manifests internally.

**Status:** ready-for-agent

**Blocked by:** 08: Tie OS lastDelta to the booted image across restart;
10: Include volumes and parent identities with lifecycle-safe collection.

**Policy:** Record and match exact verified owning-runtime digests. A cross-representation matching extension is outside this ticket.

- [ ] Exercise actual reconstructed delta images, including canonical refresh,
  instead of deriving runtime identity behavior from ordinary-pull fixtures.
- [ ] Where reconstructed and canonical manifests differ, retain only an
  association verified against the content actually observed; otherwise
  withhold lastDelta rather than claiming canonical identity.
- [ ] Preserve a verified index when retained for observed content; report the
  verified platform manifest when index provenance is unavailable.
- [ ] Withhold mismatched index/platform representations rather than adding
  digest aliases to history. Runtime identity verification happens outside
  Store/monitor locks.
- [ ] Verify that a reported source index plus device platform resolves to
  source/target platform manifests in generation; do not change the public
  status shape or introduce a new server generation workflow.
- [ ] Live verification covers reconstructed Podman and CRI content and a
  bootc update, including multi-platform bootc when the environment supports it.
  Record tested versions, measurements, and unresolved environment gaps.
- [ ] Extend existing behavior tests for any fixes revealed by those workloads;
  runtime measurements and emitted digest/outcome pairs are acceptance evidence.
