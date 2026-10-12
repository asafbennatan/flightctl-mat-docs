# Standardize agent-side OCI delta outcomes and image digest reporting

Status: ready-for-agent
Spec: [Feature spec](../spec.md)

## Summary

Standardize delta candidate selection, runtime-aware image digest reporting, and outcome semantics across OS and application image updates. Preserve each target type's existing storage and apply flow while keeping delta artifacts and intermediate data temporary and outcome state separate from image storage.

## Acceptance Criteria

- OS and application image status reports observed digests from bootc, the correct Podman user store, or the configured CRI runtime; desired image identity remains separate from lastDelta.
- Source image, desired target, reconstructed manifest, observed image, and delta artifact digests remain distinct. lastDelta contains only outcome and optional fallback reason.
- Image index digests, selected platform manifest digests, and runtime image IDs remain distinct; observed digest status comes from the owning subsystem.
- A hinted delta's source digest comes from its artifact metadata and must be available in the target's owning store before apply.
- Discovery considers related referrers in the desired target's repository, filters to locally available source images in the owning store, and selects the smallest total downloadable delta with deterministic tie-breaking.
- Digest-pinned CRI image references remain eligible for delta application and refresh the exact requested reference after import.
- Delta download, reconstruction, import, staging, visibility, or refresh failures report Fallback with a reason and attempt the full target. An unusable hinted target, including a top-level OCI artifact, follows the same rule.
- No selected candidate and no failed hint report NotUsed when an update proceeds without a delta; an already-present desired target with the correct digest reports NotRequired.
- Application Partial, deterministic fallback-reason selection, full-target recovery, and reconciliation failure follow the spec.
- VM images and image-backed volumes are collected from native Quadlet constructs with the resolved RunAs owner. Compose nested images remain eligible; top-level Podman artifacts and Helm chart packages stay on their existing non-delta paths; Helm-rendered workload images use CRI.
- Delta archives and intermediate apply products remain temporary; reconstructed and final targets use their existing OS, per-user Podman, or CRI runtime store. Outcomes persist separately and survive restart for unchanged target identities.
- Outcome state resets for changed image targets but remains for hint-only changes.

## Testing

Extend the OS manager and application PrefetchManager behavior suites, and assert runtime-observed digests in the existing OS and application status tests. Cover VM native Quadlet target collection through existing Quadlet coverage. See the spec for detailed cases and prior art.

## Comments
