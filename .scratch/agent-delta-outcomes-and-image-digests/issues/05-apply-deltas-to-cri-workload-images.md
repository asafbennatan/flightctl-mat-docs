# 05: Apply deltas to CRI workload images, including digest-pinned targets

**What to build:** CRI workload image targets use the configured CRI runtime's image store for source checks and delta imports, including digest-pinned references. After reconstruction, the agent refreshes the exact desired reference through CRI and uses a full CRI pull when delta use fails.

**Blocked by:** 03: Select and apply locally usable OS deltas.

Status: implemented

- [x] A hinted delta's OCI subject digest matches the resolved target platform manifest; its source image digest comes from artifact metadata and is checked in the configured CRI runtime store.
- [x] Discovery lists OCI 1.1 referrers for the exact resolved target platform manifest digest in the desired image's repository, filters candidates to source images available in that CRI store, and selects the smallest total downloadable delta with deterministic tie-breaking.
- [x] CRI-O imports the reconstructed image into storage visible to CRI; containerd imports through its configured endpoint and workload namespace. The existing runtime visibility check remains part of the apply result.
- [x] Digest-pinned CRI references remain eligible for delta application, and the exact requested reference is used for the post-import CRI pull.
- [x] Applied is reported only after reconstruction, runtime import and visibility, and canonical desired-reference refresh succeed.
- [x] Delta download, reconstruction, import, visibility, or refresh failures report Fallback with a reason and attempt a full CRI pull of the desired reference.
- [x] Reconciliation continues when the full CRI pull succeeds and fails when that recovery pull fails.
- [x] Helm chart packages continue through the Helm chart cache path; rendered workload images collected as CRI targets remain eligible for deltas.
- [x] CRI target outcomes participate in the existing application aggregation and persistence contract.
- [x] PrefetchManager tests cover CRI-O and containerd imports, local source availability, digest-pinned references, canonical refresh, fallback, and application status.

## Comments

Implemented configured CRI source validation and deterministic delta discovery, digest-pinned imports and canonical refresh, and full-pull recovery. Added PrefetchManager behavior coverage for CRI-O and containerd, Helm chart caching, application status, and outcome persistence.

Validation: focused package tests, full unit suite (9,308 tests, 2 skipped, with race detection and coverage), Go lint, documentation lint, and spelling checks passed. Standards and spec reviews found no issues. Integration testing was stopped at the user's request.
