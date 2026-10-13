# Image management

This context identifies images and describes the outcomes of applying deltas.

## Language

**Image reference** — A registry name that selects an image, optionally through a tag or digest.

**Digest-pinned image reference** — An image reference that names a registry object by digest instead of a mutable tag.

**Image index digest** — The digest of an image index that selects platform-specific manifests.

**Platform manifest digest** — The digest of an image manifest for one platform. For a multi-platform image, it can differ from the image index digest.

**Desired target digest** — The registry digest associated with the image selected as the desired update target. For a multi-platform image, it can identify the index rather than a platform manifest.

**OCI referrer subject digest** — The digest of the image object a referrer is associated with, such as an image index or image manifest. Referrer lookup is keyed by this digest. It identifies the subject object, not the referrer artifact or a manifest reconstructed by applying a delta.

**Source image digest** — The digest of the base image from which an OCI delta reconstructs a target image.

**Reconstructed manifest digest** — The digest of the image manifest produced by applying a delta. It can differ from the canonical manifest digest for the desired target image.

**Observed image digest** — A verified registry digest identifying the image currently held or run by its owning subsystem, independently of the delta outcome. For a multi-platform image, it is the verified index digest when that identity is available, otherwise the observed platform manifest digest.

**Delta artifact digest** — The digest identifying the OCI artifact that carries a delta. It identifies the delta artifact, not the source or target image.

**Runtime image ID** — An identifier assigned by an image runtime. It may be opaque and is not necessarily a registry image digest.

**OCI image delta** — An OCI artifact containing the changes needed to reconstruct a target image from a source image.

**Delta hint** — A reference supplied with an update to identify a specific delta artifact.

**Delta discovery** — Finding a delta related to a desired image when an update does not identify one directly.

**Delta candidate** — A validated OCI delta artifact considered for one target image, identified by its reference, source digest, target digest, and download size.

**Locally usable delta candidate** — A delta candidate whose source image exists in the store that will reconstruct the target. Remote-only or wrong-runtime sources do not qualify.

**Top-level application package** — The Helm chart or Compose/Quadlet package artifact that defines an application; it is not an OCI image-delta target.

**Canonical refresh reference** — The digest-pinned reference to the selected platform manifest used after reconstruction to establish the target image's registry identity.

**Delta apply outcome** — The agent's result for using a delta during an update. It describes the update attempt, separately from image identity.

**Last delta result** — The delta apply outcome associated with the observed image identities currently reported for an OS or application. An application's result describes its reported image set, including workload images and image-backed volumes.

**NotRequired** — The existing target image or top-level application package satisfies the agent's fetch rules, so neither a delta nor a full fetch is needed; a supplied image-delta hint does not change a top-level package no-op. This outcome does not imply a fresh registry digest verification.

**NotUsed** — Delta application was skipped without a delta-apply failure; a full image fetch may still be needed.

**Applied** — All delta work for the target succeeded, including any required canonical refresh.

**Fallback** — A hinted or selected delta could not be used or applied, so the agent attempted a full image pull. The result carries a reason.

**Partial** — An application update applied a delta to at least one image target and used no delta or fell back for another. Targets reported as `NotRequired` do not make the result partial.

**Fallback reason** — The explanation associated with a `Fallback` result. An application with multiple fallback failures reports one deterministic representative reason.
