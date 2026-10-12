# Associate agent delta outcomes with reported image digests

Status: ready-for-agent

## Problem Statement

The agent updates OS images and application images through separate delta flows. Operators need to know which image digest the device actually observes, while the agent also needs to report whether it applied a delta, skipped delta work, or fell back to a full target pull. Those are different facts, but current behavior can mix their meanings. Preparing a new image can publish its delta outcome while the device still reports the previous booted OS or running workload images. Persisted outcomes currently follow desired-target fingerprints, which do not establish their association with the reported images.

Outcome semantics and candidate choice also differ between the flows: an OS image that is already present can be reported as NotUsed while an application target reports NotRequired, discovery can depend on registry ordering, and digest-pinned CRI targets currently take the full-pull path. Operators need the same outcome meanings and predictable delta selection across both flows.

Application targets also use different OCI stores. A Podman image may belong to the Unix user selected by RunAs, while Helm-rendered images belong to the configured CRI runtime. A source image in one store does not prove that the same reference is available in another. VM workloads reach the agent as native Quadlet units, and image-backed workload or volume references should remain eligible for delta updates. Top-level Podman artifacts and Helm charts have different full-pull/cache paths and are not image-delta targets.

The agent must support both explicit delta hints and discovery, including digest-pinned CRI image references. A failed or unusable delta must not prevent an otherwise successful full image update.

## Solution

Use one delta contract for OS and application targets while keeping each target type's existing reconstruction, import, staging, and refresh flow. A hint identifies the candidate delta artifact; the source image digest must come from that artifact's metadata and be available in the target's owning store. Without a hint, discover related deltas in the desired target's repository, retain only candidates whose source image is available in the owning store, and select the smallest candidate.

Keep delta opportunistic. If a supplied or selected candidate cannot be used, report Fallback with a reason and try the full target operation. If no candidate was selected and no hinted candidate failed, report NotUsed and use the normal full-target path. Reconciliation fails only if the required full-target operation fails.

Report actual observed image digests through the subsystem that owns each image, independently of delta application. Keep desired image identity outside lastDelta, which contains only the agent-side outcome and optional fallback reason. Publish lastDelta only from recorded outcomes that verifiably match the observed image digests reported alongside it. Persist per-image digest-associated history and compute the application aggregate during status collection from the same complete gathered image set. Keep previous observed outcomes while the next update is prepared, including across restart. Preserve a verified index identity when available; otherwise report a verified platform manifest digest. Resolve multi-platform indexes to platform manifests internally for delta generation.

## User Stories

1. As a device operator, I want OS status to report the digest observed by bootc, so that I can tell which OS image the device is running.
2. As an application operator, I want image status to use digests observed by the owning Podman or CRI runtime, so that status describes the images on the device rather than metadata inferred from a delta.
3. As an operator, I want the desired image reference or digest represented separately from the observed image digest, so that I can compare the requested target with what the runtime reports.
4. As an operator, I want lastDelta to contain only the delta outcome and optional fallback reason, so that image identities remain separate from apply status.
5. As an agent, I want source image, desired target, reconstructed manifest, observed image, and delta artifact digests treated as separate identities, so that each digest is used for its intended purpose.
6. As an agent, I want NotRequired when the desired target is already present with the correct digest, so that an already-satisfied update is not described as a skipped delta.
7. As an agent, I want NotUsed when an update needs the target but no delta candidate is selected, so that a normal full pull is distinguishable from a failed delta attempt.
8. As an agent, I want an update with no hint and no eligible discovered delta to use the full-target path and report NotUsed, so that delta remains an optional optimization.
9. As an agent, I want a hinted delta's source image digest read from the delta artifact metadata, so that source checks use the artifact's declared base.
10. As an agent, I want a hinted delta's source image checked in the storage that owns the target, so that an image present in another runtime store is not treated as usable.
11. As an operator, I want a hinted delta whose source image is unavailable to report Fallback with a reason and attempt the full target, so that recovery is visible and can still complete.
12. As an operator, I want a supplied hint that cannot be used for the target form to report Fallback with a reason and use the full-target path, so that every failed hint has consistent semantics even if no apply command ran.
13. As an agent, I want discovery to consider related OCI delta referrers from the desired image's repository, so that discovery does not select a delta from an unrelated repository.
14. As an agent, I want discovery to retain only deltas whose declared source image is available in the target's owning store, so that selected candidates can be applied without fetching a separate base image.
15. As an operator, I want the smallest locally usable discovered delta selected, so that the agent transfers the least delta data.
16. As an operator, I want equal-sized candidates selected deterministically, so that repeated reconciliations choose consistently.
17. As an application operator, I want digest-pinned CRI image references to remain eligible for delta application, so that immutable workload targets can use delta updates.
18. As an agent, I want the exact requested digest-pinned CRI reference used when refreshing the target after reconstruction, so that the runtime records the canonical requested manifest identity.
19. As an agent, I want a successful delta to be reported as Applied only after reconstruction, import or staging, and canonical target refresh all succeed, so that Applied describes a completed target update.
20. As an operator, I want delta download, reconstruction, import, stage, visibility-check, or refresh failures to report Fallback with a reason and attempt the full target, so that a failure in an optimization does not stop reconciliation.
21. As an operator, I want reconciliation to continue when full-target recovery succeeds, so that a failed delta does not fail a successful image update.
22. As an operator, I want reconciliation to fail when the required full-target operation also fails, so that a real inability to obtain the desired image remains visible.
23. As an application operator, I want Container and Quadlet image targets to use the Podman store selected by the application's RunAs identity, so that delta source checks and imports use the same store as the workload.
24. As an application operator, I want targets with no explicit RunAs to continue using the existing agent-process user context, so that delta behavior matches current Podman ownership.
25. As an agent, I want target identity and source checks to distinguish runtime type and storage owner, so that the same image reference in Podman and CRI storage is not conflated.
26. As an application operator, I want nested workload image targets to remain eligible for delta updates, so that images inside a Compose bundle or other parent application can be updated independently.
27. As an application operator, I want image-backed application volumes to remain eligible for delta updates, so that volume image content can be updated without requiring every layer to be transferred.
28. As a VM operator, I want image references in the VM's native Quadlet units to be collected as image targets, so that VM workloads use the same delta behavior as other Quadlet workloads.
29. As a VM operator, I want image-backed VM volume references in native Quadlet units to be collected as image targets, so that delta updates can apply to those volumes when a local source is available.
30. As a Helm operator, I want chart packages to continue through the Helm chart cache path while rendered workload images use the configured CRI store, so that each Helm target is handled by its owning subsystem.
31. As a Compose operator, I want the top-level Podman artifact to continue through full artifact handling while its nested images remain eligible for deltas, so that a small Compose bundle does not require image-delta reconstruction.
32. As an operator, I want a hinted top-level OCI artifact that cannot use image-delta reconstruction to report Fallback with a reason, so that the agent explains why it used the full artifact path.
33. As an operator, I want the agent to keep using native Quadlet constructs for VM workloads, so that VM image discovery does not depend on treating them as .kube YAML.
34. As an application operator, I want Partial only when at least one image target is Applied and another is NotUsed or Fallback, so that mixed results are represented accurately.
35. As an application operator, I want NotRequired targets to remain neutral during aggregation, so that a target already at its desired digest does not make an otherwise Applied application Partial.
36. As an application operator, I want one deterministic representative fallback reason when several targets fall back, so that the current status shape remains stable and useful.
37. As an operator, I want outcomes and their verified image associations retained across restart, so that a restart does not erase the result for images still observed.
38. As an operator, I want lastDelta selected using observed image identities when the desired target changes, so that a pending update does not replace the result for images still running.
39. As an operator, I want a delta-hint-only change to preserve the outcome for an unchanged target, so that changing optimization metadata alone does not reset target history.
40. As an application operator, I want a runtime image ID kept distinct from a registry digest, so that opaque runtime identifiers are not reported as image digests.

41. As an OS operator, I want a staged update's delta outcome withheld while the previous OS is booted, so that lastDelta describes the reported booted digest.
42. As an application operator, I want all workload digests gathered and reported together, so that the aggregate describes the same application image snapshot.
43. As an application operator, I want an aggregate covering every reported workload image and image-backed volume, so that one result does not hide an unrelated image's delta behavior.
44. As an application operator, I want the aggregate withheld when expected observations or matching outcomes are missing, so that incomplete collection does not imply complete evidence.
45. As an application operator, I want recorded outcomes from different update attempts combined when they match a mixed rollout's observed images, so that status remains accurate during rollout.
46. As an application operator, I want Partial to retain its delta-usage meaning, so that rollout progress is not confused with mixed delta usage.
47. As an agent, I want multiple workloads using the same scoped image to share a result, so that cache sizing follows image identities rather than workload replica count.
48. As an agent, I want old and new digests running simultaneously to have separate result matches, so that a moving tag cannot collapse different observed content.
49. As an operator, I want one verified digest reported per observed image, so that status identifies the image without duplicating index and platform identities.
50. As an operator, I want an available verified index identity preserved, so that a multi-platform release remains identifiable.
51. As an agent, I want platform manifest digests used for multi-platform delta generation, so that generation operates on the device's selected architecture.
52. As an agent, I want opaque config IDs and unverified desired references excluded from observed digest evidence, so that matching proves which content is held or running.
53. As an agent, I want history scoped by application, image reference, storage owner, and OCI type, so that unrelated image updates cannot supply each other's outcomes.
54. As an operator, I want completed active-update outcomes retained before their first report, so that status delivery timing does not erase useful results.
55. As an operator, I want previous observed outcomes protected during incomplete collection and failed reporting, so that an update or network failure does not silently lose their associations.
56. As an agent, I want per-application history capacity proportional to complete observed and active scoped image counts, so that large applications, required volumes, and parent artifacts remain supported.
57. As an agent, I want superseded unprotected history evicted using LRU policy, so that retained history remains controlled.
58. As an operator, I want removed applications' history cleared and obsolete collections rejected after recreation, so that a reused application name does not inherit another lifetime's result.
59. As an agent, I want stale update completions rejected without deleting still-observed previous outcomes, so that concurrency does not attach the wrong result.
60. As an operator, I want legacy records without verifiable digest association withheld, so that restart migration does not invent evidence.
61. As an agent, I want owned copies of selected status, so that later eviction cannot change a report being prepared or sent.
62. As a maintainer, I want digest behavior verified using actual workloads in the relevant runtime, so that fixture assumptions do not substitute for observed runtime behavior.

## Implementation Decisions

- Put shared candidate ranking and outcome rules in a small pure decision seam that consumes normalized candidate metadata and local-source availability. Keep storage probes and target-specific reconstruction, import, staging, and refresh in the existing OS manager and application PrefetchManager flows.
- Use the source digest declared by the selected delta artifact. Do not derive a source image digest from the desired image reference or target digest.
- For an explicit hint, inspect and validate the candidate, confirm its source image is available in the target's owning store, and then apply it. An unusable hint is Fallback with a reason, followed by the full target operation.
- For discovery, inspect related referrers in the desired target's repository. Keep OCI delta candidates whose declared source image is available in the owning store. Select the candidate with the lowest total downloadable artifact size; break ties by candidate reference in lexical order.
- Keep a digest-pinned CRI target eligible for delta application. After importing a reconstruction, refresh the exact requested reference through CRI so that the canonical registry manifest is recorded. A failed delta uses a full pull of that same reference.
- Use NotRequired when the desired target is already present with the correct digest. Use NotUsed when an update proceeds without a selected candidate and no hinted candidate failed. Use Applied only after all target-specific delta steps succeed. Use Fallback when a hinted or selected candidate is unusable or an operation fails, then attempt the full target.
- Keep OS and application update paths target-specific. The OS path uses the bootc-managed image store and stages its result through the existing bootc operations. Podman image paths use the storage owner selected by the application provider. CRI image paths use the configured CRI runtime and its existing import and visibility checks.
- Preserve application outcome aggregation: Partial requires at least one Applied target and at least one NotUsed or Fallback target. NotRequired is neutral. When there are multiple fallback reasons, report the lexically first reason.
- Evolve the existing concrete delta status Store in place. Keep its existing file I/O dependency and shared OS/application ownership. Its interface handles desired-scope reconciliation, verified per-image result recording, and result selection from a complete observed snapshot. Keep runtime commands and registry verification in their existing owning modules.
- Evolve the existing persisted delta status file to retain per-image digest-associated history for both OS and applications. Applications currently persist per-image outcomes rather than a precomputed aggregate, but their desired-target fingerprints are insufficient observation evidence. The OS currently retains only one desired-target outcome. Version the changed persisted format; legacy records without verified association remain unpublished unless verified.
- Associate each outcome with one verified image digest, image reference, storage owner, and OCI type within its OS/application scope. Keep attempt identity for rejecting stale writes separate from observed-image matching. Do not retain redundant source, config, reconstructed, index, and platform identities as extra history keys.
- Select lastDelta from the same observed image snapshot used for publication. Compute application aggregates from matching retained per-image outcomes during status collection. Do not cache a complete aggregate or rerun delta computation. Outcomes from different accepted attempts may combine during a mixed rollout.
- Require complete observations and matching outcomes for every required image. Include workload images, image-backed volumes, and applicable reported parent artifacts. Keep artifact manifest identities distinct from executable-image platform identities. Missing expected images, including workloads without observable images, withhold the aggregate.
- Retain matching previous outcomes across desired-target changes. Protect the previous complete observed set and active-update results, including completed results not yet observed. Incomplete collection must not release protection. Superseded unprotected history is eligible for LRU eviction.
- Use an application history capacity of `2 × max(complete observed distinct scoped image count, active-update distinct image count)`, replacing the fixed eight-record proposal. Count required volumes and parent artifacts, deduplicate replicas, and shrink only after complete collection; apply the confirmed protected overflow policy below.
- Under the store lock, match the complete snapshot and return owned copies so subsequent eviction cannot mutate a pending report. Gather application observations together and validate application lifetime across workload, volume, and parent collection. Application removal clears scope history; recreation rejects obsolete snapshots and completions.
- Separate application lifetime from active desired-update identity. A superseded completion cannot overwrite current work, while outcomes from previous legitimate attempts may still match currently running images. Do not derive lifecycle solely from desired-spec equality.
- Recording errors must not be interpreted as proof of durability. The current store changes memory before writing; define retry behavior through existing file I/O mechanisms. Result selection remains in-memory, with runtime verification performed before acquiring store locks.
- Keep the existing public status shape. Desired image identity remains outside lastDelta; image status continues to report observed digests from bootc, the correct Podman user store, or CRI. Do not add source, target, reconstructed, observed, or artifact digest fields to lastDelta.
- Report one verified index digest when the owning subsystem retains reliable index provenance for the observed content; otherwise use the verified observed platform manifest digest. Do not copy the desired index onto an old running image. An opaque runtime/config ID is not a registry digest, and a platform manifest alone cannot establish a unique parent index.
- Continue resolving source indexes using device platform and selecting a compatible target platform manifest in the control plane. Multi-platform delta generation uses source and target platform manifests; reporting a verified source index remains compatible with that resolution.
- Resolve workload identity from immutable runtime content. Reference-based Podman inspection of a moving tag is insufficient evidence of the running container. An immutable-reference fallback after failed CRI inspection is not automatically verified observation evidence.
- For VM applications, collect targets from the native Quadlet representation and carry the resolved RunAs owner to the Podman path. Do not introduce a .kube representation for VMs.
- Keep Helm chart resolution in its chart-cache path; apply delta behavior only to the rendered workload images that are collected as CRI image targets.
- Keep top-level Podman artifact handling on the existing full artifact path. A supplied image-delta hint for such an artifact reports Fallback with a reason before the full artifact pull; without a failed hint, it reports NotUsed. Nested image targets remain independently eligible.
- Do not broaden incomplete generic .kube target collection as part of this change. Existing generic .kube behavior remains separate from native Quadlet VM handling.

## Testing Decisions

- Confirmed primary seam: the existing delta status Store interface, using existing file I/O test facilities. Test externally observable recording, selection, restart, and eviction behavior; do not assert private cache structure or add mock-only interfaces. The user confirmed these existing seams: Store behavior, emitted OS/application digest–lastDelta pairs, and live runtime identity verification.
- Existing Store persistence, superseded-target, and reindexed-result tests provide prior art. Change the desired-target clearing expectation to preserve still-observed history. Cover old A while B is prepared, selection after B becomes observed, stale completions, incomplete collections, shared images, mixed rollout, removal/recreation, capacity pressure, and owned result copies.
- Extend existing OS manager and application status behavior tests to assert that each emitted lastDelta matches the digests emitted alongside it. Cover staged-but-not-booted OS updates and application snapshots spanning independently updated pods, image-backed volumes, and parent artifacts.
- Cover restart with protected completed-but-unreported results, legacy evidence-free state, corrupt state, write failures, and unknown identity. Cover mismatched index/platform representations withholding publication unless the exact verified recorded digest is observed.
- Preserve existing OS manager and application PrefetchManager behavior coverage for delta candidate ranking, ownership, digest-pinned CRI refresh, reconstruction/import/staging, fallback, aggregate outcome rules, and hint-only changes. Existing native Quadlet extraction tests cover VM image and image-backed volume discovery.
- Runtime identity tests must use actual bootc, Podman, and CRI workloads, independent of mocked status tests. Exercise tag changes, index-pinned and platform-pinned references, and reconstructed delta content. Verify registry object hashes and index/platform relationships against the running content. Repeated unit fixtures do not establish runtime digest semantics.
- Test the accepted capacity and recency contracts rather than incidental cache ordering. A delayed or failed network report must not alter an owned selected status or evict protected active results.

## Out of Scope

- New server-side delta-generation behavior, artifact creation, distribution, retention, or garbage collection. Preserve and verify existing index-to-platform generation resolution.
- Changes to the control-plane or public application status schema.
- Adding digest fields to lastDelta.
- Delta reconstruction for top-level OCI artifacts or Helm chart packages; they continue through their existing full artifact or chart-cache paths.
- Expanding generic .kube target extraction or changing how Kubernetes manifests are collected.
- Delta updates for non-image volumes, firmware, or target types outside OS images, application workload images, and image-backed volumes.
- UI, CLI, or control-plane presentation changes.

## Further Notes

### Confirmed retention and matching policies

These policies were clarified during implementation. Missing evidence must never be replaced with desired references:

- Confirmed retention policy: `2 × max(complete observed image count, active-update image count)`, counting distinct scoped image identities including required parents and image-backed volumes rather than replicas. Shrink only after complete collection. Permit temporary overflow for protected records.
- Recency: refresh matched records during complete status collection regardless of network delivery success. Persist recency with the next normal state write; do not add disk writes to status collection.
- Digest matching: record the verified digest supplied by the owning runtime and select by exact observed-digest match. Index preservation does not require a cross-representation matching extension. A mismatched representation withholds lastDelta; any future equivalence extension requires separate verified evidence.
- Protected overflow is confirmed: never evict protected records to meet a numeric limit; prune eligible history after complete observations release protection. Retain two OS records, allowing protected overflow.
- Preserve an already-recorded scoped digest outcome when the image is encountered again; synthetic NotRequired or NotUsed observations must not erase how that image was obtained. No unrelated attempt may overwrite it through a digest-only global key.

The retention counting, overflow, recency, and OS capacity policies were explicitly confirmed by the user. Exact verified matching needs no index/platform equivalence extension.

### Runtime evidence

Live verification on 12 October 2026 tested VM Podman 5.8.5, host Podman 5.8.7, bootc 1.16.13, and an isolated MicroShift 4.19 / CRI-O 1.32.8 container. Both Podman versions showed selector-dependent digest metadata: tag-based image inspection returned the platform manifest, while immutable-image-ID inspection and container ImageDigest retained an index for tag/index pulls. Platform-pinned pulls returned the platform digest. Stored raw manifests matched the platform manifest in all ordinary-pull cases.

MicroShift/CRI-O tagged and index-pinned pods reported the platform manifest in Kubernetes imageID and CRI imageRef; image inspection included both index and platform repository digests. An isolated bootc 1.16.13 VM staged and booted a real four-architecture index: its desired and booted references retained the index, while staged and booted `imageDigest` matched the independently verified amd64 child manifest. The previous digest remained booted until restart and then appeared as rollback; the initial image's registry was unavailable, so its raw manifest was not independently verified. These observations disprove a universal rule that every observed digest equals the desired platform manifest.

Reconstructed Podman and CRI images were exercised against actual content, and ordinary multi-platform bootc staging and target boot were verified. OCI-delta reconstructed bootc import/staging, containerd, and the repository's MicroShift 4.21 version remain unverified. Runtime probe evidence, including `bootc-update-evidence.json` and `bootc-update-notes.md`, and the proposed domain ADR accompany this spec in the local tracker. The older target-reset and platform-preference statements are superseded by this spec's observation association and verified-index policy.

### Storage context


The existing storage behavior is preserved. The source image remains in its owning runtime store; the downloaded delta and temporary apply products are cleaned up; the reconstructed image and refreshed desired reference go to the target's existing store; and the delta outcome is persisted separately. The target store does not hold every delta-related object.

| Digest identity | Use in the update | Reporting |
|---|---|---|
| Source image digest | Identifies the base declared by the delta artifact and is checked for availability in the target's owning store | Not included in lastDelta |
| Desired target digest | Identifies the desired registry target; an immutable requested reference is preserved through refresh | Remains in the existing desired-image representation, separate from lastDelta |
| Reconstructed manifest digest | Identifies the manifest produced by delta apply; it may differ from the canonical registry manifest | Used only for reconstruction/import; it does not replace the desired or observed digest |
| Observed image digest | Comes from bootc, the resolved Podman store, or CRI after the subsystem observes the image | Reported through the existing image digest status fields; prefer a verified index identity when retained for observed content, otherwise use the verified platform manifest digest |
| Image index digest | Identifies a multi-platform index and may differ from the selected platform manifest | Preserve it as the reported release identity only when verified against observed content; resolve it internally for platform-specific delta generation |
| Delta artifact digest | Identifies the OCI artifact being downloaded and applied | Not a source or target image digest and not included in lastDelta |
| Runtime image ID | Runtime-specific identifier that may be opaque | Keep distinct from registry digests; withhold lastDelta when the observed image identity cannot be verified |

| Target flow | Source image | Delta and intermediate data | Reconstructed or desired target | Delta outcome |
|---|---|---|---|---|
| OS image | Bootc-managed system image store | Delta archive and reconstructed OCI layout are temporary | Bootc stages the reconstructed content and desired registry reference in its managed system store | Agent delta status store |
| Podman image with RunAs, including native Quadlet VM images and image-backed volumes | Podman containers/storage for the resolved RunAs user; agent-process user when RunAs is unset | Delta archive in the existing owner-scoped temporary workspace; removed after use | Reconstructed image and refreshed canonical target reference in the same user's Podman store | Agent delta status store |
| Compose nested Podman image | Existing agent-process user's Podman store | Delta archive and intermediates are temporary | Reconstructed image and refreshed target reference in the same Podman store | Agent delta status store |
| CRI workload image, including Helm-rendered images | Configured CRI runtime image store | Delta archive and any source mount or reconstructed OCI archive are temporary | CRI-O imports into its CRI-visible containers/storage; containerd imports into the configured Kubernetes namespace, then CRI refreshes the target reference | Agent delta status store |
| Helm chart package | Helm chart cache | Not applicable; chart packages do not use OCI image deltas | Existing Helm chart cache | Not an image-delta target |
| Top-level Podman artifact | Existing Podman artifact path | Not applicable; artifact uses full artifact handling | Existing Podman artifact storage/path | Not an image-delta target; report NotUsed without a failed hint and Fallback with a reason for an unusable hint |

For application targets, the same image reference can exist in more than one runtime store. Candidate availability, import, refresh, and observed digest reporting must use the storage context selected for that target. Delta archives and intermediate data are not persistent source or target stores.
