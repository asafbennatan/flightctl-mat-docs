---
status: proposed
---
# Keep observed image digests separate from delta outcomes

Applying an OCI delta can reconstruct an image whose manifest digest differs from the canonical target, while the agent must still report the digest observed from the subsystem that owns the image. Keep desired image references/digests and runtime-observed image digests in image status; keep `lastDelta` to the agent outcome and optional fallback reason, with source-image, target-image, reconstructed-manifest, observed-image, and artifact digests treated as distinct identities. Use this contract for OS and application targets, including digest-pinned CRI references, nested workload images, and image-backed volumes; retain the agreed full-target fallback, aggregation, and unchanged-target outcome lifetime semantics.

A published `lastDelta` must correspond to the observed image identities reported alongside it. A new OS target's outcome remains unpublished while the previous OS image is booted. Apply the same association rule to applications and their reported image sets, including multiple workload images and image-backed volumes, so preparation of new content does not attach its outcome to observations of previous content.

Publish an application's aggregate only when every image target in the complete reported application image set has a verified matching outcome and observations are complete and unambiguous. The matched outcomes may come from different update attempts; compute the aggregate for the images actually reported, including during a rollout. Do not require a precomputed complete update record. Missing expected observations withhold the aggregate, including workloads that have not created an observable image. `Partial` continues to describe mixed delta usage, not rollout progress. Gather and report application workload digests together, and match delta outcomes against that same gathered application image set.

Retain the previous result while its association with the reported image set remains verifiable, even when a new target is being prepared. Persist digest association evidence for new results across agent restarts. Older saved results without this evidence remain unpublished unless their association can be verified; matching references or application names alone are insufficient.

Keep the public `lastDelta` fields as `outcome` and optional `fallbackReason`. Enforce the association internally using the image identities reported in existing status fields.

Minimize the distinct digests retained to identify each image. Preserve index-based image references and their multi-platform release identity. Report one verified index digest when the owning subsystem retains that image's index identity; otherwise report the observed platform manifest digest. Do not expose both identities for the same observed image. The index must be verified against observed content, rather than copied from the desired spec. Delta generation must use source and target platform manifest digests for multi-platform images, resolving indexes to the appropriate platform before generation. An index digest must not substitute for a platform manifest digest in a generation request.

The [OCI index specification](https://github.com/opencontainers/image-spec/blob/v1.1.1/image-index.md) defines an index as a higher-level object referencing manifests across platforms. Its digest identifies that publication as a whole. A [platform manifest](https://github.com/opencontainers/image-spec/blob/v1.1.1/manifest.md) identifies one image's configuration and layers. OCI does not designate either digest as universally preferred. Using platform manifests for delta generation does not by itself require replacing index-based desired references or standardizing public status fields on platform digests. One platform manifest can be referenced by multiple indexes, so observing it alone cannot establish a unique parent index.

The production control plane already accepts reported source indexes: `InspectImageDigestPair` resolves the source index using the device platform and selects a compatible target manifest before returning the generation pair. Therefore, generation compatibility alone does not justify platform-only reported status. Associate `lastDelta` with the verified digest reported alongside it, using one associated digest per image target in history rather than duplicating index, platform, config, source, or reconstructed-manifest identities there. Platform resolution remains internal to verification and generation.

Actual runtime observations below disprove a universal platform-manifest-only assumption. If index provenance is unavailable, use a verified observed platform manifest instead. Unknown image identities continue to withhold the aggregate under the observation-completeness rule above.

Compute an application's aggregate during status collection from retained per-image outcomes matched to the observed image set, preserving the existing aggregation mechanism. Do not cache a precomputed aggregate or require an aggregate cache key. Use a per-application, per-image LRU capacity of twice the application's workload image count, replacing the fixed eight-record limit. During updates, capacity is twice the larger complete observed or active-update image count. Count distinct scoped image identities, including required volumes and parents, rather than replicas. Shrink only after complete collection; allow protected records to exceed capacity temporarily. OS history retains two records with the same protected-overflow rule.

Every used image needs an associated digest and recorded outcome; an aggregate alone cannot establish correspondence with reported images. Multiple workloads using the same image target share its mapping. A target's identity includes its image reference, storage owner, and OCI target type. Aggregation combines recorded outcomes without rerunning delta work or inventing a new per-image outcome.

Protect outcomes needed by the previous observed images and the active update, including completed active results that have not yet been reported. Superseded results are eligible for ordinary LRU eviction. The capacity policy must accommodate applications with more active image targets than the nominal history size. Return owned copies for status collection under the cache lock, so subsequent eviction cannot invalidate selected results. Application removal or recreation must invalidate the corresponding collection before an obsolete result is attached. Complete status collection refreshes matched-result recency regardless of network delivery success. Persist recency with the next normal state write rather than writing during collection. Preserve already-recorded outcomes when an image is encountered again. Record the exact verified digest supplied by the owning runtime and require that digest for matching; preserving an index does not require storing or matching platform aliases.

## Collection limitations found by code inspection

Current CRI collection can report an immutable reference's index digest when runtime inspection fails. `TestKubernetesMonitorReportsCRIObservedDigest` covers both successful platform-digest resolution and this fallback. Therefore, the current reported digest is not guaranteed to identify a platform manifest. The [OCI image index specification](https://github.com/opencontainers/image-spec/blob/main/image-index.md) also distinguishes an index from the manifests it references.

Current Podman workload collection inspects the event's image reference instead of the running container's immutable image identity. A digest resolved through a moving tag is insufficient evidence of the running container's content. These limitations must be addressed or treated as insufficient association evidence; the policy remains open.

Application parent references can also report artifact manifest digests. Podman and bootc digest collection forwards subsystem values without normalizing them to platform manifest digests. Verification of these paths against actual runtime output remains necessary before promising platform-only reporting.

## Actual runtime verification

On 12 October 2026, the running Flight Control test VM used bootc 1.16.13 and Podman 5.8.5. The booted and rollback OS digests exactly matched the SHA256 of their raw registry manifests. Both registry objects were single-platform OCI image manifests; multi-platform bootc behavior was not tested.

A temporary Alpine 3.22 workload on that VM was pulled through an immutable multi-platform index reference. Inspecting its image through the running container's immutable image ID returned the index digest in Podman's `.Digest`, while `.RepoDigests` included both the index and the linux/amd64 child manifest digest. Therefore, even an actual workload observation can expose an index digest rather than a platform manifest digest.

Repeat workload verification used fresh image stores for tagged, index-pinned, and platform-pinned Alpine references. Results agreed on VM Podman 5.8.5 with overlay storage and host Podman 5.8.7 with rootless VFS storage:

| Pull and run reference | Image `.Digest` by reference | Image `.Digest` by immutable image ID | Hash of stored raw manifest |
| --- | --- | --- | --- |
| Tag | Platform manifest | Index | Platform manifest |
| Index digest | Index | Index | Platform manifest |
| Platform manifest digest | Platform manifest | Platform manifest | Platform manifest |

The running container's `.ImageDigest` matched the index in the first two cases and the platform manifest in the third. Thus, inspection selectors and the pulled reference affect Podman digest metadata. Current Flight Control reference-based collection produces the platform digest for the tested tagged and platform-pinned references, but the index digest for the tested index-pinned reference. The earlier immutable-image-ID observation alone did not establish the tagged-reference behavior.

Hashing the stored raw manifest selected through the running container's immutable image ID matched the registry's desired platform manifest in all three cases. This provides a verified platform identity for these ordinary-pull workloads. Reconstructed delta images were not exercised by this repeat test.

Raw manifest hashes verified both digests. The child manifest's config digest matched the running container's immutable image ID. The probe container and newly pulled image were removed after inspection. Agent and OS configuration were unchanged.

The VM has no installed MicroShift or CRI-O service. A temporary isolated MINC container supplied MicroShift 4.19 and CRI-O 1.32.8 for actual workload verification. Both Alpine 3.22 pods, one tagged and one pinned to the immutable index digest, ran successfully. Kubernetes `imageID` and CRI container `imageRef` matched the linux/amd64 platform manifest digest. CRI image inspection reported a config-object ID and both platform and index repository digests. Raw registry manifest hashes and the platform manifest's config digest verified those relationships.

The temporary cluster container, isolated storage volume, and newly pulled cluster image were removed after measurement. The existing Flight Control agent remained active, and no VM host configuration was changed.

These measurements establish behavior for the tested versions and workloads. The repository's V12 image uses MicroShift 4.21, which was not tested here. Containerd and multi-platform bootc behavior remain unverified. Code inspection and test fixtures above are separate evidence and do not substitute for runtime verification.
